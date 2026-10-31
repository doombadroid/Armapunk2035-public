if (!hasInterface) exitWith {};   // broadcast to every client; the headless client has no player to report
params[["_requester", objNull, [objNull]]];
if (isNull _requester) exitWith {};
if (isNil "_requester") exitWith {}; [
    [AP_atmcash, AP_cash, getPlayerUID player, profileName, profileNameSteam, owner player, player], "AP_fnc_adminInfo", _requester] spawn AP_fnc_MP;