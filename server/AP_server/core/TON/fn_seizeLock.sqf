/*
    APS_fnc_seizeLock  (LooneyBin, owner 2026-06-18, BUGS #363)
    SERVER-authoritative seize lock -- kills the concurrent-seize MONEY DUPE shared by all three cop seize
    flows (fn_vehBaseSeize / fn_vehicleInvSeize / fn_seizeIllegalTent). The old AP_seizing test+set was done
    CLIENT-side via an async public setVariable, so two cops both passed the "already being seized?" check
    before either broadcast landed -> both ran the seize -> APS_fnc_copSplit fired twice = everyone paid double.

    ATOMICITY (load-bearing): the callers invoke this UNSCHEDULED via remoteExecCall (AP_fnc_MP 5th arg
    _isCall=true). Unscheduled SQF runs to completion without time-slicing, so the test-and-set in the ACQUIRE
    path below cannot be interrupted between the getVariable and the setVariable -> exactly ONE of N concurrent
    cops wins. Do NOT switch the callers to spawn/remoteExec (scheduled) -- a scheduled script CAN be suspended
    between statements when the per-frame budget is hit, which re-opens the race. Also keep this fn suspend-free.

    Client args: [_vehicle, _mode]   (_mode "acquire" | "release").
      acquire -> replies on the caller via AP_seizeAcquired (publicVariableClient): 1 = you got it, 0 = busy.
    State:  AP_seizeLockMeta = [serverTime, ownerId]   (server-only -- the atomic key + 30s stale auto-release
                                                          so a cop dc/crash mid-seize can't lock a vehicle forever)
            AP_seizing       = true / nil               (broadcast bool -- what the existing readers check:
                                                          fn_openInventory, fn_inventoryOpened, the 3 seize fns)
*/
params [["_vehicle", objNull, [objNull]], ["_mode", "acquire", [""]]];
private _caller = remoteExecutedOwner;

if (isNull _vehicle) exitWith {
    if (_mode isEqualTo "acquire") then { AP_seizeAcquired = 0; _caller publicVariableClient "AP_seizeAcquired"; };};

if (_mode isEqualTo "release") exitWith {
    // only the HOLDER may release -- a stray / malicious release can't free someone else's lock (which would
    // re-open the race). Falls through (no-op) if the caller isn't the recorded owner; the 30s stale-guard backs it up.
    private _meta = _vehicle getVariable ["AP_seizeLockMeta", []];
    if ((_meta isEqualType []) && {count _meta >= 2} && {(_meta param [1, -1]) isEqualTo _caller}) then {
        _vehicle setVariable ["AP_seizeLockMeta", nil, false];
        _vehicle setVariable ["AP_seizing", nil, true];};};

// ----- ACQUIRE: atomic test-and-set. Do NOT add any suspending command between the getVariable and the two
// setVariables below, or the atomicity (and the whole fix) is lost. -----
private _meta = _vehicle getVariable ["AP_seizeLockMeta", []];
private _busy = (_meta isEqualType []) && {count _meta >= 1} && {(_meta param [0, 0]) > serverTime - 30};
if (_busy) exitWith { AP_seizeAcquired = 0; _caller publicVariableClient "AP_seizeAcquired"; };
_vehicle setVariable ["AP_seizeLockMeta", [serverTime, _caller], false];
_vehicle setVariable ["AP_seizing", true, true];
AP_seizeAcquired = 1;
_caller publicVariableClient "AP_seizeAcquired";
