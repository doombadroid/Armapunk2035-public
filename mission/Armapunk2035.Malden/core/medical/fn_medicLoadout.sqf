private _handle = [] spawn AP_fnc_stripDownPlayer;
waitUntil {scriptDone _handle};
player forceAddUniform "U_Marshal";
[] call AP_fnc_giveMedkits;
player linkItem "ItemMap";
player linkItem "ItemWatch";
player linkItem "ItemCompass";
player linkItem "ItemGPS";
// owner 2026-07-13: Night Eyes (130) baked to core -- all TT medics spawn with NVGs (GPS already linked above).
player addWeapon "Integrated_NVG_F";
[false] call AP_fnc_saveGear;