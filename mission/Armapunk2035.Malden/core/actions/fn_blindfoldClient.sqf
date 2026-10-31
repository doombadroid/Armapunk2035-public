if !(remoteExecutedOwner in [0, 2]) exitWith {};   // server hop only (APS_fnc_victimSRV checks actor/range/state); 0 = a local call or spawn, which remoteExecutedOwner does not survive
params[["_mode", 0, [0]], ["_kidnapper", objNull, [objNull]]];
if !(_mode in [1, 2]) exitWith {};
if (isNull player) exitWith {};
switch (_mode) do {case 1: {if !(alive player) exitWith {};
            if !(player getVariable["AP_restrained", false]) exitWith {};
            if (player getVariable["AP_blinded", false]) exitWith {};
            AP_old_goggles = (goggles player);
            removeGoggles player;
            private _blindfold = "G_blindfold_01_black_F";
            player addGoggles _blindfold;
            systemChat format["You were blindfolded by %1.", _kidnapper getVariable["AP_name", [name _kidnapper] call AP_fnc_cleanName]];
            player setVariable["AP_blinded", true, true];
            cutText["You are blindfolded.", "BLACK FADED"];
            0 cutFadeOut 9999999;
            AP_old_group = group player;
            if !((units group player) isEqualTo[]) then {[player] join grpNull;
                if ("ItemGPS" in (assignedItems player)) then {player setVariable["hadGPS", true]; [
                        [true, player], "AP_fnc_setGroupRestrainMarker", units AP_old_group] spawn AP_fnc_MP;};};
            player unlinkItem 'ItemMap';
            player unlinkItem 'ItemGPS';
            player removeItem 'ItemMap';
            player removeItem 'ItemGPS';
            // LooneyBin #514: this waited on the WRONG flag. In SQF `waitUntil { a; b; c }` only the LAST
            // expression is the loop condition -- the two `!getVariable` lines above were dead, and the loop
            // actually blocked on AP_restrained, not AP_blinded. So when a blindfolded prisoner had their
            // restraint cleared first (jail/relog clears AP_restrained), case 2 fired before the blackout was
            // meant to lift; and when the blindfold itself was cleared (AP_blinded set false) but restraint
            // lingered, the cleanup NEVER ran -> stuck black screen. Wait on the blindfold flag, which is what
            // case 2 actually reverses.
            waitUntil {uiSleep 1;
                !(player getVariable["AP_blinded", false])};
            [2] spawn AP_fnc_blindfoldClient;};
    case 2: {if ((goggles player) in ["G_blindfold_01_black_F", "G_blindfold_01_white_F"]) then {removeGoggles player;};
            if (AP_old_goggles != "") then {player addGoggles AP_old_goggles;
                AP_old_goggles = nil;};
            if !(isNull AP_old_group) then {[player] joinSilent AP_old_group;
                AP_old_group = grpNull;};
            player setVariable["AP_blinded", false, true];
            player linkItem 'ItemMap';
            if (player getVariable["hadGPS", false]) then {player linkItem 'ItemGPS';
                player setVariable["hadGPS", nil];};
            0 cutFadeOut 1;};};