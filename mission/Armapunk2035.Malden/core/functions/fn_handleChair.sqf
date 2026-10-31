params[["_chairObject", objNull, [objNull]]];
if (_chairObject isEqualTo AP_electricChair) exitWith {};
if !(isNull AP_sittingChair) then {deleteVehicle AP_sittingChair;
    AP_sittingChair = objNull;
    ["", 0, "switchMove", player] spawn AP_fnc_handleAnim;} else {private _posATL = getPosATL _chairObject;
    private _chairDirection = -180;
    private _zCoord = 0;
    private _hiddenObject = "Land_ClutterCutter_small_F"
    createVehicle _posATL;
    _hiddenObject setPosATL _posATL;
    _hiddenObject setDir((direction _chairObject) - _chairDirection);
    player attachTo[_hiddenObject, [0, 0, _zCoord]];
    player switchMove "Crew";
    private _toSend = allPlayers select {(_x distance player) <= 200}; [
        ["crew", 300, "switchMove", player], "AP_fnc_handleAnim", _toSend] spawn AP_fnc_MP;
    detach player;
    AP_sittingChair = _hiddenObject;};