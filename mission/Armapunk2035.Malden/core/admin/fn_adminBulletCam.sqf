#include "..\..\macro.h"
/*
    AP_fnc_adminBulletCam  (LooneyBin NEW 2026-06-10, owner request)
    Admin-menu TOGGLE: while ON, every shot you fire is followed by a projectile camera.
    SPACE cancels the cam mid-flight (the key is only intercepted while a cam is live).
    Impact = ~1.2s linger on the hit point, then back to first person. Toggle again to turn OFF.
    Note: the Fired EH lives on the current player object -- after a death/respawn just toggle it on again.
*/
if ((call AP_adminLevel) <= 1) exitWith {};
if (isNil "AP_bulletCam") then { AP_bulletCam = false; };
AP_bulletCam = !AP_bulletCam;

if (AP_bulletCam) then {AP_bulletCamEH = player addEventHandler ["Fired", {params ["_unit", "", "", "", "", "", "_projectile"];
        if (!AP_bulletCam || {isNull _projectile}) exitWith {};
        if (missionNamespace getVariable ["AP_bulletCamActive", false]) exitWith {};   // one cam at a time
        [_projectile] spawn {params ["_proj"];
            AP_bulletCamActive = true;
            AP_bulletCamAbort = false;
            // Arma culls projectiles past the FIRER's object view distance -> the bullet "despawns"
            // mid-flight and the cam ends. Bump terrain + object VD for the brief flight, restore after.
            // (setObjectViewDistance is clamped to terrain viewDistance, so raise both.)
            private _oldVD = viewDistance;
            private _oldOVD = (getObjectViewDistance) select 0;
            setViewDistance 12000;
            setObjectViewDistance 12000;
            private _cam = "camera" camCreate (getPosATL _proj);
            _cam cameraEffect ["Internal", "Back"];
            showCinemaBorder false;
            private _kd = (findDisplay 46) displayAddEventHandler ["KeyDown",
                "if ((_this select 1) isEqualTo 57) then { AP_bulletCamAbort = true; true } else { false }"];
            private _lastPos = getPosATL _proj;
            while { !isNull _proj && {!AP_bulletCamAbort} } do {private _v = velocity _proj;
                if ((vectorMagnitude _v) > 0.1) then {private _dir = _v vectorMultiply (1 / vectorMagnitude _v);
                    _cam setPosATL ((getPosATL _proj) vectorAdd (_dir vectorMultiply -2.2) vectorAdd [0, 0, 0.4]);
                    _cam camSetTarget _proj;
                    _cam camCommit 0;};
                _lastPos = getPosATL _proj;
                sleep 0.001;};
            if (!AP_bulletCamAbort) then {     // impact linger
                _cam camSetTarget _lastPos;
                _cam camCommit 0;
                sleep 1.2;};
            (findDisplay 46) displayRemoveEventHandler ["KeyDown", _kd];
            _cam cameraEffect ["Terminate", "Back"];
            camDestroy _cam;
            setViewDistance _oldVD;            // restore the player's view distance
            setObjectViewDistance _oldOVD;
            AP_bulletCamActive = false;};}];
    ["Bullet cam ON -- your next shot is followed. SPACE cancels mid-flight. Toggle again to disable.", "basic"] spawn AP_fnc_handleMessage;
} else {if (!isNil "AP_bulletCamEH") then { player removeEventHandler ["Fired", AP_bulletCamEH]; AP_bulletCamEH = nil; };
    AP_bulletCamAbort = true;
    ["Bullet cam OFF.", "basic"] spawn AP_fnc_handleMessage;};
