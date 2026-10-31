params["_obj_main", "_stance"];
if (_obj_main isKindOf "CAManBase") then {};
_obj_main addAction["Send Broadcast ($30,000)", AP_fnc_ch7Broadcast, "", 1.5, false, false, "", '', 5];