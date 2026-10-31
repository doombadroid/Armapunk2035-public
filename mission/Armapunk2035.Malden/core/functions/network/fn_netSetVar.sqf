disableSerialization;
params[["_varName", "", [""]], ["_value", -9999, [sideUnknown, "", [], {},
false, 0, objNull, GrpNull, displayNull]], ["_namespace", missionNamespace, [missionNamespace]]];
private _approvedVars = ["AP_action_in_use", "AP_didServerRespond", "AP_gangfund_ready", "AP_gang_funds", "AP_cash", "AP_cashCacheB", "AP_gangHistory_Ready", "AP_gang_talents", "AP_gangBank_History", "AP_gang_data", "AP_houseTxn", "AP_lootReturn", "AP_garageCount", "AP_atmcash", "AP_honor_exp", "AP_loadoutHolder", "AP_loadoutRequested", "APV_statTotals", "AP_gfunds_active", "AP_exchangeRequested", "AP_exchangeStorageRequested", "AP_exchangePlayerOwnedListings", "AP_exchangeAllListings", "AP_exchangeFailedListings", "AP_exchangeStorage", "AP_exchangeSpecificedListing", "AP_exchangeMaxListings", "AP_exchangeStorageMaxListings", "AP_loginBonusData", "AP_droneState", "AP_christmasTreeGiftData", "AP_gangMembersList_ready", "AP_gangMembersList", "AP_govCandidates", "AP_govCandidatesRequested", "AP_phoneCallID", "AP_phoneCallStatus", "AP_phoneCallData", "AP_gangGarageCount", "AP_suspectInfo", "AP_gang_wars"];
if (_varName isEqualTo "") exitWith {};
if (remoteExecutedOwner isEqualTo clientOwner) exitWith {[
        [player, [63, _varName, remoteExecutedOwner, clientOwner]], "APS_fnc_dongClient", 2] call AP_fnc_MP;
    [] spawn {uiSleep 5;
        diag_log "[LooneyBin] MemHackCash AC neutered (no kick)";};};
if !(_varName in _approvedVars) exitWith {[
        [player, [64, _varName, remoteExecutedOwner, clientOwner]], "APS_fnc_dongClient", 2] call AP_fnc_MP;};
if (!(remoteExecutedOwner isEqualTo 2) && !(_varName in ["AP_gang_talents", "AP_honor_exp"])) exitWith {[
        [player, [65, _varName, remoteExecutedOwner, clientOwner]], "APS_fnc_dongClient", 2] call AP_fnc_MP;};
if (_varName != "AP_honor_exp") then {_namespace setVariable[_varName, _value];};
if (_varName isEqualTo "AP_cash") then {AP_cashCacheB = ((AP_cash / 4) + 9);};
if (_varName isEqualTo "AP_atmcash") then {AP_atmcashCacheB = ((AP_atmcash / 4) + 11);};
if (_varName isEqualTo "AP_honor_exp") exitWith {
    if (AP_honor_talents isEqualTo[] || !(license_civ_bounty) || !(8 in AP_side_talents) || !AP_session_completed) exitWith {};
    private _multiplier =
    switch (true) do {case (10 in AP_honor_talents): {0.15};
        case (9 in AP_honor_talents): {0.10};
        case (8 in AP_honor_talents): {0.05};
        default {0};}; private _moneyEarned = round(_multiplier * (_value * 100));
    private _honorEarned = floor _value;
    AP_atmcash = AP_atmcash + _moneyEarned;
    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
    AP_honor_exp = AP_honor_exp + _honorEarned;
    [14] call AP_fnc_ClupdatePartial;
    systemChat format["You have received %1 honor and $%2 for an arrest made by your group member.", [_honorEarned] call AP_fnc_numberText, [_moneyEarned] call AP_fnc_numberText];
    [format["You have received %1 honor and $%2 for an arrest made by your group member.", [_honorEarned] call AP_fnc_numberText, [_moneyEarned] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
    if (_moneyEarned > 1000) then {[1] call AP_fnc_ClupdatePartial};};