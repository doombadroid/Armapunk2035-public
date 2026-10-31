// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_cyberdeckLaunch.sqf  (AP_fnc_cyberdeckLaunch)
    LooneyBin 2026-07-19: Cyberdeck HOME MENU dispatcher. Runs hack #_id against the target the player had
    locked when they opened the menu (AP_cdTarget, captured on the Custom-20 keypress -- see fn_keyUpHandler).
    Closes the menu FIRST so the cursorTarget-reading heist fns (openSafe) re-read the still-aimed
    object (a dialog freezes the camera, so the aim is intact). openVault no longer belongs on that
    list -- the Malden rewrite takes no arguments and reads no cursorTarget; it gates on the player's
    distance to AP_fedDome. Every hack does its own client gate + a server-authoritative action; this
    is only the router.
*/
params [["_id", -1]];
private _tgt = missionNamespace getVariable ["AP_cdTarget", objNull];
closeDialog 0;
switch (_id) do {case 0: { [_tgt] spawn AP_fnc_cyberdeck; };             // Vehicle Unlock  (router -> lockpick / Sequence Breach)
    case 1: { [_tgt] spawn AP_fnc_cyberdeckIgnition; };     // Hack Ignition
    case 2: { [_tgt] spawn AP_fnc_cyberdeck; };             // Breach House    (router -> Terminal Breach)
    case 3: { [] spawn AP_fnc_openSafe; };                  // Crack Safe      (reads cursorTarget -- still aimed)
    case 4: { [] spawn AP_fnc_cyberdeckBank; };             // Bank Vault      (marker-proximity)
    case 5: { [] spawn AP_fnc_openVault; };                 // Fed Reserve     (no target: gates on AP_fedDome proximity)
    case 6: { [_tgt] spawn AP_fnc_cyberdeck; };             // Hijack Rig      (router -> takeover)
    case 7: { [_tgt] spawn AP_fnc_cyberdeckATM; };          // ATM Jackpot
    case 8: { [] spawn AP_fnc_cyberdeckWardrive; };         // Wardrive Scan   (no target)
    default {};};
