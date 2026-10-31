if (isNil {AP_ticket_unit}) exitWith {["Person to ticket is nil", "basic"] spawn AP_fnc_handleMessage;};
if (isNull AP_ticket_unit) exitWith {["Person to ticket doesn't exist.", "basic"] spawn AP_fnc_handleMessage;};
private _val = ctrlText 2652;
if !([_val] call AP_fnc_isNumber) exitWith {["You didn't enter a positive integer.", "basic"] spawn AP_fnc_handleMessage;};
_val = parseNumber _val;
if (_val <= 0) exitWith {["The ticket must be atleast $1.", "basic"] spawn AP_fnc_handleMessage;};
if (_val > 1500000) exitWith {
    [format["You can't give tickets higher than %1.", [1500000] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;}; [
    [0, format["%1 gave a ticket of $%2 to %3", profileName, [_val] call AP_fnc_numberText, name AP_ticket_unit]], "AP_fnc_broadcast", -2] spawn AP_fnc_MP;
[
    ["-TICKET-", player, profileName, format["gave a ticket of $%1 to %2 (%3) at POS: %4", [_val] call AP_fnc_numberText, name AP_ticket_unit, getPlayerUID AP_ticket_unit, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
[[player, _val], "AP_fnc_ticketPrompt", AP_ticket_unit, false, false] spawn AP_fnc_MP;
closeDialog 0;
["action", "giveticketvalue", _val] call AP_fnc_handleQuest;
["action", "ticket", 1] call AP_fnc_handleQuest;
["ticketsgiven", 1] call AP_fnc_statArrUpdate;
["ticketsgivenamount", _val] call AP_fnc_statArrUpdate;