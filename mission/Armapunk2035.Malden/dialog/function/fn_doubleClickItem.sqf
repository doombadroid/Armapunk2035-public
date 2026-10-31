params[["_list", 0, [0]], ["_box", 0, [0]], ["_remove", false, [false]], ["_physicalStorage", false, [false]]];
disableSerialization;
private _ctrl = lbData[_list, lbCurSel _list];
private _num = 1;
if !(_physicalStorage) then {if (_remove) then {
        private _index = [_ctrl, (AP_trunk_vehicle getVariable "AP_vinv") select 0] call AP_fnc_index;
        private _data = (AP_trunk_vehicle getVariable "AP_vinv") select 0;
        _num = (_data select _index) select 1;} else {private _var = format["AP_inv_%1", _ctrl];
        _num = missionNamespace getVariable _var;};} else {if (_remove) then {
        private _index = [_ctrl, (AP_trunk_vehicle getVariable "AP_pinv") select 0] call AP_fnc_index;
        private _data = (AP_trunk_vehicle getVariable "AP_pinv") select 0;
        _num = (_data select _index) select 1;} else {_num = lbValue[_list, lbCurSel _list];};};
ctrlSetText[_box, format["%1", _num]];