params["_type"];
switch (_type) do {case "init": {if (!isNil "AP_light") then {deleteVehicle AP_light};
            AP_light = "#lightpoint"
            createVehicleLocal[0, 0, 0];
            AP_light setLightBrightness 1;
            AP_light setLightDayLight false;
            ["update"] call AP_fnc_brightNight;}; case "update": {AP_nightBrightness = AP_nightBrightness max 0 min 1;
                private _brightness =
                if (AP_nightBrightness > 0) then {600 * abs(1 - (2 ^ AP_nightBrightness))} else {0};
                AP_light setLightAttenuation[10e10, (30000 / (_brightness max 10e-10)), 4.31918e-005, 4.31918e-005];
                AP_light setLightAmbient[0.3, 0.5, 1];};
        default {};};