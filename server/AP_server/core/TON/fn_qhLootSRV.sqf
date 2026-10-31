// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_qhLootSRV.sqf  (APS_fnc_qhLootSRV)
    LooneyBin 2026-07-21: QUICKHACK LOOT rolls (owner spec: consumables + rare installable hack chips).
    Tiered by source; the server rolls and grants so a client can't mint its own drops.

      [_source, _player]   _source: "fed" | "cartel"   (the rogue van seeds its own crate cart instead)

    Throttled per-UID per-source so re-running the same heist beat can't farm rolls.
*/
params [["_source", "", [""]], ["_player", objNull, [objNull]]];
if (isNull _player || {!(_source in ["fed", "cartel"])}) exitWith {};

// WHO AND WHEN (audit 2026-09-26, mints/TONb-0-0). This is CfgRE-whitelisted and used to trust its payload whole:
// any client, from anywhere and without doing a heist, could send ["fed", player] for a guaranteed hack chip plus
// a "heist" schematic roll -- APS_fnc_fabGrantSRV trusts that roll, because it arrives through the spawn below as
// owner 0 -- and reset its own cooldown with a publicVariable. A client call now has to be about the CALLER
// (resolved from remoteExecutedOwner, alive) and backed by heist state the server can see:
//   "fed"    -- the reserve is breached (phase 1), or its dome was cracked within the last minute (phase 2 with
//               more than 540 of its 600 s left), and the caller is at the dome terminal (maldenFedSRV "dome"'s
//               own 10 m). fn_openVault sends this the moment the terminal breach succeeds, beside "dome".
//   "cartel" -- a cartel flag within 250 m fully held by the caller's gang, its 30-min capture cooldown stamped
//               in the last 2 minutes. fn_captureCartel sends this the moment the capture completes, right after
//               publishing that flag state.
// Server-internal calls (owner 0) are trusted as before. The cooldown lives in localNamespace now.
// Round 2 (audit r2heist): the fed phase is read from the SERVER-PRIVATE SRV_maldenFed (the global is a client-writable
// display copy) and the caller's gang from the server's uid->gang map, not the client-writable gang_data unit var.
// NOT closed: AP_capData / AP_capture_cooldown are still stamped by the capturing client itself (fn_captureCartel),
// because cartel capture is client-authoritative and the server keeps no capture record. A modified client can still
// pass the cartel arm near a flag; the per-UID 300 s cooldown below bounds it until capture moves server-side.
private _src = remoteExecutedOwner;
private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
private _earned = _src isEqualTo 0 || {_caller isEqualTo _player && {alive _caller} && {
    if (_source isEqualTo "fed") then {
        private _s = localNamespace getVariable ["SRV_maldenFed", [0, -1]];
        // the terminal's literal (fn_maldenFedSRV sets AP_FED_TERMPOS to it), not that global: a client
        // publicVariable of AP_FED_TERMPOS would move the terminal onto itself
        (_caller distance [11218.9, 4471.06, 18.16]) <= 10
            && {(_s param [0, 0]) isEqualTo 1 || {(_s param [0, 0]) isEqualTo 2 && {((_s param [1, -1]) - serverTime) > 540}}}
    } else {
        private _gid = format ["%1", (localNamespace getVariable ["APS_gangOfUid", createHashMap]) getOrDefault [getPlayerUID _caller, 0]];
        _gid isNotEqualTo "0" && {(([] call AP_fnc_cartelCfg) findIf {
            private _f = missionNamespace getVariable [_x select 2, objNull];
            private _cd = if (isNull _f) then { [] } else { _f getVariable ["AP_capData", []] };
            !isNull _f && {(_caller distance _f) < 250} && {(format ["%1", _cd param [0, 0]]) isEqualTo _gid}
                && {(_cd param [2, 0]) >= 1} && {((_f getVariable ["AP_capture_cooldown", 0]) - serverTime) > 1680}
        }) > -1}
    }}};
if (!_earned) exitWith {
    ["-SEC-", _caller, format ["BLOCKED qhLootSRV '%1' for %2 (no %1 completion the server can see for the caller)", _source, name _player]] call APS_fnc_logIt;
};

private _uid = getPlayerUID _player;
private _qcd = localNamespace getVariable "AP_qhLootCd";
if (isNil "_qcd") then { _qcd = createHashMap; localNamespace setVariable ["AP_qhLootCd", _qcd]; };
private _tkey = _source + "|" + _uid;
if (serverTime < (_qcd getOrDefault [_tkey, 0])) exitWith {};
_qcd set [_tkey, serverTime + 300];

// [class, qty, chance] -- fed pays best (hardest content), cartel moderate. Every hack chip is a PERMANENT
// unlock (owner 2026-07-22), so one lucky roll is a forever upgrade and duplicates are tradeable.
// FED (owner 2026-07-22): consumable chance rolls PLUS one GUARANTEED hack chip, weighted across every
// tier -- T1 common, T3 the meat, T4 rare, Chauffeur/Puppet under 1% each. The ICE Firewall (the counter)
// still rides the chance table so the defence spreads slightly ahead of the offence.
private _table = if (_source isEqualTo "fed") then {
    [["proxychain", 2, 1], ["breachkit", 1, 0.6], ["icefirewall", 1, 0.14], ["deadmanchip", 1, 0.12]]} else {
    [["proxychain", 1, 0.5], ["breachkit", 1, 0.3], ["ghostplatechip", 1, 0.1],
     ["icefirewall", 1, 0.06], ["flatlinecharge", 1, 0.04], ["blackoutdaemon", 1, 0.02], ["memoryholechip", 1, 0.02], ["chauffeurchip", 1, 0.008], ["puppetchip", 1, 0.005], ["deadmanchip", 1, 0.05]]
};

private _won = []; {_x params ["_cls", "_qty", "_chance"];
    if (random 1 < _chance) then { _won pushBack [_cls, _qty]; };} forEach _table;

// fed only: the guaranteed weighted chip. Weights sum to 100; a completed fed ALWAYS pays exactly one chip.
if (_source isEqualTo "fed") then {
    // owner 2026-07-23: T1 cut 48 -> 30, freed weight pushed into T3 (the tier money can't buy) 40.5 -> 58.5.
    // T1 chips are cheaply shop-bought, so showering them devalued the whole system; T3 is the loot-only meat.
    private _chips = [["pingchip", 7.5], ["distractchip", 7.5], ["staticchip", 7.5], ["whiteoutchip", 7.5],      // T1  30
        ["stickychip", 6.5], ["jamchip", 6.5], ["wiretapchip", 6.5], ["crybabychip", 6.5],         // T3  58.5
        ["synapsechip", 6.5], ["leechchip", 6.5], ["shortchip", 6.5], ["eyespychip", 6.5], ["valetchip", 6.25],
        ["ghostplatechip", 3], ["blackoutdaemon", 2.5], ["flatlinecharge", 2.5], ["memoryholechip", 2],  // T4  10
        ["chauffeurchip", 0.75], ["puppetchip", 0.75],                                             // apex <1% each
        // DETONATE (owner 2026-08-03): the rarest thing in the game -- 3x rarer than the other two apex
        // chips, ~1 per 400 completed feds. Its 0.25 came out of the T3 block (valetchip 6.5 -> 6.25) so
        // the weights still sum to exactly 100. Fed only; deliberately absent from the cartel table below,
        // because cartels are farmed far harder than feds and this is the only lethal hack.
        ["detonatechip", 0.25]
    ];
    private _roll = random 100;
    private _acc = 0;
    private _pick = "";
    { _acc = _acc + (_x select 1); if (_roll < _acc && {_pick isEqualTo ""}) then { _pick = _x select 0; }; } forEach _chips;
    if (_pick isEqualTo "") then { _pick = "pingchip"; };   // float-edge fallback: roll == 100 exactly
    _won pushBack [_pick, 1];};
if (_won isEqualTo []) exitWith {};
 {_x params ["_cls", "_qty"];
    [[true, _cls, _qty], "AP_fnc_handleInv", _player, false] spawn AP_fnc_MP;} forEach _won;
private _dn = createHashMapFromArray [["proxychain", "Proxy Chain"], ["breachkit", "Breach Kit"], ["ghostplatechip", "Ghost Plate Chip"],
    ["icefirewall", "ICE Firewall Chip"], ["flatlinecharge", "Flatline Chip"], ["blackoutdaemon", "Blackout Daemon"], ["memoryholechip", "Memory Hole Chip"], ["puppetchip", "Puppet Strings Chip"], ["deadmanchip", "Dead Man's Clutch Chip"], ["chauffeurchip", "Chauffeur Override Chip"],
    ["pingchip", "Ping.exe Chip"], ["distractchip", "Distract.exe Chip"], ["staticchip", "Static Burst Chip"], ["whiteoutchip", "Whiteout Chip"], ["stickychip", "Sticky Fingers Chip"], ["jamchip", "Jam.exe Chip"], ["wiretapchip", "Wiretap Chip"], ["crybabychip", "Crybaby Chip"], ["synapsechip", "Synapse Drag Chip"], ["leechchip", "Leech Chip"], ["shortchip", "Short Circuit Chip"], ["eyespychip", "Eye Spy Chip"], ["valetchip", "Valet Protocol Chip"]];
private _names = _won apply { format ["%2x %1", _dn getOrDefault [_x select 0, _x select 0], _x select 1] };
[[format ["<t color='#c9e21a'>DECK LOOT</t> -- recovered from the intrusion: %1.", _names joinString ", "], "cyberjackpot"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
["-QHLOOT-", _player, name _player, format ["%1 loot -> %2", _source, str _won]] call APS_fnc_logIt;

// 2026-08-22: a successful intrusion is also a "heist" faucet for Fabricator schematics. Routed
// through APS_fnc_fabGrantSRV like every other faucet -- it does its own pool pick, its own rarity
// roll, its own dedupe and its own throttle, so this is a report that something happened rather
// than a grant. Nothing here decides which schematic, or whether there is one at all.
// spawn, not call: APS_fnc_fabGrantSRV's buy arm waits on the ND lock, so the whole function is
// written to run scheduled.
["roll", [_player, "heist", ""]] spawn APS_fnc_fabGrantSRV;
