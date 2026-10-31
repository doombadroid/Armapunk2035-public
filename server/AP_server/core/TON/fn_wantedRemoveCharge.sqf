/*
    APS_fnc_wantedRemoveCharge  (LooneyBin -- implemented from stub 2026-06-09)
    Client (core/pmenu/fn_dropCharge.sqf, cop wanted menu "drop charge") sends:
        [_unitUID, _name, _chargeID, _amount]
    Removes _amount occurrences of charge _chargeID from the target's wanted entry, subtracts the
    charge's bounty value + jail time, persists (insertWanted = ON DUPLICATE KEY UPDATE), and fully
    clears the entry (memory + DB + bounty-hunter lists) when no charges remain.
    APS_wantedList (localNamespace) entry shape (wanted_add.sqf): [name, uid, crimes[](chargeIDs, repeats), bounty, jailTime]
*/
params [["_uid", "", [""]], ["_name", "", [""]], ["_chargeID", -1, [0]], ["_amount", 0, [0]]];
// owner 2026-06-23 SECURITY (security.md §2.2/§2.3): cop-only. Caller = fn_dropCharge (cop wanted menu).
// Ungated, any civ could remoteExec [anyUID,name,chargeID,amount] to drop anyone's charges. Derive the real
// caller (remoteExecutedOwner, non-spoofable) and require side==west; server-internal passes. _uid/_name are
// later interpolated into SQL via DB_fnc_insertWanted/deleteWanted -- strip quotes here (those helpers'
// KRON_Replace is undefined on the dedi server, see §2.3) so a crafted name/uid can't inject.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _callerUID = getPlayerUID _caller;
if (_src isNotEqualTo 0 && {!(_caller call APS_fnc_isDutyCop)}) exitWith { ["-SEC-", _caller, format ["BLOCKED wantedRemoveCharge by %1 on %2", _callerUID, _uid]] call APS_fnc_logIt; };
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
_uid = _uid call _san;  _name = _name call _san;
if (_uid isEqualTo "" || {_chargeID < 0} || {_amount <= 0}) exitWith {};

private _wl = localNamespace getVariable "APS_wantedList";
private _index = [_uid, _wl] call AP_fnc_index;
if (_index isEqualTo -1) exitWith {
    diag_log format ["[LooneyBin][wantedRemoveCharge] %1 not on the wanted list (charge %2)", _uid, _chargeID];};

private _data    = _wl select _index;
private _crimes  = +(_data select 2);
private _bounty  = _data select 3;
private _jail    = _data param [4, 0];

// strip up to _amount occurrences of the charge
private _removed = 0;
while {_removed < _amount && {_chargeID in _crimes}} do {_crimes deleteAt (_crimes find _chargeID);
    _removed = _removed + 1;};
if (_removed isEqualTo 0) exitWith {diag_log format ["[LooneyBin][wantedRemoveCharge] %1 has no charge %2 to remove", _uid, _chargeID];};

// charge value / jail time from the mission config (compiled on the server too)
private _value   = ["getChargeValue", _chargeID] call AP_fnc_wantedChargesConfig;
// by id: getChargeTimes is a packed list, so indexing it by id read the NEXT charge's time (and further off after the 49/69-71 gaps)
private _timePer = (["getRow", _chargeID] call AP_fnc_wantedChargesConfig) param [3, 0];
_bounty = (_bounty - (_value * _removed)) max 0;
_jail   = (_jail - (_timePer * _removed)) max 0;

if (_crimes isEqualTo []) then {
    // last charge dropped -> full removal (mirrors wanted_remove.sqf)
    _wl deleteAt _index;
    [_uid] spawn DB_fnc_deleteWanted;
    [[_uid], "AP_fnc_removeBounty", -2, false] spawn AP_fnc_MP;   // -2 = clients only (target `true` ran it on the SERVER too -> undefined AP_bounty_list RPT errors)
    // if they're online, clear their local wanted flag like wanted_remove does
    private _unit = allPlayers param [allPlayers findIf { (getPlayerUID _x) isEqualTo _uid }, objNull];
    if (!isNull _unit) then {AP_wanted = 0;
        (_unit getVariable ["ownerID", owner _unit]) publicVariableClient "AP_wanted";};} else {
    private _newData = [_data select 0, _uid, _crimes, _bounty, _jail];
    _wl set [_index, _newData];
    [_data select 0, _uid, _crimes, _bounty, _jail] spawn DB_fnc_insertWanted;   // ON DUPLICATE KEY UPDATE = persist the reduction
};
diag_log format ["[LooneyBin][wantedRemoveCharge] removed %1x charge %2 from %3 -> bounty %4, jail %5, %6 charge(s) left", _removed, _chargeID, _uid, _bounty, _jail, count _crimes];
