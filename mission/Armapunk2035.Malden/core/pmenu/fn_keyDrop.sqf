/*
    fn_keyDrop.sqf — give up your own key to a vehicle/house.

    TWO ENTRY POINTS, ONE SET OF RULES
      The keychain dialog (2700) fires this from a ButtonClick, so _this is
      [control, ...] and the vehicle comes from listbox 2702 — unchanged.
      The web deck passes the vehicle directly: [controlNull, _vehicle].

    A Control is not an Object, so the dialog's [control] argument can never be
    mistaken for a vehicle by the type-checked params.

    Note the impound branch: within 50 m of the impound object the FIRST owner
    dropping their key deletes the vehicle outright, because nobody is left to
    reclaim it. Everyone else just removes themselves from the owner list.

    Usage:  _this spawn AP_fnc_keyDrop;                  // from the dialog
            [controlNull, _veh] spawn AP_fnc_keyDrop;    // from a page
*/
params [["_control", controlNull, [controlNull]], ["_vehicle", objNull, [objNull]]];
disableSerialization;

private _fromDialog = isNull _vehicle;
if (_fromDialog) then {
    private _display = findDisplay 2700;
    if (!isNull _display) then {
        private _sel = lbCurSel (_display displayCtrl 2702);
        if (_sel >= 0 && { _sel < count AP_vehicles }) then { _vehicle = AP_vehicles select _sel; };
    };
};

if (isNull _vehicle) exitWith { false };

private _vehicleIndex = AP_vehicles find _vehicle;
if (_vehicleIndex isEqualTo -1) exitWith {
    ["That is not on your keychain.", "basic"] spawn AP_fnc_handleMessage;
    false
};

private _vehicleOwners = _vehicle getVariable ["AP_vehOwners", []];
private _mine = _vehicleOwners findIf {(getPlayerUID player) isEqualTo (_x param [0, ""])};
if (_mine isEqualTo -1) exitWith { false };

/*  LATENT BUG, DELIBERATELY LEFT ALONE — needs an owner ruling.

    The original impound branch reads:

        if ((getPlayerUID player) isEqualTo(_vehicleOwners select 0) select 0)

    which parses as ((uid isEqualTo <array>) select 0) — a String compared to an
    Array is always false, and `select` on the result never yields true. So the
    "first owner at the impound deletes the vehicle outright" case has never
    actually fired; at the impound it behaves exactly like a normal drop.

    Making it work would start DELETING players' vehicles at the impound, which
    is not a change to make while re-plumbing a function for a second caller.
    Behaviour below is therefore identical to what is live today.            */
AP_vehicles deleteAt _vehicleIndex;
_vehicleOwners deleteAt _mine;
_vehicle setVariable ["AP_vehOwners", _vehicleOwners, true];

if (_fromDialog) then {  };
true
