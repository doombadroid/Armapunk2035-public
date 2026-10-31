params[["_building", objNull, [objNull]]];
if (AP_houseTxn) exitWith {
    ["You are currently in the process of buying or selling a home. Wait a bit and try again...", "basic"] spawn AP_fnc_handleMessage;};
if (isNull _building) exitWith {["House object not passed correctly. Try again...", "basic"] spawn AP_fnc_handleMessage;};
private _owner = _building getVariable["AP_homeOwner", ""];
private _id = _building getVariable["AP_houseID", -1];
if !(_owner isEqualTo getPlayerUID player) exitWith {["You do not own this building!", "basic"] spawn AP_fnc_handleMessage;};
if (_id isEqualTo - 1) exitWith {["House object not passed correctly. Try again...", "basic"] spawn AP_fnc_handleMessage;};
if ((_building getVariable["AP_house_price", -1]) > 0) then {
    ["<t align='center'>Enter 0 to remove your house from the market.</t>", "Remove House Listing", "Confirm"] call AP_fnc_inputMenu;
} else {["<t align='center'>Enter desired sale price.", "List House for Sale", "Confirm"] call AP_fnc_inputMenu;};
if (AP_input_response isEqualTo "") exitWith {["You failed to enter a value.", ""] spawn AP_fnc_handleMessage;};
private _listPrice = parseNumber AP_input_response;
AP_houseTxn = true;
AP_input_response = "";
if (_listPrice isEqualTo 0 && ((_building getVariable["AP_house_price", -1]) > 0)) exitWith {
    _building setVariable["AP_house_price", -1, true];
    [format["Your building is no longer listed on the public market!", _listPrice], "basic"] spawn AP_fnc_handleMessage; [
        ["-HOUSELIST-", player, (profileName), format["removed a building for sale at POS: %1", getPosATL _building]], "APS_fnc_logIt", 2, false, false] call AP_fnc_MP;
    [[_building, _id, player, -1], "APS_fnc_updateHousePrice", 2] call AP_fnc_MP;
    AP_houseTxn = false;};
if (_listPrice > 4999999) exitWith {["You can't list a building for more than $4,999,999", "basic"] spawn AP_fnc_handleMessage;
    AP_houseTxn = false;};
if (_listPrice < 1000) exitWith {["You must list your building for at least $1,000.", "basic"] spawn AP_fnc_handleMessage;
    AP_houseTxn = false;};
if (_listPrice < 0) exitWith {["The number you entered is invalid!", "basic"] spawn AP_fnc_handleMessage;
    AP_houseTxn = false;};
if !([_listPrice toFixed 0] call AP_fnc_isNumber) exitWith {
    ["Enter only numbers, no other characters, for the list price.", "basic"] spawn AP_fnc_handleMessage;
    AP_houseTxn = false;};
_building setVariable["AP_house_price", _listPrice, true]; [
    [_building, _id, player, _listPrice], "APS_fnc_updateHousePrice", 2] call AP_fnc_MP; [
    ["-HOUSELIST-", player, (profileName), format["listed a building for sale $%1 at POS: %2", [_listPrice] call AP_fnc_numberText, (getPosATL _building)]], "APS_fnc_logIt", 2, false, false] call AP_fnc_MP;
[format["Congrats! Your building is now listed on the public market for $%1 for other citizens to purchase!", [_listPrice] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
[] spawn {uiSleep 10;
    AP_houseTxn = false;};