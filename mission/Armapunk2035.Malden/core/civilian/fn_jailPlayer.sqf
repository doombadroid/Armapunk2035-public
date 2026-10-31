params[["_sender", objNull, [objNull]], ["_adminJail", false, [false]], ["_isSkiptracer", false, [false]], ["_isInterrogate", false, [false]], ["_onLogin", false, [false]]];
if ((AP_is_arrested param [0,0]) isEqualTo 1 && !(_onLogin)) exitWith {};
if ((call AP_adminLevel) isEqualTo 0) then {(findDisplay 49) closeDisplay 1;};
player setVariable["AP_restrained", nil, true];
player setVariable["AP_escorting", nil, true];
player setVariable["AP_transporting", nil, true];
if (_isSkiptracer) then {} else {if (_isInterrogate) then {
        private _weaponHolder = createVehicle["WeaponHolderSimulated", getPosATL player, [], 0, "CAN_COLLIDE"]; {
            _weaponHolder addItemCargoGlobal[_x, 1]}
        forEach(primaryWeaponItems player + [primaryWeapon player] + secondaryWeaponItems player + [secondaryWeapon player] + handgunItems player + [handgunWeapon player] + uniformItems player + vestItems player + backPackitems player + [uniform player] + [vest player] + [backpack player]);
        removeAllContainers player;};};
if (_adminJail) then {
    titleText[format["The admin %1 has jailed you as punishment. Consider reading the rules at our Discord.", name _sender], "PLAIN"];
} else {titleText["You have been arrested! You can wait your time out or pay your full bail.", "PLAIN"];};
private _jailSpawn = "jail_marker2";
private _jailRelease = "jail_release2";
private _jailPos = getMarkerPos _jailSpawn;
if (isWeaponDeployed player) then {player playMove "";};
player setPosATL _jailPos;
if (license_civ_bounty) then {player setVariable["AP_isBountyHunter", false, true];
    license_civ_bounty = false;};
if (license_civ_gun) then {["You have lost your Firearms License.", "basic"] spawn AP_fnc_handleMessage;
    license_civ_gun = false;
    [7] call AP_fnc_ClupdatePartial;};
if !(isNull AP_escort) then {[] call AP_fnc_stopEscorting};
player setVariable["AP_arrested", true, true];
profileNameSpace setVariable["AP_requestedTrial", false];
removeAllWeapons player; {player removeMagazine _x}
forEach(magazines player);
if (getNumber(missionConfigFile >> "CfgWeights" >> uniform player >> "illegal") isEqualTo 1) then {removeUniform player};
if (vest player in ["V_HarnessOGL_brn", "V_TacVest_blk_POLICE"]) then {removeVest player;};
if (headgear player in ["H_CrewHelmetHeli_B", "H_Cap_police"]) then {removeHeadgear player;};
if (player getVariable["AP_blinded", false]) then {if ((goggles player) in ["G_blindfold_01_black_F", "G_blindfold_01_white_F"]) then {
        removeGoggles player;};
    if (AP_old_goggles != "") then {player addGoggles AP_old_goggles;
        AP_old_goggles = nil;};
    player linkItem 'ItemMap';
    if (player getVariable["hadGPS", false]) then {player linkItem 'ItemGPS';
        player setVariable["hadGPS", nil];};};
[true] call AP_fnc_saveGear;
if !(isNull _sender) then {private _val = A_stats_crimes select 0;
    if (_adminJail) then {[
            ["-ADMINACTION-", _sender, (name _sender), format["admin jailed %1 (%2) with a bounty of %3.", (profileName), (getPlayerUID player), [_val] call AP_fnc_numberText]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    } else {if (_sender != player) then {[
                ["-ARRESTED-", _sender, (name _sender), format["(%1) arrested %2 (%3) (%4) with a bounty of %5.", side _sender, (profileName), (getPlayerUID player), side player, [_val] call AP_fnc_numberText]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
        } else {[
                ["-TURNEDIN-", _sender, (name _sender), format["%2 (%1) (%3) has sent himself to jail with a bounty of %4.", side _sender, (profileName), (getPlayerUID player), [_val] call AP_fnc_numberText]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
        };};};
private _uid = getPlayerUID player;
private _bountyHunters = allPlayers select {!(((_x getVariable["AP_myBounties", []]) findIf {_uid in _x}) isEqualTo - 1)};
if !(_bountyHunters isEqualTo[]) then {[_uid, false] remoteExec["AP_fnc_removeBounty", _bountyHunters];}; [
    [player, _jailSpawn, _jailRelease], "APS_fnc_jailSys", 2, false, false] spawn AP_fnc_MP;