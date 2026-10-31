/*
    (ASY|TON)_fnc_vehicleCreate  (LooneyBin: 2020 vehicle-buy adapter)
    2020 client args : [player, _vehicle, getPlayerUID player, _side("cop"/"civ"/"med"),
                        _skinID, _alarm, _isMaxTac, _isFirefighter, _isSRT]   (fn_vehicleShopBuy :265)
    Generates a plate, INSERTs the persistent row, and stamps the vehicle with ownership vars so
    it can be stored later: AP_dbInfo=[uid,plate] (2020 client reads this), dbInfo=[uid,plate,color,
    alarm] (2017 server readers: vehicleStore/vehicleDead/cleanup). Adds the Killed EH so a destroyed
    car deletes its row. MaxTac/Firefighter/SRT vehicles are temporary — set up, not persisted.
    NOTE: rewritten from the 2017 signature ([uid,side,veh,color,player,plate,...]); no other callers.
*/
params [["_player",objNull,[objNull]], ["_vehicle",objNull,[objNull]], ["_uid","",[""]],
    ["_side","",[""]], ["_color",0,[0]], ["_alarm",0,[0]],
    ["_isMaxTac",false,[false]], ["_isFirefighter",false,[false]], ["_isSRT",false,[false]], ["_mods",[],[[]]]];
// owner 2026-06-23 SECURITY (security.md §2.3 — cross-account write + SQLi): the client _uid flows into
// DB_fnc_insertVehicle's INSERT (pid slot) RAW. Force the actor to the NON-SPOOFABLE caller's OWN account
// (fn_vehicleShopBuy always passes getPlayerUID player -- you buy a car for yourself) and escape it, so a
// scripter can't register a bought vehicle under someone ELSE's pid or inject SQL. Server-internal keeps _uid.
// (_className passed to insertVehicle is typeOf _vehicle = the real server-side class, so it's safe.)
private _src = remoteExecutedOwner;
// One-shot token APS_fnc_rigSRV "craft" sets for the truck it is registering (audit 2026-09-26, r2rig). Its call runs
// inside the client's remote-executed frame, so _src cannot tell it from a client naming a live rig here directly.
// Consumed before any exit, so it never outlives that one call.
private _rigCraft = localNamespace getVariable ["APS_rigPersist_" + netId _vehicle, false];
localNamespace setVariable ["APS_rigPersist_" + netId _vehicle, nil];
if (_src != 0) then { _uid = getPlayerUID ((allPlayers select { owner _x isEqualTo _src }) param [0, objNull]); };
_uid = (format ["%1", _uid]) splitString "\'""" joinString "";
if (isNull _vehicle || _uid == "" || {!alive _vehicle}) exitWith {};
// A live rig is registered once, by its craft. Anyone else naming one here -- its owner (a second row = a second rig on
// the next pull) or a stranger (their rig, in the caller's garage) -- is refused.
private _rigKind = localNamespace getVariable ["APS_rigKind_" + netId _vehicle, ""];
if (_rigKind isNotEqualTo "" && {!_rigCraft}) exitWith {
    ["-SEC-", (allPlayers select { owner _x isEqualTo _src }) param [0, objNull], format ["BLOCKED vehicleCreate of a live %1 rig (only its Factory craft registers a rig)", _rigKind]] call APS_fnc_logIt;
};

// Temporary on-duty vehicles are never persisted, but still clean up on death.
if (_isMaxTac || _isFirefighter || _isSRT) exitWith {_vehicle addEventHandler ["Killed", { _this spawn APS_fnc_vehicleDead }];};

private _class = typeOf _vehicle;
// Audit 2026-09-26 (mints, review): an ND-ONLY vehicle (idx 3 holds nothing but nd_car / nd_priced) sells and chops
// back for New Drachma, the one server-owned wallet, and a client can createVehicle one itself and name it here. So a
// client call must cash a receipt APS_fnc_ndSRV "debit" filed for this uid in the last 120 s, worth at least 80% of
// the class's ND price (the vehshop discount floor, fn_getDiscount). One receipt registers one vehicle. Vehicles also
// sold for cash (Strider, Ifrit, ...) are the client-authoritative-cash boundary; their ND payouts are capped where
// they are paid (fn_srvSellVehicle, fn_chopShopSell). Server-internal calls (_src 0) are trusted as before.
private _vRow = ["getVehicleRow", "", _class] call AP_fnc_vehicleConfig;
private _keys = _vRow param [3, []];
private _receiptOk = true;
if (_src != 0 && {_keys isEqualType []} && {_keys isNotEqualTo []} && {(_keys - ["nd_car", "nd_priced"]) isEqualTo []}) then {
    private _nd = parseNumber ([_class] call AP_fnc_ndPriceCfg);
    if (_nd <= 0) then { private _bp = _vRow param [7, 0]; if (_bp isEqualType []) then { _bp = _bp param [0, 0]; };
        _nd = if (_bp isEqualType 0) then { _bp / 6000 } else { 0 }; };   // fn_vehicleShopBuy's 6000:1 fallback
    private _rc = localNamespace getVariable ["AP_ndReceipts", createHashMap];
    private _mine = (_rc getOrDefault [_uid, []]) select { serverTime - (_x select 1) < 120 };
    private _i = _mine findIf { (_x select 0) >= (_nd * 0.8) - 0.0001 };
    _receiptOk = _i > -1;
    if (_receiptOk) then { _mine deleteAt _i; };
    _rc set [_uid, _mine];
};
if (!_receiptOk) exitWith {
    ["-SEC-", (allPlayers select { owner _x isEqualTo _src }) param [0, objNull], format ["BLOCKED vehicleCreate of ND-only %1 (no server-seen ND payment for it in the last 120 s)", _class]] call APS_fnc_logIt;
};
private _type = switch (true) do {case (_class in ["C_Kart_01_Blu_F","C_Kart_01_Fuel_F","C_Kart_01_Red_F","C_Kart_01_Vrana_F"]): {"Kart"};
    case (_vehicle isKindOf "Car"): {"Car"};
    case (_vehicle isKindOf "Air"): {"Air"};
    case (_vehicle isKindOf "Ship"): {"Ship"};
    default {"Car"};};
private _sideStr = switch (toLower _side) do {case "west"; case "cop": {"cop"};
    case "independent"; case "med": {"med"};
    default {"civ"};};
// SIDE BY ROSTER, NOT BY PACKET -- same rule as DB_fnc_updatePartial/DB_fnc_updateRequest. `_side` above is
// the client's own claim (fn_vehicleShopBuy's AP_effSide-derived string); a modified on-duty client can
// mis-tag a purchase against an unused side to dodge its own faction's cap, or tag a duty-shop buy "civ" to
// keep the asset after the flip -- nothing downstream re-checks side once the row is written. Route it
// exactly like a save: only once the shift is ACKED (fn_dutySRV.sqf's grant watchdog). Unrostered/unacked
// buyers -- everyone, on a flag-false server, and every civilian -- keep the client-claimed value verbatim.
if (localNamespace getVariable ["AP_dutyEnabled", false]) then {
    private _dutyRow = _uid call APS_fnc_dutyLookup;
    private _rosterFlag = if !(_dutyRow param [3, false]) then { "" } else {
        switch (_dutyRow param [0, ""]) do {
            case "maxsec": {"cop"};
            case "trauma": {"med"};
            default {""};
        };
    };
    if (_rosterFlag isNotEqualTo "") then {
        if (_rosterFlag isNotEqualTo _sideStr) then {
            // Standing rule: log subject from remoteExecutedOwner, never the payload. `_src` is already
            // resolved above for the uid re-derivation; reuse it rather than trust `_player`.
            private _mmUnit = if (_src isEqualTo 0) then { objNull } else {
                (allPlayers select { owner _x isEqualTo _src }) param [0, objNull]
            };
            ["-DUTY-", _mmUnit, format ["ROUTE MISMATCH vehicleCreate uid=%1 claimed=%2 rostered=%3 -- saved as %3", _uid, _sideStr, _rosterFlag]] call APS_fnc_logIt;
        };
        _sideStr = _rosterFlag;
    };
};
private _alarmBool = (_alarm > 0);
// buy-time mods (client-supplied, ui branch): numeric-coerce EVERY slot (kills SQLi via str _mods),
// pad legacy callers to the 9-slot shape, keep slot 0 in sync with the alarm flag.
_mods = _mods apply { round parseNumber format ["%1", _x] };
if (count _mods < 9) then { _mods = [[0, 1] select _alarmBool, 0, 0, 0, 0, 0, 0, 0, 0]; };
while {count _mods < 10} do { _mods pushBack 0; };
_mods resize 10;   // slot 9 = autopilot module (was resize 9 -- silently amputated shop-bought autopilot)
if (_alarmBool || ((_mods param [0, 0]) > 0)) then { _mods set [0, 1]; _alarmBool = true; };
if (_color < 0) then { _color = 0; };               // -1 = no skin; insertVehicle rejects -1
private _plate = floor (random 999000) + 1000;      // 4-6 digit plate (per-pid identity/key)

// insertVehicle: [uid, side, type, classname, color, plate, fuel, damage, alarm, mods]
// rig identity (_rigKind, above) comes off the server-local copy APS_fnc_rigAdopt keeps in localNamespace, never a
// packet field, and not the public AP_rigKind a client can setVariable onto any flatbed it registers here (nor any
// object var: a client overwrites an unpublished one too -- audit 2026-09-26, mints2)
[_uid, _sideStr, _type, _class, _color, _plate, 1, 0, _alarmBool, _mods, _rigKind] call DB_fnc_insertVehicle;

_vehicle setVariable ["AP_dbInfo", [_uid, _plate], true];               // 2020 client (store lookup)
_vehicle setVariable ["dbInfo", [_uid, _plate, _color, _alarmBool], true]; // 2017 readers (idle cleanup garages via this)
_vehicle addEventHandler ["Killed", { _this spawn APS_fnc_vehicleDead }];
