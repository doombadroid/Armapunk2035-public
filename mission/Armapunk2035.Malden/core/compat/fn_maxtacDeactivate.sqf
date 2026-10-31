// AP_fnc_maxtacDeactivate -- LooneyBin: MaxTac stand-down (restored 2026-06-11).
// The server calls this via "[] call AP_fnc_maxtacDeactivate" during fed/bank/prison cleanup, which
// runs it on the SERVER (no player there). So when invoked on the server we re-broadcast to the
// summoned officers; on each officer's client we restore the pre-MaxTac loadout and clear MaxTac state.
if (isServer) exitWith {{if (!isNull _x) then { [[], "AP_fnc_maxtacDeactivate", _x, false] spawn AP_fnc_MP; };
    } forEach (missionNamespace getVariable ["AP_maxtac_officers", []]);};
if (!AP_activeMAXTAC && !AP_MAXTACActionAvail) exitWith {};
["MaxTac deployment has ended. Returning you to your patrol gear.", "basic"] spawn AP_fnc_handleMessage;
if (!isNil "AP_maxtacLoadout") then {player setUnitLoadout AP_maxtacLoadout;
    AP_maxtacLoadout = nil;
    [] spawn {uiSleep 0.5;
        [uniform player, "setIdx", 0] call AP_fnc_clothingTextures;};};
AP_activeMAXTAC = false;
AP_MAXTACActionAvail = false;
AP_isMaxTac = false;
