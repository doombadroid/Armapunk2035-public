// AP_fnc_newDispatch -- LooneyBin: auto-dispatch receiver (restored 2026-06-11).
// Server AP_fnc_createDispatch remoteExecs [ _id, _desc, _value, _pos ] to every west officer when an
// event fires (bank drill / fed reserve / prison break / store robbery). Shows a CAD popup + map marker.
params [["_id", 0, [0]], ["_desc", "", [""]], ["_value", 0, [0]], ["_pos", [0,0,0], [[]]]];
if (side player != west) exitWith {};
if (_desc isEqualTo "") exitWith {};
private _val = [_value] call AP_fnc_numberText; [
    format["<t color='#316dff'><t size='1.6'><t align='center'>Police Dispatch</t></t></t><br/><br/><t align='left'><t size='0.85'><t color='#33CC33'>Crime: <t color='#ffffff'>%1<br/><t color='#33CC33'>Reward: <t color='#ffffff'>$%2<br/><br/><t color='#ffffff'>Respond to the marked location.", _desc, _val],
    "copmsg"] spawn AP_fnc_handleMessage;
systemChat format["--- POLICE DISPATCH: %1 (reward $%2) ---", _desc, _val];
if (!(_pos isEqualTo [0,0,0]) && {(_pos select 0) > 0}) then {
    [_desc, _pos, " Dispatch -", "colorBLUFOR", "mil_warning", 600] spawn AP_fnc_createLMarker;};
AP_messages pushBack [format["Dispatch: %1", _desc], format["DISPATCH: %1 (reward $%2)", _desc, _val], time];
