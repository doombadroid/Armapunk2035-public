/*
    APS_fnc_claimBodybagSRV  (LooneyBin: claim a combat-log fugitive bodybag) -- runs on the SERVER.
    owner 2026-06-27: when a WANTED player combat-logs, fn_playerDisconnected drops a tagged "Fugitive Bodybag"
    object at their logout spot. MaxSec (any rank) OR the bounty hunter tracking that player's bounty can scroll-wheel
    it (fn_setupActions action -> remoteExec here). This:
      1. JAILS the offline fugitive PERSISTENTLY -- writes players.arrested=[1,bail,sentence] so they spawn in the
         cell on their next login (survives a server restart, unlike the in-memory re-jail list).
      2. also pushes them into the re-jail list (localNamespace APS_restrainedPlayers; re-jail this session if they relog before a restart).
      3. pays the claimer the FULL bounty + a combat-log bonus (owner decision), via the normal bountyReceive path.
      4. clears the fugitive's wanted (server list + DB row) so the bounty is resolved + can't be double-claimed.
      5. deletes the bodybag.
    Client passes [_bag, AP_side_talents]. The claimer is the NON-SPOOFABLE remoteExecutedOwner -- re-gated server-side (cop or BH),
    distance-checked, and single-fired (the server bag registry) so a double-click / remote can't pay twice or jail-from-afar.
    The talents array only picks a duty cop's pay tier (step 4); a forged one reaches at most the legit 107 tier.
*/
params [["_bag", objNull, [objNull]], ["_tal", [], [[]]]];
if (isNull _bag) exitWith {};

// --- authorize the claimer (mirrors APS_fnc_setJail's gate: MaxSec duty roster OR a bounty hunter) ---
// AP_isBountyHunter is CLIENT-set (fn_buyLicense), and so is the civ_licenses column (updatePartial mode 2):
// there is no server truth for the BH license yet, so a fake BH can at most claim a REAL fugitive bag.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (isNull _caller) exitWith {};
if !((_caller call APS_fnc_isDutyCop) || {_caller getVariable ["AP_isBountyHunter", false]}) exitWith {
    ["-SEC-", _caller, format ["BLOCKED bodybag claim by %1 (not cop/BH)", getPlayerUID _caller]] call APS_fnc_logIt;};
// anti-remote (must physically be at the bag)
if ((_caller distance _bag) > 6) exitWith {};
// srvmisc-0-1: the bag's identity comes from the SERVER registry fn_playerDisconnected filled when it dropped the
// bag, never from object vars (any client could write AP_bbUID/AP_bbBounty/AP_bbJailTime onto any object and
// jail any UID for any sentence, or have any object within 6 m deleted). Taking the entry out IS the
// single-fire: a second claim, or any object that is not a real fugitive bag, finds nothing.
private _rec = (localNamespace getVariable ["APS_bodybags", createHashMap]) deleteAt (netId _bag);
if (isNil "_rec") exitWith {};
_bag setVariable ["AP_bbClaimed", true, true];   // hides the scroll action on every client; not a gate
_rec params ["_uid", "_bname", "_bounty", "_jail"];
_bounty = round _bounty;
_jail = round _jail;
// a fugitive pardoned (APS_fnc_wantedPardon) or cleared since the drop owes nothing: no jail, no pay
// both lists are localNamespace: a client publicVariable cannot forge or clear an entry
private _wl = localNamespace getVariable "APS_wantedList";
private _wid = _wl findIf { _uid in _x };
if (_wid isEqualTo -1) exitWith { deleteVehicle _bag;
    [[format ["%1 is no longer wanted -- nothing to collect.", _bname], "basic"], "AP_fnc_handleMessage", _caller, false] spawn AP_fnc_MP; };
if (_jail < 1) then { _jail = 600; };                 // floor: wanted but no charge-time -> 10 min
private _bail  = _bounty max 2500;                    // bail = bounty (jailMe model), floored so it isn't free

// 1. PERSISTENT jail: arrested=[flag,bail,sentenceSeconds]. fn_queryRequest loads this on login ->
//    fn_initCiv re-runs AP_fnc_jailPlayer -> the fugitive spawns straight into the cell. Survives a restart.
//    MUST mres-encode (same as fn_updatePartial's _enc) -- the column stores the value WITH outer quotes
//    ("[1,26055,573]"), and the login _dec expects that; a plain [..] would fail to decode.
private _arrEnc = [[1, _bail, _jail]] call DB_fnc_mresArray;
["UPDATE players SET arrested = %s WHERE playerid = %s", 1, false, [_arrEnc, _uid]] call DB_fnc_asyncQuery;

// 2. re-jail THIS session too (if they reconnect before a restart) -- the existing combat-log mechanism.
private _rp = localNamespace getVariable "APS_restrainedPlayers";
if !(_uid in _rp) then { _rp pushBack _uid; };

// 3. clear their wanted (server list + DB) so it's resolved + can't be claimed twice.
_wl = localNamespace getVariable "APS_wantedList";   // re-read + re-find: the DB call above suspends, and the list can shift
_wid = _wl findIf { _uid in _x };
if (_wid != -1) then { _wl deleteAt _wid; };
["DELETE FROM wanted WHERE playerid = %s", 1, false, [_uid]] call DB_fnc_asyncQuery;

// 4. pay the claimer: FULL bounty + combat-log bonus (owner decision). Same payout path as a live arrest.
private _bonus  = (round (_bounty * 0.5)) max 10000;  // +50%, min $10k (tunable)
private _payout = _bounty + _bonus;
// owner 2026-09-26 SECURITY (AUDIT A6): a DUTY COP claimer's pool is priced HERE (was re-sent by their client to copSplit):
// the same tier x payout, $1M-capped math fn_bountyReceive ran, then copSplit remoteExec'd at the server (owner 2 = internal,
// see APS_fnc_wantedBounty) CHARGED to the claimer (arg 3). The bounty comes from the server bag registry, and
// the pay counts against the claimer's rolling budget. bountyReceive below still fires for prestige/UI (and a BH's own cash).
if (_caller call APS_fnc_isDutyCop) then {
    private _m = switch (true) do {case (107 in _tal): {1}; case (106 in _tal): {0.85}; case (105 in _tal): {0.75}; default {0.6};};
    [[_caller, round ((_payout * _m) min 1000000), _caller], "APS_fnc_copSplit", 2] spawn AP_fnc_MP;};
[[_payout, _payout, _caller, _bounty], "AP_fnc_bountyReceive", _caller, false] spawn AP_fnc_MP;
[[format ["You sent fugitive %1 to jail -- they'll be behind bars on their next login.", _bname], "basic"], "AP_fnc_handleMessage", _caller, false] spawn AP_fnc_MP;

["-COMBATLOG-CLAIM-", getPlayerUID _caller, format ["%1 (%2) claimed fugitive %3 [%4]: jailed %5s, paid $%6 (bounty $%7 + bonus $%8)", name _caller, getPlayerUID _caller, _bname, _uid, _jail, _payout, _bounty, _bonus]] call APS_fnc_logIt;

// 5. remove the bodybag
deleteVehicle _bag;
