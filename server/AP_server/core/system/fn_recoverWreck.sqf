// LooneyBin owner 2026-07-04: Wreckage Recovery Kit -- return a WRECK to its OWNER's garage (active=0), then
// remove the wreck. Server-authoritative: the owner UID + plate come from the wreck's AP_dbInfo (set by the
// garage-pull path), never from the caller. DELETE-then-INSERT on (pid, plate) so exactly ONE garage row
// exists whether the wreck's row was already deleted (uninsured -> fn_vehicleDead removed it) or still sits
// active=1 (insured), and a double-recover race collapses to a single row.
params [["_wreck", objNull, [objNull]]];
// owner 2026-07-05: DB-visible entry trace (the RPT is block-buffered / unreadable live). Records whether the
// server was even reached + the exact state it gates on (null / alive / dbInfo), so we can pin where recovery
// dies without an in-game repro. Reads on objNull are safe (return the default).
["-WRECKKIT-SRV", objNull, format ["recv: class=%1 isNull=%2 alive=%3 dbInfoP=%4 dbInfoL=%5", (if (isNull _wreck) then {"none"} else {typeOf _wreck}), isNull _wreck, (!isNull _wreck && {alive _wreck}), (_wreck getVariable ["AP_dbInfo", []]), (_wreck getVariable ["dbInfo", []])]] spawn APS_fnc_logIt;
if (isNull _wreck) exitWith {};
if (alive _wreck) exitWith {};   // only actual wrecks

private _dbInfo = _wreck getVariable ["AP_dbInfo", []];
if (count _dbInfo == 0) then { _dbInfo = _wreck getVariable ["dbInfo", []]; };
if (count _dbInfo < 2) exitWith {
    diag_log format ["[LooneyBin][recoverWreck] wreck %1 has no dbInfo -> can't map it to a garage; clearing it anyway", typeOf _wreck];
    ["-WRECKKIT-SRV", objNull, format ["EXIT no-dbInfo (count<2) on %1 -- wreck cleared, NO db write", typeOf _wreck]] spawn APS_fnc_logIt;
    { deleteVehicle _x } forEach (attachedObjects _wreck);
    deleteVehicle _wreck;};

private _uid   = format ["%1", _dbInfo select 0];
private _plate = format ["%1", _dbInfo select 1];
// SECURITY (owner 2026-07-04): AP_dbInfo is written CLIENT-side with public=true at garage-pull, so a script
// executor can broadcast an arbitrary [uid,plate] onto any wreck. These go into raw SQL below, so validate that
// both are plain DIGIT strings (Steam64 UIDs, gang UIDs, and plates are all integers) -> a spoofed value with a
// quote/paren/space can never break out of the quoted literal (no SQLi / no table-wipe). Mirror of the
// fn_loginBonusSRV hardening. _class comes from typeOf (the real object, not spoofable), so it needs no scrub.
private _isNum = { params ["_s"]; (count _s > 0) && {(toArray _s) findIf { !(_x >= 48 && {_x <= 57}) } < 0} };
if !((_uid call _isNum) && {_plate call _isNum}) exitWith {
    diag_log format ["[LooneyBin][recoverWreck] REJECTED non-numeric dbInfo (uid=%1 plate=%2) on %3 -- possible spoof; wreck cleared, NO db write", _uid, _plate, typeOf _wreck];
    ["-WRECKKIT-SRV", objNull, format ["EXIT non-numeric dbInfo uid=%1 plate=%2 on %3 -- wreck cleared, NO db write", _uid, _plate, typeOf _wreck]] spawn APS_fnc_logIt;
    { deleteVehicle _x } forEach (attachedObjects _wreck);
    deleteVehicle _wreck;};
// owner 2026-07-24 SECURITY (audit): the 2026-07-04 hardening above scrubs uid/plate against SQL injection
// but NOT against authorisation -- AP_dbInfo is written client-side with public=true, so a script executor
// can stamp its OWN uid onto somebody else's wreck and have it recovered into its own garage. There is also
// no caller check at all, so it can be fired from anywhere.
// A client caller must be near the wreck. The kit is used by walking up to it; the kit-possession check itself
// stays client-side (server cannot see virtual inventory here). Ownership: see the audit 2026-09-26 block below.
private _srcRW = remoteExecutedOwner;   // 0 == server-internal = trusted
if (_srcRW isNotEqualTo 0) then {private _rwCaller = (allPlayers select { owner _x isEqualTo _srcRW }) param [0, objNull];
    if (isNull _rwCaller || {(_rwCaller distance _wreck) > 30}) then {
        ["-WRECKKIT-SRV", _rwCaller, format ["BLOCKED recoverWreck (range %1) on %2",
            if (isNull _rwCaller) then {-1} else {round (_rwCaller distance _wreck)}, typeOf _wreck]] spawn APS_fnc_logIt;
        _uid = "";   // signal; the guard below exits before any DB write
    };};
if (_uid isEqualTo "") exitWith {};
private _class = typeOf _wreck;
private _isGang = (count _uid) < 15;   // gang_id (short) vs Steam64 (17) -- see the 2026-07-08 note below
// Audit 2026-09-26 (mints2): this used to INSERT a row for whatever [uid, plate] the wreck was stamped with, as class
// typeOf -- and AP_dbInfo is client-stampable, so a client-spawned Nyx with a fresh plate became a real garage row
// that sold back for New Drachma, as often as it liked (the old DB-owner lookup here only covered plates that still
// had a row). Now the wreck must be a vehicle the stamped owner really had, of THIS class:
//   * its row still exists (insured, restore-rescued, or a gang vehicle -- nothing deletes those on death), or
//   * APS_fnc_vehicleDead deleted that row when it died and filed it in the wreck ledger. A ledger entry is spent
//     by the recovery (atomically, inside isNil), so one death gives back one row.
// Stamping somebody else's uid can only return THEIR vehicle to THEIR garage, which is what the kit is for.
private _row = if (_isGang) then {
    ["SELECT classname FROM gang_vehicles WHERE gang_id = %s::integer AND plate = %s::integer", 2, false, [_uid, _plate]] call DB_fnc_asyncQuery
} else {
    ["SELECT classname FROM vehicles WHERE pid = %s AND plate = %s::integer", 2, false, [_uid, _plate]] call DB_fnc_asyncQuery
};
private _owned = false;
if (_row isEqualType [] && {_row isNotEqualTo []}) then {
    _owned = (toLower format ["%1", _row select 0]) isEqualTo (toLower _class);
} else {
    private _wl = localNamespace getVariable ["AP_wreckLedger", createHashMap];
    private _key = _uid + "|" + _plate;
    isNil { if ((_wl getOrDefault [_key, ""]) isEqualTo (toLower _class)) then { _wl deleteAt _key; _owned = true; }; };
};
if (!_owned) exitWith {
    private _who = (allPlayers select { owner _x isEqualTo _srcRW }) param [0, objNull];
    ["-SEC-", _who, format ["recoverWreck REFUSED: %1 stamped [%2, %3] has no %4 on file (no matching row, no death ledger entry)", _class, _uid, _plate, if (_isGang) then {"gang row"} else {"row"}]] call APS_fnc_logIt;
    if (!isNull _who) then { [["This wreck has no registration on file -- it can't be recovered.", "basic"], "AP_fnc_handleMessage", _who, false] spawn AP_fnc_MP; };
};
private _type  = switch (true) do {case (_class isKindOf "Air"):  { "Air" };
    case (_class isKindOf "Ship"): { "Ship" };
    default { "Car" };};

// owner 2026-07-08 (Pawnee/Blackfish never returned to garage): recreate the row -- the wreck's DB row was DELETED
// on death (no insurance on this server, so fn_vehicleDead:41 always removes it). TWO fixes vs the old code, which
// copy-pasted the civ-only login-bonus INSERT and baked in two false assumptions:
//   (1) SIDE was hardcoded 'civ'. A cop/med-owned vehicle written 'civ' is invisible to that player's garage tab
//       forever (fn_getVehicles filters side=cop/civ/med by playerSide). Use the REAL side from AP_side, which
//       fn_prepareVehicle (pull) and fn_restoreVehicles (restart) both stamp on the vehicle (values cop/civ/med)
//       and which survives on the wreck object. -> fixes cop/TT Blackfish.
//   (2) GANG vehicles were written to the personal `vehicles` table (pid=gang_id) -> matched neither garage ->
//       orphaned. Route them to gang_vehicles. Gang vs personal is told SERVER-side by id LENGTH (a gang_id is a
//       short int; a Steam64 owner uid is 17 digits) -- non-spoofable, and correct for pulled AND restored vehicles.
//       -> fixes gang-pooled Pawnee. (_isGang is computed above, before the ownership check.)

if (_isGang) then {
    // GANG -> gang_vehicles (keyed by gang_id; no side/alive/listed columns). Mirrors fn_gangGarageStore.sqf:86.
    [format ["DELETE FROM gang_vehicles WHERE gang_id='%1' AND plate='%2'", _uid, _plate]] call DB_fnc_asyncQuery;
    [format ["INSERT INTO gang_vehicles (pid, classname, type, gang_id, inventory, active, plate, color, fuel, damage) VALUES ('%1','%2','%3','%1','[]','0','%4','0','100','0')", _uid, _class, _type, _plate]] call DB_fnc_asyncQuery;
    diag_log format ["[LooneyBin][recoverWreck] %1 (plate %2) recovered to GANG garage %3", _class, _plate, _uid];
    ["-WRECKKIT-SRV", objNull, format ["WROTE gang_vehicles row: class=%1 type=%2 gang=%3 plate=%4 (active=0)", _class, _type, _uid, _plate]] spawn APS_fnc_logIt;
} else {
    // PERSONAL -> vehicles (keyed by pid) with the CORRECT stored side. active=0 -> garage; alive=1; repaired; empty.
    private _side = _wreck getVariable ["AP_side", "civ"];
    if !(_side in ["cop", "civ", "med"]) then { _side = "civ"; };   // allowlist -- AP_side is client-broadcast
    [format ["DELETE FROM %1 WHERE pid='%2' AND plate='%3'", "vehicles", _uid, _plate]] call DB_fnc_asyncQuery;
    [format ["INSERT INTO %1 (side, classname, type, pid, alive, active, inventory, color, plate, fuel, damage, alarm) VALUES ('%2', '%3', '%4', '%5', '1', '0', '[]', '0', '%6', '100', '0', '0')", "vehicles", _side, _class, _type, _uid, _plate]] call DB_fnc_asyncQuery;
    diag_log format ["[LooneyBin][recoverWreck] %1 (plate %2) recovered to garage of %3 (side %4)", _class, _plate, _uid, _side];
    ["-WRECKKIT-SRV", objNull, format ["WROTE garage row: class=%1 type=%2 side=%3 uid=%4 plate=%5 (active=0, alive=1)", _class, _type, _side, _uid, _plate]] spawn APS_fnc_logIt;
};
// The row is back, so no death is outstanding for it. A pulled car has no Killed EH -- fn_cleanup runs vehicleDead on
// its first sight of the wreck -- so that can land between the SELECT above and the INSERT, and would otherwise leave
// an entry that brings the row back a second time after it is sold.
(localNamespace getVariable ["AP_wreckLedger", createHashMap]) deleteAt (_uid + "|" + _plate);

{ deleteVehicle _x } forEach (attachedObjects _wreck);
deleteVehicle _wreck;
