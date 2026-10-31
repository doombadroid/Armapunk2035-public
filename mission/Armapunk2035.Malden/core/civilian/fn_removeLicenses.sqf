if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params[["_state", 1, [0]]];
switch (_state) do {case 0: {license_civ_rebel = false;
            license_civ_driver = false;
            license_civ_heroin = false;
            license_civ_marijuana = false;
            license_civ_coke = false;};
    case 1: {license_civ_gun = false;
            license_civ_rebel = false;
            license_civ_driver = false;};
    case 2: {if (license_civ_driver || license_civ_air || license_civ_truck || license_civ_boat) then {license_civ_driver = false;
                license_civ_air = false;
                license_civ_truck = false;
                license_civ_boat = false;
                ["You have lost all your motor vehicle licenses for vehicular manslaughter.", "basic"] spawn AP_fnc_handleMessage;};};
    case 3: {if (license_civ_gun) then {license_civ_gun = false;
                ["You have lost your firearms license for manslaughter.", "basic"] spawn AP_fnc_handleMessage;};};};