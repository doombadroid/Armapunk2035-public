/*
    APS_fnc_fedOverrideSRV  (owner 2026-06-19 -- "Fed Control" owner-menu tool)
    OWNER-ONLY. Client (admin menu) args: [_action, _pObj].
      "reset" -> clear the Federal Reserve / bank lockout state right now (calls APS_fnc_resetFed).
      "on"    -> FED OVERRIDE on: disable ALL heist cop-requirements (AP_betaZeroCops, the central
                 fn_policeRequired waiver) + keep every heist COOLDOWN timestamp cleared via a loop, so
                 the fed/bank/jewelry/loonybin can be run back-to-back. Persisted in server_control.fedoverride.
      "off"   -> restore normal cop-requirements + cooldown tracking.
    The cooldown loop only zeroes the cooldown TIMESTAMP fields (SRV_lastRobbery, AP_*_robbed[1],
    SRV_loonyBinData[0]); it never touches the ACTIVE-robbery flags ([0]), so it can't break an in-progress event.
*/
params [["_action", "", [""]], ["_pObj", objNull, [objNull]]];
if (isNull _pObj) exitWith {};
// owner 2026-07-24 SECURITY: the owner check read getPlayerUID off _pObj -- a CLIENT-SUPPLIED object -- so
// any client could pass the OWNER's player object (trivially obtainable from allPlayers) and satisfy it,
// granting itself the cop-requirement waiver and permanently-cleared heist cooldowns. Latent while this fn
// had no CfgRE entry; it is being whitelisted now so the owner's dead "Fed Control" button works, which
// would have made it live. Derive from the non-spoofable remoteExecutedOwner and reply to that caller.
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
private _caller = if (_src isEqualTo 0) then { _pObj } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if !((getPlayerUID _caller) isEqualTo "76561190000000001") exitWith {
    [["Fed Control is owner-only.", "basic"], "AP_fnc_handleMessage", _caller, false] spawn AP_fnc_MP;
    if (_src isNotEqualTo 0) then { ["-SEC-", _caller, format ["BLOCKED fedOverrideSRV '%1' (not the owner; claimed %2)", _action, getPlayerUID _pObj]] call APS_fnc_logIt; };
};
_pObj = _caller;   // downstream logging/messaging uses the verified actor

switch (toLower _action) do {case "reset": {[] call APS_fnc_resetFed;
        ["-FEDOVERRIDE-", _pObj, "manually RESET the Federal Reserve / bank lockout"] call APS_fnc_logIt;
        [["Federal Reserve / bank lockout CLEARED + domes re-locked. Retry enabled.", "basic"], "AP_fnc_handleMessage", _pObj, false] spawn AP_fnc_MP;
    };

    case "on": {AP_fedOverride  = true;
        localNamespace setVariable ["AP_fedOverride", true];   // the copy the clear loop keys on (audit r2heist)
        AP_betaZeroCops = true;                       // central cop-requirement waiver (fn_policeRequired)
        localNamespace setVariable ["AP_betaZeroCops", true];   // the copy every SERVER heist gate reads (Lsec-0-1)
        publicVariable "AP_fedOverride"; publicVariable "AP_betaZeroCops";
        ["UPDATE server_control SET fedoverride=1 WHERE id=1"] call DB_fnc_asyncQuery;
        ["-FEDOVERRIDE-", _pObj, "Fed Override ON -- cop requirements + heist cooldowns DISABLED"] call APS_fnc_logIt;
        // cooldown-clear loop: zero the cooldown TIMESTAMPS only (not the active flags) while the override is on.
        // Keyed on the localNamespace flag: a client publishing AP_fedOverride=false used to stop the clears
        // while the waiver above stayed on, leaving the owner's toggle half-on.
        [] spawn {while { localNamespace getVariable ["AP_fedOverride", false] } do {
                if (!isNil "SRV_lastRobbery" && {SRV_lastRobbery != -99999}) then { SRV_lastRobbery = -99999; publicVariable "SRV_lastRobbery"; };
                if (!isNil "AP_fed_robbed"  && {(AP_fed_robbed  param [1, 0]) != -99999}) then { AP_fed_robbed  set [1, -99999]; publicVariable "AP_fed_robbed"; };
                if (!isNil "AP_bank_robbed" && {(AP_bank_robbed param [1, 0]) != -99999}) then { AP_bank_robbed set [1, -99999]; publicVariable "AP_bank_robbed"; };
                // Loony Bin + Malden Fed: clear the SERVER-PRIVATE copy (the only one their gates read), then republish.
                private _lb = localNamespace getVariable "SRV_loonyBinData";
                if (!isNil "_lb" && {(_lb param [0, 0]) != -99999}) then { _lb set [0, -99999]; SRV_loonyBinData = +_lb; publicVariable "SRV_loonyBinData"; };
                // The Malden Fed's HIGH SECURITY lockout is slot 4 of its own state array, not a AP_*_robbed
                // timestamp, so the clears above cannot reach it. Same rule as the others: cooldown only, never
                // the phase -- slot 0 is left exactly as it is, so an in-progress robbery is untouched.
                // This is the SECOND copy of this loop: init.sqf runs the same clears for a persisted override
                // restored at boot, and the two must stay in step.
                private _mf = localNamespace getVariable "SRV_maldenFed";
                if (!isNil "_mf" && {(_mf param [4, -1]) != -1}) then {
                    _mf set [4, -1]; SRV_maldenFed = +_mf; publicVariable "SRV_maldenFed"; };
                uiSleep 4;};};
        [["Fed Override is now ON. Cop requirements + all heist cooldowns are DISABLED.", "basic"], "AP_fnc_handleMessage", _pObj, false] spawn AP_fnc_MP;
    };

    case "off": {AP_fedOverride  = false;
        localNamespace setVariable ["AP_fedOverride", false];   // stops the clear loop(s)
        AP_betaZeroCops = false;
        localNamespace setVariable ["AP_betaZeroCops", false];
        publicVariable "AP_fedOverride"; publicVariable "AP_betaZeroCops";
        ["UPDATE server_control SET fedoverride=0 WHERE id=1"] call DB_fnc_asyncQuery;
        ["-FEDOVERRIDE-", _pObj, "Fed Override OFF -- normal cop requirements + cooldowns restored"] call APS_fnc_logIt;
        [["Fed Override is now OFF. Cop requirements + heist cooldowns are back to normal.", "basic"], "AP_fnc_handleMessage", _pObj, false] spawn AP_fnc_MP;
    };};
