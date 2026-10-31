params[["_PLB_code", {}, [{}]], ["_this", []]];
private "_PLB_return";
isNil {_PLB_return = ([_x] apply {call _PLB_code}) select 0;};
if (!isNil "_PLB_return") then {_PLB_return};