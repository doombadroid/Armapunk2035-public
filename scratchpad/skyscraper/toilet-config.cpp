// toilet-config.cpp — luxury wall-hung toilet with integrated bidet. No anims: no model.cfg needed.
class CfgPatches {
    class ap_structures_toilet {
        units[] = {"Land_AP_LuxToiletBidet_F"};
        weapons[] = {};
        requiredVersion = 2.10;
        requiredAddons[] = {"A3_Structures_F"};
    };
};
class CfgVehicles {
    class House_F;
    class Land_AP_LuxToiletBidet_F : House_F {
        scope = 2;
        scopeCurator = 2;
        displayName = "Toilet (luxury, bidet)";
        model = "\ap_structures\ap_lux_toilet_bidet.p3d";   // adjust to your addon prefix
        editorCategory = "EdCat_Structures";
        editorSubcategory = "EdSubcat_Furniture";
        vehicleClass = "Structures";
        mapSize = 1;
        icon = "iconObject_1x1";
        cost = 22000;
        armor = 200;
        destrType = "DestructNo";
        class AnimationSources {};
        class UserActions {};
    };
};
