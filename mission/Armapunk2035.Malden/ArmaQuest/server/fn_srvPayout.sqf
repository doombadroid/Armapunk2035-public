// SPDX-License-Identifier: MIT
/*
    server/fn_srvPayout.sqf   —   aq_fnc_srvPayout

    Purpose: grant a quest's rewards through the profile mapping — money, items,
    licences, XP, faction reputation — and report honestly whether all of it landed.

    WHY THIS EXISTS
    Payout is the only place ArmaQuest reaches out and changes the host's world,
    and it is the one operation with no undo. Two failures matter:
      - Paying and not completing, or completing and not paying. Either one is
        reported by players as theft, and the log has to be able to settle it.
      - Paying twice. The obvious fix for "a grant failed, let them retry" is to
        run the whole payout again, which pays the successful half a second time.
    So this function is FAIL CLOSED and IDEMPOTENT: it checks every grant is
    possible before performing any of them, and it records a receipt for each
    grant it completes, so a retry resumes instead of restarting.

    WHAT IT DOES
      1. Reads the reward block (config class or radiant instance alike).
      2. Pre-flight: every profile function this payout needs must exist. If one
         does not, nothing is granted and the missing entry is named.
      3. Grants in a fixed order, writing a receipt into the quest state after
         each success.
      4. Returns [allGranted, receipts]. Anything other than all-granted means
         the caller must NOT mark the quest complete.

    SCALING (contract, because a reward can be scaled in exactly one place or it
    is scaled twice). `scaleWith` is applied by the GENERATOR, at generation
    time, and nowhere else: aq_fnc_scaleReward multiplies the instance's numeric
    rewards and then removes the key, so a radiant instance carries FINAL reward
    values and this function has nothing to decide. That is the reading the rest
    of the system already depends on — the offer screen, aq_fnc_dryRun and
    docs/RADIANT.md all show the scaled figure, and an offer that advertises one
    number and pays another is the worst version of this bug.
      A `scaleWith` still present in a reward block reaching here therefore means
    one of two things: an authored quest declared it (it is radiant-only, and it
    is ignored), or the generator did not run. Either way it is reported rather
    than acted on, because applying it here as well would double every payout the
    moment the generator's `deleteAt` changed.

    Usage:  ([_player, _uid, _rewardSrc, _qstate] call aq_fnc_srvPayout)
                params ["_ok", "_receipts"];

    Returns: [BOOL, ARRAY of ["money", n] | ["item", class, qty]
                              | ["license", name] | ["xp", n]
                              | ["rep", factionId, delta]]
*/

params [
    ["_player",  objNull, [objNull]],
    ["_uid",     "",      [""]],
    ["_rewards", configNull, [configNull, createHashMap]],
    ["_qstate",  createHashMap, [createHashMap]]
];

if (!isServer) exitWith { [false, []] };
if (_uid isEqualTo "") exitWith {
    diag_log text "[AQ] payout: no uid; refusing to pay.";
    [false, []]
};

private _qid  = _qstate getOrDefault ["quest", "?"];
private _paid = _qstate getOrDefault ["paid", []];

// ------------------------------------------------------------ read plan ----
private _money = [_rewards, "money", 0] call aq_fnc_cfgGet;
private _xp    = [_rewards, "xp", 0] call aq_fnc_cfgGet;
private _items = [_rewards, "items", []] call aq_fnc_cfgGet;
private _lics  = [_rewards, "licenses", []] call aq_fnc_cfgGet;
private _reps  = [_rewards, "rep", []] call aq_fnc_cfgGet;

if !(_money isEqualType 0) then { _money = 0; };
if !(_xp    isEqualType 0) then { _xp = 0; };
if !(_items isEqualType []) then { _items = []; };
if !(_lics  isEqualType []) then { _lics = []; };
if !(_reps  isEqualType []) then { _reps = []; };

// See SCALING above: the figures read here are already final. A surviving
// scaleWith is reported and NOT applied, because the alternative — applying it
// here as well — pays twice the moment the generator stops removing it, and a
// reward that is quietly double is not a bug anyone reports as a bug.
private _scaleSlot = [_rewards, "scaleWith", ""] call aq_fnc_cfgGet;
if (_scaleSlot isEqualType "" && {_scaleSlot != ""}) then {
    diag_log text format ["[AQ] payout: quest '%1' still carries scaleWith '%2' at grant time. scaleWith is a generation-time instruction and is applied by aq_fnc_scaleReward; it is ignored here. Paying %3. If this is an authored quest, remove the key — it is radiant-only.",
        _qid, _scaleSlot, _money];
};

// ----------------------------------------------------------- pre-flight ----
// Everything needed is resolved before anything is granted. A payout that dies
// half way through because a licence function is not mapped is the one case
// where the player has been paid and the quest has not completed.
private _need = [];
if (_money > 0) then { _need pushBack ["payMoney", "money"]; };
if (count _items > 0) then { _need pushBack ["giveItem", "items"]; };
if (count _lics  > 0) then { _need pushBack ["grantLicense", "licenses"]; };
if (count _reps  > 0) then { _need pushBack ["addRep", "rep"]; };

private _fns = createHashMap;
private _blocked = "";
{
    _x params ["_key", "_what"];
    private _name = [_key] call aq_fnc_profile;
    private _fn = if (_name isEqualType "" && {_name != ""}) then { missionNamespace getVariable [_name, {}] } else { {} };
    if (_fn isEqualTo {}) then {
        if (_blocked isEqualTo "") then { _blocked = _key; };
        diag_log text format ["[AQ] payout BLOCKED: quest '%1' pays %2, but AQ_Profile >> %3 maps to '%4', which is not a defined function.",
            _qid, _what, _key, _name];
    } else {
        _fns set [_key, _fn];
    };
} forEach _need;

if (_blocked != "") exitWith {
    diag_log text format ["[AQ] payout: quest '%1' for %2 granted NOTHING (missing profile entry '%3'). The quest stays active and can be handed in again once the profile is fixed.", _qid, _uid, _blocked];
    [false, []]
};

// XP is optional by design: a host with no XP system leaves awardXp empty and
// quests that offer XP simply do not offer it. That is not a payout failure.
private _xpFn = {};
if (_xp > 0) then {
    private _n = ["awardXp"] call aq_fnc_profile;
    if (_n isEqualType "" && {_n != ""}) then {
        _xpFn = missionNamespace getVariable [_n, {}];
        if (_xpFn isEqualTo {}) then {
            diag_log text format ["[AQ] payout: AQ_Profile >> awardXp names '%1', which is not defined. XP for quest '%2' is skipped.", _n, _qid];
        };
    };
};

// -------------------------------------------------------------- grants -----
private _receipts = [];
private _allOk = true;

private _once = {
    params ["_key", "_code"];
    // Already granted on an earlier attempt: skip, but still report it so the
    // completion message shows the player everything they earned.
    if (_key in _paid) exitWith { true };
    private _ok = call _code;
    if (_ok isEqualType true && {_ok}) then {
        _paid pushBack _key;
        _qstate set ["paid", _paid];
        true
    } else {
        diag_log text format ["[AQ] payout FAILED: quest '%1' for %2, grant '%3' returned %4. Quest NOT completed; earlier grants in this payout are receipted and will not be repeated.", _qid, _uid, _key, _ok];
        false
    };
};

if (_money > 0) then {
    private _f = _fns get "payMoney";
    if (["money", { [_uid, _money] call _f }] call _once) then {
        _receipts pushBack ["money", _money];
    } else { _allOk = false; };
};

if (_allOk) then {
    {
        private _row = _x;
        private _cls = "";
        private _qty = 1;
        if (_row isEqualType []) then {
            _cls = _row param [0, "", [""]];
            _qty = _row param [1, 1, [0]];
        } else {
            if (_row isEqualType "") then { _cls = _row; };
        };
        // Quantities are never scaled: six emblems is not a bigger version of
        // one emblem, so a template that wants a bigger physical reward declares
        // it. aq_fnc_scaleReward makes the same choice at generation time.
        if (_cls != "" && {_qty > 0} && {_allOk}) then {
            private _f = _fns get "giveItem";
            if ([format ["item:%1", _cls], { [_uid, _cls, _qty] call _f }] call _once) then {
                _receipts pushBack ["item", _cls, _qty];
            } else { _allOk = false; };
        };
    } forEach _items;
};

if (_allOk) then {
    {
        private _lic = _x;
        if (_lic isEqualType "" && {_lic != ""} && {_allOk}) then {
            private _f = _fns get "grantLicense";
            if ([format ["lic:%1", _lic], { [_uid, _lic] call _f }] call _once) then {
                _receipts pushBack ["license", _lic];
            } else { _allOk = false; };
        };
    } forEach _lics;
};

// rep[] — an array of [factionId, delta] pairs (FACTION_REP_SPEC.md section
// 6.3), so one quest can move several factions in one payout, some of them
// down: "helping the docks at the neon faction's expense" is an authored pair
// with a negative delta, not an error. Unlike items[], there is no bare-value
// shorthand — a delta is not optional the way a quantity of 1 is a sane
// default for an item — so a malformed pair is skipped rather than guessed
// at; fn_validate reports the shape at preInit, and this is the runtime half
// of the same contract that keeps a broken rewards block from being silently
// half-paid.
if (_allOk) then {
    {
        private _pair = _x;
        private _fid   = "";
        private _delta = 0;
        if (_pair isEqualType [] && {count _pair == 2}) then {
            _fid   = _pair param [0, "", [""]];
            _delta = _pair param [1, 0, [0]];
        };
        if (_fid != "" && {!(_delta isEqualTo 0)} && {_allOk}) then {
            private _f = _fns get "addRep";
            if ([format ["rep:%1", _fid], { [_uid, _fid, _delta] call _f }] call _once) then {
                _receipts pushBack ["rep", _fid, _delta];
            } else { _allOk = false; };
        };
    } forEach _reps;
};

// XP last and non-blocking: it is the one grant whose absence cannot leave the
// host's economy inconsistent.
if (_allOk && {_xp > 0} && {!(_xpFn isEqualTo {})}) then {
    if (!("xp" in _paid)) then {
        private _ok = [_uid, _xp] call _xpFn;
        _paid pushBack "xp";
        _qstate set ["paid", _paid];
        if !(_ok isEqualType true && {_ok}) then {
            diag_log text format ["[AQ] payout: awardXp returned %1 for quest '%2'; XP is treated as best-effort and the quest still completes.", _ok, _qid];
        };
    };
    _receipts pushBack ["xp", _xp];
};

if (_allOk) then {
    diag_log text format ["[AQ] payout: quest '%1' paid to %2 -> %3", _qid, _uid, _receipts];
};

[_allOk, _receipts]
