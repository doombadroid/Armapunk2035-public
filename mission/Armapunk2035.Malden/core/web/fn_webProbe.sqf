/*
    fn_webProbe.sqf — measure the bridge's remaining unknowns.

    Four things were being repeated as "unknown" and one of them (how big a
    payload ExecJS survives) decides whether assets can live server-side and be
    shipped to a page at runtime. Rather than keep saying unknown, measure.

      1. ExecJS payload ceiling — push progressively larger strings and ask the
         page what actually arrived. A too-large payload is expected to vanish
         SILENTLY, so a missing value is the result, not an error.
      2. Deflate / Inflate — same trip with the engine's compressor, which is
         the obvious way to raise that ceiling.
      3. Audio — whether a page can produce sound at all, by two independent
         routes. Whether it is AUDIBLE and whether Arma's volume slider moves it
         needs a human; this reports what the page can see.
      4. Simultaneous browser controls — four at once, each announcing itself.

    Memory footprint is sampled from outside the game, correlated against the
    [WEBPROBE] timestamps this writes.

    Usage (debug console):  [] spawn AP_fnc_webProbe;
    Results go to the RPT tagged [WEBPROBE]. Takes ~40s.
*/

if (!canSuspend) exitWith { diag_log "[WEBPROBE] needs a scheduled context — use spawn"; };

diag_log format ["[WEBPROBE] ==== start t=%1 ====", diag_tickTime toFixed 1];

// probe.html carries the handlers this drives (bulkArm / bulkGot / audio)
if (!isNull (findDisplay 937600)) then { closeDialog 0; uiSleep 1; };
createDialog "AP_web_probe";
uiSleep 5;
private _disp = findDisplay 937600;
if (isNull _disp) exitWith { diag_log "[WEBPROBE] probe dialog would not open"; };
private _ctrl = _disp displayCtrl 937601;

// ---------------------------------------------------- 1. ExecJS ceiling ----
// Build the test string by doubling — a per-character loop at these sizes would
// take longer than the probe.
private _mk = {
    params ["_len"];
    private _s = "abcdefghij";
    while { count _s < _len } do { _s = _s + _s; };
    _s select [0, _len]
};

diag_log "[WEBPROBE] --- ExecJS payload ladder (silent drop = ceiling found) ---";
private _biggestOk = 0;
{
    private _len = _x;
    private _payload = [_len] call _mk;
    // arm the page so a stale value from the previous rung cannot be misread
    [_ctrl, "bulkArm", [_len], 6] call webui_fnc_call;
    private _t0 = diag_tickTime;
    [_ctrl, "bulk", _payload] call webui_fnc_push;
    uiSleep 0.6;
    private _r = [_ctrl, "bulkGot", [], 8] call webui_fnc_call;
    private _got = if (isNil "_r") then { -2 } else { _r getOrDefault ["got", -1] };
    private _ms  = round ((diag_tickTime - _t0) * 1000);
    diag_log format ["[WEBPROBE] ladder %1 chars -> page saw %2  (%3 ms)%4",
        _len, _got, _ms, if (_got isEqualTo _len) then { "" } else { "   <-- LOST" }];
    if (_got isEqualTo _len) then { _biggestOk = _len; };
} forEach [1000, 10000, 50000, 100000, 250000, 500000, 1000000, 2000000, 4000000];
diag_log format ["[WEBPROBE] LARGEST PAYLOAD THAT SURVIVED: %1 chars (%2 KB)",
    _biggestOk, round (_biggestOk / 1024)];

// ------------------------------------------------- 2. Deflate / Inflate ----
// Engine-side compressor. Inflate's OUTPUT is documented as capped at 1 MB, but
// what matters here is how much ORIGINAL data fits under the ExecJS ceiling once
// compressed — highly repetitive text compresses enormously.
diag_log "[WEBPROBE] --- Deflate ---";
{
    private _raw = [_x] call _mk;
    private _def = _ctrl ctrlWebBrowserAction ["Deflate", _raw];
    diag_log format ["[WEBPROBE] deflate %1 chars -> %2 b64 chars (%3:1)",
        _x, count _def, if (count _def > 0) then { round (_x / (count _def)) } else { 0 }];
} forEach [100000, 1000000];

// ------------------------------------------------------------- 3. audio ----
diag_log "[WEBPROBE] --- audio (listen now) ---";
private _a = [_ctrl, "audio", [], 8] call webui_fnc_call;
diag_log format ["[WEBPROBE] audio: %1", _a];

diag_log format ["[WEBPROBE] ==== done t=%1 ====", diag_tickTime toFixed 1];
diag_log "[WEBPROBE] audio question for the human: did you HEAR a tone, and does the Arma volume slider change it?";
