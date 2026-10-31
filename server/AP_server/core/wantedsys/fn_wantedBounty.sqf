 
private["_civ","_cop","_id","_half","_share","_friends","_amount"]; 
_civ = [_this,0,Objnull,[Objnull]] call BIS_fnc_param;
_cop = [_this,1,Objnull,[Objnull]] call BIS_fnc_param;
_half = [_this,2,false,[false]] call BIS_fnc_param;
_share = [_this,3,false,[false]] call BIS_fnc_param;
private _tal = [_this,4,[],[[]]] call BIS_fnc_param;   // the arrester's AP_side_talents -- ONLY picks the cop pay tier (_copPay)
// owner 2026-06-23 SECURITY (security.md §2.2): caller = fn_arrestAction (the ARRESTER -- a cop OR a tasked
// bounty-hunter civ -- collecting the bounty on _civ). Ungated, anyone could remoteExec [victim, self] to pay
// themselves a bounty with no arrest. Require the paid arrester (_cop) to BE the real caller (remoteExecutedOwner,
// non-spoofable) so you can only ever pay YOURSELF; server-internal passes.
// NEEDS OWNER REVIEW: this proves WHO is paid but not that a legitimate arrest happened (no server-side restrained/
// distance/task check) -- a scripter can still self-pay for any wanted player. To fully close, validate server-side
// that _civ is restrained by _cop (or is _cop's active bounty task) before paying.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_src isNotEqualTo 0 && {!(_cop isEqualTo _caller)}) exitWith { ["-SEC-", _caller, format ["BLOCKED wantedBounty by %1 (cop arg %2)", getPlayerUID _caller, getPlayerUID _cop]] call APS_fnc_logIt; };
if(isNull _civ OR isNull _cop) exitWith {};
// The gate above proves who is PAID, not that anyone was arrested: [self, self] paid the caller his own
// self-reported bounty (TONa-0-7). fn_arrestAction only fires for a duty cop or a bounty hunter (the same gate
// APS_fnc_handleJail applies right after), on ANOTHER restrained player it is standing over (arrest area 100 m
// at most). Self is checked by UID, not object: `vehicle player` or the caller's old corpse is a different
// object that can still resolve to the caller's own wanted entry.
if (_src isNotEqualTo 0 && {(!(_caller call APS_fnc_isDutyCop) && {!(_caller getVariable ["AP_isBountyHunter", false])}) || {!(_civ isKindOf "CAManBase")} || {!(isPlayer _civ)} || {(getPlayerUID _civ) isEqualTo (getPlayerUID _caller)} || {!(_civ getVariable ["AP_restrained", false])} || {(_civ distance _cop) > 150}}) exitWith {
    ["-SEC-", _caller, format ["BLOCKED wantedBounty by %1 on %2 (not cop/BH, not a restrained other player, or %3 m away)", getPlayerUID _caller, getPlayerUID _civ, round (_civ distance _cop)]] call APS_fnc_logIt; };

// owner 2026-09-26 SECURITY (AUDIT A6 review): a duty cop never arrests itself or another duty cop.
if (_civ isEqualTo _cop || {_civ call APS_fnc_isDutyCop}) exitWith { ["-SEC-", _caller, format ["BLOCKED wantedBounty self/cop arrest by %1 (civ arg %2)", getPlayerUID _caller, getPlayerUID _civ]] call APS_fnc_logIt; };

// localNamespace, never a missionNamespace global: index 3 is paid below, and a client publicVariable would overwrite a global
private _wl = localNamespace getVariable "APS_wantedList";
_id = [(getPlayerUID _civ),_wl] call AP_fnc_index; 
 
if(_id != -1) then {
// owner 2026-06-24 (#517 double-jail exploit -- player089: "send to jail then hit it again" = repeat money + honor):
// SINGLE-FIRE. fn_arrestAction cleared its AP_arrest guard BEFORE this fired and handleJail is async, so a 2nd
// "Send to Jail" re-called this with the SAME _civ and PAID AGAIN. Capture the entry, then CLEAR the offender's
// wanted exactly like APS_fnc_wantedPardon (drop the cop-list entry + zero their client crimes via wantedListAdd
// 999 + wipe the DB row) BEFORE paying. -> a re-call finds _id == -1 (no second pay); the offender's AP_wantedAmt
// goes to 0 so re-clicks bail at fn_arrestAction's "not wanted" guard (no repeat honor); and the arrest finally
// clears the bounty (it used to leave them wanted after jail).
private _entry = _wl select _id;
private _ouid  = getPlayerUID _civ;
_wl deleteAt _id;
// owner 2026-06-24 (JAIL instant-release regression introduced by the #517 fix above): the #517 patch wiped the
// offender's CLIENT A_stats_crimes here (wantedListAdd 999). But the arrest path
// (fn_arrestAction -> APS_fnc_handleJail -> AP_fnc_jailMe) derives the SENTENCE LENGTH *and* jailMe's
// release-loop guard ("A_stats_crimes select 0 == 0", index 0 = the wanted $) from that SAME client array --
// and AP_fnc_wantedPerson is a stub, so there is NO server-side sentence fallback. wantedBounty and handleJail
// are spawned in PARALLEL by fn_arrestAction, so this wipe RACED jailMe's read -> _jailTime computed as 0 +
// line-128 early-out -> the prisoner was released the instant they reached the cell = "every arrest = instant
// release". So DO NOT wipe the crimes here. jailMe already wipes them on RELEASE (its own wantedListAdd 999).
// #517's money-dupe protection is preserved by the deleteAt + DB DELETE (a re-click finds _id == -1 -> no 2nd
// pay). To still block the repeat-HONOR re-click, just zero the offender's cop-facing wanted amount --
// fn_arrestAction's "not wanted" guard (line 19) reads AP_wantedAmt -- WITHOUT touching the sentence-bearing
// A_stats_crimes.
_civ setVariable ["AP_wantedAmt", 0, true];
["DELETE FROM wanted WHERE playerid = %s", 1, false, [_ouid]] call DB_fnc_asyncQuery;
// owner 2026-09-26 SECURITY (AUDIT A6): a DUTY COP's share is priced and paid HERE, no longer by the cop's client
// (fn_bountyReceive -> [player, _val] -> APS_fnc_copSplit). The bounty itself is still OFFENDER-client-authoritative
// (APS_fnc_wantedSyncList), so this only caps it: same math that client ran, talent tier (105/106/107 -> 0.75/0.85/1,
// else 0.6) x share, capped at $1M per pay. The tier comes from a talents array (client-authoritative, like every
// talent), so a forged one reaches at most the legit 107 tier. copSplit is remoteExec'd AT THE SERVER (owner 2 =
// internal, no 2s cooldown) with the ARRESTER (_cop) as arg 3, so every pay counts against the arrester's rolling budget.
private _copPay = {params ["_u", "_v", "_t"];
    if !(_u call APS_fnc_isDutyCop) exitWith {};
    private _m = switch (true) do {case (107 in _t): {1}; case (106 in _t): {0.85}; case (105 in _t): {0.75}; default {0.6};};
    [[_u, round ((_v * _m) min 1000000), _cop], "APS_fnc_copSplit", 2] spawn AP_fnc_MP;};
if(_half) then {[_cop, (_entry select 3) / 2, _tal] call _copPay; [[(_entry select 3) / 2,(_entry select 3)],"AP_fnc_bountyReceive",_cop,false] spawn AP_fnc_MP;}
else {_friends = [units group _cop, {_cop distance _x < 100 && _x != _cop}] call BIS_fnc_conditionalSelect;
_amount = _entry select 3;
private _apb = localNamespace getVariable ["APS_allpoints", []];   // server-only APB target (init.sqf); nil before the first APB
if (count _apb > 0) then {if (_apb select 1 == _ouid) then {_amount = _amount * 1.5;
localNamespace setVariable ["APS_allpoints", []];};};
_original = _amount; 
if (_share && count _friends > 0) then {_amount = round (_amount / ((count _friends) + 1)); {
[_x, _amount, _x getVariable ["AP_talents", []]] call _copPay;   // ponytail: server AP_talents holds the CIVILIAN tree on shift -> friend cop tier 0.6 (civ-arrester share only; rare); upgrade = keep the duty tree server-side
[[_amount,_amount,_cop,_original],"AP_fnc_bountyReceive",_x,false] spawn AP_fnc_MP;} forEach _friends;};
[_cop, _amount, _tal] call _copPay;
[[_amount,_amount,_cop,_original],"AP_fnc_bountyReceive",_cop,false] spawn AP_fnc_MP;};};