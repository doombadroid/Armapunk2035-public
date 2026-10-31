params["_ctrl", "_code"];
private _handled = false;
if (AP_show_actions) then {AP_show_actions = false;
    private _obj_main = player;
    removeAllActions _obj_main;
    AP_actions = [];};
_handled