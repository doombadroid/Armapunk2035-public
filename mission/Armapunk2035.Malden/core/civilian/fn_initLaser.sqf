params[["_team", 1, [1]]];
private _endTime = time + 200;
player setVariable["AP_laserTagged", nil, true];
player setVariable["AP_laserTeam", _team, true];
AP_laser_blue = 0;
AP_laser_red = 0;
AP_laser_inprogress = true;
civ_gear = getUnitLoadout player;
removeVest player;
removeHeadgear player;
removeBackpack player;
removeUniform player;
removeAllWeapons player;
private _plb_dmg = player;
_plb_dmg setDamage 0;
player setFatigue 0;
private _uniform =
if (_team isEqualTo 1) then {"U_B_Protagonist_VR"} else {"U_O_Protagonist_VR"};
private _smoke =
if (_team isEqualTo 1) then {"SmokeShellBlue"} else {"SmokeShellRed"};
player forceAddUniform _uniform;
player addHeadgear "G_Goggles_VR";
player addMagazines["16Rnd_9x21_Mag", 4];
player addWeapon "hgun_Rook40_snds_F";
player assignItem "Integrated_NVG_F";
player addMagazine _smoke;
private _teamName =
if (_team isEqualTo 1) then {"BLUE"} else {"RED"};
private _enemyName =
if (_team isEqualTo 1) then {"RED"} else {
    "BLUE"}; [[0, 2], format["Get ready, the round is about to begin. You are team %1, eliminate team %2!", _teamName, _enemyName]
] call AP_fnc_broadcast;
[] spawn {while {AP_laser_inprogress}
    do {uiSleep 0.1;
        if (cameraView == "EXTERNAL") then {player switchCamera "INTERNAL"};};};
_uniform spawn {private _uniform = _this;
    private _oldUniform = "";
    while {AP_laser_inprogress}
    do {_oldUniform = uniform player;
        waitUntil {uiSleep 1;
            !AP_laser_inprogress || (_oldUniform != (uniform player))};
        if (AP_laser_inprogress) then {player forceAddUniform _uniform};};};
[] spawn {while {AP_laser_inprogress}
    do {private _blueScore = AP_laser_blue;
        private _redScore = AP_laser_red;
        waitUntil {!AP_laser_inprogress || _blueScore != AP_laser_blue || _redScore != AP_laser_red};
        if (AP_laser_inprogress) then {
            systemChat format["Blue Team: [%1 remaining] :: Red Team: [%2 remaining]", AP_laser_blue, AP_laser_red];};};};
waitUntil {!AP_laser_inprogress || time > _endTime};
if (isWeaponDeployed player) then {player playMove "";};
AP_laser_inprogress = false;
player setPosATL(player getVariable["AP_laserPos", getMarkerPos "city"]);
player setVariable["AP_laserTeam", nil, true];
[player] joinSilent AP_old_group;
player setUnitLoadout civ_gear;
if !(uniform player isEqualTo "") then {[uniform player, "setUniform", ""] call AP_fnc_clothingTextures;};