params[["_house", "", [""]]];
if (_house isEqualTo "") exitWith {[]};
if (_house == "getHouses") exitWith {
    // owner 2026-07-11 (Malden Makeover): the 4 _b_whiteblue classes are the swap SHELLS (TON_fnc_maldenSRV).
    // Every house gate keys off this registry (fn_setupActions house action, life_houseTypes, gang-house list)
    // -- a maldened house missing here loses ALL interaction ("like I don't even own it anymore").
    ["Land_i_House_Small_01_V1_F", "Land_i_House_Small_01_V2_F", "Land_i_House_Small_01_V3_F", "Land_i_House_Small_02_V1_F", "Land_i_House_Small_02_V2_F", "Land_i_House_Small_02_V3_F", "Land_i_House_Small_03_V1_F", "Land_i_House_Big_01_V1_F", "Land_i_House_Big_01_V2_F", "Land_i_House_Big_01_V3_F", "Land_i_House_Big_02_V1_F", "Land_i_House_Big_02_V2_F", "Land_i_House_Big_02_V3_F", "Land_i_Stone_HouseSmall_V1_F", "Land_i_Stone_HouseSmall_V2_F", "Land_i_Stone_HouseSmall_V3_F", "Land_i_Stone_Shed_V1_F", "Land_i_Stone_Shed_V2_F", "Land_i_Stone_Shed_V3_F", "Land_i_Addon_02_V1_F", "Land_i_Garage_V1_F", "Land_i_Garage_V2_F", "Land_i_Garage_V1_dam_F", "Land_i_Garage_V2_dam_F", "Land_i_Shed_Ind_F", "Land_i_Shop_01_V1_F", "Land_i_Shop_01_V2_F", "Land_i_Shop_01_V3_F", "Land_Slum_House01_F", "Land_Slum_House02_F", "Land_Slum_House03_F", "Land_i_House_Small_01_b_whiteblue_F", "Land_i_House_Small_01_b_white_F", "Land_i_House_Small_01_b_blue_F", "Land_i_House_Small_01_b_yellow_F", "Land_i_House_Small_01_b_pink_F", "Land_i_House_Small_01_b_brown_F", "Land_i_House_Small_02_b_whiteblue_F", "Land_i_House_Small_02_b_white_F", "Land_i_House_Small_02_b_blue_F", "Land_i_House_Small_02_b_yellow_F", "Land_i_House_Small_02_b_pink_F", "Land_i_House_Small_02_b_brown_F", "Land_i_House_Big_01_b_whiteblue_F", "Land_i_House_Big_01_b_white_F", "Land_i_House_Big_01_b_blue_F", "Land_i_House_Big_01_b_yellow_F", "Land_i_House_Big_01_b_pink_F", "Land_i_House_Big_01_b_brown_F", "Land_i_House_Big_02_b_whiteblue_F", "Land_i_House_Big_02_b_white_F", "Land_i_House_Big_02_b_blue_F", "Land_i_House_Big_02_b_yellow_F", "Land_i_House_Big_02_b_pink_F", "Land_i_House_Big_02_b_brown_F"]
};
private _return =
switch (_house) do {
    // owner 2026-07-11 (Malden Makeover): swap shells mirror their base family's stats (upgrade menus,
    // sell/repair pricing, cap seeding all read these). Buy-price inert -- shells only stand on owned
    // houses. All 6 colors per family (skin picker); no case fall-through in SQF, one block each.
    case "Land_i_House_Small_01_b_whiteblue_F":
        { [70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000], [2000, 20000]], 300] };
    case "Land_i_House_Small_01_b_white_F":
        { [70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000], [2000, 20000]], 300] };
    case "Land_i_House_Small_01_b_blue_F":
        { [70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000], [2000, 20000]], 300] };
    case "Land_i_House_Small_01_b_yellow_F":
        { [70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000], [2000, 20000]], 300] };
    case "Land_i_House_Small_01_b_pink_F":
        { [70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000], [2000, 20000]], 300] };
    case "Land_i_House_Small_01_b_brown_F":
        { [70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000], [2000, 20000]], 300] };
    case "Land_i_House_Small_02_b_whiteblue_F":
        { [70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000], [2000, 20000]], 300] };
    case "Land_i_House_Small_02_b_white_F":
        { [70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000], [2000, 20000]], 300] };
    case "Land_i_House_Small_02_b_blue_F":
        { [70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000], [2000, 20000]], 300] };
    case "Land_i_House_Small_02_b_yellow_F":
        { [70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000], [2000, 20000]], 300] };
    case "Land_i_House_Small_02_b_pink_F":
        { [70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000], [2000, 20000]], 300] };
    case "Land_i_House_Small_02_b_brown_F":
        { [70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000], [2000, 20000]], 300] };
    case "Land_i_House_Big_01_b_whiteblue_F":
        { [150000, 112500, [[200, 5000], [650, 35000], [900, 55000]], [[500, 5000], [1500, 15000], [3000, 30000]], 675] };
    case "Land_i_House_Big_01_b_white_F":
        { [150000, 112500, [[200, 5000], [650, 35000], [900, 55000]], [[500, 5000], [1500, 15000], [3000, 30000]], 675] };
    case "Land_i_House_Big_01_b_blue_F":
        { [150000, 112500, [[200, 5000], [650, 35000], [900, 55000]], [[500, 5000], [1500, 15000], [3000, 30000]], 675] };
    case "Land_i_House_Big_01_b_yellow_F":
        { [150000, 112500, [[200, 5000], [650, 35000], [900, 55000]], [[500, 5000], [1500, 15000], [3000, 30000]], 675] };
    case "Land_i_House_Big_01_b_pink_F":
        { [150000, 112500, [[200, 5000], [650, 35000], [900, 55000]], [[500, 5000], [1500, 15000], [3000, 30000]], 675] };
    case "Land_i_House_Big_01_b_brown_F":
        { [150000, 112500, [[200, 5000], [650, 35000], [900, 55000]], [[500, 5000], [1500, 15000], [3000, 30000]], 675] };
    case "Land_i_House_Big_02_b_whiteblue_F":
        { [150000, 112500, [[200, 5000], [650, 35000], [900, 55000]], [[500, 5000], [1500, 15000], [3000, 30000]], 675] };
    case "Land_i_House_Big_02_b_white_F":
        { [150000, 112500, [[200, 5000], [650, 35000], [900, 55000]], [[500, 5000], [1500, 15000], [3000, 30000]], 675] };
    case "Land_i_House_Big_02_b_blue_F":
        { [150000, 112500, [[200, 5000], [650, 35000], [900, 55000]], [[500, 5000], [1500, 15000], [3000, 30000]], 675] };
    case "Land_i_House_Big_02_b_yellow_F":
        { [150000, 112500, [[200, 5000], [650, 35000], [900, 55000]], [[500, 5000], [1500, 15000], [3000, 30000]], 675] };
    case "Land_i_House_Big_02_b_pink_F":
        { [150000, 112500, [[200, 5000], [650, 35000], [900, 55000]], [[500, 5000], [1500, 15000], [3000, 30000]], 675] };
    case "Land_i_House_Big_02_b_brown_F":
        { [150000, 112500, [[200, 5000], [650, 35000], [900, 55000]], [[500, 5000], [1500, 15000], [3000, 30000]], 675] };
    case "Land_i_House_Small_01_V1_F": {[70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000], [2000, 20000]
                ], 300]}; case "Land_i_House_Small_01_V2_F": {[70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000],
                        [1000, 10000], [2000, 20000]], 300]};
        case "Land_i_House_Small_01_V3_F": {[70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000],
                        [2000, 20000]], 300]};
        case "Land_i_House_Small_02_V1_F": {[70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000],
                        [2000, 20000]], 300]};
        case "Land_i_House_Small_02_V2_F": {[70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000],
                        [2000, 20000]], 300]};
        case "Land_i_House_Small_02_V3_F": {[70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000],
                        [2000, 20000]], 300]};
        case "Land_i_House_Small_03_V1_F": {[70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000],
                        [2000, 20000]], 300]};
        case "Land_i_Shop_01_V1_F": {[70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000], [2000, 20000]
                    ], 300]};
        case "Land_i_Shop_01_V2_F": {[70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000], [2000, 20000]
                    ], 300]};
        case "Land_i_Shop_01_V3_F": {[70000, 52500, [[200, 5000], [325, 15000], [500, 35000]], [[500, 5000], [1000, 10000], [2000, 20000]
                    ], 300]};
        case "Land_i_House_Big_01_V1_F": {[150000, 112500, [[200, 5000], [650, 35000], [900, 55000]], [[500, 5000], [1500, 15000],
                        [3000, 30000]], 675]};
        case "Land_i_House_Big_01_V2_F": {[150000, 112500, [[200, 5000], [650, 35000], [900, 55000]], [[500, 5000], [1500, 15000],
                        [3000, 30000]], 675]};
        case "Land_i_House_Big_01_V3_F": {[150000, 112500, [[200, 5000], [650, 35000], [900, 55000]], [[500, 5000], [1500, 15000],
                        [3000, 30000]], 675]};
        case "Land_i_House_Big_02_V1_F": {[150000, 112500, [[200, 5000], [650, 35000], [900, 55000]], [[500, 5000], [1500, 15000],
                        [3000, 30000]], 675]};
        case "Land_i_House_Big_02_V2_F": {[150000, 112500, [[200, 5000], [650, 35000], [900, 55000]], [[500, 5000], [1500, 15000],
                        [3000, 30000]], 675]};
        case "Land_i_House_Big_02_V3_F": {[150000, 112500, [[200, 5000], [650, 35000], [900, 55000]], [[500, 5000], [1500, 15000],
                        [3000, 30000]], 675]};
        case "Land_i_Stone_HouseSmall_V1_F": {[120000, 90000, [[200, 5000], [500, 30000], [750, 60000]], [[500, 5000], [1500, 15000],
                        [3000, 30000]], 500]};
        case "Land_i_Stone_HouseSmall_V2_F": {[120000, 90000, [[200, 5000], [500, 30000], [750, 60000]], [[500, 5000], [1500, 15000],
                        [3000, 30000]], 500]};
        case "Land_i_Stone_HouseSmall_V3_F": {[120000, 90000, [[200, 5000], [500, 30000], [750, 60000]], [[500, 5000], [1500, 15000],
                        [3000, 30000]], 500]};
        case "Land_i_Stone_Shed_V1_F": {[40000, 30000, [[200, 5000], [250, 10000], [300, 20000]], [[500, 5000], [700, 7000], [1000, 10000]
                    ], 275]};
        case "Land_i_Stone_Shed_V2_F": {[40000, 30000, [[200, 5000], [250, 10000], [300, 20000]], [[500, 5000], [700, 7000], [1000, 10000]
                    ], 275]};
        case "Land_i_Stone_Shed_V3_F": {[40000, 30000, [[200, 5000], [250, 10000], [300, 20000]], [[500, 5000], [700, 7000], [1000, 10000]
                    ], 275]};
        case "Land_i_Addon_02_V1_F": {[40000, 30000, [[200, 5000], [250, 10000], [300, 20000]], [[500, 5000], [700, 7000], [1000, 10000]
                    ], 275]};
        case "Land_i_Garage_V1_F": {[60000, 35000, [[125, 4500], [175, 8000], [250, 15000]], [[175, 3000], [250, 5000], [325, 7500]], 275]
            };
        case "Land_i_Garage_V2_F": {[60000, 35000, [[125, 4500], [175, 8000], [250, 15000]], [[175, 3000], [250, 5000], [325, 7500]], 275]
            };
        case "Land_i_Garage_V1_dam_F": {[50000, 30000, [[125, 4500], [175, 8000], [250, 15000]], [[175, 3000], [250, 5000], [325, 7500]
                    ], 275]};
        case "Land_i_Garage_V2_dam_F": {[50000, 30000, [[125, 4500], [175, 8000], [250, 15000]], [[175, 3000], [250, 5000], [325, 7500]
                    ], 275]};
        case "Land_i_Shed_Ind_F": {[200000, 150000, [[200, 5000], [700, 50000], [900, 100000], [1260, 150000]], [[500, 5000], [1500, 15000],
                        [3000, 30000], [5000, 50000]], 1375]};
        case "Land_Slum_House01_F";
        case "Land_Slum_House02_F";
        case "Land_Slum_House03_F":   // owner 2026-06-28: wooden shacks (slum houses) = 1c buyable house @ $20k
            {[20000, 15000, [[125, 4500], [175, 8000], [250, 15000]], [[175, 3000], [250, 5000], [325, 7500]], 275]};
        default {[]};}; _return ;