private _spikes = nearestObjects[player, ["Land_Razorwire_F"], 8] select 0;
if (isNil "_spikes" || {_spikes isEqualTo[]}) exitWith {};
if isNil {(_spikes getVariable "AP_placed")}
exitWith {};
switch (AP_effSide) do {case west: {if ([true, "spikeStrip", 1] call AP_fnc_handleInv) then {
                titleText["You have packed up the spike strip.", "PLAIN"];
                deleteVehicle _spikes;};};
    case civilian: {disableSerialization;
            5 cutRsc["AP_progress", "PLAIN"];
            private _display = uiNameSpace getVariable["AP_progress", displayNull];
            private _progressBar = _display displayCtrl 38201;
            private _progressText = _display displayCtrl 38202;
            AP_action_in_use = true;
            private _increment = 1;
            private _totalTime = 10;
            private _currentPoint = 0;
            private _loopDelay = _totalTime / floor(100 / _increment);
            private _text = "Destroying spike strip";
            private _startCount = 0;
            _progressBar progressSetPosition _startCount;
            _progressText ctrlSetText format["%1 (%2%3)", _text, _startCount, "%"];
            private _duration = 20;
            private _animation = "AinvPknlMstpSnonWnonDnon_medic_1";
            [_animation, _duration] spawn AP_fnc_handleAnim;
            private _isSuccess =
            for "_i"
            from 0 to 1 step 0 do {uiSleep _loopDelay;
                if (isNull _progressBar) exitWith {[2, "You have failed to destroy the spike strip."] call AP_fnc_broadcast;
                    false};
                _currentPoint = (progressPosition _progressBar) + (_increment / 100);
                _progressBar progressSetPosition _currentPoint;
                _progressText ctrlSetText format["%1 (%2%3)", _text, round(_currentPoint * 100), "%"];
                if (_currentPoint >= 1) exitWith {true};
                if ((speed player) >= 2) exitWith {[2, "You have failed to destroy the spike strip."] call AP_fnc_broadcast;
                    false};
                if !((vehicle player) isEqualTo player) exitWith {
                    [2, "You have failed to destroy the spike strip."] call AP_fnc_broadcast;
                    false};
                if (player getVariable["AP_downed", false] || player getVariable["AP_restrained", false]) exitWith {
                    [2, "You have failed to destroy the spike strip."] call AP_fnc_broadcast;
                    false};
                if ((!AP_action_in_use) || (!alive player) || ((player distance _spikes) >= 6)) exitWith {
                    [2, "You have failed to destroy the spike strip."] call AP_fnc_broadcast;
                    false};
                false;}; AP_action_in_use = false;
            [] spawn AP_fnc_handleAnim;
            5 cutText["", "PLAIN"];
            if (_isSuccess) then {deleteVehicle _spikes;
                ["You have successfully destroyed the spike strip.", "basic"] spawn AP_fnc_handleMessage;};};
    default {};};