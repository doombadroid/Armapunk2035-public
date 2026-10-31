private _com = _this select 0;
if (!isText(getMissionConfig "rwt_chatcom" >> "commands" >> _com >> "code")) exitWith {
    ["RWT_CHATCOM: %1", "Invalid command"] call BIS_fnc_error;};
private _args = _this select[1, count _this];
private _plb_fncCall = compile(getText(getMissionConfig "rwt_chatcom" >> "commands" >> _com >> "code"));
_args call _plb_fncCall;