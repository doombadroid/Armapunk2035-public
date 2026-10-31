/*
    custom_p3ds\lux_footprint.sqf -- clear the Malden fuel station out of the Lux
    tower's ground floor.

    THE TOWER IS BUILT ON TOP OF A FUEL STATION. skyscraper30 is placed at
    [7216.602, 7777.412] and Malden already has Land_FuelStation_01_* there, so the
    forecourt sits inside the lobby:

        Land_FuelStation_01_roof_malevil_F   model x=-0.60 z= 8.36  bbox 10.03 x 10 x 4.53
        Land_FuelStation_01_pump_malevil_F   model x=-3.93 z=-0.27   <-- in the stair core
        Land_FuelStation_01_pump_malevil_F   model x= 2.00 z=-0.55
        Land_FuelStation_01_pump_malevil_F   model x= 2.55 z= 8.18
        Land_FuelStation_01_pump_malevil_F   model x=-3.38 z= 8.46

    A 20 x 20 m canopy fills the ground floor and a pump stands in the stair core, on
    the approach to the doorway. That is what "cannot get in the doorway on the
    bottom floor" was, and it is why swapping the tower's own collision changed
    nothing: a build carrying r12's exact Geometry/Roadway LODs -- the version that
    works -- behaved identically, because the obstruction was never in the p3d.

    SERVER ONLY, and that is not a style choice: hideObjectGlobal on a TERRAIN object
    only takes effect, and only JIP-persists, when it runs on the server. A client
    call silently no-ops. Same idiom and same reason as replace_sheds.sqf, which
    documents it after being caught by it.

    Hiding a terrain object removes its collision along with its visuals, so this
    both clears the walkway and stops a petrol canopy drawing through the lobby.

    Scoped by CLASS and by distance, not by "everything inside the footprint": the
    trees, walls and billboards around the plot are wanted, and a blanket sweep of
    the footprint would take them too.
*/
if (!isServer) exitWith {};

private _centre = [7216.602, 7777.412, 0];
private _hidden = 0;

{
    if (!isNull _x && {!(_x getVariable ["AP_luxFootprintHidden", false])}) then {
        _x hideObjectGlobal true;
        _x setVariable ["AP_luxFootprintHidden", true, true];
        _hidden = _hidden + 1;
    };
} forEach (nearestObjects [_centre, [
    "Land_FuelStation_01_pump_malevil_F",
    "Land_FuelStation_01_roof_malevil_F",
    "Land_FuelStation_01_shop_F",
    "Land_FuelStation_01_workshop_F"
], 30]);

diag_log format ["[LUX] footprint: hid %1 fuel-station object(s) inside the tower plot", _hidden];
