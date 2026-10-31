params[["_to", objNull, [objNull]], ["_val", 0, [0]], ["_from", objNull, [objNull]]];
if ((isNull _to) || (isNull _from) || (_val <= 0)) exitWith {};
if (player != _to) exitWith {};
if (_to isEqualTo _from) exitWith {};
if (((remoteExecutedOwner isEqualTo clientOwner) || !isRemoteExecuted) && ((call AP_adminLevel) <= 2)) exitWith {[
        [player, [75, [_val] call AP_fnc_numberText, str(getPosATL player)]], "APS_fnc_dongClient", 2] call AP_fnc_MP;};
if (_to distance2D _from > 40) exitWith {[[player, [76, [
            [_val] call AP_fnc_numberText, name _from, getPlayerUID _from, _to distance2D _from, str(getPosATL _from), str(getPosATL player)] call AP_fnc_numberText, str(getPosATL player)]], "APS_fnc_dongClient", 2] call AP_fnc_MP;
};
if ((isNull _from) || !(_from in allPlayers)) exitWith {[
        [player, [77, [_val] call AP_fnc_numberText, str(getPosATL player)]], "APS_fnc_dongClient", 2] call AP_fnc_MP;};
if (_val > 9999999) exitWith {[
        [player, [78, [_val] call AP_fnc_numberText, name _from, getPlayerUID _from, str(getPosATL player)]], "APS_fnc_dongClient", 2] call AP_fnc_MP;
};
[format["%1 has given you $%2", (name _from), [_val] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
AP_cash = AP_cash + _val;
AP_cashCacheB = ((AP_cash / 4) + 9);
[0] call AP_fnc_ClupdatePartial; [
    ["-CASHRECEIVE-", player, (profileName), format["received $%1 cash from %2 (%3).", [_val] call AP_fnc_numberText, (name _from), (getPlayerUID _from)]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
private _time = _from getVariable["AP_drugtrace", -1000];
if (time - _time < 400) then {systemChat "Druggies!"; [
        [getPlayerUID player, "AP_drugtrace", _time], "APS_fnc_varPersist", 2] spawn AP_fnc_MP;
    [_time] spawn {params["_time"];
        waitUntil {uiSleep 1;
            (AP_cash isEqualTo 0) || ((time - _time) > 400)};
        if (AP_cash isEqualTo 0) then {[[getPlayerUID player, "AP_drugtrace", -1000], "APS_fnc_varPersist", 2] spawn AP_fnc_MP;};};};