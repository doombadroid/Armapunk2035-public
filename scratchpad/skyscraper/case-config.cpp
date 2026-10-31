// case-config.cpp — storefront jewelry display case prop. No anims: no model.cfg needed.
class CfgPatches {
    class ap_structures_case {
        units[] = {"Land_AP_JewelryCase_F","Land_AP_JewelryCaseSmashed_F","Land_AP_JewelryCaseOpen_F"};
        weapons[] = {};
        requiredVersion = 2.10;
        requiredAddons[] = {"A3_Structures_F"};
    };
};
class CfgVehicles {
    class House_F;
    class Land_AP_JewelryCase_F : House_F {
        scope = 2;
        scopeCurator = 2;
        displayName = "Jewelry Display Case";
        model = "\ap_structures\ap_jewelry_case.p3d";   // adjust to your addon prefix
        editorCategory = "EdCat_Structures";
        editorSubcategory = "EdSubcat_Commercial";
        vehicleClass = "Structures";
        mapSize = 2;
        icon = "iconObject_2x1";
        cost = 40000;
        armor = 200;
        destrType = "DestructNo";
        class AnimationSources {};
        class UserActions {};
    };
    class Land_AP_JewelryCaseOpen_F : Land_AP_JewelryCase_F {
        displayName = "Jewelry Display Case (open)";
        model = "\ap_structures\ap_jewelry_case_open.p3d";
    };
    class Land_AP_JewelryCaseSmashed_F : Land_AP_JewelryCase_F {
        displayName = "Jewelry Display Case (smashed)";
        model = "\ap_structures\ap_jewelry_case_smashed.p3d";
        cost = 0;
    };
};
