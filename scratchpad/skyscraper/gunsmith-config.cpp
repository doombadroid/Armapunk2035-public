// gunsmith-config.cpp — Armapunk2035 gunsmith workbench
class CfgPatches {
    class AP_GunsmithBench {
        units[] = {"Land_AP_GunsmithBench_F"};
        weapons[] = {};
        requiredVersion = 2.18;
        requiredAddons[] = {"A3_Structures_F"};
    };
};
class CfgVehicles {
    class House_F;
    class Land_AP_GunsmithBench_F : House_F {
        scope = 2;
        scopeCurator = 2;
        displayName = "Gunsmith Workbench (AP2035)";
        model = "\ap2035\props\gunsmith\ap_gunsmith_bench.p3d";
        editorCategory = "EdCat_AP2035";
        editorSubcategory = "EdSubcat_AP_Interior";
        vehicleClass = "Structures";
        destrType = "DestructNo";
        mapSize = 2.0;
        cost = 0;
        armor = 200;
        keepHorizontalPlacement = 1;
    };
};
