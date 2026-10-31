if (!isNull(uiNamespace getVariable["AP_message_hud", displayNull])) exitWith {true};
10 cutRsc["AP_message_hud", "PLAIN"];
private _display = uiNamespace getVariable["AP_message_hud", displayNull];
AP_message_active = scriptNull;
AP_message_list = [];
!isNull _display;