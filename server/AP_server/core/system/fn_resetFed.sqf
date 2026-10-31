/*
    APS_fnc_resetFed  (LooneyBin -- admin LIVE reset of the Federal Reserve / bank-vault lockout)
    owner 2026-06-16: clears the in-memory robbery state so the fed can be attempted again WITHOUT a
    reboot, for when a robbery gets stuck "in progress" (the end-detector never fires -> AP_fed_robbed
    stays [true,...] and fn_activeFederalEvent blocks everything) or the cooldowns are just blocking retry.

    HOW TO CALL:
      - in-game debug console (run on the SERVER):   call APS_fnc_resetFed
      - loonybot (Discord):                           !srv resetfed   (-> bot_commands bridge in init.sqf)

    Server-authoritative: every var is re-broadcast (publicVariable) so client action conditions +
    fn_activeFederalEvent see the cleared state immediately -- no reconnect.
    Vars (confirmed against fn_fedAlarm + fn_bankDrillVault):
      AP_fed_robbed [active,time] · AP_bank_robbed [active,time] · AP_bank_inProgress · AP_bank_drilling
      · AP_bank_robbers · SRV_lastRobbery (the 15-min cross-heist "security is high" cooldown).
    Times set to -99999 so the bank vault's 20-min re-rob window (select 1 < serverTime-1200) also clears.
*/
if (!isServer) exitWith {diag_log "[LooneyBin][resetFed] IGNORED -- must run on the SERVER (use the debug console SERVER exec).";
    false};

AP_fed_robbed      = [false, -99999];
AP_bank_robbed     = [false, -99999];
AP_bank_inProgress = false;
AP_bank_drilling   = false;
AP_bank_robbers    = [];
SRV_lastRobbery      = -99999; {publicVariable _x;} forEach ["AP_fed_robbed", "AP_bank_robbed", "AP_bank_inProgress",
    "AP_bank_drilling", "AP_bank_robbers", "SRV_lastRobbery"];

// Malden Federal Reserve: clear the phase, both clocks and the HIGH SECURITY lockout. Goes through the
// heist's own reset so the un-looted gold and an un-driven getaway boat are cleaned up too, rather than
// being left behind for the next run to inherit.
// The server's copy is in localNamespace (fn_maldenFedSRV _fnc_setState); the global is only its display copy.
private _mf = localNamespace getVariable "SRV_maldenFed";
if (!isNil "_mf") then {
    // Key in slot 2, reason in slot 3 -- the reset is key-guarded and refuses an unkeyed call.
    ["reset", (localNamespace getVariable ["AP_fedInternalKey", ""]), "admin resetfed"] call APS_fnc_maldenFedSRV;
    // The reset deliberately arms the HIGH SECURITY lockout; an admin clearing the Fed by hand wants
    // to retry NOW, so clear that one slot afterwards. Do NOT re-assign the whole array -- the reset
    // has just set the phase and the shim through the state helper, and a blanket overwrite here would
    // silently undo both. This is the same bounded, cooldown-slot-only write FED OVERRIDE makes.
    _mf set [4, -1];
    SRV_maldenFed = +_mf;
    publicVariable "SRV_maldenFed";
};

// owner 2026-06-16 (#312): also re-lock the domes/safes/gates -- a stuck robbery can leave them
// AP_vaultlocked=0 with doors disabled (fn_openVault then refuses "already unlocked" + they won't open).
// Re-locking restores the clean breakable state so the NEXT robbery works end to end.
[] call APS_fnc_fedLockdown;

diag_log "[LooneyBin][resetFed] Federal Reserve / bank lockout CLEARED + domes re-locked by admin -- retry enabled.";
true
