params["_obj_main", "_stance", "_type"];
if (_obj_main isKindOf "CAManBase") then {};
switch (_type) do {case "gokart": {_obj_main addAction["<t color='#ADFF22'>Start AlphaCourse time trial</t>", {
                ["start", 0] call AP_fnc_timeTrial}, "", 1.5, false, false, "", 'isNull objectParent player', 5];
            _obj_main addAction["<t color='#ADFF22'>Start Go-Kart time trial</t>", {["start", 1] call AP_fnc_timeTrial
            }, "", 1.5, false, false, "", 'isNull objectParent player', 5];};};