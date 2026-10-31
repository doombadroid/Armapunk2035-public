params[["_filter", 0, [0]]];
ctrlSetText[3103, "Cop Diving Shop"];
private _ret = [];
switch (_filter) do {case 0: {_ret = [["U_B_Wetsuit", nil, 250]];
            
                _ret pushBack["U_O_Wetsuit", nil, 250];
            
                _ret pushBack["U_I_Wetsuit", nil, 250];
            
                _ret pushBack["U_B_Wetsuit", "Dark Water Wetsuit", 250, "images\lc4_dark_1.jpg"];};
    case 1: {_ret = [];};
    case 2: {_ret = [["G_Diving", nil, 150]];};
    case 3: {_ret = [["V_RebreatherB", nil, 500]];
            
                _ret pushBack["V_RebreatherIR", nil, 500];};
    case 4: {_ret = [];};}; _ret ;