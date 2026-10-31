params[["_mode", "", [""]], ["_extra", [], [[]]]];
if (_mode == "") exitWith {};
if (side player != civilian) exitWith {};
private _eventLoadout = [["arifle_MX_Black_F", "", "acc_flashlight", "optic_Arco_blk_F", ["30Rnd_65x39_caseless_black_mag", 30], [], ""],
    [], [], ["U_O_Wetsuit", [["30Rnd_65x39_caseless_black_mag", 5, 30]]], ["V_TacVest_blk", [["30Rnd_65x39_caseless_black_mag", 10, 30]]],
    [], "", "G_Aviator", [], ["ItemMap", "ItemGPS", "", "ItemCompass", "ItemWatch", "Integrated_NVG_F"]];
switch (_mode) do {case "promptMenu": {if ((SRV_duelArenaData select 1) != -1800 && (time - (SRV_duelArenaData select 1)) < 70) exitWith {
                ["Someone has already send a invite to duel someone in the past 70 seconds.", "basic"] spawn AP_fnc_handleMessage;
                closeDialog 0;};
            if (SRV_duelArenaData select 0) exitWith {
                ["The arena is already in use, wait your turn!.", "basic"] spawn AP_fnc_handleMessage;
                closeDialog 0;};
            disableSerialization;
            ["AP_duel_arena_menu"] call AP_fnc_createDialog;
            private _display = findDisplay 4400;
            private _playerList = _display displayCtrl 4402;
            private _button1 = _display displayCtrl 4408; {
                private _index = _playerList lbAdd format["%1", [name _x] call AP_fnc_cleanName];
                _playerList lbSetData[_index, getPlayerUID _x];
                _playerList lbSetColor[_index, [1, 1, 1, 1]];
                _playerList lbSetSelectColor[_index, [1, 1, 1, 0.70]];}
            forEach(allPlayers select {
                !(isNull _x) && side _x == civilian && alive _x && !(_x getVariable["AP_arrested", false]) && !(_x getVariable["AP_restrained", false])
            }) - [player];
            _button1 ctrlSetText "Invite";
            _button1 ctrlSetEventHandler["ButtonClick", "['promptInviteDueler'] spawn AP_fnc_duelArenaSystem;"];
            _button1 ctrlShow true;
            _button1 ctrlEnable false;
            _playerList ctrlSetEventHandler["LBSelChanged", "['playerSelection', _this] call AP_fnc_duelArenaSystem;"];
            _playerList lbSetCurSel - 1;}; case "playerSelection": {_extra params["_ctrlObject", "_selectedIndex"];
                disableSerialization;
                private _display = ctrlParent _ctrlObject;
                if (isNull _display) exitWith {};
                private _button1 = _display displayCtrl 4408;
                if (lbCurSel _ctrlObject == -1) exitWith {};
                _button1 ctrlEnable true;};
        case "promptInviteDueler": {private _display = findDisplay 4400;
                private _playerList = _display displayCtrl 4402;
                private _duelPrice = _display displayCtrl 4404;
                private _val = parseNumber(ctrlText _duelPrice);
                if !([str _val] call AP_fnc_isNumber) exitWith {
                    ["Invalid number try a number between $50.000 and $999.999", "basic"] spawn AP_fnc_handleMessage;};
                if (_val <= 49999) exitWith {["You must enter a number greater than $49.999", "basic"] spawn AP_fnc_handleMessage;};
                if (_val >= 1000000) exitWith {["You must enter a number less than $1.000.000", "basic"] spawn AP_fnc_handleMessage;};
                if (AP_atmcash < (_val / 2)) exitWith {
                    ["You do not have enough funds to do this invite.", "basic"] spawn AP_fnc_handleMessage;
                    closeDialog 0;};
                if ((lbCurSel 4402) isEqualTo - 1) exitWith {
                    ["You didn't select anyone to invite for a duel", "basic"] spawn AP_fnc_handleMessage;
                    false};
                private _civilian = (allPlayers select {side _x == civilian});
                private _unit = _civilian param[_civilian findIf {(getPlayerUID _x) isEqualTo(lbData[4402, lbCurSel 4402])}, objNull];
                if ((isNull _unit) || (_unit isEqualTo player)) exitWith {
                    ["You can not select yourself as a dueler...", "basic"] spawn AP_fnc_handleMessage;
                    false};
                closeDialog 0;
                waitUntil {!(isNull(findDisplay 4400))};
                if ((SRV_duelArenaData select 1) != -1800 && (time - (SRV_duelArenaData select 1)) < 70) exitWith {
                    ["Someone has already send a invite to duel someone in the past 70 seconds.", "basic"] spawn AP_fnc_handleMessage;
                    closeDialog 0;};
                if (SRV_duelArenaData select 0) exitWith {
                    ["The arena is already in use, wait your turn!.", "basic"] spawn AP_fnc_handleMessage;
                    closeDialog 0;};
                private _action = [format["Are you sure you want to invite %1 for a duel with a total of $%2?", name _unit, _val], "Invite for duel?", "Yes", "No"] call BIS_fnc_guiMessage;
                if !(_action) exitWith {};
                if ((SRV_duelArenaData select 1) != -1800 && (time - (SRV_duelArenaData select 1)) < 70) exitWith {
                    ["Someone has already send a invite to duel someone in the past 70 seconds.", "basic"] spawn AP_fnc_handleMessage;
                    closeDialog 0;};
                if (SRV_duelArenaData select 0) exitWith {
                    ["The arena is already in use, wait your turn!.", "basic"] spawn AP_fnc_handleMessage;
                    closeDialog 0;};
                if (AP_atmcash < (_val / 2)) exitWith {
                    ["You do not have enough funds to do this invite.", "basic"] spawn AP_fnc_handleMessage;
                    closeDialog 0;};
                SRV_duelArenaData set[1, time];
                SRV_duelArenaData set[2, getPlayerUID player];
                SRV_duelArenaData set[3, getPlayerUID _unit];
                SRV_duelArenaData set[4, _val];
                SRV_duelArenaData set[5, [0, 0]];
                SRV_duelArenaData set[6, false];
                publicVariable "SRV_duelArenaData";
                [format["You have been invited for a duel by %1 for a total of %2.<br/><br/>You can accept this duel by going to the courthouse and interacting with the NPC (you have one minute). All your gear will be given back once the duel has been accepted (Y inventory will not be restored)", format["%1", [name player] call AP_fnc_cleanName], _val], "basic"] remoteExec["AP_fnc_handleMessage", _unit];
                ["Your invite has been sent and you will now be awaiting acception before you get teleported! All your gear will be given back once the duel has been accepted (Y inventory will not be restored)", "basic"] spawn AP_fnc_handleMessage;
                private _inviteSent = SRV_duelArenaData select 1;
                waitUntil {uiSleep 1;
                    time - _inviteSent > 65 || SRV_duelArenaData select 0};
                if (SRV_duelArenaData select 0 && SRV_duelArenaData select 2 == getPlayerUID player) then {
                    AP_atmcash = AP_atmcash - ((SRV_duelArenaData select 4) / 2);
                    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
                    [1] call AP_fnc_ClupdatePartial; [
                        ["-BANKTRANSFER-", player, profileName, format["the duel arena has taken %1 due to the start of their duel", ((SRV_duelArenaData select 4) / 2)]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
                    AP_inEvent = true;
                    [format["Your invite has been accepted you will now be transferred to the arena and $%1 will be subtracted from your account untill the end of the fight!", (_val / 2)], "basic"] spawn AP_fnc_handleMessage;
                    [[], "APS_fnc_duelArenaSystemSRV", 2] call AP_fnc_MP;} else {
                    ["Your invite has expired!", "basic"] spawn AP_fnc_handleMessage;};};
        case "acceptInvite": {if (SRV_duelArenaData select 0) exitWith {
                    ["The arena is already in use, wait your turn!.", "basic"] spawn AP_fnc_handleMessage;
                    closeDialog 0;};
                if ((SRV_duelArenaData select 1) == -1800 || (time - (SRV_duelArenaData select 1)) > 61) exitWith {
                    ["The invite expired.", "basic"] spawn AP_fnc_handleMessage;
                    closeDialog 0;};
                private _civilian = (allPlayers select {side _x == civilian});
                private _duelPartner = _civilian param[_civilian findIf {(getPlayerUID _x) isEqualTo(SRV_duelArenaData select 2)
                }, objNull];
                if (isNull _duelPartner) exitWith {
                    ["Something went wrong~! your duel partner seems to be lost in space.", "basic"] spawn AP_fnc_handleMessage;};
                if !((SRV_duelArenaData select 3) == getPlayerUID player) exitWith {
                    ["You are not invited for this duel maybe next time kid.", "basic"] spawn AP_fnc_handleMessage;};
                private _action = [format["Are you sure you want to fight %1 for a duel with a total of $%2?", name _duelPartner, SRV_duelArenaData select 4], "Invite for duel?", "Yes", "No"] call BIS_fnc_guiMessage;
                if !(_action) exitWith {};
                if (AP_atmcash < ((SRV_duelArenaData select 4) / 2)) exitWith {
                    ["You do not have enough funds to take on this invite.", "basic"] spawn AP_fnc_handleMessage;
                    closeDialog 0;};
                if ((SRV_duelArenaData select 1) == -1800 || (time - (SRV_duelArenaData select 1)) > 61) exitWith {
                    ["The invite expired.", "basic"] spawn AP_fnc_handleMessage;
                    closeDialog 0;};
                private _civilian = (allPlayers select {side _x == civilian});
                if (isNull(_civilian param[_civilian findIf {(getPlayerUID _x) isEqualTo(SRV_duelArenaData select 2)
                }, objNull])) exitWith {
                    ["Something went wrong~! your duel partner seems to be lost in space.", "basic"] spawn AP_fnc_handleMessage;};
                SRV_duelArenaData set[0, true];
                publicVariable "SRV_duelArenaData";
                AP_inEvent = true;
                AP_atmcash = AP_atmcash - ((SRV_duelArenaData select 4) / 2);
                AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
                [1] call AP_fnc_ClupdatePartial; [
                    ["-BANKTRANSFER-", player, profileName, format["the duel arena has taken %1 due to the start of their duel", ((SRV_duelArenaData select 4) / 2)]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
                [format["You accepted the invite, you will now be transferred to the arena and $%1 will be subtracted from your account untill the end of the fight!", ((SRV_duelArenaData select 4) / 2)], "basic"] spawn AP_fnc_handleMessage;
            };
        case "joinArena": {_extra params["_position"];
                disableUserInput true;
                if !(isNull objectParent player) then {moveOut player;};
                private _preArenaLoadout = getUnitLoadout player;
                private _preArenaSkins = AP_uniformBackpack_skins;
                private _preArenaPos =
                if (surfaceIsWater(getPosATL player)) then {getPosASL player} else {getPosATL player};
                AP_old_group = group player;
                [player] join grpNull;
                player setPos _position;
                player setDamage 0;
                player setUnitLoadout _eventLoadout;
                player action["SwitchWeapon", player, player, 100];
                for "_i"
                from 5 to 1 step - 1 do {[format["%1", _i], "basic"] spawn AP_fnc_handleMessage;
                    uiSleep 1;}; disableUserInput false;
                ["Fight!", "basic"] spawn AP_fnc_handleMessage;
                private _uidToLookFor = (SRV_duelArenaData select 2);
                if ((getPlayerUID player) == (SRV_duelArenaData select 2)) then {_uidToLookFor = (SRV_duelArenaData select 3);};
                waitUntil {uiSleep 1;
                    !(SRV_duelArenaData select 0) || (isNull((allPlayers select {side _x == civilian}) param[(allPlayers select {
                        side _x == civilian}) findIf {(getPlayerUID _x) isEqualTo _uidToLookFor}, objNull]))};
                if !(SRV_duelArenaData select 6) then {private _amountWon = (SRV_duelArenaData select 4) / 2;
                    AP_atmcash = AP_atmcash + _amountWon;
                    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
                    [1] call AP_fnc_ClupdatePartial; [
                        ["-BANKTRANSFER-", player, profileName, format["has been given back $%1 due to the fact that their duel arena failed.", _amountWon]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
                    SRV_duelArenaData set[0, false];
                    SRV_duelArenaData set[6, true];
                    publicVariable "SRV_duelArenaData";};
                disableUserInput false;
                AP_inEvent = false;
                player setUnitLoadout _preArenaLoadout;
                AP_uniformBackpack_skins = _preArenaSkins;
                if (surfaceIsWater _preArenaPos) then {player setPosASL _preArenaPos} else {player setPosATL _preArenaPos};
                player setDamage 0;
                [player] joinSilent AP_old_group;
                titleText["You have been given back your previous loadout", "PLAIN"];
                [] call AP_fnc_hudUpdate;
                [] spawn {uiSleep 0.5;
                    [uniform player, "setUniform", ""] call AP_fnc_clothingTextures;
                    [backpack player, "setBackpack", ""] call AP_fnc_clothingTextures;
                    [] call AP_fnc_hudUpdate;};};
        case "nextRound": {_extra params["_position", "_doRespawn", "_deadData"];
                [format["Next round is commencing the current score is %1 - %2", ((SRV_duelArenaData select 5) select 0), ((SRV_duelArenaData select 5) select 1)], "basic"] spawn AP_fnc_handleMessage;
                disableUserInput true;
                if (_doRespawn) then {["respawn", _deadData] call AP_fnc_duelArenaSystem;};
                player setPos _position;
                player setDamage 0;
                player setUnitLoadout _eventLoadout;
                player action["SwitchWeapon", player, player, 100];
                for "_i"
                from 5 to 1 step - 1 do {[format["%1", _i], "basic"] spawn AP_fnc_handleMessage;
                    uiSleep 1;}; disableUserInput false;
                ["Fight!", "basic"] spawn AP_fnc_handleMessage;};
        case "endArena": {_extra params["_position", "_doRespawn", "_deadData"];
                disableUserInput true;
                if (SRV_duelArenaData select 6) exitWith {};
                if (_doRespawn) then {["respawn", _deadData] call AP_fnc_duelArenaSystem;};
                player setPos _position;
                player setDamage 0;
                private _score = SRV_duelArenaData select 5;
                private _winnerObject = objNull;
                private _amountWon = (SRV_duelArenaData select 4) * 0.90;
                private _civilians = (allPlayers select {side _x == civilian});
                if ((_score select 0) >= 2) then {_winnerObject = _civilians param[_civilians findIf {
                        (getPlayerUID _x) isEqualTo(SRV_duelArenaData select 2)}, objNull];};
                if ((_score select 1) >= 2) then {_winnerObject = _civilians param[_civilians findIf {
                        (getPlayerUID _x) isEqualTo(SRV_duelArenaData select 3)}, objNull];};
                if !(isNull _winnerObject) then {
                    [format["The winner of the arena is %1, congratulations for taking the W you will be walking away with a total of $%2 after a 10%3 tax taken by judges", name _winnerObject, _amountWon, "%"], "basic"] spawn AP_fnc_handleMessage;
                    if (player == _winnerObject) then {AP_atmcash = AP_atmcash + _amountWon;
                        AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
                        [1] call AP_fnc_ClupdatePartial; [
                            ["-BANKTRANSFER-", player, profileName, format["has been given $%1 due to the fact that they won the duel arena.", _amountWon]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
                    };} else {
                    ["Something went wrong during the arena and no winner could be concluded! Your money will be returned to your account.", "basic"] spawn AP_fnc_handleMessage;
                    _amountWon = (SRV_duelArenaData select 4) / 2;
                    AP_atmcash = AP_atmcash + _amountWon;
                    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
                    [1] call AP_fnc_ClupdatePartial; [
                        ["-BANKTRANSFER-", player, profileName, format["has been given back $%1 due to the fact that the duel arena failed.", _amountWon]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
                };
                SRV_duelArenaData set[6, true];
                publicVariable "SRV_duelArenaData";
                if (_doRespawn) then {uiSleep 3;
                    SRV_duelArenaData set[0, false];
                    publicVariable "SRV_duelArenaData";};};
        case "endArenaInterferance": {_extra params["_position", "_doRespawn", "_deadData"];
                disableUserInput true;
                if (SRV_duelArenaData select 6) exitWith {};
                if (_doRespawn) then {["respawn", _deadData] call AP_fnc_duelArenaSystem;};
                player setPos _position;
                player setDamage 0;
                private _amountWon = (SRV_duelArenaData select 4) / 2;
                AP_atmcash = AP_atmcash + _amountWon;
                AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
                [1] call AP_fnc_ClupdatePartial;
                SRV_duelArenaData set[6, true];
                publicVariable "SRV_duelArenaData";
                ["Something went wrong during the arena and no winner could be concluded! Your money will be returned to your account.", "basic"] spawn AP_fnc_handleMessage;
                [
                    ["-BANKTRANSFER-", player, profileName, format["has been given back $%1 due to the fact that the duel arena failed.", _amountWon]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
                if (_doRespawn) then {uiSleep 3;
                    SRV_duelArenaData set[0, false];
                    publicVariable "SRV_duelArenaData";};};
        case "respawn": {_extra params["_target", "_deadBody"];
                AP_isDead = false; localNamespace setVariable ["AP_isDead", false];
                AP_corpse = _deadBody;
                if !(isNull AP_corpse) then {private _containers = nearestObjects[AP_corpse, ["WeaponHolderSimulated"], 5]; {
                        deleteVehicle _x}
                    forEach _containers;
                    hideBody AP_corpse;};
                if !(AP_effSide isEqualTo west) then {AP_cash = 0;
                    AP_cashCacheB = ((AP_cash / 4) + 9);}; {_x setVariable["AP_aggressive", nil];}
                forEach allPlayers;
                waitUntil {alive player};
                [AP_sidechat] call AP_fnc_manageSidechat;};};