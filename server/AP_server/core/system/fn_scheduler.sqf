/*
    APS_fnc_scheduler — LooneyBin single-wheel server task scheduler (singleevh.md Phase 1).

    Replaces the ~24 permanent `spawn { while {true} do { ...work...; sleep N } }` server loops with ONE
    master wheel that fires registered jobs on their interval. Each due job runs in a SHORT TRANSIENT spawn
    (error-isolated + non-blocking) guarded against overlap. Wins vs per-loop permanent spawns:
      - far fewer permanent scheduled scripts (Arma round-robins a limited budget -> less drift under load),
      - phase JITTER: same-interval jobs (many at 300s) get random start phases so they don't "herd" and
        hammer the serialized DB_Async_Active mutex in the same window,
      - one introspection dashboard (AP_fnc_schedulerDump),
      - per-job error isolation + auto-disable after repeated failures (a legacy `while{true}` loop that
        throws is DEAD until restart; a wheel job just logs + retries, or self-disables),
      - a stale-run watchdog that reclaims a job whose transient run errored/hung without clearing its flag.

    UNCONDITIONAL since 2026-07-24. The wheel starts at server init and runs every registered job.

    There was a AP_useScheduler flag here, with every migration site written as
    `if (AP_useScheduler) then {register} else {legacy spawn}`, so flipping it off reverted to the original
    per-loop spawns. That rollback was real and it worked -- it was simply never used. The wheel went live
    2026-07-05 and across 183 archived server RPTs the flag-off path never logged once, so the second copy of
    all 22 jobs was 791 lines of code that had never executed. Removed, along with the flag.

    Stop control is AP_schedulerRunning: set it false and the wheel winds down after the current pass.
    Note what that does and does not mean -- there is no fallback any more, so stopping the wheel stops the
    jobs. That is the honest trade for deleting the legacy path; do not read it as a revert.

    Read at server INIT. Server-only.

    Install once at server init: `call APS_fnc_scheduler;` (defines the API below + the job store).
    API:
      [_id,_fn,_interval,_runAtStart,_jitter] call AP_fnc_schedule   // register/replace a job (idempotent by _id)
      [_id] call AP_fnc_unschedule                                   // remove a job
      call AP_fnc_schedulerStart                                     // start the wheel (idempotent)
      call AP_fnc_schedulerDump                                      // -> [[id,intervalS,dueInS,enabled,errCount,lastMs,inFlight],..]; also diag_logs

    Job tuple in localNamespace "AP_scheduler_jobs" (hashMap: id -> tuple; localNamespace because the tuples hold CODE and publicVariable cannot reach it):
      [0 _fn, 1 _interval, 2 _nextRunTt, 3 _inFlight, 4 _enabled, 5 _errCount, 6 _lastMs, 7 _inFlightSince, 8 _label, 9 _state]

    CALLBACK gets its persistent per-job STATE hashMap: `{ params ["_st"]; ... }`. Use it for:
      - cross-iteration state (de-dupe / edge-detector / accumulators) a closure can't capture from the enclosing
        scope: `private _last = _st getOrDefault ["last", -1]; ...; _st set ["last", _v];`
      - ONE-SHOT boot setup that used to sit before the loop (waitUntil an object, place a prop, seed config):
        `if !(_st getOrDefault ["init", false]) then { <setup -- may suspend, jobs run in a spawn>; _st set ["init", true]; };`
      - SELF-EXIT of a conditional-while loop: `if (<done>) exitWith { [<id>] call AP_fnc_unschedule; };`
    State persists for the job's lifetime; fresh on re-register.
*/
if (!isServer) exitWith {};   // the scheduler is the SERVER heartbeat only

if (isNil {localNamespace getVariable "AP_scheduler_jobs"}) then { localNamespace setVariable ["AP_scheduler_jobs", createHashMap]; };
if (isNil "AP_schedulerRunning")  then { AP_schedulerRunning = false; };
AP_scheduler_staleGrace = 60;   // seconds past a run's own interval before an in-flight run is presumed dead
AP_scheduler_maxErrors  = 5;    // consecutive stale/error reclaims before a job auto-disables

AP_fnc_schedule = compileFinal {
    params [["_id","",[""]], ["_fn",{},[{}]], ["_interval",60,[0]], ["_runAtStart",false,[false]], ["_jitter",true,[false]]];
    if (_id isEqualTo "") exitWith { diag_log "[PLB-sched] schedule rejected: empty id"; "" };
    if (_interval <= 0)   exitWith { diag_log format ["[PLB-sched] schedule rejected: bad interval %1 for %2", _interval, _id]; "" };
    private _now = diag_tickTime;
    // JITTER: spread same-interval jobs across their window so they don't all fire together and herd on the DB mutex.
    private _first = if (_runAtStart) then { _now } else { _now + (if (_jitter) then { random _interval } else { _interval }) };
    // idempotent by id (replace) -> JIP / re-init can never double-register the same job.
    (localNamespace getVariable "AP_scheduler_jobs") set [_id, [_fn, _interval, _first, false, true, 0, 0, 0, _id, createHashMap]];   // elem 9 = per-job persistent state
    _id};

AP_fnc_unschedule = compileFinal {params [["_id","",[""]]];
    (localNamespace getVariable "AP_scheduler_jobs") deleteAt _id;};

AP_fnc_schedulerStart = compileFinal {if (!isServer) exitWith {};
    if (AP_schedulerRunning) exitWith {};                                  // idempotent — one wheel only
    AP_schedulerRunning = true;
    diag_log "[PLB-sched] wheel STARTED";
    [] spawn {
        // AP_schedulerRunning is the stop control now: set it false and the wheel winds down after
        // the current pass. It replaced AP_useScheduler when that flag was retired (2026-07-24).
        while { AP_schedulerRunning } do {private _now = diag_tickTime; {
                private _job     = _y;                                       // shared reference — set[] mutates in place
                private _enabled = _job select 4;
                private _inFlight = _job select 3;
                // stale-run watchdog: a run in-flight past (interval + grace) is presumed dead (its transient
                // spawn errored/hung and never cleared the flag) -> reclaim it so the job can fire again, and
                // count it against the auto-disable budget.
                if (_inFlight && {(_now - (_job select 7)) > ((_job select 1) + AP_scheduler_staleGrace)}) then {
                    _job set [3, false]; _inFlight = false;
                    _job set [5, (_job select 5) + 1];
                    diag_log format ["[PLB-sched] job '%1' stale run reclaimed (errCount %2)", _job select 8, _job select 5];
                    if ((_job select 5) >= AP_scheduler_maxErrors) then {_job set [4, false]; _enabled = false;
                        diag_log format ["[PLB-sched] job '%1' AUTO-DISABLED after %2 failed runs", _job select 8, _job select 5];};};
                if (_enabled && {!_inFlight} && {_now >= (_job select 2)}) then {
                    _job set [2, _now + (_job select 1)];                    // schedule next fire
                    _job set [3, true];                                      // mark in-flight
                    _job set [7, _now];                                      // in-flight since (for the watchdog)
                    // Run the body in an ISOLATED transient spawn: a runtime error aborts ONLY this spawn (logged
                    // to RPT) and never the wheel or sibling jobs. On clean completion it records duration, resets
                    // the error count, and clears in-flight. On error the watchdog above reclaims the flag.
                    [_job] spawn {params ["_j"];
                        private _t0 = diag_tickTime;
                        [(_j select 9)] call (_j select 0);                  // callback gets its persistent state hashMap: params ["_st"] (may suspend / hit DB)
                        _j set [6, round ((diag_tickTime - _t0) * 1000)];    // last run ms
                        _j set [5, 0];                                       // success -> clear consecutive-error count
                        _j set [3, false];                                   // clear in-flight
                    };};} forEach (localNamespace getVariable "AP_scheduler_jobs");
            uiSleep 1;                                                       // base granularity (5s..3600s jobs quantize fine)
        };
        AP_schedulerRunning = false;
        diag_log "[PLB-sched] wheel STOPPED (AP_schedulerRunning cleared)";};};

AP_fnc_schedulerDump = compileFinal {private _now = diag_tickTime;
    private _out = []; {private _j = _y;
        _out pushBack [_x, _j select 1, round ((_j select 2) - _now), _j select 4, _j select 5, _j select 6, _j select 3];
    } forEach (localNamespace getVariable "AP_scheduler_jobs");
    _out sort true;
    diag_log format ["[PLB-sched] DUMP — %1 jobs, wheel running=%2  [id, intervalS, dueInS, enabled, errCount, lastMs, inFlight]:", count _out, AP_schedulerRunning];
    { diag_log format ["    %1", _x]; } forEach _out;
    _out};

diag_log "[PLB-sched] API installed (schedule / unschedule / schedulerStart / schedulerDump)";
true
