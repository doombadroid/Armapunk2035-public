/*
    fn_uiTexMatrix.sqf  (AP_fnc_uiTexMatrix) -- PROOF OF CONCEPT, owner 2026-09-06.
    Paints an animated HTML page (ui\html\matrix.html) onto every hidden selection of a vehicle (car, heli, boat)
    through the engine's UI-on-texture procedural texture, so the car wears live Matrix rain.

        [] call AP_fnc_uiTexMatrix;            // the vehicle under the cursor, else nearest car/heli/boat within 15 m
        [_veh] call AP_fnc_uiTexMatrix;        // a specific vehicle
        [_veh] call AP_fnc_uiTexMatrix;        // AGAIN on the same vehicle = switch it off, #reset the skins

    THE CHAIN IT PROVES: CT_WEBBROWSER (matrix.html) -> display AP_uiTexMatrix (uitex_matrix.hpp)
    -> #(rgb,1024,1024,1)uiEx(...) -> setObjectTexture on each hiddenSelection -> the car. Every link
    is documented by BI (Procedural Textures "UI On Texture", CT_WEBBROWSER "Seamless Stop/Resume"
    which describes "a ui2texture containing a browser"), and none of it has been seen on THIS client.
    The frame counter the page draws bottom-left is the pass/fail: climbing = live, stuck = the
    display rendered once, black = the browser never painted inside the texture.

    LOCAL ONLY, ON PURPOSE. setObjectTexture, not Global -- a probe should not broadcast a texture
    string every other client would then try to render. Going global later is a one-word change and
    is what AE3 does for static states only; it keeps the live display local per client.

    THE MIPMAP WORKAROUND is real and is lifted from AE3's shipped code: a display used by ui2texture
    must have been shown in normal UI once or its images fail with "Cannot load mipmap" (feedback
    T171035 / T170766). createDisplay + closeDisplay 1, once per session.

    THE DISPLAY IS CREATED BY THE FIRST TEXTURE DRAW, NOT BY THIS SCRIPT. findDisplay by the unique
    name (lowercase) returns displayNull until the engine has actually needed the texture once -- AE3
    waits for it the same way. The EachFrame pump tolerates that and starts updating when it appears.
    Without displayUpdate the texture is rendered once and never again; that is the "stuck at f 1"
    outcome, and it is a result, not a failure of the probe.

    Everything it learns goes to the RPT under [AP-PROBE] (owner standing order: probes log, the
    session reads the RPT).

    RESULT (owner, 2026-09-06, dev b0947, C_Hatchback_01_F, 1 selection): WORKS. The display appeared
    in the same frame the texture was applied (8645), the browser's first Draw came 54 frames later,
    then Draw #60 at +59 frames and #600 at +540 -- one browser paint per game frame, so the rain runs
    at full frame rate on the car. Two notes from that run: after #reset the ui2texture display had
    already gone (closeDisplay found nothing), so the engine drops a display no texture references;
    and the second run on the same car did not re-log "appeared" because AP_uiTexSeen survived the
    OFF path -- cleared there now.
*/
params [["_veh", objNull, [objNull]]];
if (!hasInterface) exitWith {};

if (isNull _veh) then {
    _veh = cursorObject;
    // Any vehicle with hidden selections will do -- helicopters and boats too (owner 2026-09-07). The
    // selection count check below is what actually decides whether there is anything to paint on.
    if (isNull _veh || {!(_veh isKindOf "LandVehicle" || {_veh isKindOf "Air"} || {_veh isKindOf "Ship"})}) then {
        _veh = (nearestObjects [player, ["Car", "Air", "Ship"], 15]) param [0, objNull];
    };
};
if (isNull _veh) exitWith { ["No vehicle under the cursor or within 15 m.", "basic"] spawn AP_fnc_handleMessage; };

// ---- second call on the same car: stop the pump and put the paint back ----
private _eh = _veh getVariable ["AP_uiTexEH", -1];
if (_eh > -1) exitWith {
    removeMissionEventHandler ["EachFrame", _eh];
    [_veh, _veh getVariable ["AP_uiTexName", ""], false] call AP_fnc_uiTexManager;
    _veh setVariable ["AP_uiTexEH", nil];
    private _n = count (_veh getObjectTextures []);
    for "_i" from 0 to (_n - 1) do { _veh setObjectTexture [_i, "#reset"]; };
    private _d = findDisplay (_veh getVariable ["AP_uiTexName", ""]);
    if (!isNull _d) then { _d closeDisplay 1; };
    diag_log format ["[AP-PROBE] uiTexMatrix OFF %1 -- %2 selection(s) reset, display closed=%3", typeOf _veh, _n, !isNull _d];
    ["Matrix off.", "basic"] spawn AP_fnc_handleMessage;
};

// ---- can this object be textured at all? ----
private _defaults = _veh getObjectTextures [];
private _n = count _defaults;
diag_log format ["[AP-PROBE] uiTexMatrix target %1 netId=%2 selections=%3 defaults=%4", typeOf _veh, netId _veh, _n, _defaults];
if (_n isEqualTo 0) exitWith {
    ["That object has no hidden selections -- nothing to paint on.", "basic"] spawn AP_fnc_handleMessage;
};

// ---- mipmap workaround: show the display once in normal UI, then drop it ----
if (isNil "AP_uiTexMatrixPreloaded") then {
    private _tmp = (findDisplay 46) createDisplay "AP_uiTexMatrix";
    diag_log format ["[AP-PROBE] uiTexMatrix preload display=%1", _tmp];
    _tmp closeDisplay 1;
    AP_uiTexMatrixPreloaded = true;
};

// ---- the texture string. uniqueName must be [a-zA-Z0-9_]; netId is "n:m". ----
private _name = toLower ("apmatrix_" + ((netId _veh) regexReplace ["[^0-9A-Za-z]", "_"]));
private _tex = format ["#(rgb,1024,1024,1)uiEx(display:AP_uiTexMatrix,uniqueName:%1,bgColor:#000000ff)", _name];
_veh setVariable ["AP_uiTexName", _name];
for "_i" from 0 to (_n - 1) do { _veh setObjectTexture [_i, _tex]; };
diag_log format ["[AP-PROBE] uiTexMatrix applied %1 to %2 selection(s): %3", _name, _n, _tex];

// ---- the pump: tell the display to re-render every frame, once it exists ----
_eh = addMissionEventHandler ["EachFrame", {
    _thisArgs params ["_veh", "_name"];
    if (isNull _veh) exitWith { removeMissionEventHandler ["EachFrame", _thisEventHandler]; };
    private _d = findDisplay _name;
    if (isNull _d) exitWith {};
    if !(_veh getVariable ["AP_uiTexSeen", false]) then {
        _veh setVariable ["AP_uiTexSeen", true];
        diag_log format ["[AP-PROBE] uiTexMatrix display %1 appeared at frame %2 (ctrls=%3)", _name, diag_frameNo, count (allControls _d)];
        // Count browser paints: "Draw" fires when Chromium painted a frame. If this never logs,
        // the display exists but the browser inside it is not rendering.
        private _ctrl = _d displayCtrl 941901;
        if (!isNull _ctrl) then {
            _ctrl ctrlAddEventHandler ["Draw", {
                private _c = (_this select 0) getVariable ["AP_draws", 0];
                _c = _c + 1;
                (_this select 0) setVariable ["AP_draws", _c];
                if (_c in [1, 60, 600]) then { diag_log format ["[AP-PROBE] uiTexMatrix browser Draw #%1 at frame %2", _c, diag_frameNo]; };
            }];
        };
    };
    // pumping is the manager's job now (capped to the nearest AP_uiTexCap surfaces); this handler only
    // watches for the display to appear and arms the Draw counter
}, [_veh, _name]];
[_veh, _name] call AP_fnc_uiTexManager;
_veh setVariable ["AP_uiTexEH", _eh];
["Matrix on. Look at the car; the counter bottom-left of each panel should climb.", "basic"] spawn AP_fnc_handleMessage;
