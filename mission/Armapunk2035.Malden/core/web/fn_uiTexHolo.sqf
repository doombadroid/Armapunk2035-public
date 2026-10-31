/*
    fn_uiTexHolo.sqf  (AP_fnc_uiTexHolo) -- PROOF OF CONCEPT 3, owner 2026-09-06: "pure html 3d".
    The hologram is ON THE CAR'S OWN PAINT, and the depth is faked by the page from the viewer's angle.

        [] call AP_fnc_uiTexHolo;            // the car under the cursor, else nearest within 15 m
        [_veh] call AP_fnc_uiTexHolo;        // a specific car; again on the same car = off, #reset paint + material
        [_veh, false] call AP_fnc_uiTexHolo; // no emissive material (flat, unlit page)

    WHY NOT A SHELL. v2 inflated a simple copy of the car 10% and textured that, so the art physically
    floated off the paint. The owner killed it: a second body chasing the first will look glitchy the
    moment the car moves, and it is not "HTML doing 3D", it is geometry doing it. Gone. No shell, no
    lightpoint, nothing attached. One object, its own hidden selections, one texture string.

    WHAT "3D" MEANS WHEN A TEXTURE CANNOT LEAVE ITS SURFACE: view-dependent parallax. Every frame SQF
    pushes the page WHERE THE CAMERA IS in the car's own model space, and the page slides its depth
    layers against each other by the tangential component of that view vector -- far layer shifts
    with the eye, near layer against it, type gets an extruded stack that fans out as you walk
    round. Look straight at a panel, it is flat art; look along it, the layers separate. It is the
    same trick parallax mapping does in a shader, done in canvas from one vector at ~30 Hz through
    the same webui push every deck page uses. It is per-texture, not per-face: one car, one UV
    sheet, one view vector, so the shift direction is exact for the panel facing you and merely
    plausible for the rest. That is the honest ceiling of "pure HTML 3D" on a flat hidden selection.

    GLOW is setObjectMaterial with ap_vendsign.rvmat on the same selections (emissive 45): the page's
    bright pixels self-light after dark, and the transparent ground stays whatever the paint is.
    "#reset" (2.20) puts both texture and material back on the second call.

    Same mipmap preload, same display-appears-on-first-draw pump, same [AP-PROBE] logging as the
    matrix probe that proved the chain; bridge attached to the browser INSIDE the ui2texture display
    (proven on b0951: "bridge attached", page-to-SQF calls landed from frame +3).
*/
params [["_veh", objNull, [objNull]], ["_glow", true, [true]]];
if (!hasInterface) exitWith {};

if (isNull _veh) then {
    _veh = cursorObject;
    if (isNull _veh || {!(_veh isKindOf "LandVehicle")}) then {
        _veh = (nearestObjects [player, ["Car"], 15]) param [0, objNull];
    };
};
if (isNull _veh) exitWith { ["No car under the cursor or within 15 m.", "basic"] spawn AP_fnc_handleMessage; };

// ---- second call: pump off, paint and material back ----
private _eh = _veh getVariable ["AP_holoEH", -1];
if (_eh > -1) exitWith {
    removeMissionEventHandler ["EachFrame", _eh];
    [_veh, _veh getVariable ["AP_holoName", ""], false] call AP_fnc_uiTexManager;
    private _n = count (_veh getObjectTextures []);
    for "_i" from 0 to (_n - 1) do { _veh setObjectTexture [_i, "#reset"]; _veh setObjectMaterial [_i, "#reset"]; };
    private _d = findDisplay (_veh getVariable ["AP_holoName", ""]);
    if (!isNull _d) then { _d closeDisplay 1; };
    { _veh setVariable [_x, nil] } forEach ["AP_holoEH", "AP_holoName", "AP_holoSeen", "AP_holoCtrl"];
    diag_log format ["[AP-PROBE] uiTexHolo OFF %1 -- %2 selection(s) reset", typeOf _veh, _n];
    ["Hologram off.", "basic"] spawn AP_fnc_handleMessage;
};

private _n = count (_veh getObjectTextures []);
diag_log format ["[AP-PROBE] uiTexHolo v3 target %1 selections=%2 glow=%3", typeOf _veh, _n, _glow];
if (_n isEqualTo 0) exitWith { ["That class has no hidden selections -- nothing to paint on.", "basic"] spawn AP_fnc_handleMessage; };

if (isNil "AP_uiTexHoloPreloaded") then {
    private _tmp = (findDisplay 46) createDisplay "AP_uiTexHolo";
    _tmp closeDisplay 1;
    AP_uiTexHoloPreloaded = true;
};

private _name = toLower ("apholo_" + ((netId _veh) regexReplace ["[^0-9A-Za-z]", "_"]));
private _tex = format ["#(rgb,1024,1024,1)uiEx(display:AP_uiTexHolo,uniqueName:%1)", _name];
for "_i" from 0 to (_n - 1) do {
    _veh setObjectTexture [_i, _tex];
    if (_glow) then { _veh setObjectMaterial [_i, "mpmissions\__cur_mp.Malden\ap_vendsign.rvmat"]; };
};
_veh setVariable ["AP_holoName", _name];
diag_log format ["[AP-PROBE] uiTexHolo applied %1 to %2 selection(s) of the car itself", _name, _n];

_eh = addMissionEventHandler ["EachFrame", {
    _thisArgs params ["_veh", "_name"];
    if (isNull _veh) exitWith { removeMissionEventHandler ["EachFrame", _thisEventHandler]; };
    private _d = findDisplay _name;
    if (isNull _d) exitWith {};
    if !(_veh getVariable ["AP_holoSeen", false]) then {
        _veh setVariable ["AP_holoSeen", true];
        diag_log format ["[AP-PROBE] uiTexHolo display %1 appeared at frame %2", _name, diag_frameNo];
        private _ctrl = _d displayCtrl 941911;
        if (!isNull _ctrl) then {
            if ([_ctrl] call webui_fnc_init) then {
                _veh setVariable ["AP_holoCtrl", _ctrl];
                diag_log format ["[AP-PROBE] uiTexHolo bridge attached to the in-texture browser %1 -- pushing 'view' at ~30 Hz", _ctrl];
            } else {
                diag_log "[AP-PROBE] uiTexHolo bridge init FAILED -- the page will animate but not parallax";
            };
            _ctrl ctrlAddEventHandler ["Draw", {
                private _c = ((_this select 0) getVariable ["AP_draws", 0]) + 1;
                (_this select 0) setVariable ["AP_draws", _c];
                if (_c in [1, 60, 600]) then { diag_log format ["[AP-PROBE] uiTexHolo browser Draw #%1 at frame %2", _c, diag_frameNo]; };
            }];
        };
    };
    // pumping is the manager's job now (capped to the nearest AP_uiTexCap surfaces)
    // THE VIEW VECTOR: the camera in the car's model space, unit length, ~30 Hz. x = across the car
    // (right +), y = along it (forward +), z = up. The page turns x and y into parallax.
    private _ctrl = _veh getVariable ["AP_holoCtrl", controlNull];
    if (!isNull _ctrl && {(diag_frameNo mod 2) isEqualTo 0}) then {
        private _v = vectorNormalized (_veh worldToModelVisual (positionCameraToWorld [0, 0, 0]));
        [_ctrl, "view", [(_v select 0) toFixed 3, (_v select 1) toFixed 3, (_v select 2) toFixed 3, (player distance _veh) toFixed 1]] call webui_fnc_push;
    };
}, [_veh, _name]];
[_veh, _name] call AP_fnc_uiTexManager;
_veh setVariable ["AP_holoEH", _eh];
["Hologram on. Walk round the car -- the layers should slide against each other as your angle changes.", "basic"] spawn AP_fnc_handleMessage;
