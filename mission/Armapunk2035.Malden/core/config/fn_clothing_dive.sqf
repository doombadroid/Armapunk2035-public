params[["_filter", 0, [0]]];
ctrlSetText[3103, "Steve's Diving Shop"];
private _ret = [];
switch (_filter) do {case 0: {_ret = [["U_B_Wetsuit", nil, 250]];
            
                _ret pushBack["U_O_Wetsuit", nil, 250];
            
                _ret pushBack["U_I_Wetsuit", nil, 250];
            
                _ret pushBack["U_B_Wetsuit", "Dark Water Wetsuit", 250, "images\lc4_dark_1.jpg"];};
    case 1: {_ret = [];};
    case 2: {_ret = [["G_Diving", nil, 50]];};
    case 3: {_ret = [["V_RebreatherB", nil, 500]];
            
                _ret pushBack["V_RebreatherIR", nil, 500];};
    case 4: {_ret = [["B_SCBA_01_F", nil, 500]];};
}; if (!(_filter isEqualTo 5)) then {   // owner 2026-07-13: go-kart clothing baked to core (Speed Racer 69 pruned)
    _ret append([_filter] call AP_fnc_clothing_kart);};
_ret;