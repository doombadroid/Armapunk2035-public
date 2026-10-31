params[["_jail", false, [false]]];
if !(isNull AP_escort) then {[] call AP_fnc_stopEscorting;};
private _bountyAmount = A_stats_crimes select 0;
if ((A_stats_crimes select 0) <= 0) exitWith {};
if (player getVariable["AP_restrained", false]) exitWith {
    ["Turning yourself in is not available while restrained!", "basic"] spawn AP_fnc_handleMessage;};
if (player getVariable["AP_surrendered", false]) exitWith {
    ["Turning yourself in is not available while your hands are up!", "basic"] spawn AP_fnc_handleMessage;};
if (_jail && (_bountyAmount > 100000)) exitWith {
    ["You cannot turn yourself in to jail at this time. Pay your warrant value in full instead.", "basic"] spawn AP_fnc_handleMessage;};
private _action = false;
private _exit = false;
if (_jail) then {private _curPos = getPos player;
    _action = ["Are you sure you want to turn yourself in and go to prison?", "Go To Prison", "Yes", "No"] call BIS_fnc_guiMessage;
    if (!(_action) || (_curPos distance(getPos player) >= 10) || (player getVariable["AP_restrained", false])) exitWith {_exit = true;}; [
        [getPlayerUID player], "APS_fnc_setJail", false, false] spawn AP_fnc_MP;
    [player, false] spawn AP_fnc_jailPlayer;
    _exit = true;
    if (AP_allPointsBulletin param[1, "hehe"] isEqualTo(getPlayerUID player)) then {AP_allPointsBulletin = [];
        publicVariable "AP_allPointsBulletin";};};
if (_exit) exitWith {};
_action = [format["You are currently wanted for $%1! Pay this off in full now?", [_bountyAmount] call AP_fnc_numberText], "Pay Off Bounty", "Yes", "No"] call BIS_fnc_guiMessage;
if !(_action) exitWith {};
if (AP_atmcash >= _bountyAmount) then {[999, getPlayerUID player] call AP_fnc_wantedListAdd; [
        [getPlayerUID player], "APS_fnc_wantedRemove", 2] spawn AP_fnc_MP;
    AP_atmcash = AP_atmcash - _bountyAmount;
    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
    [1] call AP_fnc_ClupdatePartial;
    private _bountyHunters = allPlayers select {!(((_x getVariable["AP_myBounties", []]) findIf {(getPlayerUID player) in _x
        }) isEqualTo - 1)};
    if !(_bountyHunters isEqualTo[]) then {[getPlayerUID player, false] remoteExec["AP_fnc_removeBounty", _bountyHunters];};
    if (AP_allPointsBulletin param[1, "hehe"] isEqualTo(getPlayerUID player)) then {AP_allPointsBulletin = [];
        publicVariable "AP_allPointsBulletin";};} else {
    ["You cannot afford to pay your fines in full. Consider serving a prison sentence instead.", "basic"] spawn AP_fnc_handleMessage;};