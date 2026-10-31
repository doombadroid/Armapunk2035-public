params[["_mode", "", ["", 0]], "_toFind"];
private _licenseArr = [["boat", "Boating License", civilian, 150], ["boat", "Medic Boating License", independent, 500],
    ["bounty", "Bounty Hunter License", civilian, 12500], ["copper", "Copper Processing", civilian, 600],
    ["cg", "Cop Boating License", west, 800], ["diamond", "Diamond Processing", civilian, 3500], ["dive", "Diving License", civilian, 200],
    ["driver", "Driver's License", civilian, 100], ["gun", "Firearm License", civilian, 250],
    ["home", "Home Owner License", civilian, 3500], ["iron", "Iron Processing", civilian, 950],
    ["marijuana", "Marijuana Processing Contract", civilian, 800], ["oil", "Oil Drilling and Processing", civilian, 1000],
    ["pilot", "Pilot License", civilian, 4000], ["pilot", "Pilot License", west, 3500], ["pilot", "Pilot License", independent, 3500],
    ["rebel", "Rebel License", civilian, 12500], ["salt", "Salt Processing", civilian, 900], ["sand", "Sand Processing", civilian, 700],
    ["truck", "Truck License", civilian, 4000]];
private["_return", "_side"];
switch (_mode) do {case "getName": {{if (_toFind == (_x select 0)) exitWith {_return = (_x select 1);};} forEach _licenseArr;
        }; case "getPrice": {{if (_toFind == (_x select 0) && AP_effSide isEqualTo(_x select 2)) exitWith {_return = (_x select 3);};}
                forEach _licenseArr;};
        case "varToStr": {{_side =
                    switch (true) do {case (_x select 2 == civilian): {"civ"};
                        case (_x select 2 == west): {"cop"};
                        case (_x select 2 == independent): {
                                "med"};}; if (_toFind == (format["license_%1_%2", _side, _x select 0])) exitWith {_return = (_x select 1);
                    };}
                forEach _licenseArr;};
        case 0: {{_side =
                    switch (true) do {case (_x select 2 == civilian): {"civ"};
                        case (_x select 2 == west): {"cop"};
                        case (_x select 2 == independent): {
                                "med"};}; missionNamespace setVariable[format["license_%1_%2", _side, _x select 0], false];}
                forEach _licenseArr;
                _return = true;};
        case 1: {AP_licenses = []; {_side =
                    switch (true) do {case (_x select 2 == civilian): {"civ"};
                        case (_x select 2 == west): {"cop"};
                        case (_x select 2 == independent): {"med"};
                    }; AP_licenses pushBack(parseSimpleArray(format["[""license_%1_%2"",""%1""]", _side, _x select 0]));}
                forEach _licenseArr;
                _return = true;};}; _return ;