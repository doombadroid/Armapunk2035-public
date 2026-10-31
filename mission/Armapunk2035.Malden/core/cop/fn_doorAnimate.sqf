params[["_object", objNull, [objNull]], ["_forced", false, [false]]];
private _action = true;
if (_forced) then {
    _action = ["You are about to force open/close a secured door. By forcing open this door you agree to MaxSec policy regarding usage of this function.", "Door Kicker 5000", "Continue", "Cancel"] call BIS_fnc_guiMessage;
};
if !(_action) exitWith {};
private _doors = getNumber(configFile >> "CfgVehicles" >> (typeOf _object) >> "NumberOfDoors");
private _door = 0;
for "_i"
from 1 to _doors do {_selPos = _object selectionPosition format["Door_%1_trigger", _i];
    _worldSpace = _object modelToWorld _selPos;
    if (player distance _worldSpace < 5) exitWith {_door = _i};}; if (_door isEqualTo 0) exitWith {
    ["You're not near a door!", "basic"] spawn AP_fnc_handleMessage;};
private _target = [1, 0] select(((_object animationPhase format["door_%1a_move", _door]) isEqualTo 1) || ((_object animationPhase format["door_%1_rot", _door]) isEqualTo 1) || ((_object animationPhase format["door_%1a_rot", _door]) isEqualTo 1)); {
    _object animateSource[format[_x, _door], _target];}
forEach["Door_%1_source", "Door_%1_sound_source", "Door_%1_noSound_source"];
if (_forced) then {[
        ["-FORCEDOOR-", player, profileName, format["opened/closed a door at location %1 - Evidence(%2) - Bank(%3) - Fed(%4) - Shipping(%5) - LoonyBin(%6)", getPosATL player, (SRV_evidence_status select 0), (AP_bank_robbed select 0), (AP_fed_robbed select 0), (SRV_convoy_status select 0), (SRV_loonyBinData param[1, false])]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
};
closeDialog 0;