/*
    APS_fnc_evidenceAppend  (LooneyBin -- implemented from stub 2026-06-09)
    Cop seizures feed the evidence-lockup pool. Client callers:
      core/cop/fn_seizePlayerIllegalAction.sqf : [_seizedVirt, 2] (virtual [[item,count],..]) or [_seizedWeps, 1]
      core/cop/fn_vehBaseSeize.sqf             : same shape
    Pool = SRV_evidencePool (virtual items, merged counts) + SRV_evidenceWeps (physical classes).
    Any seizure arms the lockup event (SRV_evidence_status[0] = hasEvidence -> civs can rob it).
    The pool is paid out by APS_fnc_evidenceTruck on a successful vault breach.
*/
params [["_items", [], [[]]], ["_type", 2, [0]]];
// owner 2026-06-25: the 2026-06-23 "cop-only (side==west)" gate was a FALSE POSITIVE. EVERY legit seizure reaches
// here from the SEIZED player's OWN client -- fn_seizePlayerIllegalAction runs on the jailed civ via fn_jailMe, and
// the cop seize path (fn_seizePlayerIllegal) remoteExecs that action TO the suspect (`_unit`). So west-only blocked
// ALL seizures -> the evidence lockup was NEVER stocked, AND a -SEC- fired on everyone who got arrested (it tripped
// 5x on one civ who was just being repeatedly jailed -- read as an "exploit", it was the jail-seize). A civ caller
// is not a payee here (they only feed the CONTESTED breach pool, which they must still WIN a vault breach to loot),
// so the side check guarded little. Drop it; keep anti-INJECTION by BOUNDING the payload (a real seize is one
// player's finite inventory) -- an oversized payload or huge per-item count IS abuse and still -SEC-s.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_src isNotEqualTo 0 && {isNull _caller}) exitWith {};   // spoofed / vanished caller
if (_src isNotEqualTo 0 && {count _items > 64}) exitWith { ["-SEC-", _caller, format ["oversized evidenceAppend (%1 entries) by %2", count _items, getPlayerUID _caller]] call APS_fnc_logIt; };
if (_items isEqualTo []) exitWith {};
if (isNil "SRV_evidencePool") then { SRV_evidencePool = []; };
if (isNil "SRV_evidenceWeps") then { SRV_evidenceWeps = []; };

if (_type isEqualTo 2) then {{_x params [["_item", "", [""]], ["_count", 0, [0]]];
        _count = _count min 5000;   // owner 2026-06-25: cap per-item so a client can't inject a huge count into the breach pool
        if (_item isNotEqualTo "" && {_count > 0}) then {private _i = SRV_evidencePool findIf { (_x select 0) isEqualTo _item };
            if (_i isEqualTo -1) then { SRV_evidencePool pushBack [_item, _count]; }
            else { (SRV_evidencePool select _i) set [1, ((SRV_evidencePool select _i) select 1) + _count]; };};} forEach _items;} else {
    { if (_x isEqualType "" && {_x isNotEqualTo ""}) then { SRV_evidenceWeps pushBack _x; }; } forEach _items;};
if (isNil "SRV_evidence_status") then { SRV_evidence_status = [false, true, 0, -1800, 2]; };
SRV_evidence_status set [0, true];   // evidence on site -> the lockup is now worth robbing
publicVariable "SRV_evidence_status";
diag_log format ["[LooneyBin][evidence] appended type %1: %2 (pool %3 virt / %4 weps)", _type, _items, count SRV_evidencePool, count SRV_evidenceWeps];
["-EVIDENCE-", objNull, format ["seizure appended type %1: %2", _type, _items]] call APS_fnc_logIt;
