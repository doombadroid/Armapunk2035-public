params["_vehicle", "_rope", "_cargo"];
if ((isNull _cargo) || (isNull _vehicle) || (!alive _cargo) || (!alive _vehicle)) exitWith {};
waitUntil {uiSleep 0.5;
    ((_vehicle distance _cargo) >= 20);};
uiSleep(random 2);
if (((getPos _vehicle) select 2) < 100) exitWith {};
if ((count(attachedObjects _cargo)) isEqualTo 0) then {if !(nearestObjects[_cargo, ["B_Parachute_02_F"], 30] isEqualTo[]) exitWith {};
    private _timeLimit = time + 3;
    private _parachute = "B_Parachute_02_F"
    createVehicle(getPos _cargo);
    _parachute setPos(getPos _cargo);
    waitUntil {time > _timeLimit || ((_parachute distance _cargo) <= 30)};
    if (time < _timeLimit) then {_cargo attachTo[_parachute, [0, 0, (((boundingBoxReal _cargo) select 2) / 2) - 0.25]];};};