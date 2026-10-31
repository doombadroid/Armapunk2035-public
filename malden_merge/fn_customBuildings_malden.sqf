// AUTO-GENERATED (pushBack form -- avoids SQF large-array-literal compile limit / GIAR stack error)
// Custom mission-embedded buildings, NO mod. Path proven: mpmissions\__cur_mp.<world>\<model>.p3d
// runs on EVERY machine (createSimpleObject is local) -- call from init.sqf, not isServer-gated
private _world = "Malden";
private _blds = [];
_blds pushBack ["Bank", 6244.42, 2870.76, 59.18, 6.53, 180.0, 1];
_blds pushBack ["RebelRig", 6221.13, 11978.71, 0.26, -11.2, 180.0, 1];
_blds pushBack ["mentalasylum13", 4254.9, 3907.5, 26.81, 7, 122.1, 3];
_blds pushBack ["EvidenceSign", 9549.04, 4202.29, 36.09, 1.3, 315.8, 1.5];
_blds pushBack ["FederalReserveSign", 11218.65, 4335.19, 16.94, 1.8, 332.6, 1.5];
_blds pushBack ["JewelryBuildingModel", 7545.76, 10570.1, 28.88, 6.85, 358.8, 1];
_blds pushBack ["HQMesh", 8551.15, 3226.34, 30.57, 3.1, 180.0, 1];
_blds pushBack ["PoliceHQWallLong", 8557.78, 3248.89, 28.98, 2.75, 320.0, 1];
_blds pushBack ["PoliceHQWallLong", 8550.84, 3257.14, 28.93, 2.75, 320.0, 1];
_blds pushBack ["PoliceHQWallLong", 8541.94, 3261.48, 28.88, 2.75, 271.9, 1];
_blds pushBack ["PoliceHQWallLong", 8531.08, 3261.82, 28.83, 2.75, 271.9, 1];
_blds pushBack ["PoliceHQWallLong", 8520.13, 3262.15, 28.76, 2.75, 271.9, 1];
_blds pushBack ["PoliceHQWallLong", 8518.66, 3200.3, 27.55, 2.75, 269.1, 1];
_blds pushBack ["PoliceHQWallLong", 8529.62, 3200.53, 28.25, 2.75, 269.1, 1];
_blds pushBack ["PoliceHQWallLong", 8540.59, 3200.73, 29.2, 2.75, 269.1, 1];
_blds pushBack ["PoliceHQWallLong", 8551.5, 3200.91, 29.84, 2.75, 269.1, 1];
_blds pushBack ["PoliceHQWallLong", 8514.12, 3257.13, 28.72, 2.75, 181.9, 1];
_blds pushBack ["PoliceHQWallLong", 8513.78, 3246.14, 28.62, 2.75, 181.9, 1];
_blds pushBack ["PoliceHQWallLong", 8513.38, 3235.19, 28.59, 2.75, 181.9, 1];
_blds pushBack ["PoliceHQWallLong", 8512.73, 3205.49, 27.47, 2.75, 181.9, 1];
_blds pushBack ["HQMesh", 5588.38, 4227.06, 103.73, 3.1, 180.0, 1];
_blds pushBack ["PoliceHQWallLong", 5528.08, 4225.44, 103.81, 2.75, 0.0, 1];
_blds pushBack ["PoliceHQWallLong", 5528.12, 4214.39, 103.83, 2.75, 0.0, 1];
_blds pushBack ["PoliceHQWallLong", 5527.91, 4247.2, 103.8, 2.75, 0.0, 1];
_blds pushBack ["PoliceHQWallLong", 5533.75, 4208.94, 103.82, 2.75, 270.0, 1];
_blds pushBack ["PoliceHQWallLong", 5544.79, 4208.99, 103.87, 2.75, 270.0, 1];
_blds pushBack ["PoliceHQWallLong", 5527.96, 4258.27, 103.28, 2.75, 0.0, 1];
_blds pushBack ["PoliceHQWallLong", 5544.3, 4263.82, 102.76, 2.75, 90.0, 1];
_blds pushBack ["PoliceHQWallLong", 5533.25, 4263.77, 102.8, 2.75, 90.0, 1];
_blds pushBack ["PoliceHQWallLong", 5566.43, 4263.88, 102.82, 2.75, 90.0, 1];
_blds pushBack ["PoliceHQWallLong", 5555.38, 4263.82, 102.86, 2.75, 90.0, 1];
_blds pushBack ["PoliceHQWallLong", 5588.57, 4264.03, 102.99, 2.75, 90.0, 1];
_blds pushBack ["PoliceHQWallLong", 5577.53, 4263.98, 103.03, 2.75, 90.0, 1];
_blds pushBack ["PoliceHQWallLong", 5594.17, 4257.89, 102.86, 2.75, 180.0, 1];
_blds pushBack ["PoliceHQWallLong", 5594.12, 4246.82, 102.84, 2.75, 180.0, 1];
_blds pushBack ["HQMesh", 3374.95, 6301.85, 232.06, 3.1, 180.0, 1];
_blds pushBack ["AsylumGrandPalaceBuilding", 7214.37, 7862.5, 166.28, 8.4, 270.0, 0.7];
_blds pushBack ["PalaceShop", 7193.75, 7932.29, 167.25, 4.8, 10.0, 0.7];
_blds pushBack ["PalaceShop", 7287.14, 7952.74, 167.6, 4.8, 180.0, 0.7];
{
    _x params ["_m","_x0","_y0","_z","_off","_dir","_scl"];
    private _o = createSimpleObject [format ["mpmissions\__cur_mp.%1\%2.p3d", _world, _m], [0,0,0]];
    _o setPosASL [_x0, _y0, _z + _off];
    _o setDir _dir;
    _o setObjectScale _scl;
} forEach _blds;
// bridge
private _bp = [8512.527, 3765, 0];
for "_i" from 1 to 16 do {
    private _mm = ["BridgeStraight","BridgeMiddle"] select (_i == 9);
    createSimpleObject [format ["mpmissions\__cur_mp.%1\%2.p3d", _world, _mm], _bp];
    _bp set [0, (_bp select 0) + 50];
};
