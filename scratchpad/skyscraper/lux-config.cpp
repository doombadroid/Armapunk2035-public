class CfgPatches {
  class lux_tower {
    units[] = {"Land_LuxTower_F"}; weapons[] = {};
    requiredVersion = 1.0; requiredAddons[] = {"A3_Structures_F"};
  };
};
class CfgVehicles {
  class House_F;
  class Land_LuxTower_F : House_F {
    scope = 2; scopeCurator = 2;
    displayName = "Lux Tower (30fl)";
    model = "\lux_tower\skyscraper_lux.p3d";
    editorCategory = "EdCat_Structures";
    vehicleClass = "Structures";
    mapSize = 40; cost = 0;
    class AnimationSources {
      class door_1_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_1_trigger"; };
      class door_2_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_2_trigger"; };
      class door_3_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_3_trigger"; };
      class door_4_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_4_trigger"; };
      class door_5_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_5_trigger"; };
      class door_6_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_6_trigger"; };
      class door_7_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_7_trigger"; };
      class door_8_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_8_trigger"; };
      class door_9_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_9_trigger"; };
      class door_10_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_10_trigger"; };
      class door_11_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_11_trigger"; };
      class door_12_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_12_trigger"; };
      class door_13_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_13_trigger"; };
      class door_14_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_14_trigger"; };
      class door_15_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_15_trigger"; };
      class door_16_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_16_trigger"; };
      class door_17_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_17_trigger"; };
      class door_18_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_18_trigger"; };
      class door_19_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_19_trigger"; };
      class door_20_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_20_trigger"; };
      class door_21_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_21_trigger"; };
      class door_22_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_22_trigger"; };
      class door_23_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_23_trigger"; };
      class door_24_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_24_trigger"; };
      class door_25_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_25_trigger"; };
      class door_26_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_26_trigger"; };
      class door_27_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_27_trigger"; };
      class door_28_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_28_trigger"; };
      class door_29_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_29_trigger"; };
      class door_30_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_30_trigger"; };
      class door_31_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_31_trigger"; };
      class door_32_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_32_trigger"; };
      class door_33_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_33_trigger"; };
      class door_34_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_34_trigger"; };
      class door_35_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_35_trigger"; };
      class door_36_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_36_trigger"; };
      class door_37_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_37_trigger"; };
      class door_38_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_38_trigger"; };
      class door_39_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_39_trigger"; };
      class door_40_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_40_trigger"; };
      class door_41_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_41_trigger"; };
      class door_42_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_42_trigger"; };
      class door_43_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_43_trigger"; };
      class door_44_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_44_trigger"; };
      class door_45_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_45_trigger"; };
      class door_46_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_46_trigger"; };
      class door_47_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_47_trigger"; };
      class door_48_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_48_trigger"; };
      class door_49_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_49_trigger"; };
      class door_50_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_50_trigger"; };
      class door_51_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_51_trigger"; };
      class door_52_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_52_trigger"; };
      class door_53_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_53_trigger"; };
      class door_54_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_54_trigger"; };
      class door_55_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_55_trigger"; };
      class door_56_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_56_trigger"; };
      class door_57_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_57_trigger"; };
      class door_58_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_58_trigger"; };
      class door_59_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_59_trigger"; };
      class door_60_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_60_trigger"; };
      class door_61_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_61_trigger"; };
      class door_62_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_62_trigger"; };
      class door_63_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_63_trigger"; };
      class door_64_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_64_trigger"; };
      class door_65_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_65_trigger"; };
      class door_66_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_66_trigger"; };
      class door_67_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_67_trigger"; };
      class door_68_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_68_trigger"; };
      class door_69_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_69_trigger"; };
      class door_70_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_70_trigger"; };
      class door_71_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_71_trigger"; };
      class door_72_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_72_trigger"; };
      class door_73_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_73_trigger"; };
      class door_74_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_74_trigger"; };
      class door_75_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_75_trigger"; };
      class door_76_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_76_trigger"; };
      class door_77_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_77_trigger"; };
      class door_78_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_78_trigger"; };
      class door_79_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_79_trigger"; };
      class door_80_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_80_trigger"; };
      class door_81_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_81_trigger"; };
      class door_82_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_82_trigger"; };
      class door_83_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_83_trigger"; };
      class door_84_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_84_trigger"; };
      class door_85_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_85_trigger"; };
      class door_86_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_86_trigger"; };
      class door_87_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_87_trigger"; };
      class door_88_source { source = "user"; animPeriod = 1; initPhase = 0; sound = "ServoDoorsSound"; soundPosition = "door_88_trigger"; };
    };
    class UserActions {
      class Open_door_1 {
        displayName = "Open Door"; position = "door_1_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_1_rot' < 0.5";
        statement = "this animate ['door_1_rot', 1]";
      };
      class Close_door_1 {
        displayName = "Close Door"; position = "door_1_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_1_rot' >= 0.5";
        statement = "this animate ['door_1_rot', 0]";
      };
      class Open_door_2 {
        displayName = "Open Door"; position = "door_2_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_2_rot' < 0.5";
        statement = "this animate ['door_2_rot', 1]";
      };
      class Close_door_2 {
        displayName = "Close Door"; position = "door_2_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_2_rot' >= 0.5";
        statement = "this animate ['door_2_rot', 0]";
      };
      class Open_door_3 {
        displayName = "Open Door"; position = "door_3_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_3_rot' < 0.5";
        statement = "this animate ['door_3_rot', 1]";
      };
      class Close_door_3 {
        displayName = "Close Door"; position = "door_3_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_3_rot' >= 0.5";
        statement = "this animate ['door_3_rot', 0]";
      };
      class Open_door_4 {
        displayName = "Open Door"; position = "door_4_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_4_rot' < 0.5";
        statement = "this animate ['door_4_rot', 1]";
      };
      class Close_door_4 {
        displayName = "Close Door"; position = "door_4_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_4_rot' >= 0.5";
        statement = "this animate ['door_4_rot', 0]";
      };
      class Open_door_5 {
        displayName = "Open Door"; position = "door_5_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_5_rot' < 0.5";
        statement = "this animate ['door_5_rot', 1]";
      };
      class Close_door_5 {
        displayName = "Close Door"; position = "door_5_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_5_rot' >= 0.5";
        statement = "this animate ['door_5_rot', 0]";
      };
      class Open_door_6 {
        displayName = "Open Door"; position = "door_6_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_6_rot' < 0.5";
        statement = "this animate ['door_6_rot', 1]";
      };
      class Close_door_6 {
        displayName = "Close Door"; position = "door_6_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_6_rot' >= 0.5";
        statement = "this animate ['door_6_rot', 0]";
      };
      class Open_door_7 {
        displayName = "Open Door"; position = "door_7_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_7_rot' < 0.5";
        statement = "this animate ['door_7_rot', 1]";
      };
      class Close_door_7 {
        displayName = "Close Door"; position = "door_7_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_7_rot' >= 0.5";
        statement = "this animate ['door_7_rot', 0]";
      };
      class Open_door_8 {
        displayName = "Open Door"; position = "door_8_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_8_rot' < 0.5";
        statement = "this animate ['door_8_rot', 1]";
      };
      class Close_door_8 {
        displayName = "Close Door"; position = "door_8_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_8_rot' >= 0.5";
        statement = "this animate ['door_8_rot', 0]";
      };
      class Open_door_9 {
        displayName = "Open Door"; position = "door_9_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_9_rot' < 0.5";
        statement = "this animate ['door_9_rot', 1]";
      };
      class Close_door_9 {
        displayName = "Close Door"; position = "door_9_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_9_rot' >= 0.5";
        statement = "this animate ['door_9_rot', 0]";
      };
      class Open_door_10 {
        displayName = "Open Door"; position = "door_10_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_10_rot' < 0.5";
        statement = "this animate ['door_10_rot', 1]";
      };
      class Close_door_10 {
        displayName = "Close Door"; position = "door_10_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_10_rot' >= 0.5";
        statement = "this animate ['door_10_rot', 0]";
      };
      class Open_door_11 {
        displayName = "Open Door"; position = "door_11_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_11_rot' < 0.5";
        statement = "this animate ['door_11_rot', 1]";
      };
      class Close_door_11 {
        displayName = "Close Door"; position = "door_11_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_11_rot' >= 0.5";
        statement = "this animate ['door_11_rot', 0]";
      };
      class Open_door_12 {
        displayName = "Open Door"; position = "door_12_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_12_rot' < 0.5";
        statement = "this animate ['door_12_rot', 1]";
      };
      class Close_door_12 {
        displayName = "Close Door"; position = "door_12_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_12_rot' >= 0.5";
        statement = "this animate ['door_12_rot', 0]";
      };
      class Open_door_13 {
        displayName = "Open Door"; position = "door_13_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_13_rot' < 0.5";
        statement = "this animate ['door_13_rot', 1]";
      };
      class Close_door_13 {
        displayName = "Close Door"; position = "door_13_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_13_rot' >= 0.5";
        statement = "this animate ['door_13_rot', 0]";
      };
      class Open_door_14 {
        displayName = "Open Door"; position = "door_14_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_14_rot' < 0.5";
        statement = "this animate ['door_14_rot', 1]";
      };
      class Close_door_14 {
        displayName = "Close Door"; position = "door_14_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_14_rot' >= 0.5";
        statement = "this animate ['door_14_rot', 0]";
      };
      class Open_door_15 {
        displayName = "Open Door"; position = "door_15_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_15_rot' < 0.5";
        statement = "this animate ['door_15_rot', 1]";
      };
      class Close_door_15 {
        displayName = "Close Door"; position = "door_15_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_15_rot' >= 0.5";
        statement = "this animate ['door_15_rot', 0]";
      };
      class Open_door_16 {
        displayName = "Open Door"; position = "door_16_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_16_rot' < 0.5";
        statement = "this animate ['door_16_rot', 1]";
      };
      class Close_door_16 {
        displayName = "Close Door"; position = "door_16_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_16_rot' >= 0.5";
        statement = "this animate ['door_16_rot', 0]";
      };
      class Open_door_17 {
        displayName = "Open Door"; position = "door_17_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_17_rot' < 0.5";
        statement = "this animate ['door_17_rot', 1]";
      };
      class Close_door_17 {
        displayName = "Close Door"; position = "door_17_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_17_rot' >= 0.5";
        statement = "this animate ['door_17_rot', 0]";
      };
      class Open_door_18 {
        displayName = "Open Door"; position = "door_18_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_18_rot' < 0.5";
        statement = "this animate ['door_18_rot', 1]";
      };
      class Close_door_18 {
        displayName = "Close Door"; position = "door_18_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_18_rot' >= 0.5";
        statement = "this animate ['door_18_rot', 0]";
      };
      class Open_door_19 {
        displayName = "Open Door"; position = "door_19_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_19_rot' < 0.5";
        statement = "this animate ['door_19_rot', 1]";
      };
      class Close_door_19 {
        displayName = "Close Door"; position = "door_19_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_19_rot' >= 0.5";
        statement = "this animate ['door_19_rot', 0]";
      };
      class Open_door_20 {
        displayName = "Open Door"; position = "door_20_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_20_rot' < 0.5";
        statement = "this animate ['door_20_rot', 1]";
      };
      class Close_door_20 {
        displayName = "Close Door"; position = "door_20_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_20_rot' >= 0.5";
        statement = "this animate ['door_20_rot', 0]";
      };
      class Open_door_21 {
        displayName = "Open Door"; position = "door_21_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_21_rot' < 0.5";
        statement = "this animate ['door_21_rot', 1]";
      };
      class Close_door_21 {
        displayName = "Close Door"; position = "door_21_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_21_rot' >= 0.5";
        statement = "this animate ['door_21_rot', 0]";
      };
      class Open_door_22 {
        displayName = "Open Door"; position = "door_22_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_22_rot' < 0.5";
        statement = "this animate ['door_22_rot', 1]";
      };
      class Close_door_22 {
        displayName = "Close Door"; position = "door_22_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_22_rot' >= 0.5";
        statement = "this animate ['door_22_rot', 0]";
      };
      class Open_door_23 {
        displayName = "Open Door"; position = "door_23_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_23_rot' < 0.5";
        statement = "this animate ['door_23_rot', 1]";
      };
      class Close_door_23 {
        displayName = "Close Door"; position = "door_23_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_23_rot' >= 0.5";
        statement = "this animate ['door_23_rot', 0]";
      };
      class Open_door_24 {
        displayName = "Open Door"; position = "door_24_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_24_rot' < 0.5";
        statement = "this animate ['door_24_rot', 1]";
      };
      class Close_door_24 {
        displayName = "Close Door"; position = "door_24_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_24_rot' >= 0.5";
        statement = "this animate ['door_24_rot', 0]";
      };
      class Open_door_25 {
        displayName = "Open Door"; position = "door_25_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_25_rot' < 0.5";
        statement = "this animate ['door_25_rot', 1]";
      };
      class Close_door_25 {
        displayName = "Close Door"; position = "door_25_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_25_rot' >= 0.5";
        statement = "this animate ['door_25_rot', 0]";
      };
      class Open_door_26 {
        displayName = "Open Door"; position = "door_26_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_26_rot' < 0.5";
        statement = "this animate ['door_26_rot', 1]";
      };
      class Close_door_26 {
        displayName = "Close Door"; position = "door_26_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_26_rot' >= 0.5";
        statement = "this animate ['door_26_rot', 0]";
      };
      class Open_door_27 {
        displayName = "Open Door"; position = "door_27_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_27_rot' < 0.5";
        statement = "this animate ['door_27_rot', 1]";
      };
      class Close_door_27 {
        displayName = "Close Door"; position = "door_27_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_27_rot' >= 0.5";
        statement = "this animate ['door_27_rot', 0]";
      };
      class Open_door_28 {
        displayName = "Open Door"; position = "door_28_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_28_rot' < 0.5";
        statement = "this animate ['door_28_rot', 1]";
      };
      class Close_door_28 {
        displayName = "Close Door"; position = "door_28_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_28_rot' >= 0.5";
        statement = "this animate ['door_28_rot', 0]";
      };
      class Open_door_29 {
        displayName = "Open Door"; position = "door_29_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_29_rot' < 0.5";
        statement = "this animate ['door_29_rot', 1]";
      };
      class Close_door_29 {
        displayName = "Close Door"; position = "door_29_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_29_rot' >= 0.5";
        statement = "this animate ['door_29_rot', 0]";
      };
      class Open_door_30 {
        displayName = "Open Door"; position = "door_30_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_30_rot' < 0.5";
        statement = "this animate ['door_30_rot', 1]";
      };
      class Close_door_30 {
        displayName = "Close Door"; position = "door_30_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_30_rot' >= 0.5";
        statement = "this animate ['door_30_rot', 0]";
      };
      class Open_door_31 {
        displayName = "Open Door"; position = "door_31_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_31_rot' < 0.5";
        statement = "this animate ['door_31_rot', 1]";
      };
      class Close_door_31 {
        displayName = "Close Door"; position = "door_31_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_31_rot' >= 0.5";
        statement = "this animate ['door_31_rot', 0]";
      };
      class Open_door_32 {
        displayName = "Open Door"; position = "door_32_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_32_rot' < 0.5";
        statement = "this animate ['door_32_rot', 1]";
      };
      class Close_door_32 {
        displayName = "Close Door"; position = "door_32_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_32_rot' >= 0.5";
        statement = "this animate ['door_32_rot', 0]";
      };
      class Open_door_33 {
        displayName = "Open Door"; position = "door_33_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_33_rot' < 0.5";
        statement = "this animate ['door_33_rot', 1]";
      };
      class Close_door_33 {
        displayName = "Close Door"; position = "door_33_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_33_rot' >= 0.5";
        statement = "this animate ['door_33_rot', 0]";
      };
      class Open_door_34 {
        displayName = "Open Door"; position = "door_34_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_34_rot' < 0.5";
        statement = "this animate ['door_34_rot', 1]";
      };
      class Close_door_34 {
        displayName = "Close Door"; position = "door_34_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_34_rot' >= 0.5";
        statement = "this animate ['door_34_rot', 0]";
      };
      class Open_door_35 {
        displayName = "Open Door"; position = "door_35_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_35_rot' < 0.5";
        statement = "this animate ['door_35_rot', 1]";
      };
      class Close_door_35 {
        displayName = "Close Door"; position = "door_35_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_35_rot' >= 0.5";
        statement = "this animate ['door_35_rot', 0]";
      };
      class Open_door_36 {
        displayName = "Open Door"; position = "door_36_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_36_rot' < 0.5";
        statement = "this animate ['door_36_rot', 1]";
      };
      class Close_door_36 {
        displayName = "Close Door"; position = "door_36_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_36_rot' >= 0.5";
        statement = "this animate ['door_36_rot', 0]";
      };
      class Open_door_37 {
        displayName = "Open Door"; position = "door_37_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_37_rot' < 0.5";
        statement = "this animate ['door_37_rot', 1]";
      };
      class Close_door_37 {
        displayName = "Close Door"; position = "door_37_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_37_rot' >= 0.5";
        statement = "this animate ['door_37_rot', 0]";
      };
      class Open_door_38 {
        displayName = "Open Door"; position = "door_38_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_38_rot' < 0.5";
        statement = "this animate ['door_38_rot', 1]";
      };
      class Close_door_38 {
        displayName = "Close Door"; position = "door_38_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_38_rot' >= 0.5";
        statement = "this animate ['door_38_rot', 0]";
      };
      class Open_door_39 {
        displayName = "Open Door"; position = "door_39_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_39_rot' < 0.5";
        statement = "this animate ['door_39_rot', 1]";
      };
      class Close_door_39 {
        displayName = "Close Door"; position = "door_39_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_39_rot' >= 0.5";
        statement = "this animate ['door_39_rot', 0]";
      };
      class Open_door_40 {
        displayName = "Open Door"; position = "door_40_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_40_rot' < 0.5";
        statement = "this animate ['door_40_rot', 1]";
      };
      class Close_door_40 {
        displayName = "Close Door"; position = "door_40_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_40_rot' >= 0.5";
        statement = "this animate ['door_40_rot', 0]";
      };
      class Open_door_41 {
        displayName = "Open Door"; position = "door_41_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_41_rot' < 0.5";
        statement = "this animate ['door_41_rot', 1]";
      };
      class Close_door_41 {
        displayName = "Close Door"; position = "door_41_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_41_rot' >= 0.5";
        statement = "this animate ['door_41_rot', 0]";
      };
      class Open_door_42 {
        displayName = "Open Door"; position = "door_42_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_42_rot' < 0.5";
        statement = "this animate ['door_42_rot', 1]";
      };
      class Close_door_42 {
        displayName = "Close Door"; position = "door_42_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_42_rot' >= 0.5";
        statement = "this animate ['door_42_rot', 0]";
      };
      class Open_door_43 {
        displayName = "Open Door"; position = "door_43_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_43_rot' < 0.5";
        statement = "this animate ['door_43_rot', 1]";
      };
      class Close_door_43 {
        displayName = "Close Door"; position = "door_43_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_43_rot' >= 0.5";
        statement = "this animate ['door_43_rot', 0]";
      };
      class Open_door_44 {
        displayName = "Open Door"; position = "door_44_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_44_rot' < 0.5";
        statement = "this animate ['door_44_rot', 1]";
      };
      class Close_door_44 {
        displayName = "Close Door"; position = "door_44_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_44_rot' >= 0.5";
        statement = "this animate ['door_44_rot', 0]";
      };
      class Open_door_45 {
        displayName = "Open Door"; position = "door_45_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_45_rot' < 0.5";
        statement = "this animate ['door_45_rot', 1]";
      };
      class Close_door_45 {
        displayName = "Close Door"; position = "door_45_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_45_rot' >= 0.5";
        statement = "this animate ['door_45_rot', 0]";
      };
      class Open_door_46 {
        displayName = "Open Door"; position = "door_46_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_46_rot' < 0.5";
        statement = "this animate ['door_46_rot', 1]";
      };
      class Close_door_46 {
        displayName = "Close Door"; position = "door_46_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_46_rot' >= 0.5";
        statement = "this animate ['door_46_rot', 0]";
      };
      class Open_door_47 {
        displayName = "Open Door"; position = "door_47_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_47_rot' < 0.5";
        statement = "this animate ['door_47_rot', 1]";
      };
      class Close_door_47 {
        displayName = "Close Door"; position = "door_47_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_47_rot' >= 0.5";
        statement = "this animate ['door_47_rot', 0]";
      };
      class Open_door_48 {
        displayName = "Open Door"; position = "door_48_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_48_rot' < 0.5";
        statement = "this animate ['door_48_rot', 1]";
      };
      class Close_door_48 {
        displayName = "Close Door"; position = "door_48_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_48_rot' >= 0.5";
        statement = "this animate ['door_48_rot', 0]";
      };
      class Open_door_49 {
        displayName = "Open Door"; position = "door_49_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_49_rot' < 0.5";
        statement = "this animate ['door_49_rot', 1]";
      };
      class Close_door_49 {
        displayName = "Close Door"; position = "door_49_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_49_rot' >= 0.5";
        statement = "this animate ['door_49_rot', 0]";
      };
      class Open_door_50 {
        displayName = "Open Door"; position = "door_50_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_50_rot' < 0.5";
        statement = "this animate ['door_50_rot', 1]";
      };
      class Close_door_50 {
        displayName = "Close Door"; position = "door_50_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_50_rot' >= 0.5";
        statement = "this animate ['door_50_rot', 0]";
      };
      class Open_door_51 {
        displayName = "Open Door"; position = "door_51_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_51_rot' < 0.5";
        statement = "this animate ['door_51_rot', 1]";
      };
      class Close_door_51 {
        displayName = "Close Door"; position = "door_51_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_51_rot' >= 0.5";
        statement = "this animate ['door_51_rot', 0]";
      };
      class Open_door_52 {
        displayName = "Open Door"; position = "door_52_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_52_rot' < 0.5";
        statement = "this animate ['door_52_rot', 1]";
      };
      class Close_door_52 {
        displayName = "Close Door"; position = "door_52_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_52_rot' >= 0.5";
        statement = "this animate ['door_52_rot', 0]";
      };
      class Open_door_53 {
        displayName = "Open Door"; position = "door_53_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_53_rot' < 0.5";
        statement = "this animate ['door_53_rot', 1]";
      };
      class Close_door_53 {
        displayName = "Close Door"; position = "door_53_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_53_rot' >= 0.5";
        statement = "this animate ['door_53_rot', 0]";
      };
      class Open_door_54 {
        displayName = "Open Door"; position = "door_54_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_54_rot' < 0.5";
        statement = "this animate ['door_54_rot', 1]";
      };
      class Close_door_54 {
        displayName = "Close Door"; position = "door_54_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_54_rot' >= 0.5";
        statement = "this animate ['door_54_rot', 0]";
      };
      class Open_door_55 {
        displayName = "Open Door"; position = "door_55_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_55_rot' < 0.5";
        statement = "this animate ['door_55_rot', 1]";
      };
      class Close_door_55 {
        displayName = "Close Door"; position = "door_55_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_55_rot' >= 0.5";
        statement = "this animate ['door_55_rot', 0]";
      };
      class Open_door_56 {
        displayName = "Open Door"; position = "door_56_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_56_rot' < 0.5";
        statement = "this animate ['door_56_rot', 1]";
      };
      class Close_door_56 {
        displayName = "Close Door"; position = "door_56_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_56_rot' >= 0.5";
        statement = "this animate ['door_56_rot', 0]";
      };
      class Open_door_57 {
        displayName = "Open Door"; position = "door_57_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_57_rot' < 0.5";
        statement = "this animate ['door_57_rot', 1]";
      };
      class Close_door_57 {
        displayName = "Close Door"; position = "door_57_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_57_rot' >= 0.5";
        statement = "this animate ['door_57_rot', 0]";
      };
      class Open_door_58 {
        displayName = "Open Door"; position = "door_58_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_58_rot' < 0.5";
        statement = "this animate ['door_58_rot', 1]";
      };
      class Close_door_58 {
        displayName = "Close Door"; position = "door_58_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_58_rot' >= 0.5";
        statement = "this animate ['door_58_rot', 0]";
      };
      class Open_door_59 {
        displayName = "Open Door"; position = "door_59_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_59_rot' < 0.5";
        statement = "this animate ['door_59_rot', 1]";
      };
      class Close_door_59 {
        displayName = "Close Door"; position = "door_59_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_59_rot' >= 0.5";
        statement = "this animate ['door_59_rot', 0]";
      };
      class Open_door_60 {
        displayName = "Open Door"; position = "door_60_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_60_rot' < 0.5";
        statement = "this animate ['door_60_rot', 1]";
      };
      class Close_door_60 {
        displayName = "Close Door"; position = "door_60_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_60_rot' >= 0.5";
        statement = "this animate ['door_60_rot', 0]";
      };
      class Open_door_61 {
        displayName = "Open Door"; position = "door_61_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_61_rot' < 0.5";
        statement = "this animate ['door_61_rot', 1]";
      };
      class Close_door_61 {
        displayName = "Close Door"; position = "door_61_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_61_rot' >= 0.5";
        statement = "this animate ['door_61_rot', 0]";
      };
      class Open_door_62 {
        displayName = "Open Door"; position = "door_62_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_62_rot' < 0.5";
        statement = "this animate ['door_62_rot', 1]";
      };
      class Close_door_62 {
        displayName = "Close Door"; position = "door_62_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_62_rot' >= 0.5";
        statement = "this animate ['door_62_rot', 0]";
      };
      class Open_door_63 {
        displayName = "Open Door"; position = "door_63_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_63_rot' < 0.5";
        statement = "this animate ['door_63_rot', 1]";
      };
      class Close_door_63 {
        displayName = "Close Door"; position = "door_63_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_63_rot' >= 0.5";
        statement = "this animate ['door_63_rot', 0]";
      };
      class Open_door_64 {
        displayName = "Open Door"; position = "door_64_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_64_rot' < 0.5";
        statement = "this animate ['door_64_rot', 1]";
      };
      class Close_door_64 {
        displayName = "Close Door"; position = "door_64_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_64_rot' >= 0.5";
        statement = "this animate ['door_64_rot', 0]";
      };
      class Open_door_65 {
        displayName = "Open Door"; position = "door_65_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_65_rot' < 0.5";
        statement = "this animate ['door_65_rot', 1]";
      };
      class Close_door_65 {
        displayName = "Close Door"; position = "door_65_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_65_rot' >= 0.5";
        statement = "this animate ['door_65_rot', 0]";
      };
      class Open_door_66 {
        displayName = "Open Door"; position = "door_66_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_66_rot' < 0.5";
        statement = "this animate ['door_66_rot', 1]";
      };
      class Close_door_66 {
        displayName = "Close Door"; position = "door_66_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_66_rot' >= 0.5";
        statement = "this animate ['door_66_rot', 0]";
      };
      class Open_door_67 {
        displayName = "Open Door"; position = "door_67_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_67_rot' < 0.5";
        statement = "this animate ['door_67_rot', 1]";
      };
      class Close_door_67 {
        displayName = "Close Door"; position = "door_67_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_67_rot' >= 0.5";
        statement = "this animate ['door_67_rot', 0]";
      };
      class Open_door_68 {
        displayName = "Open Door"; position = "door_68_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_68_rot' < 0.5";
        statement = "this animate ['door_68_rot', 1]";
      };
      class Close_door_68 {
        displayName = "Close Door"; position = "door_68_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_68_rot' >= 0.5";
        statement = "this animate ['door_68_rot', 0]";
      };
      class Open_door_69 {
        displayName = "Open Door"; position = "door_69_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_69_rot' < 0.5";
        statement = "this animate ['door_69_rot', 1]";
      };
      class Close_door_69 {
        displayName = "Close Door"; position = "door_69_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_69_rot' >= 0.5";
        statement = "this animate ['door_69_rot', 0]";
      };
      class Open_door_70 {
        displayName = "Open Door"; position = "door_70_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_70_rot' < 0.5";
        statement = "this animate ['door_70_rot', 1]";
      };
      class Close_door_70 {
        displayName = "Close Door"; position = "door_70_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_70_rot' >= 0.5";
        statement = "this animate ['door_70_rot', 0]";
      };
      class Open_door_71 {
        displayName = "Open Door"; position = "door_71_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_71_rot' < 0.5";
        statement = "this animate ['door_71_rot', 1]";
      };
      class Close_door_71 {
        displayName = "Close Door"; position = "door_71_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_71_rot' >= 0.5";
        statement = "this animate ['door_71_rot', 0]";
      };
      class Open_door_72 {
        displayName = "Open Door"; position = "door_72_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_72_rot' < 0.5";
        statement = "this animate ['door_72_rot', 1]";
      };
      class Close_door_72 {
        displayName = "Close Door"; position = "door_72_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_72_rot' >= 0.5";
        statement = "this animate ['door_72_rot', 0]";
      };
      class Open_door_73 {
        displayName = "Open Door"; position = "door_73_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_73_rot' < 0.5";
        statement = "this animate ['door_73_rot', 1]";
      };
      class Close_door_73 {
        displayName = "Close Door"; position = "door_73_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_73_rot' >= 0.5";
        statement = "this animate ['door_73_rot', 0]";
      };
      class Open_door_74 {
        displayName = "Open Door"; position = "door_74_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_74_rot' < 0.5";
        statement = "this animate ['door_74_rot', 1]";
      };
      class Close_door_74 {
        displayName = "Close Door"; position = "door_74_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_74_rot' >= 0.5";
        statement = "this animate ['door_74_rot', 0]";
      };
      class Open_door_75 {
        displayName = "Open Door"; position = "door_75_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_75_rot' < 0.5";
        statement = "this animate ['door_75_rot', 1]";
      };
      class Close_door_75 {
        displayName = "Close Door"; position = "door_75_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_75_rot' >= 0.5";
        statement = "this animate ['door_75_rot', 0]";
      };
      class Open_door_76 {
        displayName = "Open Door"; position = "door_76_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_76_rot' < 0.5";
        statement = "this animate ['door_76_rot', 1]";
      };
      class Close_door_76 {
        displayName = "Close Door"; position = "door_76_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_76_rot' >= 0.5";
        statement = "this animate ['door_76_rot', 0]";
      };
      class Open_door_77 {
        displayName = "Open Door"; position = "door_77_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_77_rot' < 0.5";
        statement = "this animate ['door_77_rot', 1]";
      };
      class Close_door_77 {
        displayName = "Close Door"; position = "door_77_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_77_rot' >= 0.5";
        statement = "this animate ['door_77_rot', 0]";
      };
      class Open_door_78 {
        displayName = "Open Door"; position = "door_78_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_78_rot' < 0.5";
        statement = "this animate ['door_78_rot', 1]";
      };
      class Close_door_78 {
        displayName = "Close Door"; position = "door_78_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_78_rot' >= 0.5";
        statement = "this animate ['door_78_rot', 0]";
      };
      class Open_door_79 {
        displayName = "Open Door"; position = "door_79_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_79_rot' < 0.5";
        statement = "this animate ['door_79_rot', 1]";
      };
      class Close_door_79 {
        displayName = "Close Door"; position = "door_79_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_79_rot' >= 0.5";
        statement = "this animate ['door_79_rot', 0]";
      };
      class Open_door_80 {
        displayName = "Open Door"; position = "door_80_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_80_rot' < 0.5";
        statement = "this animate ['door_80_rot', 1]";
      };
      class Close_door_80 {
        displayName = "Close Door"; position = "door_80_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_80_rot' >= 0.5";
        statement = "this animate ['door_80_rot', 0]";
      };
      class Open_door_81 {
        displayName = "Open Door"; position = "door_81_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_81_rot' < 0.5";
        statement = "this animate ['door_81_rot', 1]";
      };
      class Close_door_81 {
        displayName = "Close Door"; position = "door_81_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_81_rot' >= 0.5";
        statement = "this animate ['door_81_rot', 0]";
      };
      class Open_door_82 {
        displayName = "Open Door"; position = "door_82_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_82_rot' < 0.5";
        statement = "this animate ['door_82_rot', 1]";
      };
      class Close_door_82 {
        displayName = "Close Door"; position = "door_82_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_82_rot' >= 0.5";
        statement = "this animate ['door_82_rot', 0]";
      };
      class Open_door_83 {
        displayName = "Open Door"; position = "door_83_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_83_rot' < 0.5";
        statement = "this animate ['door_83_rot', 1]";
      };
      class Close_door_83 {
        displayName = "Close Door"; position = "door_83_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_83_rot' >= 0.5";
        statement = "this animate ['door_83_rot', 0]";
      };
      class Open_door_84 {
        displayName = "Open Door"; position = "door_84_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_84_rot' < 0.5";
        statement = "this animate ['door_84_rot', 1]";
      };
      class Close_door_84 {
        displayName = "Close Door"; position = "door_84_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_84_rot' >= 0.5";
        statement = "this animate ['door_84_rot', 0]";
      };
      class Open_door_85 {
        displayName = "Open Door"; position = "door_85_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_85_rot' < 0.5";
        statement = "this animate ['door_85_rot', 1]";
      };
      class Close_door_85 {
        displayName = "Close Door"; position = "door_85_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_85_rot' >= 0.5";
        statement = "this animate ['door_85_rot', 0]";
      };
      class Open_door_86 {
        displayName = "Open Door"; position = "door_86_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_86_rot' < 0.5";
        statement = "this animate ['door_86_rot', 1]";
      };
      class Close_door_86 {
        displayName = "Close Door"; position = "door_86_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_86_rot' >= 0.5";
        statement = "this animate ['door_86_rot', 0]";
      };
      class Open_door_87 {
        displayName = "Open Door"; position = "door_87_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_87_rot' < 0.5";
        statement = "this animate ['door_87_rot', 1]";
      };
      class Close_door_87 {
        displayName = "Close Door"; position = "door_87_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_87_rot' >= 0.5";
        statement = "this animate ['door_87_rot', 0]";
      };
      class Open_door_88 {
        displayName = "Open Door"; position = "door_88_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_88_rot' < 0.5";
        statement = "this animate ['door_88_rot', 1]";
      };
      class Close_door_88 {
        displayName = "Close Door"; position = "door_88_trigger"; radius = 2; onlyForPlayer = 0; priority = 0.4;
        condition = "this animationPhase 'door_88_rot' >= 0.5";
        statement = "this animate ['door_88_rot', 0]";
      };
    };
  };
};
