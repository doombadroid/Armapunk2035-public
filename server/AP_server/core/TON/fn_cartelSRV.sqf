/*
    APS_fnc_cartelSRV  (LooneyBin: REPAIRED -- was a passthrough to APS_fnc_monitorCaptures)
    Client args: [_mode, _capIndex, _value]  (mode 0 = cartel tax payout)

    THE BUG: monitorCaptures is the cartel-capture LOOP and is already `spawn`ed once at boot
    (init.sqf). The stub re-ran it on every client cartel-action -> each call spawned ANOTHER immortal
    `while{true}` loop (lag accumulator) AND double-incremented capture progress (cartels flipped faster
    than intended).

    What the call actually means: when a player processes/crafts at a cartel they DON'T own, the cartel
    takes a tax cut; `_value` is the $ value of that cut. It belongs to the gang that controls the
    cartel. So: resolve the controlling gang from the flag's (networked) AP_capData and credit its bank.
    Do NOT touch the capture loop.

    _capIndex -> flag (mirrors fn_processAction's switch; craftRecipe uses 0 = arms):
      0 arms_flag · 1 drug_flag · 2 oil_flag · 3 wongs_flag
*/
params [["_mode", 0, [0]], ["_capIndex", -1, [0]], ["_value", 0, [0]], ["_ownerGang", -1, [0, ""]]];

// owner 2026-06-21 (#433 "no notification when someone takes our cartel"): mode 1 = a rival STARTED capturing a
// cartel owned by gang _ownerGang (fn_captureCartel passes the owner id as arg4 BEFORE it overwrites the flag).
// Alert that gang's ONLINE CIVILIAN members (off-duty cops/medics excluded) so they can defend. The old client-
// only alert almost never fired AND this server path was DEAD (_value arrived as -1 -> hit the <=0 exit below).
// Throttled per-cartel (60s) so a contested back-and-forth doesn't spam. Mode 0 (tax payout) is unchanged.
if (_mode isEqualTo 1) exitWith {if (format ["%1", _ownerGang] in ["", "-1", "0"]) exitWith {};
    private _flagO = switch (_capIndex) do { case 0: { arms_flag }; case 1: { drug_flag }; case 2: { oil_flag }; case 3: { wongs_flag }; default { objNull } };
    if (isNull _flagO) exitWith {};
    if ((serverTime - (_flagO getVariable ["AP_capAlertT", -999])) < 60) exitWith {};   // per-cartel throttle
    _flagO setVariable ["AP_capAlertT", serverTime];
    private _zoneName = if (_capIndex < 0 || {_capIndex >= count _roster}) then { "a Cartel" } else { (_roster select _capIndex) select 1 };
    private _members = allPlayers select { (side _x isEqualTo civilian) && {(format ["%1", (_x getVariable ["gang_data", [0]]) param [0, -1]]) isEqualTo (format ["%1", _ownerGang])} };
    if !(_members isEqualTo []) then {[[_zoneName, "cartelcapture"], "AP_fnc_handleMessage", _members, false, false] spawn AP_fnc_MP;};
};

if (_value <= 0) exitWith {};

private _cRoster = [] call AP_fnc_cartelCfg;
private _flagObj = if (_capIndex < 0 || {_capIndex >= count _cRoster}) then { objNull }
    else { missionNamespace getVariable [(_cRoster select _capIndex) select 2, objNull] };
if (isNull _flagObj) exitWith {};

(_flagObj getVariable ["AP_capData", [0, "Neutral", 0]]) params [["_gangID", 0], ["_gangName", ""], ["_progress", 0]];
if (_progress < 1 || {str _gangID isEqualTo "0"}) exitWith {};   // only a fully-captured cartel pays its owner

private _gidx = AP_server_gangs findIf { (format ["%1", _x select 0]) isEqualTo (format ["%1", _gangID]) };   // format, not str -> type-agnostic gang-id match (see gangBank note)
if (_gidx < 0) exitWith {};
private _gang = AP_server_gangs select _gidx;
private _cap  = ((((_gang select 6) max 1) * AP_gangbank_cap) min 2500000) max 0;   // max 1: a stale/0 member-count would zero the cap and silently drop the payout (mirrors fn_gangBank guard)
// owner 2026-06-23 SECURITY (security.md §2.1 HIGH): the client-sent _value (tax cut) was UNBOUNDED -> a gang
// that holds a cartel could remoteExec [0,0,9.9e8] for ~1B/call. The _cap above (members * per-member cap,
// <=2.5M) was COMPUTED BUT NEVER APPLIED -- apply it now as the per-call credit ceiling. A legit tax cut is a
// small % of a process value, far under _cap; this bounds the exploit to one bank-cap's worth per call instead
// of a billion. (Clamp the BASE _value pre-stimmy so the intended stimmy 10x still injects cash as designed.)
_value = (round _value) max 0;
if (_value > _cap) then {
    [[998, objNull, format ["CARTEL tax clamp: gang %1 _value $%2 capped to $%3 (members %4)", _gangID, _value, _cap, _gang select 6]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;
    _value = _cap;};
// owner 2026-06-18: STIMMY CHECKS -- when ON, 10x the cartel-OWNER payout for Arms(0)/Drug(1)/Wongs(3) to inject
// cash at low pop. The player's tax cut is set CLIENT-side (fn_processAction) and is UNCHANGED -- only the gang-bank
// CREDIT here is multiplied = money conjured from nothing, by design. Oil(2) excluded (untaxed rubber). CLANKR
// reads the same server_control.stimmy flag so the resulting bank growth/withdrawals don't spam the owner.
// APS_stimmy is server-only (localNamespace); the published AP_stimmy is a display copy any client can overwrite.
private _mult = if ((localNamespace getVariable ["APS_stimmy", false]) && {_capIndex in [0, 1, 3]}) then {10} else {1};
private _credit = _value * _mult;
private _newBank = (((_gang select 5) + _credit)) max 0;   // LooneyBin: gang bank cap removed
if (_newBank > (_gang select 5)) then {_gang set [5, _newBank];
    AP_server_gangs set [_gidx, _gang];
    [str (_gang select 0), 0, 0, _newBank] spawn DB_fnc_updateGang;   // persist gangs.bank
    [[998, objNull, format ["Cartel(%1 %2) tax $%3%7 -> gang %4 bank $%5. Srv %6", _capIndex, _gangName, _credit, _gangID, _newBank, AP_server_instance, (if (_mult > 1) then { format [" [STIMMY x%1 from $%2]", _mult, _value] } else { "" })]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;
};
