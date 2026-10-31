if (objectParent player isKindOf "Air") exitWith {
    ["That's a touch dangerous to try, don't you think?", "basic"] spawn AP_fnc_handleMessage;};
private _spikeStrip = createVehicle["Land_Razorwire_F", [random(999), random(999), 999], [], 0, "CAN_COLLIDE"];
private _plb_dmg = _spikeStrip;
uiSleep 1;
_plb_dmg setDamage 1;
_spikestrip hideObjectGlobal true;
if (isNull objectParent player) then {_spikeStrip attachTo[player, [0, 5.5, 0]];} else {_spikeStrip attachTo[vehicle player, [0, -5, 0]];};
detach _spikeStrip;
private _dir = getDir(vehicle player);
if (isNull objectParent player) then {_spikeStrip setDir(_dir + 90);} else {_spikeStrip setDir _dir;};
_spikeStrip setPos[getPos _spikeStrip select 0, getPos _spikeStrip select 1, 0];
_spikestrip hideObjectGlobal false;
_plb_dmg setDamage 1;
_spikeStrip setVariable["AP_placed", true, true]; [[_spikeStrip, 600], "APS_fnc_setCleanTime", 2] spawn AP_fnc_MP; [
    [_spikeStrip], "APS_fnc_srvSpikeStrip", 2] spawn AP_fnc_MP;