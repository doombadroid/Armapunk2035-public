/*
    AP_fnc_getBuildID (LooneyBin compat -- reverse-drift; real impl)
*/
// LooneyBin compat: stable building id for houses/gang houses
params [["_obj",objNull,[objNull]]];
if (isNull _obj) exitWith {-1};
private _id = _obj getVariable ["houseId", -1];
if (_id isEqualTo -1) then { _id = _obj getVariable ["AP_buildID", -1]; };
if (_id isEqualTo -1) then { private _p = getPosWorld _obj; _id = parseNumber (format ["%1%2", round (_p select 0), round (_p select 1)]); };
// houseId/AP_buildID are PUBLIC object vars (any client can setVariable them) and the server formats this id raw into
// '...' SQL (insertStorage, updateStorage, deleteHouse, queryHouses, receiveHouses). Real ids are numbers or digit strings.
if (_id isEqualType "") then { _id = _id splitString "'" joinString "" };
if !(_id isEqualTypeAny [0, ""]) then { _id = -1 };
_id
