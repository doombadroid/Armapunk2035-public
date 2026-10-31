params["_obj_main", "_stance", "_govBuilding"];
if (_obj_main isKindOf "CAManBase") then {};
_obj_main addAction["Vote for Governor", AP_fnc_govVotingMenu, "", 1.5, false, false, "", '', 5];
if (_govBuilding) then {_obj_main addAction["Run for Office", AP_fnc_govCandidateMenu, "", 1.5, false, false, "", '', 5];};