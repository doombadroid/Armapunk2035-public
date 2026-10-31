// shower-config.cpp — luxury walk-in shower prop. No anims: no model.cfg needed.
class CfgPatches {
    class ap_structures_shower {
        units[] = {"Land_AP_LuxShower_F"};
        weapons[] = {};
        requiredVersion = 2.10;
        requiredAddons[] = {"A3_Structures_F"};
    };
};
class CfgVehicles {
    class House_F;
    class Land_AP_LuxShower_F : House_F {
        scope = 2;
        scopeCurator = 2;
        displayName = "Shower (luxury walk-in)";
        model = "\ap_structures\ap_lux_shower.p3d";   // adjust to your addon prefix
        editorCategory = "EdCat_Structures";
        editorSubcategory = "EdSubcat_Furniture";
        vehicleClass = "Structures";
        mapSize = 2;
        icon = "iconObject_1x2";
        cost = 25000;
        armor = 200;
        destrType = "DestructNo";
        class AnimationSources {};
        class UserActions {};
    };
};
