// JIP FOOTGUN: the T-5 broadcast rides the JIP queue (server init.sqf:455), so a
// player JOINING inside the last five minutes receives this BEFORE core/init.sqf
// has created AP_effSide -- two script errors per join, one per queued copy.
// Fall back to playerSide: a joiner that early is on a civilian slot anyway
// (factions are a shift, not a slot), so the right warning still lands.
private _side = missionNamespace getVariable ["AP_effSide", playerSide];
if (_side isEqualTo civilian) then {
    ["If you want a vehicle to persist through restart that you own or a lockpicked police vehicle please exit the vehicle now and stay within 150m of the vehicle(s) as the server restarts.", "basic"] spawn AP_fnc_handleMessage;
};
if (_side isEqualTo west) then {
    ["You can now send players to jail from any location on the map due to a nearing server restart. Use this option in accordance to MaxSec policy and guidelines.", "basic"] spawn AP_fnc_handleMessage;
};
waitUntil {uiSleep 1;
    (serverCycleLength - (serverTime - serverStartTime)) <= 55};
uiSleep random(25);
[] call AP_fnc_ClupdateRequest;