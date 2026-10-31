params [["_anchor", objNull, [objNull]]];
/*
    AP_fnc_fabAnim  -- move a multi-part fabricator's parts while it prints, client-side.

    One loop per client per anchor, alive while the anchor's body is drawn (AP_fnc_fabModelClear
    ends it). All state is read from the anchor, so every client computes the same pose:

      AP_fabRun = [start, end]   serverTime; published by APS_fnc_fabSRV on "queue" and on the
                                 boot respawn. printing = serverTime < end; print time
                                 t = clamp(serverTime - start, 0, end - start) -- frozen at the
                                 last pose when idle, exactly the design page's poseF770.
      AP_fabSpec                 the generated data row: lift, rest offsets, and the print-cycle
                                 constants [PASS s, XT m, ZT m, NPASS, LAYER m, NLAYERS] read
                                 out of f770.js by the builder.

    Pose (poseF770): PASS-second passes across X with a smoothstep, direction alternating per pass;
    NPASS passes per layer sweep the head across Z, boustrophedon; the platform drops LAYER metres
    per layer and resets after NLAYERS (the demo loop). The head rides the bridge, so its offset
    carries the bridge's dx as well as its own dz. Offsets are attachTo [right, forward, up]:
    design X -> right, design Z (front +) -> forward, design Y (up) -> up.

    Screens: two coplanar quads, READY shown when idle and PRINTING while printing (hideObject is a
    local effect, which is all a client-local object needs).

    Tick 0.05 s within 120 m while printing (a 1.3 s pass over 0.56 m is ~2 cm a tick); 0.5 s when
    idle or far, like the rig's far rule -- an idle machine only needs to notice a new window.
*/
if (isNull _anchor || {!hasInterface}) exitWith {};
if (_anchor getVariable ["AP_fabAnimUp", false]) exitWith {};
_anchor setVariable ["AP_fabAnimUp", true];
private _spec = _anchor getVariable ["AP_fabSpec", []];
private _parts = _anchor getVariable ["AP_fabParts", createHashMap];
if (_spec isEqualTo [] || {count _parts isEqualTo 0}) exitWith { _anchor setVariable ["AP_fabAnimUp", false]; };
private _lift = _spec select 2;
(_spec select 4) params ["_pass", "_xt", "_zt", "_npass", "_layerM", "_nlayers"];

private _place = {
    params ["_key", "_dx", "_dfwd", "_dup"];
    private _e = _parts getOrDefault [_key, []];
    if (_e isEqualTo []) exitWith {};
    _e params ["_o", "_off"];
    if (isNull _o) exitWith {};
    _o attachTo [_anchor, [(_off select 0) + _dx, (_off select 1) + _dfwd, (_off select 2) + _lift + _dup]];
};

private _shown = "";
private _lastPose = [];
while { !isNull _anchor && { !isNull (_anchor getVariable ["AP_fabModel", objNull]) } } do {
    (_anchor getVariable ["AP_fabRun", [0, 0]]) params [["_t0", 0, [0]], ["_t1", 0, [0]]];
    private _printing = serverTime < _t1;
    private _t = ((serverTime - _t0) max 0) min ((_t1 - _t0) max 0);
    private _far = (player distance _anchor) > 120;

    private _p = floor (_t / _pass);
    private _k = (_t mod _pass) / _pass;
    private _s = _k * _k * (3 - 2 * _k);
    private _dx = ([1, -1] select ((_p mod 2) isEqualTo 1)) * (-_xt + 2 * _xt * _s);
    private _layer = floor (_p / _npass);
    private _i = _p mod _npass;
    private _sweep = [_i, _npass - 1 - _i] select ((_layer mod 2) isEqualTo 1);
    private _dz = -_zt + (2 * _zt * _sweep) / (_npass - 1);
    private _dy = -(_layer mod _nlayers) * _layerM;
    private _pose = [_dx, _dz, _dy];
    if (_pose isNotEqualTo _lastPose) then {
        ["bridge", _dx, 0, 0] call _place;
        ["head", _dx, _dz, 0] call _place;
        ["platform", 0, 0, _dy] call _place;
        _lastPose = _pose;
    };

    private _want = ["screen_ready", "screen_printing"] select _printing;
    if (_want isNotEqualTo _shown) then {
        {
            private _e = _parts getOrDefault [_x, []];
            if (_e isNotEqualTo []) then { (_e select 0) hideObject (_x isNotEqualTo _want); };
        } forEach ["screen_ready", "screen_printing"];
        _shown = _want;
    };
    uiSleep ([0.05, 0.5] select (_far || {!_printing}));
};
_anchor setVariable ["AP_fabAnimUp", false];
