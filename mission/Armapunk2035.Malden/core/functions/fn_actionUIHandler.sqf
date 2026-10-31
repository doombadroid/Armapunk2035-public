private _actionDisplayText = _this select 4;
private _handled = false;
_handled =
switch (_actionDisplayText) do {default {_handled};
}; if (player getVariable["AP_restrained", false] || player getVariable["AP_downed", false]) then {_handled = true;};
if ((call AP_adminLevel) >= 2) then {_handled = false;};
_handled;