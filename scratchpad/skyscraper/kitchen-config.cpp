// kitchen-config.cpp — integrated kitchen run prop. No anims: no model.cfg needed.
class CfgPatches {
    class ap_structures_kitchen {
        units[] = {"Land_AP_KitchenRun_F"};
        weapons[] = {};
        requiredVersion = 2.10;
        requiredAddons[] = {"A3_Structures_F"};
    };
};
class CfgVehicles {
    class House_F;
    class Land_AP_KitchenRun_F : House_F {
        scope = 2;
        scopeCurator = 2;
        displayName = "Kitchen Run (integrated)";
        model = "\ap_structures\ap_kitchen_run.p3d";   // adjust to your addon prefix
        editorCategory = "EdCat_Structures";
        editorSubcategory = "EdSubcat_Furniture";
        vehicleClass = "Structures";
        mapSize = 3;
        icon = "iconObject_2x1";
        cost = 20000;
        armor = 200;
        destrType = "DestructNo";
        class AnimationSources {};
        class UserActions {};
    };
};
