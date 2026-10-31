#include "..\..\macro.h"
if (scriptAvailable(8)) exitWith {["You can only grab the rubber out so quick...", "basic"] spawn AP_fnc_handleMessage;};
params["_target", "_caller", "", ""];
if (isNull _target) exitWith {[[player, [61, "Rubber"]], "APS_fnc_dongClient", 2] call AP_fnc_MP;};
if (_target isEqualTo _caller) exitWith {[[player, [62, "Rubber"]], "APS_fnc_dongClient", 2] call AP_fnc_MP;};
if (isNull oil_flag) exitWith {};
if !(alive player) exitWith {};
private _flagData = oil_flag getVariable["AP_capData", [0, "Neutral", 0.5]];
private _rubberCount = oil_flag getVariable["AP_cap_oil", -1];
_flagData params[["_ownerID", -1], ["_ownerName", ""], ["_progress", -1]];
if (AP_gang_data isEqualTo[]) exitWith {};
if (_ownerName isEqualTo "" || _ownerID isEqualTo - 1 || _progress isEqualTo - 1 || _rubberCount isEqualTo - 1) exitWith {};
if ((player distance2D oil_flag) > 8) exitWith {
    ["You need to stay by the flag to retrieve the rubber!", "basic"] spawn AP_fnc_handleMessage;};
if (_rubberCount isEqualTo 0) exitWith {["There is no rubber in the container to grab!", "basic"] spawn AP_fnc_handleMessage;};
AP_gang_data params[["_myGangID", -1, [0]], ["_myGangName", "", [""]], ["_myGangRank", -1, [0]]];
if (_myGangID isEqualTo - 1 || _myGangName isEqualTo "") exitWith {};
if (!(_myGangID isEqualTo _ownerID) || !(_myGangName == _ownerName)) exitWith {
    ["You do not own the cartel!", "basic"] spawn AP_fnc_handleMessage;};
if (_myGangName == _ownerName && !(_progress isEqualTo 1)) exitWith {
    ["You need to fully capture the cartel to retrieve rubber!", "basic"] spawn AP_fnc_handleMessage;};
private _nearUnits = (nearestObjects[player, ["Man"], 10]) arrayIntersect playableUnits;
if (count _nearUnits > 1) exitWith {
    ["You cannot pull out rubber while another player is near the flag!", "basic"] spawn AP_fnc_handleMessage;};
AP_didServerRespond = false;
private _maxDelayTime = time + 5; [[player], "APS_fnc_lagCheck", false, false] spawn AP_fnc_MP;
waitUntil {time > _maxDelayTime || AP_didServerRespond};
if (time > _maxDelayTime) exitWith {["Fetching rubber failed... Try again.", "basic"] spawn AP_fnc_handleMessage;};
_rubberCount = oil_flag getVariable["AP_cap_oil", -1];
if (_rubberCount isEqualTo 0) exitWith {["There is no rubber in the container to grab!", "basic"] spawn AP_fnc_handleMessage;};
_nearUnits = (nearestObjects[player, ["Man"], 10]) arrayIntersect playableUnits;
if (count _nearUnits > 1) exitWith {
    ["You cannot pull out rubber while another player is near the flag!", "basic"] spawn AP_fnc_handleMessage;};
private _diff = ["rubber", _rubberCount, AP_carryWeight, AP_maxWeight] call AP_fnc_calWeightDiff;
if (_diff <= 0) exitWith {["Your inventory space is full.", "basic"] spawn AP_fnc_handleMessage;};
if !(alive player) exitWith {};
if ((player distance2D oil_flag) > 8) exitWith {
    ["You need to stay by the flag to retrieve the rubber!", "basic"] spawn AP_fnc_handleMessage;};
private _restartTime =
if (isNil "serverStartTime") then {round((14400 - serverTime) / 60)} else {round((serverCycleLength - (serverTime - serverStartTime)) / 60)
};
if (_restartTime <= 5) exitWith {
    ["You cannot take rubber from the cartel within 5 minutes of a restart. Try again after restart.", "basic"] spawn AP_fnc_handleMessage;
};
if !(_diff isEqualTo _rubberCount) then {if ([true, "rubber", _diff] call AP_fnc_handleInv) then {_rubberCount = _rubberCount - _diff;
        [format["You have retrieved %1 rubber from the cartel. There is %2 rubber left.", _diff, _rubberCount], "basic"] spawn AP_fnc_handleMessage;
        oil_flag setVariable["AP_cap_oil", _rubberCount, true]; [
            ["-CARTELRUBBER-", player, (profileName), format["Has taken cartel %1 rubber, %2 rubber remaining", _diff, _rubberCount]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    };} else {if ([true, "rubber", _rubberCount] call AP_fnc_handleInv) then {
        [format["You have retrieved all %1 rubber from the cartel.", _rubberCount], "basic"] spawn AP_fnc_handleMessage;
        oil_flag setVariable["AP_cap_oil", 0, true]; [
            ["-CARTELRUBBER-", player, (profileName), format["Has taken cartel %1 rubber, 0 rubber remaining", _rubberCount]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    };};