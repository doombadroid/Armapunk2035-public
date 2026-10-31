/*
    fn_uiTexManager.sqf  (AP_fnc_uiTexManager) -- ONE pump for every live HTML texture on this client,
    capped to the nearest AP_uiTexCap (20) objects. Owner 2026-09-06: "cap live html surfaces to nearest
    20 cars" -- the bench showed ~0.3 ms of frame time per pumped surface and a hard 30 fps floor past
    about sixty, so the budget is a count, not a distance.

        [_obj, "apstatic_2_5297"] call AP_fnc_uiTexManager;          // register: pump this display for this object
        [_obj, "apstatic_2_5297", false] call AP_fnc_uiTexManager;   // unregister (the caller closes the display)
        AP_uiTexCap = 20;                                              // live at any time

    HOW IT CAPS. Every frame the registry is pruned of null objects and displays, sorted by distance
    from the CAMERA (not the player -- a spectator or a PiP shot sees what the camera sees), and only
    the first AP_uiTexCap get displayUpdate. A ui2texture display that is not updated is frozen on its
    last frame at zero readback cost -- but its Chromium keeps painting in its own process, so a
    surface that drops out of the top N also gets "StopBrowser" on its control, and "ResumeBrowser"
    when it climbs back in (the page reloads; for a noise or animation page that is invisible). That
    is what makes the cap a cost cap rather than a readback cap.

    Callers: fn_skinStaticPump (the 2 s reskin static, every viewer), fn_uiTexMatrix, fn_uiTexHolo,
    fn_uiTexBench (which raises the cap to N for the run, so it still measures the raw cost).
*/
params [["_obj", objNull, [objNull]], ["_name", "", [""]], ["_on", true, [true]]];
if (!hasInterface) exitWith {};
if (isNil "AP_uiTexReg") then { AP_uiTexReg = []; };
if (isNil "AP_uiTexCap") then { AP_uiTexCap = 20; };

// Registrations are keyed by OBJECT + display (owner 2026-09-06, siren swap): several cars can wear one
// live display and one of them switching skins must not stop the pump for the others. Each frame the
// display is pumped once, for its nearest wearer.
if (_name isNotEqualTo "") then {
    private _i = AP_uiTexReg findIf { ((_x select 1) isEqualTo _name) && {(_x select 0) isEqualTo _obj} };
    if (_on) then {
        if (_i isEqualTo -1) then { AP_uiTexReg pushBack [_obj, _name, true]; };
    } else {
        if (_i > -1) then { AP_uiTexReg deleteAt _i; };
    };
};

if (isNil "AP_uiTexManagerEH") then {
    AP_uiTexManagerEH = addMissionEventHandler ["EachFrame", {
        if (AP_uiTexReg isEqualTo []) exitWith {};
        private _cam = positionCameraToWorld [0, 0, 0];
        // prune on a null OBJECT only. The display is created by the engine's FIRST DRAW of the texture,
        // which is a second or more after registration -- pruning on a null display (b0962-b0965) dropped
        // every entry before it could ever be pumped, and every live surface froze on a black first frame.
        AP_uiTexReg = AP_uiTexReg select { !isNull (_x select 0) };
        private _sorted = [AP_uiTexReg, [], { (_x select 0) distance _cam }, "ASCEND"] call BIS_fnc_sortBy;
        private _seen = []; private _pumped = 0;
        {
            _x params ["_o", "_n", "_live"];
            if (_n in _seen) then { continue };   // this display already handled for a nearer wearer
            _seen pushBack _n;
            private _d = findDisplay _n;
            if (isNull _d) then { continue };   // not drawn yet; pump it the frame it exists
            _pumped = _pumped + 1;
            if (_pumped <= AP_uiTexCap) then {
                if (!_live) then {
                    private _c = (allControls _d) param [0, controlNull];
                    if (!isNull _c) then { _c ctrlWebBrowserAction ["ResumeBrowser"]; };
                    _x set [2, true];
                };
                displayUpdate _d;
            } else {
                if (_live) then {
                    private _c = (allControls _d) param [0, controlNull];
                    if (!isNull _c) then { _c ctrlWebBrowserAction ["StopBrowser"]; };
                    _x set [2, false];
                };
            };
        } forEach _sorted;
        AP_uiTexReg = _sorted;
    }];
};
