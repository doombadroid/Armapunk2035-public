#include "..\..\macro.h"
if (AP_govClientData param[1, false]) exitWith {
    ["You have already became a candidate for this week!", "basic"] spawn AP_fnc_handleMessage};
if ((getPlayerUID player) isEqualTo(SRV_governorData param[0, "GovUID"])) exitWith {
    ["You have already became a governor this past election!", "basic"] spawn AP_fnc_handleMessage};
if (scriptAvailable(5)) exitWith {
    ["You can only attempt to become a candidate every couple seconds!", "basic"] spawn AP_fnc_handleMessage;};
disableSerialization;
["govCandidateMenu"] call AP_fnc_createDialog;
private _display = findDisplay 10600;
private _policyInput = _display displayCtrl 10601;
private _investmentInput = _display displayCtrl 10602;
private _submitButton = _display displayCtrl 10603;
_submitButton ctrlAddEventHandler["ButtonClick", {_this spawn {params["_control"];
        _control ctrlEnable false;
        private _policy = ctrlText 10601;
        private _investment = parseNumber(ctrlText 10602);
        private _length = count _policy;
        if (_length < 15) exitWith {["The minimum character limit for a policy is 15.", "basic"] spawn AP_fnc_handleMessage;
            _control ctrlEnable true;};
        if (_length > 150) exitWith {["The maximum character limit for a policy is 150.", "basic"] spawn AP_fnc_handleMessage;
            _control ctrlEnable true;};
        private _action = [format["<t align='center' size='0.75'>The Governor system is intended to be a server wide feature that allows anyone to run for and hold the position. The rule is that you, or any member of your gang cannot hold office more than once in a 30 day period. Any attempt to circumvent this 30 day requirement such as leaving the gang etc will be considered exploiting. It's imperative that we work to ensure that this server feature is not cornered by one or two groups of people. The team of staff reserves the right to review and judge as needed. If we feel that your actions, group, or gang status was changed to exploit this feature. You are liable for administrative action being taken against you. This is your first and only warning.</t>"], "Warning", "Okay", "No"] call AP_fnc_guiMessage;
        if !(_action) exitWith {};
        if (!([str _investment] call AP_fnc_isNumber)) exitWith {["Invalid Number format.", "basic"] spawn AP_fnc_handleMessage;
            _control ctrlEnable true;};
        if (_investment < 75000) exitWith {["Your investment must be at least $75,000 or more!", "basic"] spawn AP_fnc_handleMessage;
            _control ctrlEnable true;};
        if (_investment > AP_atmcash) exitWith {
            ["You don't have enought money to run for governor!", "basic"] spawn AP_fnc_handleMessage};
        // owner 2026-06-17 (#316 "ran for gov, restart, took my $75k"): block re-filing using the SERVER's
        // candidate list (SRV_govCandidates -- publicVariable'd + rebuilt from DB on every restart) instead of
        // the client-only "already candidate" flag, which RESETS on reconnect. Without this, a returning
        // candidate could pay the $75k AGAIN, then the server rejected it ("already on the ballot") with NO
        // refund -> money gone for nothing. Check BEFORE deducting.
        if (!isNil "SRV_govCandidates" && {(SRV_govCandidates findIf { (_x select 0) isEqualTo (getPlayerUID player) }) > -1}) exitWith {
            ["You are already on the ballot for this election -- no need to file again.", "basic"] spawn AP_fnc_handleMessage;
            _control ctrlEnable true;};
        AP_atmcash = AP_atmcash - _investment;
        AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
        [1] call AP_fnc_ClupdatePartial; [
            ["runForOffice", [player, [profileName, getPlayerUID player, (AP_gang_data param[0, -1])], AP_effSide, round _investment, _policy]], "APS_fnc_govSystemSRV", 2] call AP_fnc_MP;
        [format["You have sent your candidate information to the Government of %1, players now may vote for you! Good Luck!", worldName]] spawn AP_fnc_handleMessage;
        AP_govClientData set[1, true];
        [21] call AP_fnc_ClupdatePartial;
        closeDialog 0;};}];