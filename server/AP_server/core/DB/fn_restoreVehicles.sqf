// extDB3 (LooneyBin): restore persisted vehicles from vehicle_mem on boot
_pageNo = 0;

// owner 2026-06-21 (#457/#453): GARAGE-RETURN failed/missed restores. A PERSONAL vehicle that was OUT
// (active='1') but whose vehicle_mem snapshot is missing/stale (pulled <480s before an ungraceful restart, or
// its row chopped/sold) has NO recovery path -- the world object is gone but the row stays active='1', which
// the garage query (fn_getVehicles active='0') HIDES, so the vehicle vanishes from BOTH world and garage (47
// rows were stuck live; bit player103's Orca + black lace trucks). Gang vehicles already get this reset (init.sqf:152);
// personal vehicles never did. Reset every active='1' -> '0' HERE, BLOCKING (mode 2) so it COMMITS before the
// loop below re-flips genuinely-restored plates back to '1' (line 135) -- extDB3's multi-thread mode-1 writes
// can reorder on the same row, so a blocking reset is required to avoid marking a just-restored vehicle garaged.
// Net: a restore miss falls back to the owner's garage (re-pullable) instead of being lost forever.
["UPDATE vehicles SET active = false WHERE active = true", 2] call DB_fnc_asyncQuery;

while {true} do {_mem = [];
    // owner 2026-06-13: SELECT explicit columns, NOT `*`. vehicle_mem has an auto-increment `id` PK that
    // `SELECT *` returns FIRST -> every `_x select N` below was off by one (plate read the id, class read
    // damage, etc.) -> the class name landed where a position compile happens -> "Undefined variable
    // c_hatchback_01_sport_f" and the restore aborted. These 10 cols match the body's indices 0..9 exactly.
    // QUOTE(class): the classname (e.g. C_Offroad_01_covered_F) is a plain bareword -> extDB3 returns it
    // UNQUOTED -> asyncQuery's `call compile` of the whole result hit it as an undefined variable and the
    // ENTIRE result failed to parse (no rows -> nothing restored). QUOTE makes it a string. (worldspace/
    // inventory/owners/dbInfo are mresArray-escaped, so extDB3 already returns them quoted.)
    _query = format["SELECT plate, worldspace, dir, inventory, info_owners, dbInfo, fuel, damage, class, insured FROM vehicle_mem ORDER BY plate LIMIT 20 OFFSET %1",(_pageNo * 20)];
    _mem = [_query,2,true] call DB_fnc_asyncQuery;
    _pageNo = _pageNo + 1;
 {_vInfo = [];
        // owner 2026-06-13: format-coerce before parseNumber. `SELECT *` on vehicle_mem has NO QUOTE(), so
        // extDB3 auto-types numeric columns (plate/dir/fuel/damage) to NUMBER -> raw `parseNumber(<Number>)`
        // THREW "Type Number, expected Bool,String" at line 13 and ABORTED the whole restore loop -> no
        // vehicles respawned at their saved positions. (Latent until saveVehicles started filling vehicle_mem.)
        _plate = parseNumber format ["%1", _x select 0];
        _class = _x select 8;
        _pos = [(_x select 1)] call DB_fnc_mresToArray;
        _pos = parseSimpleArray (format["%1", _pos]);
        _dir = parseNumber format ["%1", _x select 2];
        _inventory = [(_x select 3)] call DB_fnc_mresToArray;
        _inventory = parseSimpleArray (format["%1", _inventory]);
        _owners = [(_x select 4)] call DB_fnc_mresToArray;
        _owners = parseSimpleArray (format["%1", _owners]);
        _dbInfo = [(_x select 5)] call DB_fnc_mresToArray;
        _dbInfo = parseSimpleArray (format["%1", _dbInfo]);
        if (!isNil "_dbInfo") then {_fuel = (parseNumber format ["%1", _x select 6]) / 100;
            _damage = (parseNumber format ["%1", _x select 7]) / 100;
            _insured = [(parseNumber format["%1",(_x select 9)]),1] call DB_fnc_bool;

            // owner 2026-06-13: explicit SELECT, NOT `*`. Two problems with `*`: (a) side/classname are
            // barewords -> extDB3 unquoted -> `call compile` "Undefined variable: civ" -> whole row failed;
            // (b) the live `vehicles` table grew columns (listed, inventory) so `*` shifted plate/color/alarm
            // away from the indices the body reads (7/8/12). This rebuilds the result so select 1=side,
            // 2=classname, 7=plate, 8=color, 12=alarm land exactly where the code expects, QUOTE'd as needed.
            // owner 2026-06-14 (#186): also pull `mods` (slot 13) so the storage-upgrade cap survives a soft
            // restart. QUOTE(COALESCE(mods,'[]')) matches fn_getVehicles' format (TEXT, 9-slot SQF literal).
            _query = format["SELECT id, side, classname, 0 AS c3, 0 AS c4, 0 AS c5, 0 AS c6, plate, color, 0 AS c9, 0 AS c10, 0 AS c11, alarm, COALESCE(mods,'[]') AS mods, COALESCE(rig_kind,'') AS rig_kind FROM %2 WHERE plate='%1'",_plate,"vehicles"];
            _vInfo = [_query,2] call DB_fnc_asyncQuery;
            if !(_vInfo isEqualTo []) then {_plate = (parseNumber (format["%1", _vInfo select 7]));
                _alarm = (parseNumber (format["%1", _vInfo select 12]));
                if (_class == "") then { _class = _vInfo select 2; };
                _vehicle = _class createVehicle (_pos);
                _vehicle setPos _pos;
                // owner 2026-06-19: restored vehicles -- especially HELIS -- spawned belly-up / on their side and
                // rolled down hills. The restore set position + HEADING (setDir) but NEVER the UP vector, so a heli
                // re-created on a slope clipped the terrain and physics tipped it; after the 20s damage shield it
                // then crashed -> Killed EH -> APS_fnc_vehicleDead DELETED it from the DB (owner lost 2 Orcas).
                // Force a FLAT, UPRIGHT orientation (heading preserved). For AIR add a little ground clearance +
                // zero velocity so it settles gently instead of spawning embedded in the surface.
                _vehicle setVectorDirAndUp [[sin _dir, cos _dir, 0], [0, 0, 1]];
                // owner 2026-06-24 (#502 "truck restored EXPLODED, lost a cargo van of diamonds at the proc plant"):
                // GROUND vehicles got NO collision-settle -- only AIR did. A car/truck restored at its EXACT saved
                // position at a busy spot (processing plant, pump, gather node) can spawn EMBEDDED in static map
                // clutter/terrain. The 20s shield hides this, but the instant `allowDamage true` flips on (line ~92)
                // physics resolves the overlap as a huge collision -> the vehicle EXPLODES the moment the shield
                // lifts, and its trunk cargo dies with it (fn_vehicleDead then garages the DB row, but the diamonds
                // in AP_vinv are gone). Give ground vehicles the SAME gentle-settle as air: tiny vertical clearance
                // so they drop onto the surface instead of spawning inside it, + zeroed velocity. (kindOf "Air"
                // covers helis/planes; everything else -- Car/Tank/Ship -- now also gets nudged. Ships get +0.2 only.)
                if (_vehicle isKindOf "Air") then {private _gp = getPosATL _vehicle;
                    _vehicle setPosATL [_gp select 0, _gp select 1, (_gp select 2) + 0.5];
                    _vehicle setVelocity [0, 0, 0];} else {private _gp = getPosATL _vehicle;
                    private _clr = if (_vehicle isKindOf "Ship") then { 0.2 } else { 0.35 };
                    _vehicle setPosATL [_gp select 0, _gp select 1, (_gp select 2) + _clr];
                    _vehicle setVelocity [0, 0, 0];};
                // owner 2026-06-14: shield restored vehicles from SPAWN-COLLISION destruction. Two cars parked
                // close together get re-created at their EXACT saved positions and can overlap on spawn ->
                // physics damage -> Killed EH -> APS_fnc_vehicleDead DELETES them from the DB (owner loses the
                // car -- this ate a Tempest device + a box truck). Block damage for 20s so they settle, then
                // restore the real (saved) damage + normal damage handling.
                // owner 2026-06-24 (#502): at shield-lift, ZERO velocity + re-assert the saved damage BEFORE
                // re-enabling damage. Without this, any residual overlap/momentum built up under the shield
                // discharged as a lethal collision the instant `allowDamage true` ran -> instant explosion. Order
                // matters: setVelocity [0,0,0] kills momentum, setDamage _dmg while STILL shielded restores the
                // real (low) saved damage, THEN allowDamage true hands the now-settled vehicle to normal handling.
                _vehicle allowDamage false;
                [_vehicle, _damage] spawn {params ["_v", "_dmg"];
                    uiSleep 20;
                    if (isNull _v) exitWith {};
                    _v setVelocity [0, 0, 0];
                    _v setDamage _dmg;
                    _v allowDamage true;};
                // owner 2026-06-13: restore the KEYS into AP_vehOwners (what the access/lock checks read).
                // Was only setting the dead "vehicle_info_owners" -> restored vehicles had no keys ("NoVehData")
                // so owners couldn't access their own car after a restart. FALLBACK: if the saved owner list is
                // empty (old rows saved before saveVehicles read AP_vehOwners), grant keys to the registered
                // owner from dbInfo[0] (the owner UID) so the owner still gets in. Keep the legacy var too.
                private _keys = if (_owners isEqualType [] && {count _owners > 0}) then { _owners } else { [[(_dbInfo select 0), "Owner"]] };
                _vehicle setVariable["AP_vehOwners",_keys,true];
                _vehicle setVariable["vehicle_info_owners",_keys,true];
                if(typeName (_dbInfo select 2) == "STRING") then {_dbInfo set[2,objnull]};
                _vehicle setVariable["dbInfo",_dbInfo,true];
                // owner 2026-06-13: set AP_dbInfo too -- THIS is what links the vehicle to its owner. On
                // connect, fn_queryRequest matches `vehicles select {getVariable "AP_dbInfo" param 0 == uid}`
                // and pushes the result into the owner's AP_vehicles (= their keychain + trunk-access list).
                // restore only set the legacy "dbInfo" -> the restored car never entered AP_vehicles -> owner
                // had keys (AP_vehOwners) but NO keychain entry + NO trunk access (admin-force only). Format
                // [ownerUID, plate] from the saved dbInfo (param 0 = uid for personal, gang id for gang vehicles).
                _vehicle setVariable["AP_dbInfo", _dbInfo, true];
                _vehicle setVariable["idleTime",1];
                _vehicle setVariable["insured",_insured];
                // owner 2026-06-21 (#425/#428): restore AP_side. The chop + claim actions (fn_chopShopSell:17,
                // fn_chopShopClaim:17/45) gate on AP_side in ["civ","cop"]; fn_prepareVehicle sets it on the buy/
                // garage-pull path, but a RESTORED persistent vehicle never runs that -> after a restart a stolen/
                // found vehicle couldn't be chopped or claimed ("This vehicle cannot be chopped"). Side = the
                // owner 2026-06-30 (#13): the side column holds the plain LABEL "civ"/"cop"/"med" (already a string,
                // QUOTE'd) -- NOT an engine side const. The old `call compile "civ"` re-evaluated that label as an
                // SQF identifier -> "Undefined variable: civ" on EVERY restored vehicle (the guard then mis-defaulted
                // cop/med to "civ") + ~2600 boot -SCRIPTERR-s. Read it as a string, stripping any QUOTE single-quotes
                // (robust whether extDB returns "civ" or "'civ'"); validate + default to civ for a junk row.
                private _sideStr = (format ["%1", _vInfo select 1]) splitString "'" joinString "";
                if !(_sideStr in ["civ", "cop", "med"]) then { _sideStr = "civ"; };
                _vehicle setVariable ["AP_side", _sideStr, true];
                // owner 2026-06-21 (Ebola vehicle-loss): stamp the restore time -- fn_vehicleDead uses it so a vehicle
                // that dies from a restore-collision (clipped a building, e.g. parked at the bank) within 60s is GARAGED
                // instead of DELETED. Without this, restored-into-a-building vehicles blow up post-shield + are lost.
                _vehicle setVariable["AP_restoredAt", serverTime, true];
                // RESOURCE RIG (2026-08-27): a rig truck left OUT across a restart must be re-adopted or it
                // restores as a bare flatbed (textures, published vars, drill visuals all live in APS_fnc_rigAdopt).
                // rig_kind is _vInfo select 14 (appended to the SELECT above; consumers read positionally).
                private _rigKind = format ["%1", _vInfo param [14, ""]];
                if (_rigKind in ["extractor", "processor"]) then { [_vehicle, _rigKind] call APS_fnc_rigAdopt; };
                _vehicle setFuel _fuel;
                _vehicle setDamage _damage;
                _vehicle addEventHandler["Killed","_this spawn APS_fnc_vehicleDead"];
                _vehicle addEventHandler["GetOut", "_this call AP_fnc_vehicleExit"];
                _vehicle addEventHandler["handleDamage","_this call AP_fnc_handleVehicleDamage"];
                [_vehicle] call AP_fnc_clearVehicleAmmo;
                [_vehicle] spawn APS_fnc_igiInit;
                _vehicle lock 2;
                _vehicle enableRopeAttach false;

                // owner 2026-06-13: restore into AP_vinv (the live trunk var) so vehicle Y-inventory survives
                // a soft restart. Was setting the dead "Trunk" var -> restored vehicles always came back empty.
                _vehicle setVariable ["AP_vinv",_inventory,true];

                // owner 2026-06-14 (#186): restore the storage-upgrade trunk cap. AP_vcap (= base getVirtCap +
                // mods[1] storage upgrade) is normally set by fn_prepareVehicle on a garage PULL, but a vehicle
                // left OUT during a soft restart is rebuilt here and never got it -> the cap reader (fn_vehicleWeight
                // -> AP_vcap) fell back to the base, so an upgraded HEMTT box dropped from 1000 to 100 and couldn't
                // store past 100. Re-derive it from the persisted mods column.
                private _mods = parseSimpleArray (format["%1", _vInfo select 13]);
                if (!(_mods isEqualType []) || {count _mods < 9}) then { _mods = [0,0,0,0,0,0,0,0,0]; };
                _vehicle setVariable ["AP_mods", _mods, true];
                if (!isNil "AP_fnc_vehicleConfig") then {
                    _vehicle setVariable ["AP_vcap", (["getVirtCap", "", (typeOf _vehicle)] call AP_fnc_vehicleConfig) + (_mods param [1, 0]), true];
                };
                // owner 2026-07-21: derive the DRIVETRAIN flags from mods slot 9 here too. fn_prepareVehicle was
                // the ONLY place that set AP_autopilot, and it does not run on a restart restore -- so a vehicle
                // left out over a soft restart came back with its paid-for autopilot module silently dead (the
                // TAB radial gate reads AP_autopilot). Same derivation, same slot: 1 = autopilot, 2 = Analog
                // Retrofit (no computer -> immune to every remote-vehicle hack, no autopilot).
                if ((_mods param [6, 0]) isEqualTo 1) then { _vehicle setVariable ["AP_chameleon", true, true]; };   // slot 6 = Chameleon Paint, same restart-restore reason as the drivetrain flag below
                switch (_mods param [9, 0]) do {case 1: { _vehicle setVariable ["AP_autopilot", true, true]; };
                    case 2: { _vehicle setVariable ["AP_analog", true, true]; _vehicle setVariable ["AP_autopilot", false, true]; };};

                [[_vehicle,(call compile format["%1",_vInfo select 8])],"AP_fnc_colorVehicle",true,false] spawn BIS_fnc_MP;

                // owner 2026-06-14: REMOVED the per-type vehicleAnimate calls. They used the OLD arg order
                // [vehicle, "presetName", bool] but fn_vehicleAnimate now takes [className, vehicle, preset,
                // skinID, showDoors] AND switches on playerSide (invalid server-side) -> 4 boot errors per
                // restore + the presets never applied anyway. Color/skin is already done via colorVehicle above.

                [_plate,_dbInfo select 0,_vehicle,1,_alarm] spawn DB_fnc_updateVehicle;};};} foreach _mem;
    if ((count _mem) < 20) exitWith {};};

// owner 2026-06-19 (persistence cluster): do NOT wipe vehicle_mem after the restore. The periodic vehicle
// save (server init, every 8 min) now keeps it CURRENT, so a crash / ungraceful manual restart restores the
// last ~8-min snapshot instead of losing every spawned vehicle. (Was: sleep 300; DELETE FROM vehicle_mem.)
