params[["_caseType", "", [""]], ["_values", [], [[]]]];
// LooneyBin: passive mode NUKED (disabled for now; re-enable later by removing this block). Never turn
// it on, and clear the flags so the damage handlers that key on AP_passiveMode/AP_unitPassiveMode stop
// protecting the player + their vehicle.
AP_passiveMode = false;
AP_passiveModeJIP = false;
if (!isNull player) then { player setVariable ["AP_unitPassiveMode", false, true]; };
if (true) exitWith {};

switch (_caseType) do {case "start": {if (!(call AP_newplayer) || AP_passiveMode) exitWith {};
            AP_passiveMode = true;
            AP_passiveModeJIP = true;
            player setVariable["AP_unitPassiveMode", true, true];
            // LooneyBin (owner, 2026-06-11): MyLoonyBin donation/gold reward popup removed.
            if (A_stats_civTime > 120) exitWith {["stop"] spawn AP_fnc_passiveMode;};
            if ((A_stats_crimes select 0) >= 1500) exitWith {["disable", [1]] spawn AP_fnc_passiveMode;};
            private _inWarzone = ((getPosATL player) inPolygon AP_warzonePoly) || ((getPosATL player) inPolygon AP_drugPenPoly);
            if (_inWarzone) exitWith {["disable", [2]] spawn AP_fnc_passiveMode;};
            [] spawn {uiSleep 15;
                while {AP_passiveMode}
                do {if (A_stats_civTime > 120) exitWith {["stop"] spawn AP_fnc_passiveMode;};
                    if ((A_stats_crimes select 0) >= 1500) exitWith {["disable", [1]] spawn AP_fnc_passiveMode;};
                    private _inWarzone = ((getPosATL player) inPolygon AP_warzonePoly) || ((getPosATL player) inPolygon AP_drugPenPoly);
                    if (_inWarzone) exitWith {["disable", [2]] spawn AP_fnc_passiveMode;};
                    uiSleep 20;};};}; case "initMessage": {if (!AP_passiveMode) exitWith {};
                [format["<t color='#FF0000'><t size='1.5'><t align='center'>Passive Mode<br/><br/></t></t></t>Since you are a new player, passive mode has been enabled.<br/><br/>This means you are not vulnerable to other civilians for 2 hours. Some features will be limited like picking up guns, etc.<br/><br/>Passive mode will be removed after 2 hours or when you choose to disable it in your Phone (Y) -> 'Passive' app. <br/><br/>It can also be TEMPORARY disabled which makes you vulnerable, but some features will still be disabled if you have the following things:<br/><br/>- Having a bounty of $1,500 or higher.<br/>- Being in an illegal area.<br/>- Using a firearm."], "warning"] spawn AP_fnc_handleMessage;
            };
        case "disable": {_values params[["_type", 0, [0]]];
                if (!AP_passiveMode) exitWith {};
                AP_passiveMode = false;
                player setVariable["AP_unitPassiveMode", false, true];
                private _message =
                switch (_type) do {case 1: {"- Having a bounty of $1,500 or higher."};
                    case 2: {"- Being in an illegal area/zone."};
                    default {"- Having a bounty of $1,500 or higher.<br/>- Being in an illegal area/zone."};};
                [ format ["<t color='#FF0000'><t size='1.5'><t align='center'>Passive Mode<br/><br/></t></t></t>WARNING! You are now vulnerable again due to: <br/><br/><t color='#FF0000'>%1</t><br/><br/>Since you are in Passive Mode, some features are still disabled. You can disable Passive Mode completely in your Phone (Y) -> 'Passive' app.<br/><br/>To get unvulnerable again, make sure to follow the requirements and relog.", _message], "warning"] spawn AP_fnc_handleMessage;
                [] call AP_fnc_hudUpdate;};
        case "stopPhone": {if (!AP_passiveModeJIP) exitWith {};
                private _action = ["Do you want to disable passive mode? This action cannot be undone.", "Passive Mode", "No", "Yes"] call BIS_fnc_GUIMessage;
                if (_action) exitWith {};
                AP_passiveMode = false;
                AP_passiveModeJIP = false;
                player setVariable["AP_unitPassiveMode", false, true];
                [24] call AP_fnc_ClupdatePartial;
                ["You have disabled passive mode!", "basic"] spawn AP_fnc_handleMessage;
                [] call AP_fnc_hudUpdate;};
        case "stop": {if (!AP_passiveModeJIP) exitWith {};
                AP_passiveMode = false;
                AP_passiveModeJIP = false;
                player setVariable["AP_unitPassiveMode", false, true];
                [24] call AP_fnc_ClupdatePartial;
                [format["<t color='#FF0000'><t size='1.5'><t align='center'>Passive Mode<br/><br/></t></t></t>Passive mode has been disabled because you have reached 2 hours of playtime!"], "warning"] spawn AP_fnc_handleMessage;
                [] call AP_fnc_hudUpdate;};
        default {};};