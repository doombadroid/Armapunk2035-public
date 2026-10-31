params[["_vehicle", objNull, [objNull]]];
private _nearest = AP_escort;
if (isNull _nearest) exitWith {};
if (!isPlayer _nearest || !alive _nearest) exitWith {systemChat "You can't put a dead body in your vehicle. The upholstery will stink."};
if (((getPos _nearest) distance player) > 20) exitWith {};
if !(_nearest getVariable["AP_restrained", false]) exitWith {systemChat "Can't put someone in a vehicle when they're not restrained."}; [
    ["putinveh", _nearest, [_vehicle, false]], "APS_fnc_victimSRV", 2] spawn AP_fnc_MP;   // server re-checks, wakes them (AP_fnc_setUnconscious)
detach _nearest;
AP_escort = objNull;
_nearest setVariable["AP_escorting", nil, true];
_nearest setVariable["AP_transporting", true, true];
_nearest action["getInCargo", _vehicle];
uiSleep 1;
private _countCargo = (count fullCrew[_vehicle, "cargo", true]);
private _countTurret = (count fullCrew[_vehicle, "turret", true]);
private _totalCount = _countCargo + _countTurret;
private _seats = [];
for "_x"
from 0 to _totalCount do {_seats pushBack _x
}; if (typeOf _vehicle in ["O_T_LSV_02_unarmed_F", "B_T_LSV_01_unarmed_F", "C_Offroad_01_comms_F", "C_Offroad_02_unarmed_F"]) then {[
        ["putinveh", _nearest, [_vehicle, true]], "APS_fnc_victimSRV", 2] spawn AP_fnc_MP;} else {{scopeName "positionLoop";
        if (vehicle _nearest isEqualTo _nearest) then {_nearest action["getInCargo", _vehicle, _x];
            _nearest action["getInCommander", _vehicle];
            _nearest action["getInTurret", _vehicle, [_x]];} else {breakOut "positionLoop";};}
    forEach _seats;};
player setVariable["AP_escortObj", nil];