/*
    fn_invFigure.sqf -- the WORN figure as the player's actual body. INVENTORY_SPEC.md §9.8.

        ["start", [fx, fy, fw, fh, ...]] call AP_fnc_invFigure   -> { ok, live, msg }
        ["stop"]                         call AP_fnc_invFigure

    A native picture control shows a render-to-texture camera at the strip the page reserves for
    the figure; the page reports the strip as fractions of the browser control ([fx, fy, fw, fh]).

    THE LAWS, each measured in a dev build on 2026-09-03 (INVENTORY_SPEC.md §9.8 has the story):
      1. Nothing native draws ABOVE the browser control -- a sibling declared or ctrlCreate'd after
         it never shows. The browser alpha-composites over controls drawn BEFORE it. So the figure
         group is declared before the Page control and the page masks a transparent hole at the
         strip (body.figlive #frame) for it to show through.
      2. The engine renders a PiP at the SCREEN's aspect and at a resolution capped by the PiP video
         setting (~1024x432 here), whatever texture size or shape is asked and whatever the r2t
         aspect parameter says (256x1024, 1024x2048 and aspect 0.46 were all tried). An upright body
         therefore gets ~2 px per texel at this strip size. Two stacked cameras (b0902-b0906) doubled
         that but never read as one body to the owner, so it is ONE camera at mid height again, and
         the player can DRAG THE STRIP TO TURN THE MANNEQUIN (invFigureRot) instead. Camera FOV has
         a floor near 0.086 (requests below render as 0.086 -- measured twice), so the camera sits
         where the needed FOV stays above it. camSetFov = tan(half vertical angle).
      3. ctrlSetAngle rotates within the control's own bounds (BIKI), so a rolled render cannot be
         turned upright without clipping -- that shortcut is closed.
      4. The studio is OFF-WORLD: a mannequin created LOCALLY (createVehicleLocal, no network object)
         300 m over the sea corner, copying the player's loadout, face and textures on every push,
         with a backdrop plane behind it. Planes attached to the real player blacked out the world the
         player sees around the dialog; attachTo children of an unsimulated parent are never placed,
         so the planes sit at absolute positions.
      5. LIGHT AND EXPOSURE. The PiP shares the main view's HDR adaptation, so an unlit studio
         rendered one backdrop texture three different colours depending on where the player stood;
         and at night there was nothing to see. So: the studio is a closed black box (roof, floor,
         walls, a wall behind the camera) with its own key and fill lightpoints, and the aperture is
         pinned (setAperture, AP_invFigAperture 20) while the figure is live, auto again on close.
         Under that the render is linear and time-of-day-proof, and the backdrop texture is the
         solved value for the page's --panel (#0c1622). A native static in the exact panel colour
         sits under the picture, so everything outside the render is exact.

    Falls back (live = false, the page keeps its silhouette) when PiP is off in the video options
    (isPiPEnabled), when the player is in a vehicle, or when the dialog is gone.

    Tunables (console, live): AP_invFigDist (m in front, 6.5), AP_invFigSide (m to the right, 0),
    AP_invFigBottom (-0.02) / AP_invFigTop (2.25) (the framed span, m above the feet), AP_invFigAperture (20),
    AP_invFigKey (4.0) / AP_invFigFill (2.0) (range-limited body lamps), AP_invFigNightAmbient (0.3 x (1 - sunOrMoon), the unlimited ambient lamp),
    AP_invFigBackdrop (procedural colour texture), AP_invFigIsolate (true), AP_invFigRes (2048),
    AP_invFigStudioPos ([200, 200, 300]).
*/
params [["_verb", "", [""]], ["_box", [], [[]]]];
private _disp = findDisplay 938500;
private _clip = _disp displayCtrl 938502;   // the controls group that crops the renders to the strip
private _pic  = _disp displayCtrl 938503;   // the picture (938504 is unused since the single-camera return)
private _fill = _disp displayCtrl 938505;   // panel-colour static under the pictures
private _page = _disp displayCtrl 938501;
private _fnOut = { params ["_live", ["_msg", ""]]; createHashMapFromArray [["ok", true], ["live", _live], ["msg", _msg]] };

// Each helper guards itself (security 2026-09-26): one isNil guard over the block let a value published
// under that one name skip every definition. core\init.sqf defines them all at client init ("boot"/"init").
    // THE DIAL (owner, 2026-09-04, hand-tuned in the console): one set for night, one for day, blended
    // on sunOrMoon (0 = night, 1 = day) -- aperture in log space (exposure is), lamps linearly. Setting
    // AP_invFigAperture / AP_invFigKey / AP_invFigFill / AP_invFigNightAmbient in the console overrides
    // the blend for that knob (nil = blended).
    if !(isFinal "AP_fnc_invFigTune") then {AP_fnc_invFigTune = compileFinal {
        private _d = sunOrMoon;
        private _pick = { params ["_var", "_night", "_day", "_log"];
            private _v = missionNamespace getVariable _var;
            if (!isNil "_v") exitWith { _v };
            if (_log) then { _night * ((_day / _night) ^ _d) } else { _night + (_day - _night) * _d }
        };
        [
            ["AP_invFigAperture", 8,   50,  true]  call _pick,
            ["AP_invFigKey",      4,   1.5, false] call _pick,
            ["AP_invFigFill",     2,   0.7, false] call _pick,
            ["AP_invFigNightAmbient", 0.4, 0, false] call _pick
        ]
    }};
    if !(isFinal "AP_fnc_invFigSync") then {AP_fnc_invFigSync = compileFinal {
        private _m = uiNamespace getVariable ["AP_invFigMan", objNull];
        if (isNull _m) exitWith {};
        _m setUnitLoadout [getUnitLoadout player, false];
        _m setFace (face player);
        { _m setObjectTexture [_forEachIndex, _x]; } forEach (getObjectTextures player);
        _m switchMove (if (primaryWeapon player != "") then { "AmovPercMstpSlowWrflDnon" } else { "AmovPercMstpSnonWnonDnon" });
    }};
    if !(isFinal "AP_fnc_invFigStudio") then {AP_fnc_invFigStudio = compileFinal {
        params [["_on", true]];
        { deleteVehicle _x } forEach (uiNamespace getVariable ["AP_invFigStudio", []]);
        uiNamespace setVariable ["AP_invFigStudio", []];
        uiNamespace setVariable ["AP_invFigMan", objNull];
        if (!_on) exitWith { false };
        private _base = missionNamespace getVariable ["AP_invFigStudioPos", [200, 200, 300]];
        private _man = "C_man_1" createVehicleLocal [0, 0, 0];
        if (isNull _man) exitWith { diag_log "[INV] figure: mannequin failed (createVehicleLocal)"; false };
        _man setPosASL _base;
        _man setDir 0;
        _man allowDamage false;
        _man enableSimulation false;
        uiNamespace setVariable ["AP_invFigMan", _man];
        call AP_fnc_invFigSync;
        // MEASURED 2026-09-03, single-tone studio frames under auto exposure: (7,14,23) -> (2,4,10),
        // (17,30,41) -> (37,59,79); this value is the interpolation for the page's --panel #0c1622
        // SOLVED 2026-09-03 (aperture 20, key 0.4 / fill 0.2): measured (0.10,0.15,0.20) -> (33,45,60)
        // (0.06,0.107,0.16) -> (20,33,50), (0.05,0.094,0.142) -> (17,30,45), (0.036,0.070,0.110) -> (0,0,4);
        // this value interpolates between them for the page's --panel #0c1622. Re-solve if the lights,
        // the aperture or the panel colour change.
        // ARGB, NOT RGB: #(rgb,...) procedural colours are DXT-compressed (5-6 bits per channel), so
        // 0.046 and 0.05 snapped to different levels and the render jumped 0 -> 17 between them; the
        // panel colour sits between two such levels. #(argb,...) is 8 bits per channel.
        // the render crushes textures below ~0.06 to black (a tonemapper toe), and the panel colour
        // needs ~0.05 under the body's light -- so the backdrop gets LESS light than the body (steep
        // attenuation, the backdrop 2.6 m further from the lamps) and a mid-tone texture, which the
        // render maps smoothly, lands on the panel. CALIBRATION ROUND: left 0.10, right 0.20.
        // MEASURED 2026-09-03 at the settled exposure (aperture 20, lamps 1.0/0.5, no ambient, backdrop
        // 4.4 m back): 0.05 -> 0 (crushed), 0.075 -> 36, 0.10 -> 49, 0.20 -> 80 (R; G/B alike). The
        // panel's 12/21/33 sit just above the crush, interpolated below. Both planes one tone now;
        // AP_invFigBackdrop2 remains for a two-tone calibration round.
        // THE CLIFF (measured 2026-09-03): the tonemapper crushes scene luminance below ~0.052 to black
        // and the first non-black it renders is ~30 at aperture 20 (0.05 -> 0, 0.058 -> 31, 0.075 -> 36,
        // 0.10 -> 49, 0.20 -> 80); closing the aperture to 60 lowers that floor only to ~20 and turns
        // the player's world near-black. The page's --panel (12,21,33) is below the floor at any
        // exposure that keeps the world visible, so the backdrop is the closest smooth tone and the
        // page blends its edges into the panel with a vignette (inventory.html #figVignette).
        // CALIBRATION ROUND with the lamps actually in the box: left / right tones
        private _tex  = missionNamespace getVariable ["AP_invFigBackdrop",  "#(argb,8,8,1)color(0.058,0.096,0.139,1)"];
        private _tex2 = missionNamespace getVariable ["AP_invFigBackdrop2", "#(argb,8,8,1)color(0.10,0.15,0.20,1)"];
        private _texL = "#(argb,8,8,1)color(0,0,0,1)";   // the box's own surfaces
        private _made = [_man];
        {
            _x params ["_off", "_dir", "_up", "_t"];
            private _o = "UserTexture10m_F" createVehicleLocal [0, 0, 0];
            _o setObjectTexture [0, _t];
            _o setPosASL (_base vectorAdd _off);
            _o setVectorDirAndUp [_dir, _up];
            _made pushBack _o;
        } forEach [
            // the backdrop, 4.4 m behind the mannequin (further from the lamps), both faces; two tones
            // this round (screen-left is +x: the camera faces south)
            [[ 5, -4.4, 1.0], [0,  1, 0], [0, 0, 1], _tex],
            [[ 5, -4.4, 1.0], [0, -1, 0], [0, 0, 1], _tex],
            [[-5, -4.4, 1.0], [0,  1, 0], [0, 0, 1], _tex2],
            [[-5, -4.4, 1.0], [0, -1, 0], [0, 0, 1], _tex2],
            // THE BOX (owner: "a light source so you can see it at night"): roof, floor, side walls and
            // a wall behind the camera keep the sun out, so the studio's light is the only light and
            // the render reads the same at noon and at midnight. Black, single-sided, both faces.
            [[0, 3.0,  5.0], [0, 1, 0], [0, 0, 1],  _texL], [[0, 3.0, 5.0], [0, 1, 0], [0, 0, -1], _texL],   // roof (laid flat)
            [[0, -4.0, 5.0], [0, 1, 0], [0, 0, 1],  _texL], [[0, -4.0, 5.0], [0, 1, 0], [0, 0, -1], _texL],  // roof, rear
            [[0, 3.0, -0.05],[0, 1, 0], [0, 0, 1],  _texL], [[0, 3.0, -0.05],[0, 1, 0], [0, 0, -1], _texL],  // floor
            [[0, -4.0, -0.05],[0, 1, 0], [0, 0, 1], _texL], [[0, -4.0, -0.05],[0, 1, 0], [0, 0, -1], _texL], // floor, rear
            [[-4.9, 3.0, 1.0],[1, 0, 0], [0, 0, 1], _texL], [[-4.9, 3.0, 1.0],[-1, 0, 0], [0, 0, 1], _texL], // left wall
            [[ 4.9, 3.0, 1.0],[1, 0, 0], [0, 0, 1], _texL], [[ 4.9, 3.0, 1.0],[-1, 0, 0], [0, 0, 1], _texL], // right wall
            [[0, 8.0, 1.0],  [0, 1, 0], [0, 0, 1],  _texL], [[0, 8.0, 1.0],  [0, -1, 0], [0, 0, 1], _texL]   // behind the camera
        ];
        // THE LIGHT. Two range-limited body lamps (they stop at ~5 m, short of the backdrop) and one
        // ambient-only lamp with no range limit whose strength follows how dark the sky is (none at
        // noon, the dusk sky's worth at night) -- that ambient is what puts the backdrop on the panel
        // colour after dark (measured 2026-09-04: (12,22,34) at night) and what the sky does by day.
        (call AP_fnc_invFigTune) params ["", "_keyB", "_fillB", "_amb"];
        {
            _x params ["_off", "_bright", "_col", "_ambCol", "_att"];
            private _l = "#lightpoint" createVehicleLocal [0, 0, 0];
            _l setPosASL (_base vectorAdd _off);          // ASL: createVehicleLocal's ATL is above the sea FLOOR here
            _l setLightBrightness _bright;
            _l setLightColor _col;
            _l setLightAmbient _ambCol;
            _l setLightUseFlare false;
            _l setLightAttenuation _att;
            _l setLightDayLight true;
            _made pushBack _l;
        } forEach [
            [[ 1.8, 3.5, 2.4], _keyB,  [1.0, 0.97, 0.92], [0, 0, 0], [2, 0, 0, 0.15, 4.5, 5.5]],
            [[-2.2, 3.0, 1.4], _fillB, [0.85, 0.9, 1.0],  [0, 0, 0], [2, 0, 0, 0.15, 4.5, 5.5]],
            [[ 0.0, 1.5, 3.0], 0.01, [1, 1, 1], [_amb * 0.95, _amb, _amb * 1.12], [1, 0, 0, 0.001]]
        ];
        uiNamespace setVariable ["AP_invFigStudio", _made];
        diag_log format ["[INV] figure: studio at %1, mannequin %2 wears %3", _base, _man, uniform _man];
        true
    }};
    // aim: one camera at the middle of the framed span, looking level at the mannequin, far enough
    // that the field of view stays above the engine's floor
    if !(isFinal "AP_fnc_invFigAim") then {AP_fnc_invFigAim = compileFinal {
        private _cam = uiNamespace getVariable ["AP_invFigCam", objNull];
        if (isNull _cam) exitWith {};
        private _subj = uiNamespace getVariable ["AP_invFigMan", objNull];
        if (isNull _subj) then { _subj = player };
        private _d    = missionNamespace getVariable ["AP_invFigDist", 6.5];
        private _side = missionNamespace getVariable ["AP_invFigSide", 0];
        private _bot  = missionNamespace getVariable ["AP_invFigBottom", -0.3];
        private _top  = missionNamespace getVariable ["AP_invFigTop", 2.25];
        private _mid  = (_bot + _top) / 2;
        private _fov  = ((_top - _bot) / 2) / _d;     // tan(half angle) = half span / distance
        // the mannequin turns (invFigureRot); the camera stays on the studio's axis, not the model's.
        // AGL, the frame camSetPos/camSetTarget take (getPosATL over the sea is height above the sea
        // FLOOR: 399 m here, and the camera stared at the sky -- b0908).
        private _base = ASLToAGL (getPosASL _subj);
        private _tgt  = _base vectorAdd [0, 0, _mid];
        private _pos  = _base vectorAdd [_side, _d, _mid];
        _cam camSetTarget _tgt;
        _cam camSetPos _pos;
        _cam camSetFov _fov;
        _cam camSetFocus [-1, -1];
        _cam camCommit 0;
    }};
    // drag on the strip turns the mannequin (page -> invFigureRot [degrees])
    if !(isFinal "AP_fnc_invFigRot") then {AP_fnc_invFigRot = compileFinal {
        params [["_deg", 0, [0]]];
        private _m = uiNamespace getVariable ["AP_invFigMan", objNull];
        if (isNull _m) exitWith { false };
        _m setDir ((getDir _m) + _deg);
        true
    }};
if (_this isEqualTo "boot") exitWith { true };   // core\init.sqf: define the helpers above at client init

switch (_verb) do {
    case "start": {
        if (isNull _disp || {isNull _clip} || {isNull _pic} || {isNull _page}) exitWith { [false, "NO SCREEN"] call _fnOut };
        _box params [["_fx", 0, [0]], ["_fy", 0, [0]], ["_fw", 0, [0]], ["_fh", 0, [0]]];
        if (_fw <= 0 || {_fh <= 0}) exitWith { [false, "NO BOX"] call _fnOut };

        // the strip in screen units: fn_invBridge.sqf's own window geometry (deck scale x UI grid, centred)
        private _s = profileNamespace getVariable ["AP_deckScale", 1];
        private _gw = 2.5 * pixelW * pixelGrid; private _gh = 2.5 * pixelH * pixelGrid;
        private _pw = 40 * _gw * _s; private _ph = 22 * _gh * _s;
        private _px = 0.5 - _pw / 2;  private _py = 0.5 - _ph / 2;
        private _x = _px + _fx * _pw; private _y = _py + _fy * _ph;
        private _w = _fw * _pw;       private _h = _fh * _ph;
        _clip ctrlSetPosition [_x, _y, _w, _h];
        _clip ctrlCommit 0;
        _fill ctrlSetPosition [0, 0, _w, _h];
        _fill ctrlCommit 0;

        // the picture: as tall as the strip, as wide as that height x the screen's aspect (the render's
        // shape), centred so the group shows the middle column
        (getResolution) params ["_resW", "_resH"];
        private _aspect = _resW / (_resH max 1);
        private _hpx = _h / pixelH;
        private _sw = (_hpx * _aspect) * pixelW;
        _pic ctrlSetPosition [(_w - _sw) / 2, 0, _sw, _h];
        _pic ctrlCommit 0;
        diag_log format ["[INV] figure: page %1 box %2 -> clip %3 pic %4 (%5x%6 px) pip=%7 veh=%8",
            [_px, _py, _pw, _ph], _box select [0, 4], ctrlPosition _clip, ctrlPosition _pic,
            round (_hpx * _aspect), round _hpx, isPiPEnabled, vehicle player != player];

        if (!isPiPEnabled) exitWith { _clip ctrlShow false; [false, "PIP OFF"] call _fnOut };
        if (vehicle player != player) exitWith { _clip ctrlShow false; [false, "IN VEHICLE"] call _fnOut };

        private _res = missionNamespace getVariable ["AP_invFigRes", 2048];
        _pic ctrlSetText format ["#(argb,%1,%1,1)r2t(apinvfig,1.0)", _res];
        _pic ctrlShow true; _fill ctrlShow true;
        _clip ctrlShow true;

        private _cam = uiNamespace getVariable ["AP_invFigCam", objNull];
        if (isNull _cam) then {
            if (missionNamespace getVariable ["AP_invFigIsolate", true]) then { [true] call AP_fnc_invFigStudio; };
            private _subj = uiNamespace getVariable ["AP_invFigMan", objNull];
            if (isNull _subj) then { _subj = player };
            _cam = "camera" camCreate (getPosATL _subj);
            uiNamespace setVariable ["AP_invFigCam", _cam];
            call AP_fnc_invFigAim;
            _cam cameraEffect ["internal", "back", "apinvfig"];
            // EXPOSURE LOCK. The PiP shares the main view's HDR adaptation: one backdrop texture
            // rendered (0,2,8) in a corridor and (37,59,79) on sunlit cliffs, so no fixed colour can
            // match the page unless the aperture is pinned while the figure is live. 12 blew the
            // world out (b0905); 30 is near dusk auto. Auto again on close. AP_invFigAperture tunes it.
            setAperture ((call AP_fnc_invFigTune) select 0);
            [] spawn {
                while { !isNull (findDisplay 938500) && { !isNull (uiNamespace getVariable ["AP_invFigCam", objNull]) } } do {
                    uiSleep 0.5;
                    call AP_fnc_invFigAim;
                };
            };
        } else {
            call AP_fnc_invFigAim;
        };
        diag_log format ["[INV] figure: live, cam %1, subject %2, shown=%3 text=%4",
            _cam, uiNamespace getVariable ["AP_invFigMan", player], ctrlShown _clip, ctrlText _pic];
        [true, ""] call _fnOut
    };

    case "stop": {
        private _cam = uiNamespace getVariable ["AP_invFigCam", objNull];
        if (!isNull _cam) then {
            _cam cameraEffect ["terminate", "back", "apinvfig"];
            camDestroy _cam;
        };
        uiNamespace setVariable ["AP_invFigCam", objNull];
        setAperture -1;   // exposure back to automatic
        if (!isNil "AP_fnc_invFigStudio") then { [false] call AP_fnc_invFigStudio; };
        if (!isNull _pic) then { _pic ctrlSetText ""; _pic ctrlShow false; };
        if (!isNull _clip) then { _clip ctrlShow false; };
        [false, ""] call _fnOut
    };

    default { [false, "UNKNOWN VERB"] call _fnOut };
}
