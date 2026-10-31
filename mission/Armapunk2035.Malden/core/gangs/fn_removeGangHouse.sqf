params[["_building", objNull, [objNull]], ["_gangid", -1, [0]], ["_houseOwner", "", [""]]];
if (isNull _building || _gangid isEqualTo - 1) exitWith {};
if !((AP_gang_data select 0) isEqualTo _gangid) exitWith {};
deleteMarkerLocal AP_gangBldgMark;
AP_gangBldgMark = "";
AP_vehicles deleteAt(AP_vehicles find _building);
AP_houses deleteAt(AP_houses find(str(getPosATL _building)));
AP_gangBuilding = [objNull, []];
AP_gang_data set[3, [0, 0, 0]];
private _text =
if (AP_gang_data param[2, 0] isEqualTo 1) then {"You have removed this house as your gang house."} else {
    "The leader has removed or sold the gang house, and it has been removed from your spawn options..."};
[_text, "basic"] spawn AP_fnc_handleMessage;