params[["_pain", 0, [0]]];
AP_pain = _pain;
if (_pain > 0) then {player setVariable["AP_unitPain", _pain, true];
    systemChat "You are in pain";
    profileNamespace setVariable["AP_unitPain", _pain];
    _pain spawn {private _pain = _this;
        while {true}
        do {if !(_pain isEqualTo AP_pain) exitWith {};
            resetCamShake;
            addCamShake[1, 2, _pain * 10];
            uiSleep 3.5;};};} else {if (player getVariable["AP_unitPain", -1] > 0) then {player setVariable["AP_unitPain", nil, true];
        profileNamespace setVariable["AP_unitPain", _pain];};};