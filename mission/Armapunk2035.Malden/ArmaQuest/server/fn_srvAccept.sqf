// SPDX-License-Identifier: MIT
/*
    server/fn_srvAccept.sqf   —   aq_fnc_srvAccept

    Purpose: the acceptance gate. Decides whether a player may take a quest from
    a giver, and performs the offered -> active transition if so.

    WHY THIS EXISTS
    Acceptance is where a quest system's authority is either established or lost.
    Everything downstream — progress, payout, chains — assumes the quest was
    legitimately taken by a player who satisfied its gates. If any part of that
    check happens on the client, an edited client accepts a quest it can never
    see, skips a prerequisite chain, or takes the same repeatable job forty times
    in a minute; and because the reward path itself looks correct, the resulting
    economy damage is invisible until someone audits balances.
    So every check is here. The client sends two strings and gets a verdict.

    It also exists to be reusable as a *question*: the offer list has to answer
    "may this player take this?" for each candidate, and if that were a second
    implementation the two would drift, which shows up as quests that appear on
    the board and refuse to be accepted. Hence the dry-run mode below.

    WHAT IT DOES
      1. Rejects the call if it did not come from the machine that owns _player.
      2. Resolves the quest: a live offer (radiant or chained) or an authored
         quest from the catalogue.
      3. Checks, in this order and with a named reason for each failure:
         giver match, side, already-active, active-quest cap, once/cooldown,
         requires[], offer expiry, objective sanity.
      4. On success: builds the qstate, consumes the offer, records radiant
         slot usage, marks the record dirty, and pushes the new quest to the
         owner.

    GATING IS A PURE FUNCTION OF ONE QUEST. Nothing in the checks below writes
    anything a later evaluation reads. Offer-list building calls this once per
    candidate and the answers do not depend on the order it does that in.

    Usage:  [_player, "market_trader", "copper_run"] call aq_fnc_srvAccept;
            // dry run, used by the offer list:
            ([_player, "market_trader", "copper_run", true] call aq_fnc_srvAccept)
                params ["_ok", "_reason"];

    Returns: BOOL in normal mode, [BOOL, "reason"] in dry-run mode.

    NOTE FOR HOSTS: this is remoteExec'd from clients, so it needs an entry in
    the mission's CfgRemoteExec whitelist if one is in use — as does the client
    callback aq_fnc_sync in the other direction. A whitelist rejection is silent
    on the calling machine, which makes it look like the server ignored the
    player.
*/

params [
    ["_player",  objNull, [objNull]],
    ["_giverId", "",      [""]],
    ["_questId", "",      [""]],
    ["_dryRun",  false,   [false]]
];

private _fail = {
    params ["_reason", ["_loud", false]];
    if (_loud) then {
        diag_log text format ["[AQ] accept REJECT %1: quest='%2' giver='%3' player=%4",
            _reason, _questId, _giverId, _player];
    };
    if (_dryRun) exitWith { [false, _reason] };
    private _o = owner _player;
    if (_o > 0) then { ["offerResult", [false, _reason, _questId]] remoteExec ["aq_fnc_sync", _o]; };
    false
};

if (!isServer) exitWith { ["notServer", true] call _fail };
if !(localNamespace getVariable ["aq_srvReady", false]) exitWith { ["notReady", true] call _fail };

// ------------------------------------------------------------- identity ----
// remoteExecutedOwner is 0 when this was called locally (the dry run from the
// offer list, or a chain being offered) and the caller's machine id otherwise.
// A client may only act for its own unit; anything else is an attempt to accept
// a quest on someone else's behalf and is logged as what it is.
// UNVERIFIED: remoteExecutedOwner returns 0 outside a remoteExec call and the
// caller's client id inside one. Confirm by logging it from both paths.
private _reo = remoteExecutedOwner;
if (_reo > 0 && {owner _player != _reo}) exitWith {
    diag_log text format ["[AQ] SECURITY accept: machine %1 tried to accept '%2' for a unit it does not own (%3, owned by %4).",
        _reo, _questId, _player, owner _player];
    ["spoofedUnit"] call _fail
};

if (isNull _player) exitWith { ["noPlayer"] call _fail };
if (!alive _player) exitWith { ["dead"] call _fail };
if (_questId isEqualTo "") exitWith { ["noQuest"] call _fail };

private _uidFn = missionNamespace getVariable [(["playerUid"] call aq_fnc_profile), {}];
if (_uidFn isEqualTo {}) exitWith {
    diag_log text "[AQ] FATAL accept: AQ_Profile >> playerUid resolves to no function; no player can be identified, so no quest can be accepted.";
    ["noProfileUid"] call _fail
};
private _uid = [_player] call _uidFn;
if (!(_uid isEqualType "") || {_uid isEqualTo ""}) exitWith { ["noUid", true] call _fail };

private _pst = ["player", _uid] call aq_fnc_srvStore;
if (isNil "_pst") exitWith { ["noState", true] call _fail };
private _now = (localNamespace getVariable "aq_srvEpochBase") + time;

// -------------------------------------------------------- resolve quest ----
// A quest is either a live offer (radiant board entry or a chained offer held
// for this player) or an authored catalogue entry. Offers are checked first:
// a radiant instance id never collides with a config class name, but if a host
// ever made one that did, the live offer is the more specific answer.
private _offer  = nil;
private _shared = false;

private _personal = _pst getOrDefault ["offers", createHashMap];
private _o = _personal getOrDefault [_questId, nil];
if !(isNil "_o") then { _offer = _o; };

if (isNil "_offer") then {
    {
        if ((_x getOrDefault ["quest", ""]) isEqualTo _questId) exitWith {
            _offer = _x; _shared = true;
        };
    } forEach ((localNamespace getVariable ["aq_srvBoard", createHashMap]) getOrDefault [_giverId, []]);
};

private _inst = createHashMap;
private _src  = configNull;

if !(isNil "_offer") then {
    _inst = _offer getOrDefault ["inst", createHashMap];
    // Emptiness is asked with count, never by comparing to a fresh HashMap:
    // whether isEqualTo compares HashMaps by content or by identity is not
    // something this area should be betting on.
    if (count _inst == 0) then {
        // An offer for an authored quest: the catalogue is still the source.
        _src = [_questId] call aq_fnc_cfgQuest;
    } else {
        _src = _inst;
    };
} else {
    _src = [_questId] call aq_fnc_cfgQuest;
};

if (_src isEqualType configNull && {isNull _src}) exitWith { ["unknownQuest", true] call _fail };

// ------------------------------------------------------------- the gates ---
// Ordered cheapest-and-most-specific first so the reason a player sees is the
// one that actually explains their situation.

private _questGiver = [_src, "giver", ""] call aq_fnc_cfgGet;
if (!isNil "_offer") then { _questGiver = _offer getOrDefault ["giver", _questGiver]; };
if (_questGiver isEqualType "" && {_questGiver != ""} && {_giverId != ""} && {_questGiver != _giverId}) exitWith {
    ["wrongGiver"] call _fail
};

// Side. Empty or "any" means anyone.
//
// The quest's own vocabulary ("civ", "cop") is mapped onto an engine side
// through AQ_Settings >> sideMap, and the comparison is then made against the
// engine's `side`. The profile is deliberately NOT involved: DESIGN.md section
// 9 fixes what the profile covers, and an entry for side-mapping would make
// every host's table diverge from the documented one for a value the engine
// already knows.
// The mapping is what carries the disagreement between forks about what a
// civilian is, and it is one config line to override.
// The verdict is carried out of the block in a flag: `exitWith` leaves the
// block it is written in, not the function, so a gate written as an exitWith
// inside a `then` is a gate that logs its refusal and then lets the player
// through anyway.
private _sideOk = true;
private _wantSide = [_src, "side", ""] call aq_fnc_cfgGet;
if (_wantSide isEqualType "" && {_wantSide != ""} && {toLower _wantSide != "any"}) then {
    private _map = ["sideMap", [["civ", "CIV"], ["cop", "WEST"], ["med", "GUER"], ["reb", "EAST"]]] call aq_fnc_setting;
    private _want = "";
    { if (((_x select 0) isEqualType "") && {toLower (_x select 0) isEqualTo toLower _wantSide}) exitWith { _want = toUpper (_x select 1); }; } forEach _map;
    if (_want isEqualTo "") then {
        diag_log text format ["[AQ] accept: quest '%1' declares side '%2', which AQ_Settings >> sideMap does not map. Treating the quest as unavailable rather than open to everyone.", _questId, _wantSide];
        _want = "#unmapped";
    };
    _sideOk = (toUpper (str (side _player))) isEqualTo _want;
};
if (!_sideOk) exitWith { ["wrongSide"] call _fail };

private _active = _pst getOrDefault ["active", createHashMap];
if (!isNil {_active get _questId}) exitWith { ["alreadyActive"] call _fail };
// LOCAL PATCH (VENDORED.txt): one live instance per radiant template. Every
// instance has its own id, and srvFact offers a fact to every active quest, so
// ten copies of one template turned one robbery or one hack into ten payouts.
private _tpl = _inst getOrDefault ["template", ""];
if (_tpl isNotEqualTo "" && {((values _active) findIf { ((_x getOrDefault ["inst", createHashMap]) getOrDefault ["template", ""]) isEqualTo _tpl }) > -1}) exitWith { ["alreadyActive"] call _fail };

private _maxActive = ["maxActive", 10] call aq_fnc_setting;
if (!(_maxActive isEqualType 0)) then { _maxActive = 10; };
if (_maxActive > 0 && {count _active >= _maxActive}) exitWith { ["tooManyActive"] call _fail };

// repeatable: 0 = once ever | -1 = always | N = cooldown seconds.
// A cooldown of -1 in the player's record means permanently locked, which is
// how a once-only quest is retired whether it ended in success or failure.
private _repeat = [_src, "repeatable", 0] call aq_fnc_cfgGet;
if (_repeat isEqualType "") then { _repeat = parseNumber _repeat; };
if !(_repeat isEqualType 0) then { _repeat = 0; };
private _completedCount = (_pst getOrDefault ["completed", createHashMap]) getOrDefault [_questId, 0];
private _cdUntil = (_pst getOrDefault ["cooldown", createHashMap]) getOrDefault [_questId, 0];

if (_cdUntil isEqualTo -1) exitWith { ["retired"] call _fail };
if (_repeat isEqualTo 0 && {_completedCount > 0}) exitWith { ["onceOnly"] call _fail };
if (_repeat > 0 && {_now < _cdUntil}) exitWith { ["onCooldown"] call _fail };

// requires[]. Evaluated fresh, from this quest's declaration only.
private _req = [_src, "requires", []] call aq_fnc_cfgGet;
if !(_req isEqualType []) then { _req = []; };
private _missing = "";
{
    private _tok = _x;
    if (_tok isEqualType "" && {_tok != ""}) then {
        private _parts = _tok splitString ":";
        private _kind = toLower (_parts param [0, ""]);
        private _name = _parts param [1, ""];
        // _qty is clamped to a positive default for item:'s optional quantity: a
        // missing or non-positive count there means "at least one", the only
        // reading that makes sense for a quantity of items. This clamp is
        // deliberately NOT reused below for rep:, which parses its own third
        // part independently inside its own case. rep:<factionId>:<n> is a
        // SIGNED threshold -- rep:f_dock:-500 is how hostile-gated content is
        // written (FACTION_REP_SPEC.md section 6.1) -- and running it through a
        // clamp that rewrites anything <= 0 to 1 would silently turn "gate this
        // to someone the faction hates" into "gate this to someone who merely
        // likes them", the opposite of what the quest author wrote.
        private _qty  = parseNumber (_parts param [2, "1"]);
        if (_qty <= 0) then { _qty = 1; };

        private _ok = switch (_kind) do {
            case "quest": {
                ((_pst getOrDefault ["completed", createHashMap]) getOrDefault [_name, 0]) > 0
            };
            case "license": {
                private _f = missionNamespace getVariable [(["hasLicense"] call aq_fnc_profile), {}];
                if (_f isEqualTo {}) then {
                    diag_log text format ["[AQ] accept: quest '%1' requires license '%2' but AQ_Profile >> hasLicense is unset. Refusing the quest; a missing profile entry must not become an open door.", _questId, _name];
                    false
                } else {
                    ([_uid, _name] call _f) isEqualTo true
                };
            };
            case "item": {
                private _f = missionNamespace getVariable [(["countItem"] call aq_fnc_profile), {}];
                if (_f isEqualTo {}) then {
                    diag_log text format ["[AQ] accept: quest '%1' requires item '%2' but AQ_Profile >> countItem is unset. Refusing the quest.", _questId, _name];
                    false
                } else {
                    private _have = [_uid, _name] call _f;
                    (_have isEqualType 0) && {_have >= _qty}
                };
            };
            case "rep": {
                // rep:<factionId>:<n> is always three parts; unlike item:'s
                // quantity, the threshold is not optional, so a two-part token is
                // malformed rather than defaulted. FACTION_REP_SPEC.md section 6.1.
                if ((count _parts) != 3) then {
                    diag_log text format ["[AQ] accept: quest '%1' has a malformed rep: requirement '%2'; expected 'rep:<factionId>:<n>'. Treating it as unsatisfied.", _questId, _tok];
                    false
                } else {
                    if (_name isEqualTo "") then {
                        diag_log text format ["[AQ] accept: quest '%1' has a rep: requirement naming no faction ('%2'). Treating it as unsatisfied.", _questId, _tok];
                        false
                    } else {
                        private _f = missionNamespace getVariable [(["getRep"] call aq_fnc_profile), {}];
                        if (_f isEqualTo {}) then {
                            diag_log text format ["[AQ] accept: quest '%1' requires rep with '%2' but AQ_Profile >> getRep is unset. Refusing the quest; a missing profile entry must not become an open door.", _questId, _name];
                            false
                        } else {
                            // Deliberately parseNumber on the raw third part, not
                            // _qty: _qty's clamp forces anything <= 0 to 1, and a
                            // rep threshold of exactly 0 or a negative number are
                            // both meaningful values that clamp would destroy —
                            // see the comment above _qty's own definition.
                            private _threshold = parseNumber (_parts select 2);
                            private _have = [_uid, _name] call _f;
                            (_have isEqualType 0) && {_have >= _threshold}
                        };
                    };
                };
            };
            case "align": {
                // align:<factionId>  -- the player's organisation is aligned with
                // that faction.
                // align:any          -- aligned with anybody at all.
                //
                // Allegiance, not standing. rep: asks how much a faction likes THIS
                // PLAYER, which one player earns alone; this asks whose side their
                // crew is on, which one player does not decide. Content meant for a
                // committed organisation gates on the first form; content that only
                // needs somebody with a patron uses the second.
                //
                // "any" is therefore a reserved faction id: a host whose catalogue
                // literally contains a faction called "any" cannot gate on it by
                // name. Said out loud here because it is invisible otherwise, and
                // the alternative -- a separate token kind meaning "aligned at
                // all" -- is a worse trade for a name nobody uses.
                private _f = missionNamespace getVariable [(["factionOf"] call aq_fnc_profile), {}];
                if (_f isEqualTo {}) then {
                    diag_log text format ["[AQ] accept: quest '%1' requires alignment with '%2' but AQ_Profile >> factionOf is unset. Refusing the quest; a missing profile entry must not become an open door.", _questId, _name];
                    false
                } else {
                    private _has = [_uid] call _f;
                    if !(_has isEqualType "") then {
                        diag_log text format ["[AQ] accept: quest '%1' requires alignment but AQ_Profile >> factionOf returned %2, not a string. Treating it as unsatisfied.", _questId, typeName _has];
                        false
                    } else {
                        if (toLower _name isEqualTo "any") then { _has != "" } else { _has isEqualTo _name }
                    };
                };
            };
            case "world": {
                if (isNil {localNamespace getVariable "aq_worlds"}) then { localNamespace setVariable ["aq_worlds", createHashMap]; };
                private _resolver = (localNamespace getVariable "aq_worlds") getOrDefault [_name, nil];
                if (isNil "_resolver" || {!(_resolver isEqualType {})}) then {
                    diag_log text format ["[AQ] accept: quest '%1' requires world '%2', which nothing has registered with aq_fnc_registerWorld. Treating it as unsatisfied.", _questId, _name];
                    false
                } else {
                    // Read-only and isolated by construction (WORLD_STATE_SPEC.md
                    // section 5): a resolver takes no arguments, and its failure
                    // must not take the whole offer build down with it.
                    // try/catch is what SQF offers for that containment.
                    // UNVERIFIED: whether try/catch here also catches an ordinary
                    // runtime scripting error (an undefined variable, a wrong
                    // argument type) and not only an explicit `throw` is an
                    // engine-behaviour claim this file cannot execute to confirm.
                    // Check by registering a resolver that references an
                    // undefined variable and confirming the offer build still
                    // completes for every OTHER candidate quest rather than
                    // aborting the whole pass.
                    private _result = nil;
                    try {
                        _result = call _resolver;
                    } catch {
                        if (isNil "aq_worldErrLogged") then { aq_worldErrLogged = createHashMap; };
                        if (isNil { aq_worldErrLogged get _name }) then {
                            aq_worldErrLogged set [_name, true];
                            // Reported ONCE per key, not once per evaluation: this
                            // case runs on every offer build, for every candidate
                            // quest carrying the token, for every player who opens
                            // a giver -- an unthrottled log on a call site that
                            // busy is the amplifier this library designs against
                            // elsewhere (AQ_Settings >> factRateLimit; the identical
                            // reasoning is spelled out in fn_srvFact.sqf).
                            diag_log text format ["[AQ] accept: world resolver '%1' threw (%2). Treating it as unsatisfied here and on every further evaluation; reported once for this key.", _name, _exception];
                        };
                    };
                    if (isNil "_result") then {
                        false
                    } else {
                        if ((count _parts) == 3) then {
                            // The token's value half is always a STRING (it came
                            // out of splitString); a resolver that answers a
                            // number or anything else for the value form simply
                            // does not match rather than risking isEqualTo across
                            // two different types, which this file does not rely
                            // on being safe.
                            (_result isEqualType "") && {_result isEqualTo (_parts select 2)}
                        } else {
                            (_result isEqualType true) && {_result}
                        };
                    };
                };
            };
            default {
                // An unrecognised prerequisite is a config error, and the safe
                // reading of "I do not understand this gate" is "closed".
                diag_log text format ["[AQ] accept: quest '%1' has an unrecognised requires[] entry '%2'. Recognised prefixes: quest:, license:, item:, rep:, align:, world:. Treating it as unsatisfied.", _questId, _tok];
                false
            };
        };
        if (!_ok && {_missing isEqualTo ""}) then { _missing = _tok; };
    };
} forEach _req;
if (_missing != "") exitWith { [format ["requires:%1", _missing]] call _fail };

// Offer expiry. Checked late because "you were too slow" is only worth saying
// to a player who could otherwise have taken it.
private _offerDead = false;
if (!isNil "_offer") then {
    private _exp = _offer getOrDefault ["expires", 0];
    if ((_exp isEqualType 0) && {_exp > 0} && {_now > _exp}) then { _offerDead = true; };
};
if (_offerDead) exitWith { ["offerExpired"] call _fail };

// Objectives. A quest with none can never complete, and would sit in the active
// list forever; that is a config bug and it is reported as one.
private _objIds = [];
if (count _inst > 0) then {
    { _objIds pushBack (_x getOrDefault ["id", ""]); } forEach (_inst getOrDefault ["objectives", []]);
} else {
    private _root = _src >> "objectives";
    if (isClass _root) then {
        { _objIds pushBack (configName _x); } forEach (configProperties [_root, "isClass _x", true]);
    };
};
_objIds = _objIds select { _x isEqualType "" && {_x != ""} };
if (count _objIds == 0) exitWith { ["noObjectives", true] call _fail };

if (_dryRun) exitWith { [true, "ok"] };

// ------------------------------------------------------------ transition ---
private _timeLimit = [_src, "timeLimit", 0] call aq_fnc_cfgGet;
if !(_timeLimit isEqualType 0) then { _timeLimit = 0; };

private _qstate = createHashMap;
_qstate set ["quest",    _questId];
_qstate set ["giver",    _giverId];
_qstate set ["state",    "active"];
_qstate set ["started",  _now];
_qstate set ["deadline", [0, _now + _timeLimit] select (_timeLimit > 0)];
_qstate set ["index",    0];
_qstate set ["objIds",   _objIds];
_qstate set ["objState", createHashMapFromArray (_objIds apply { [_x, createHashMap] })];
_qstate set ["paid",     []];
_qstate set ["inst",     _inst];

_active set [_questId, _qstate];
_pst set ["active", _active];

// Radiant bookkeeping: the slot values this instance used go on cooldown for
// this player, so the generator stops sending them to the same place. Recorded
// on accept rather than on generation because a shared board is generated once
// for everybody but taken by one person.
//
// What is stored is WHEN, not UNTIL. The generator's filter is
// (now - lastUsed) < notUsedWithin, and that window belongs to the slot asking
// the question: two templates may draw the same pool entry with two different
// windows, so a stored expiry would let whichever accepted last decide the
// answer for both. The cooldownSeconds carried on the offer is used at
// presentation time (fn_srvBoard) against this stamp.
{
    _x params [["_key", "", [""]], ["_secs", 0, [0]]];
    if (_key != "" && {_secs > 0}) then {
        (_pst getOrDefault ["recent", createHashMap]) set [_key, _now];
    };
} forEach (if (isNil "_offer") then {[]} else {_offer getOrDefault ["used", []]});

// The offer is consumed. For a shared board this is also what makes the race
// real: whoever accepts first takes it off everyone else's board.
if (!isNil "_offer") then {
    if (_shared) then {
        ["take", _giverId, _questId] call aq_fnc_srvBoard;
    } else {
        _personal deleteAt _questId;
    };
};

["dirty", format ["player:%1", _uid]] call aq_fnc_srvStore;

private _own = owner _player;
if (_own > 0) then { ["offerResult", [true, "ok", _questId]] remoteExec ["aq_fnc_sync", _own]; };

// Push the freshly-armed quest with real progress figures. Progress is computed
// in one place (fn_srvFact) so the offer screen, the journal and the HUD can
// never disagree about what "3 of 8" means.
[_player, "", []] call aq_fnc_srvFact;

diag_log text format ["[AQ] accept: %1 took '%2' from '%3'%4.",
    _uid, _questId, _giverId,
    ["", " (radiant)"] select (count _inst > 0)];

true
