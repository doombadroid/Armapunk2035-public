params["_obj_main", "_stance"];
if (_obj_main isKindOf "CAManBase") then {};
_obj_main addAction["Pay Bail", {[player] call AP_fnc_postBail
}, nil, 1.5, false, false, "", '((AP_is_arrested param [0,0]) isEqualTo 1)', 5];
_obj_main addAction["Request a Court Trial", {["defendantRequestTrial", [player]] spawn AP_fnc_trialSystem
}, nil, 1.5, false, false, "", '((AP_is_arrested param [0,0]) isEqualTo 1)', 5];
_obj_main addAction["Let me out!", {if (AP_effSide isEqualTo west && (SRV_prisonData select 1)) exitWith {
        ["You cannot do this while a prison break is ongoing!", "basic"] spawn AP_fnc_handleMessage};
    private _plb_pos =
    if (AP_effSide isEqualTo west) then {[16846, 13529.6, 1.02138378]} else {getMarkerPos "jail_release2"};
    player setPos _plb_pos;
}, "", 1.5, false, false, "", '((AP_is_arrested param [0,0]) isEqualTo 0) && !(player getVariable ["AP_arrested", false])', 5];
_obj_main addAction["Queue for Laser tag", AP_fnc_laserJoin, "", 0, false, false, "", ' AP_effSide isEqualTo civilian && ((AP_is_arrested param [0,0]) isEqualTo 1)', 5];