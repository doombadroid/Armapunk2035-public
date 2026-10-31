if ((AP_is_arrested param [0,0]) isEqualTo 0) exitWith {};
if ((player distance(getMarkerPos "corrections")) > 100) exitWith {};
if (A_stats_crimes select 57 >= 1) exitWith {["You cannot escape prison while admin jailed.", "basic"] spawn AP_fnc_handleMessage;};
if (profileNameSpace getVariable["AP_requestedTrial", false]) exitWith {
    ["A prison break has occurred but you cannot escape when you're waiting on a trial.", "basic"] spawn AP_fnc_handleMessage};
private _time = (time + 65);
private _action = ["The Prison's security system has been compromised! Would you like to escape from jail? You have 1 minute to decide!", "Escape from Prison?", "Yes", "No"] call BIS_fnc_guiMessage;
if (round(_time - time) < 1) exitWith {systemChat "You took too long to decide! You will now serve your sentence out!";};
if !(SRV_prisonData select 1) exitWith {systemChat "You took too long to decide! The prison break is no longer in progress."};
if (_action) then {AP_breakout = true;};