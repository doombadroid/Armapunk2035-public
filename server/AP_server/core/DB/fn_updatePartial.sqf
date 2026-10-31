/*
    DB_fnc_updatePartial  (LooneyBin: 2020 per-slot save)
    client fn_ClupdatePartial -> [player, side, uid, mode, ...data]
    mode -> column map mirrors core/session/fn_ClupdatePartial.sqf. Arrays are
    backtick-encoded (DB_fnc_mresArray); numbers stored raw; quest strings stored flat.
*/
params [["_player",objNull,[objNull]],["_side",civilian,[civilian]],["_uid","",[""]],["_mode",-1,[0]]];
if (_uid == "" || _mode < 0) exitWith {};
// owner 2026-06-23 SECURITY (security.md §2.3 — SQLi): the client _uid is interpolated into EVERY partial-save
// WHERE playerid clause (and DB_fnc_asyncQuery is unparameterized), so a crafted _uid (e.g. ' OR '1'='1)
// rewrote every player's row. Escape it once here. Cases 20 (quest arrays) and 24 (firefighter flag) also
// interpolated their client values (_d/_e) RAW -- those are sanitized inline below.
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
_uid = _uid call _san;
// THE ACTING ACCOUNT IS THE CALLER, NOT THE PACKET -- and unlike the routing block below, the answer here is
// REFUSAL. `_uid` is a bare string the client chose and `_player` a bare object reference it chose, and every
// case below interpolates that uid into `UPDATE ... WHERE playerid`, so a forged packet naming another
// Steam64 rewrites THAT account's gear, licenses, talents, arrest state or crimes out of the attacker's own
// client state. Re-routing (the fix used for a lying `_side`) is meaningless here: the two candidates are two
// different ACCOUNTS rather than two columns of one, so there is no "right column" to land the write in and
// landing it anywhere IS the attack. This is APS_fnc_vehicleCreate's PR5 hardening and the idiom
// APS_fnc_statTableUpdate already carries (fn_statTableUpdate.sqf:18-19), applied to the two save paths that
// were still deriving identity from the payload.
// SERVER-LOCAL CALLS ARE EXEMPT, AND THEY ARE REAL. remoteExecutedOwner reads 0 only for a call made on this
// machine, which no client can forge; owner 0 therefore means the SERVER is saving on someone's behalf and
// the packet is the server's own. fn_playerDisconnected.sqf:55/57/60 are exactly that -- the leaving player's
// position (mode 10), written after the unit may already be objNull. Refusing those would silently break the
// disconnect flush, which is why the exemption is explicit rather than implied.
// AN UNRESOLVABLE SENDER GETS NO DB ROW, BUT IT IS NOT SILENT. A live owner id with no unit in allPlayers
// cannot be attributed to any account, so there is nobody to name in the row; fn_statTableUpdate.sqf:19-20
// already treats that shape as a plain drop and this matches it -- but the drop itself now gets an RPT-only
// [AP-DUTY] breadcrumb (below), so a legitimate race (client quit mid-flush) never masquerades as a lost
// save. A resolved MISMATCH is the loggable case, and the subject is the
// SENDER (standing rule: never the payload) -- APS_fnc_logIt stamps @SRC from remoteExecutedOwner itself, so
// the row carries verified provenance. It is one INSERT where the unhardened code did one UPDATE, so this
// adds no DB write volume, and the rows are what the remoteExec-spam watch consumes.
private _src = remoteExecutedOwner;
private _sender = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _senderUid = if (_src isEqualTo 0) then { _uid } else { if (isNull _sender) then { "" } else { getPlayerUID _sender } };
if (_senderUid isNotEqualTo _uid) exitWith {
    if (_senderUid isNotEqualTo "") then {
        ["-SEC-", _sender, format ["BLOCKED cross-account partial-save mode=%1: packet named uid %2, sender is %3", _mode, _uid, _senderUid]] call APS_fnc_logIt;
    } else {
        // unattributable by construction (no live unit for this owner) -- RPT breadcrumb only, no DB row.
        diag_log format ["[AP-DUTY] partial-save dropped, unresolvable sender: mode=%1 payload uid=%2 owner=%3", _mode, _uid, _src];
    };
};
// ...and the same substitution for `_player`, which case 4 writes a server-side variable on
// (`_player setVariable ["AP_talents", ...]`). Left as the payload's own reference, a forged packet that
// happened to carry a MATCHING uid could still aim that write at a different unit. The sender's own unit is
// the only object this function has any business touching.
if (_src isNotEqualTo 0) then { _player = _sender; };
// LooneyBin: DB_fnc_mresArray already does `_this select 0`, and every caller below passes `[_d]`.
// The old `[_this]` here added a SECOND wrap -> every _enc field was stored double-nested
// (civ_gear='[[gear]]', position='[[x,y,z]]', ...). On load the 2020 client got `[gear]` instead of
// `gear` -> setUnitLoadout failed -> player spawned NAKED; position needed a load-unwrap; etc.
// Pass through so mresArray's own select-0 unwrap yields the single, correct value.
private _enc = { _this call DB_fnc_mresArray };            // [value] -> backtick string of value
private _d   = if (count _this > 4) then { _this select 4 } else { nil };
private _e   = if (count _this > 5) then { _this select 5 } else { nil };
// every mode below reads _d; a short/malformed client packet left it nil -> "Undefined variable _d"
// in the format call and the UPDATE ran with garbage. Drop the packet instead.
if (isNil "_d") exitWith {};
// WHICH CHARACTER THIS SAVE BELONGS TO IS THE SERVER'S CALL, NOT THE PACKET'S. `_side` above is the client's
// own AP_effSide, sent in the packet -- i.e. the one field a modified client sets to decide which of civ_/cop_/
// med_ its gear, licenses and talents are written to. Once the duty groups are published by netId a client can
// also make `side player` genuinely west without ever reaching APS_fnc_dutySRV, so even a server-side re-read of
// the engine side would agree with it. The roster is the only record that cannot be reached from a client at all.
// ROUTE, NEVER REJECT. A mismatch is logged and the save still lands -- in the RIGHT column. Dropping it would
// turn a lie into permanent kit loss for whoever was actually telling the truth (a legitimate save racing a
// clock-off, say), and this function is the only writer those columns have.
// Unrostered players -- every civilian, and every player at all while AP_dutyEnabled is false -- keep the
// client-claimed value verbatim, so a flag-false server behaves exactly as it did before this PR.
private _sideFlag = switch (_side) do { case west:{"cop"}; case independent:{"med"}; default {"civ"} };
if (localNamespace getVariable ["AP_dutyEnabled", false]) then {   // server copy (Lsec-0-1); the published global is client-writable
    private _dutyRow = _uid call APS_fnc_dutyLookup;
    // AND ONLY ONCE THE SHIFT IS ACKED. The roster entry is written BEFORE the grant is pushed to the
    // client, and the client's very first act on receiving it is to flush the CIVILIAN character -- gear
    // (mode 3) and talents (mode 4) -- while AP_effSide still says civilian, because those columns are the
    // only copy of it. Routing on a bare "is rostered" would catch exactly that flush and write the
    // civilian's kit and trees into cop_gear/cop_talents, destroying the character the flush exists to
    // preserve, on every single sign-on. Slot 3 is APS_fnc_dutySRV's ack flag: false until the client has
    // confirmed the engine side actually moved, i.e. false for precisely the window in which the client is
    // telling the truth about being a civilian. Before the ack, believe the packet; after it, believe the
    // roster.
    private _rosterFlag = if !(_dutyRow param [3, false]) then { "" } else {
        switch (_dutyRow param [0, ""]) do {
            case "maxsec": {"cop"};
            case "trauma": {"med"};
            default {""};
        };
    };
    if (_rosterFlag isNotEqualTo "") then {
        if (_rosterFlag isNotEqualTo _sideFlag) then {
            // Standing rule: log subject from remoteExecutedOwner, never the payload -- `_player` above is
            // whatever object reference the CLIENT put in its own remoteExec'd array, so a forged call could
            // name anyone as the mismatch subject. `_sender` is that resolution, done once by the origin gate
            // at the top of the file (it used to be re-derived here, shadowing it). The uid stays in the
            // message text (already sanitized).
            ["-DUTY-", _sender, format ["ROUTE MISMATCH partial mode=%1 uid=%2 claimed=%3 rostered=%4 -- saved as %4", _mode, _uid, _sideFlag, _rosterFlag]] call APS_fnc_logIt;
        };
        _sideFlag = _rosterFlag;
    };
};
private _qP = ""; private _qG = "";   // player / players_global UPDATE bodies

switch (_mode) do {case 0:  { _qP = format ["cash='%1'", _d call DB_fnc_numberSafe]; };
    case 1:  { _qP = format ["bankacc='%1'", _d call DB_fnc_numberSafe]; };
    case 2:  { _qP = format ["%2_licenses='%1'", [_d] call _enc, _sideFlag]; };
    case 3:  { _qP = format ["%2_gear='%1'", [_d] call _enc, _sideFlag]; };
    case 4:  { _qP = format ["%2_talents='%1', %2_exp='%3'", [_d] call _enc, _sideFlag, _e call DB_fnc_numberSafe];
               // TALENT BRIDGE: keep the server-side unit copy in sync with the standard-tree save (respec/learn)
               // so server payout/yield perks see the new build without a relog. Mirrors the login stash in
               // DB_fnc_queryRequest. _d = the array just persisted for this side; _player = the caller's unit.
               if (!isNull _player) then { _player setVariable ["AP_talents", _d, false]; }; };
    case 5:  { _qP = format ["arrested='%1'", [_d] call _enc]; };
    case 6:  { _qP = format ["cash='%1', bankacc='%2'", _d call DB_fnc_numberSafe, _e call DB_fnc_numberSafe]; };
    case 7:  { _qG = format ["achievements='%1'", [_d] call _enc]; };
    case 8:  { _qP = format ["crimes='%1'", [_d] call _enc]; };
    case 9:  { _qG = format ["stats='%1'", [_d] call _enc]; };
    // position is the CIVILIAN character's spawn point (bug #439). The other two writers (fn_updateRequest.sqf,
    // fn_playerDisconnected.sqf) already gate on the routed side; this one relied on the CLIENT's own guard --
    // a modified on-duty client could write the shared civilian position (logoff-inside-PD teleport). Mirror
    // updateRequest's own gate: only when the ROUTED flag reads civ.
    case 10: { if (_sideFlag isEqualTo "civ" && {_d isEqualType []} && {(count _d isEqualTo 0) || {count _d >= 3}}) then {
            _qP = format ["position='%1'", [_d] call _enc]; }; };   // same shape gate as fn_updateRequest: [] (death sentinel) or [x,y,z], nothing else
    // 11/12/13 are the DEATH-gear reset (LooneyBin #63: onPlayerKilled resets AP_gear to the side default and
    // sends one of these; without them the DB kept pre-death gear -> combat-log dupe). They used to name
    // civ_gear/cop_gear/med_gear literally, which made the MODE NUMBER the column selector -- the one field a
    // forged packet picks freely, so any client could plant a packet in any of the three. Routing them through
    // _sideFlag is behaviour-identical for an honest client (fn_onPlayerKilled.sqf picks 11/12/13 off AP_effSide,
    // exactly what _sideFlag is derived from) and takes the choice away from a dishonest one.
    case 11: { _qP = format ["%2_gear='%1'", [_d] call _enc, _sideFlag]; };
    case 12: { _qP = format ["%2_gear='%1'", [_d] call _enc, _sideFlag]; };
    case 13: { _qP = format ["%2_gear='%1'", [_d] call _enc, _sideFlag]; };
    case 14: { _qG = format ["honor_exp='%1', honor_talents='%2'", _d call DB_fnc_numberSafe, [_e] call _enc]; };
    case 15: { _qP = format ["prefix='%1'", (format ["%1", _d]) splitString "\'""`" joinString ""]; };   // LooneyBin: prefix is PLAYER TEXT -- stored raw, an exotic value (quotes/spaces, e.g. "The Eminent %1") broke the load-row compile and bricked that account's connect
    case 16: { _qP = format ["prestige='%1', pre_talents='%2'", _d call DB_fnc_numberSafe, [_e] call _enc]; };   // LooneyBin: cop prestige TREE -> its OWN pre_talents column. Was cop_talents, but cop_talents ALSO holds the cop STANDARD talent tree (AP_side_talents, talentCfg west IDs 73-129), which fn_updateRequest rewrites EVERY periodic save -> the prestige unlocks (AP_cop_talents, prestigeCfg cop IDs 1-41) got clobbered each sync = "prestige doesn't persist on cop". Medic dodged this (medic_talents != med_talents). prestige currency is a NUMBER (numberSafe); talents array via _enc.
    // 17 is the SCD re-route of mode 3 (fn_ClupdatePartial.sqf:66-67 hands an undercover officer's gear save to
    // it). Same treatment as 11/12/13 and for the same reason: an honest sender always has AP_effSide west here
    // (AP_copRole "scd" is only ever set on the MaxSec side), so _sideFlag reads "cop" and nothing changes; a
    // forged mode 17 from a civilian now writes that civilian's own civ_gear instead of seeding their cop_gear.
    case 17: { _qP = format ["%2_gear='%1'", [_d] call _enc, _sideFlag]; };
    case 18: {   // LooneyBin 2026-07-23 NEW DRACHMA: new_drachma is SERVER-authoritative now (APS_fnc_ndSRV owns
        // every write -- exact DECIMAL(20,4) ledger). A client still sending partial-18 is either a stale
        // mission PBO or a tamper attempt; either way it must never touch the ledger. _qP stays "" -> no query.
        diag_log format ["[LooneyBin][ND][TAMPER] partial-18 new_drachma write IGNORED from %1 (value %2)", _uid, _d];};
    case 19: { _qP = format ["title='%1'", _d call DB_fnc_numberSafe]; };
    // case 20 (completed_quests/progress_quests) removed with the legacy quest system, task 11 --
    // client mode 20 is no longer sent (core/functions/fn_initStats.sqf, core/session/fn_ClupdateRequest.sqf).
    // Left in place, this case would have referenced two dropped columns (sql/drop_legacy_quest_columns.sql);
    // harmless while unreachable, but a landmine for anyone who resurrects a mode-20 call site later.
    case 21: { _qP = format ["gov_data='%1'", [_d] call _enc]; };
    case 22: { _qP = format ["infamy_exp='%1', infamy_talents='%2'", _d call DB_fnc_numberSafe, [_e] call _enc]; };
    case 23: { _qP = format ["medic_prestige='%1', medic_talents='%2'", _d call DB_fnc_numberSafe, [_e] call _enc]; };   // LooneyBin Trauma Team prestige
    case 24: { _qP = format ["isfirefighter='%1'", _d call DB_fnc_numberSafe]; };   // LooneyBin: firefighter registration persistence (1/0) -- coerce numeric (SQL guard)
    default  { };};

if (_qP != "") then { [format ["UPDATE players SET %1 WHERE playerid='%2'", _qP, _uid]] call DB_fnc_asyncQuery; };
if (_qG != "") then { [format ["UPDATE players_global SET %1 WHERE playerid='%2'", _qG, _uid]] call DB_fnc_asyncQuery; };
