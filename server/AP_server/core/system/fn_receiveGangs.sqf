 
private["_session","_index","_talents","_members"]; 
_session = _this select 0;
diag_log format ["[LooneyBin][receiveGangs] received %1 row(s)", if (isNil "_session") then {-1} else {count _session}];

if(isNil "_session") exitWith {};
 {_sess = _x;
_index = -1; 
{ if ((_sess select 0) == (_x select 0)) then { _index = _forEachIndex; }; } foreach AP_server_gangs; 
if (_index < 0) then { _index = count AP_server_gangs; }; 
_members = _x param [6, 0]; if (_members isEqualType "") then { _members = parseNumber _members };
// gangs.talents is an mres column -- it is in the migration's transcoded set, so on
// PostgreSQL it comes back through mres.encode() like every other one. Decoding it
// with a bare parseSimpleArray was always wrong and only ever worked by accident:
// talents is a PURE NUMBER array, and for those the mres form and a plain array
// literal come out identical once extDB3's whole-result compile has eaten the outer
// quotes. On PostgreSQL there is no such compile, the real mres form arrives, and
// parseSimpleArray fails with a format error once per boot -- after which every gang
// silently falls back to [] and nobody's talents load.
//
// Routed through the same two-step decode receiveHouses uses (mresToArray hands back
// the INTERMEDIATE STRING, which then needs parseSimpleArray). parseSimpleArray, never
// call compile, on anything that came out of the database.
_talents = _x param [8, ""];
if (_talents isEqualType "") then {
    private _t = [_talents] call DB_fnc_mresToArray;
    if (_t isEqualType "") then { _t = parseSimpleArray (format ["%1", _t]) };
    _talents = _t;
};
if (isNil "_talents" || {!(_talents isEqualType [])}) then { _talents = [] };
if (count _x > 1) then { AP_server_gangs set [_index, [(_x param [0,-1]),(_x param [1,""]),(_x param [2,0]),parseNumber(format["%1",_x param [3,0]]),parseNumber(format["%1",_x param [4,0]]),parseNumber(format["%1",_x param [5,0]]),_members,parseNumber(format["%1",_x param [7,0]]),_talents]]; };
} foreach (_session);
diag_log format ["[LooneyBin][receiveGangs] AP_server_gangs now %1 gang(s)", count AP_server_gangs];
 