/*
    APS_fnc_registerForeskin  (LooneyBin, owner 2026-06-24)
    client args : [_victimUID]   (a player CIRCUMCISED a cop -> register that cop in the named-foreskin registry)

    Named foreskins are dynamic virtual items foreskin_<uid> rendered as "<name>'s Foreskin" (fn_virtItemCfg merges
    AP_foreskinReg). This server fn is the SOLE writer of that registry. ANTI-SPOOF: the client passes only the UID;
    the displayed NAME is resolved from the DB (players.name), never from the client -- so no one can forge an
    arbitrary/offensive name. The worst a forged UID achieves is registering a REAL player's foreskin classname; the
    item GRANT itself is client-side like every virtual item (pre-existing trust model + CLANKR cover that). Idempotent:
    skip if already in AP_foreskinReg + INSERT IGNORE. Broadcasts so every client can render the name (e.g. a trade).
*/
params [["_uid", "", [""]]];

// sanitize + validate: strip quotes/backticks, require a plausible numeric steamid (5-20 digits)
_uid = (format ["%1", _uid]) splitString "\'""`" joinString "";
private _chars = _uid splitString "";
if !((count _chars > 4) && {count _chars < 21} && {(_chars findIf { !(_x in ["0","1","2","3","4","5","6","7","8","9"]) }) == -1}) exitWith {};

// already registered? (idempotent -- the optimistic client-side add races this; the broadcast below re-asserts truth)
// The registry is the server's localNamespace copy (audit r2items, see init.sqf): the AP_foreskinReg global is only
// the published copy, and any client can publicVariable over it.
private _reg = localNamespace getVariable ["AP_foreskinReg", []];
if ((_reg findIf { (_x select 0) isEqualTo _uid }) != -1) exitWith {};

// resolve the REAL name from the DB (authoritative; client cannot forge it)
private _nm = "Unknown";
// owner 2026-06-24 FIX: use the canonical SYNCHRONOUS multi-row form ([_,2,true]) + param-index parse, exactly like
// the gov/gangfort reloads (fn_govSystemSRV / fn_gangFortressSRV). The old [_,2] (no `true`) returned a row shape
// that failed the `isEqualType []` guard below -> the name never resolved -> every foreskin registered as "Unknown"
// (retro's came out "Unknown" even though players.name='retro').
// QUOTE(name): [_,2,true] `call compile`s the result, so a bare `name` was parsed as SQF -> multi-word names
// ("Mr player104") and most tokens mangled to `any`/undefined -> "Unknown" (only a lucky single-token name like
// "retro" survived). QUOTE makes it a proper string literal so the REAL player name resolves for every name.
private _rows = [format ["SELECT name FROM players WHERE playerid='%1' ORDER BY id DESC LIMIT 1", _uid], 2, true] call DB_fnc_asyncQuery;
private _nmRaw = format ["%1", (_rows param [0, []]) param [0, ""]];
if !(_nmRaw isEqualTo "") then { _nm = _nmRaw; };

// sanitize the name for the SQF array + SQL write (drop quotes/backticks; cap length)
_nm = (format ["%1", _nm]) splitString "\'""`" joinString "";
if (count (_nm splitString "") > 32) then { _nm = _nm select [0, 32]; };
if (_nm isEqualTo "") then { _nm = "Unknown"; };

// persist (idempotent) + register + broadcast
[format ["INSERT INTO foreskins (uid,name) VALUES ('%1','%2') ON CONFLICT DO NOTHING", _uid, _nm]] call DB_fnc_asyncQuery;
_reg pushBack [_uid, _nm];
localNamespace setVariable ["AP_foreskinReg", _reg];
AP_foreskinReg = +_reg;
publicVariable "AP_foreskinReg";
["-EXECUTE-", objNull, "SERVER", format ["foreskin registered: %1's Foreskin (uid %2)", _nm, _uid]] call APS_fnc_logIt;
