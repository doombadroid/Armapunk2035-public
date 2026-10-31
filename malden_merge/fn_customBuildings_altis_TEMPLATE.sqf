/*
    fn_customBuildings.sqf  (LooneyBin Altis -- custom mission-embedded buildings, NO mod)
    Spawns custom .p3d buildings shipped INSIDE the Altis mission PBO. Clients receive them
    via the normal mission download -- no addon, no -mod, no signature.

    PROVEN PATH (this box, 2026-06-22): models MUST be referenced as
        mpmissions\__cur_mp.Altis\custom_p3ds\<Model>.p3d
    (absolute dev paths + bare names fail silently -> invisible on server/clients.)

    SETUP:
      1. Drop the chosen .p3d (+ any .paa textures) into  mission/LooneyBin.Altis/custom_p3ds/
      2. Fill _B below: [model, x, y, dir]  (z auto from terrain ASL + the catalog zOffset)
      3. Call server-side at init (initServer.sqf):  [] call AP_fnc_customBuildings;

    CATALOG (model -> zOffset, scale)  -- from ProjectMaldenMerge:
      Bank 6.53/1   JewelryBuildingModel 6.85/1   HQMesh 3.1/1   PoliceHQWallLong 2.75/1
      AsylumGrandPalaceBuilding 8.4/0.7   PalaceShop 4.8/0.7   mentalasylum13 7/3
      RebelRig -11.2/1   EvidenceSign 1.3/1.5   FederalReserveSign 1.8/1.5   ShopBuildingTrini ?/1
*/
if (!isServer) exitWith {};
private _world = "Altis";
private _cat = createHashMapFromArray [
    ["Bank",[6.53,1]], ["JewelryBuildingModel",[6.85,1]], ["HQMesh",[3.1,1]],
    ["PoliceHQWallLong",[2.75,1]], ["AsylumGrandPalaceBuilding",[8.4,0.7]],
    ["PalaceShop",[4.8,0.7]], ["mentalasylum13",[7,3]], ["RebelRig",[-11.2,1]],
    ["EvidenceSign",[1.3,1.5]], ["FederalReserveSign",[1.8,1.5]], ["ShopBuildingTrini",[0,1]]
];
// >>> FILL THIS: [model, x, y, dirDeg]  (one row per building you want on Altis)
private _B = [
    // ["Bank", 0000.0, 0000.0, 0],
];
{
    _x params ["_m","_x0","_y0","_dir"];
    private _c = _cat getOrDefault [_m, [0,1]];
    private _o = createSimpleObject [format ["mpmissions\__cur_mp.%1\custom_p3ds\%2.p3d", _world, _m], [0,0,0]];
    private _gz = getTerrainHeightASL [_x0, _y0];
    _o setPosASL [_x0, _y0, _gz + (_c select 0)];
    _o setDir _dir;
    _o setObjectScale (_c select 1);
} forEach _B;
