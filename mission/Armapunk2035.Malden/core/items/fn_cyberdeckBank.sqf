// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_cyberdeckBank.sqf  (AP_fnc_cyberdeckBank)
    LooneyBin 2026-07-19: Bank Vault hack launched from the Cyberdeck home menu. Mirrors the "Hack Bank Vault"
    scroll action (fn_setupActions): must be jacked into the vault door, Terminal Breach (6 cmds), then hand the
    job to the server (APS_fnc_bankRobbery). Every gate here matches the scroll action so the two entry points
    behave identically.
*/
if (!(call AP_fnc_hasDeck)) exitWith { ["You need a Cyberdeck for that.", "basic"] spawn AP_fnc_handleMessage; };
if ((player distance (getMarkerPos "AP_bank_door")) >= 4) exitWith {
    ["Get up against the bank vault door to jack in.", "basic"] spawn AP_fnc_handleMessage;};
if (AP_bank_robbed select 0) exitWith { ["The bank vault is already being cracked.", "basic"] spawn AP_fnc_handleMessage; };
if ((AP_bank_robbed select 1) >= serverTime - 1200) exitWith {
    [2, "Security is high due to a recent robbery -- try the vault again later."] call AP_fnc_broadcast;};
if !(isNull objectParent player) exitWith { ["Get out of the vehicle first.", "basic"] spawn AP_fnc_handleMessage; };
if ((missionNamespace getVariable ["AP_lastBankDrillClick", -999]) > serverTime - 15) exitWith {
    ["Drill already starting, give it a moment.", "basic"] spawn AP_fnc_handleMessage;};
AP_lastBankDrillClick = serverTime;
if ([] call AP_fnc_activeFederalEvent) exitWith {
    ["There is already another Federal Event happening.", "basic"] spawn AP_fnc_handleMessage;};
if !([4, true] call AP_fnc_policeRequired) exitWith {};
if (SRV_lastRobbery > (serverTime - (60 * 15))) exitWith {
    [2, format ["Security is high due to a recent robbery and you cannot rob the bank. Try again in %1 minute(s).", ceil ((SRV_lastRobbery - (serverTime - (60 * 15))) / 60)]] call AP_fnc_broadcast;
};

private _bankRoot = [2] call AP_fnc_cyberdeckTerm;   // Terminal Breach gates the bank job (was a drill)
if !(_bankRoot isEqualTo 1) exitWith {};
[[player, cursorObject], "APS_fnc_bankRobbery", 2] spawn AP_fnc_MP;
["bankdrill", 1] call AP_fnc_statArrUpdate;
