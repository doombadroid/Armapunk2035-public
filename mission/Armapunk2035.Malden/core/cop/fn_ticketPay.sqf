if (isNil {AP_ticket_val} || isNil {AP_ticket_cop}) exitWith {};
if ((AP_is_arrested param [0,0]) isEqualTo 1) exitWith {};
AP_ticket_attempted = true;
private _copPaidAmount = AP_ticket_val;
private _arrestCap = 1000000;
if ((call AP_adminLevel) >= 2) then {if (_copPaidAmount > _arrestCap) then {_copPaidAmount = _arrestCap;};};
if (AP_atmcash < AP_ticket_val) exitWith {
    ["You don't have enough money in your bank account or on you to pay the ticket.", "basic"] spawn AP_fnc_handleMessage; [
        [1, format["%1 couldn't pay the ticket due to not having enough money.", [profileName] call AP_fnc_cleanName]], "AP_fnc_broadcast", AP_ticket_cop, false, false] spawn AP_fnc_MP;
    closeDialog 0;};
if (AP_ticket_val < 0) exitWith {[[player, [70, str AP_ticket_val]], "APS_fnc_dongClient", 2] call AP_fnc_MP;
    closeDialog 0;};
AP_ticket_paid = true;
[format["You have paid the ticket of $%1", [AP_ticket_val] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
AP_atmcash = (round(AP_atmcash - AP_ticket_val)) max 0;
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
[1] call AP_fnc_ClupdatePartial; [
    [0, format["%1 paid the ticket of $%2", profileName, [AP_ticket_val] call AP_fnc_numberText]], "AP_fnc_broadcast", west, false, false] spawn AP_fnc_MP;
[[AP_ticket_cop, _copPaidAmount], "APS_fnc_copSplit", 2] spawn AP_fnc_MP; [
    [2, format["$%1 has been spread amongst the active police force for a ticket paid by %2", [_copPaidAmount] call AP_fnc_numberText, [profileName] call AP_fnc_cleanName]], "AP_fnc_broadcast", AP_ticket_cop, false, false] spawn AP_fnc_MP;
[999, getPlayerUID player] call AP_fnc_wantedListAdd; [[getPlayerUID player], "APS_fnc_wantedRemove", 2] spawn AP_fnc_MP;
player setVariable["AP_wantedAmt", (A_stats_crimes select 0), true];
[8] call AP_fnc_ClupdatePartial;
[3] call AP_fnc_ClupdatePartial;
[] call AP_fnc_hudUpdate; [
    ["-TICKET-", player, (profileName), format["paid a ticket of %1 at POS: %2", AP_ticket_val, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
closeDialog 0;
private _uid = getPlayerUID player;
private _bountyHunters = allPlayers select {!(((_x getVariable["AP_myBounties", []]) findIf {_uid in _x}) isEqualTo - 1)};
if !(_bountyHunters isEqualTo[]) then {[_uid] remoteExec["AP_fnc_removeBounty", _bountyHunters];};
if (AP_allPointsBulletin param[1, "hehe"] isEqualTo _uid) then {AP_allPointsBulletin = [];
    publicVariable "AP_allPointsBulletin";};
if (AP_ticket_val > 250) then {[AP_ticket_val * 0.0012] remoteExec["AP_fnc_addExperience", AP_ticket_cop];
    [floor(AP_ticket_val / 25)] remoteExec["AP_fnc_earnPrestige", AP_ticket_cop];};
["ticketspaidamount", AP_ticket_val] call AP_fnc_statArrUpdate;
["ticketspaid", 1] call AP_fnc_statArrUpdate;