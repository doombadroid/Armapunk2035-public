
private["_idleTime","_insured","_time","_delay","_dbInfo","_uid","_plate","_trunk","_sql","_item","_revive","_ammo","_maxAmmo"];

systemChat "Performing cleanup...";
 {_timeOfDeath = _x getVariable ["ToD", time];

    if (!(isPlayer _x) && {(_x getVariable ["AP_respawnedOrphan", false]) || ((time - _timeOfDeath) > 1860)}) then /* LooneyBin: never reap a dead player's OWN body during their bleedout/revive window (AP_death_timer=30min). owner 2026-06-16 (#291/#292): the old guard reaped any corpse whose "Revive" var was unset -- but the REAL early-respawn cause was the ENGINE corpseManager (description.ext corpseRemovalMinTime=360 -> bodies vanished at ~6min, force-respawning the player). That's now raised to 1860s. Here we no longer key off Revive at all: reap only (a) a body whose player CHOSE to respawn (AP_respawnedOrphan, set in fn_doRespawn -> cleared fast, no 31min litter) or (b) any body dead longer than 1860s (30min window elapsed -> revive impossible). A body still bleeding for a medic is neither -> kept the full 30 min. */
    {deleteVehicle _x;};} foreach allDeadMen;

// owner 2026-07-16: ABANDONED-BODY SAFETY NET. A player who logs out (or switches factions) while ALIVE leaves a
// frozen, un-controlled unit that is NOT dead -> never in allDeadMen -> the sweep above can't touch it, so it
// litters the map at the logout spot forever (esp. faction switches: log out as civ, back in as cop -> the civ
// body stays). fn_playerDisconnected deletes the unit on a clean disconnect, but anything that slips that path
// (misroute, crash-timeout, side change) is caught here: any player-TAGGED unit (AP_steamid set) that no online
// player owns is abandoned -> reap it + its dropped gear. mapData NPCs/event AI have no AP_steamid, live players
// return isPlayer true, so neither is touched.
private _onlineUIDs = (call AP_fnc_realPlayers) apply { getPlayerUID _x }; {private _bsid = _x getVariable ["AP_steamid", ""];
    if (!(isPlayer _x) && {_bsid isNotEqualTo ""} && {!(_bsid in _onlineUIDs)}) then {
        { deleteVehicle _x; } forEach (nearestObjects [_x, ["WeaponHolderSimulated"], 6]);
        deleteVehicle _x;};} forEach allUnits;

// owner 2026-07-09 (THE reason "vehicles never despawn"): commit 5706ac7e's reformat wrapped the guards +
// vehicle-if below in an EXTRA bare { } block, re-binding the trailing `else` to that block instead of the
// Car/Air/Ship if:  { ...all the reap logic... } else { ...junk sweep... }.  In SQF `else` is a plain binary
// operator on two CODE values -- outside an if-then it just BUILDS the [thenCode, elseCode] array and executes
// NEITHER. So this entire forEach parsed fine, "ran" clean every 300s, and did NOTHING since 2026-06-27: no
// idle reap, no wreck reap, no junk sweep. The 07-01 (_object) and 07-04 (wreck-linger) fixes edited code
// INSIDE the dead literal, which is why they never observably fixed anything. Restored the intended nesting:
//   guards -> if (vehicle) then { alive ? idle-reap : wreck-linger } else { generic junk sweep };
// and while resurrecting the reap, gave it the gang-vehicle store branch it always lacked (see below).
{if (_x getVariable ["AP_adminVehicle", false]) then { continue };
    // LooneyBin: admin-spawned vehicles are never auto-reaped (cleared only via admin menu "delete all admin vehicles")
    if (_x getVariable ["AP_eventVeh", false]) then { continue };
    // owner 2026-06-20: event vehicles (Loony Bin getaway Tempest) are never auto-reaped -- they persist until restart (loonyBinReset no longer deletes the Tempest at event-end). Without this exemption a player-driven-then-abandoned Tempest would get an idleTime stamp + reap at the 40/60min delay below.
    if (alive _x && {_x getVariable ["AP_ignitionBombArmed", false]}) then { continue };
    // owner 2026-06-23 (#505): a vehicle rigged with a LIVE ignition bomb is a deliberate trap left as bait -- skip idle-reap so it persists until the planter triggers it (engine start -> detonation) or a restart, instead of vanishing at the 40-min spawned tier. Guarded on `alive` so a DETONATED wreck (setDamage 1, armed flag cleared in APS_fnc_ignitionBombSRV) still falls through to the normal dead-vehicle reap below -- no immortal wreck litter.

    // owner 2026-07-23: + Tank -- the ND-shop Nyx (I_LT_01_cannon_F) is a TANK, so it fell through to the
    // ELSE junk-sweep below, which has NO crew check and deletes anything lacking Revive/owner/Trunk vars ->
    // it deleted an OCCUPIED Nyx mid-drive, silently. Tanks now go through the real vehicle lifecycle
    // (idle-stamp -> 40min auto-garage -> wreck-linger) like every other player vehicle.
    if (((_x isKindOf "Car") || (_x isKindOf "Air") || (_x isKindOf "Ship") || (_x isKindOf "Tank")) && typeOf _x != "Steerable_Parachute_F") then
    {_idleTime = _x getVariable ["idleTime", 0];

        if (alive _x) then {
            // LooneyBin fix owner 2026-07-04: stamp-on-first-sight. The reap gate below is `if (_idleTime > 0)`,
            // so an empty vehicle whose idleTime never got stamped (e.g. the client->server setVehicleIdle
            // remoteExec never landed) was skipped FOREVER and never reaped = cars lingering for days. Start
            // its 40min clock here, server-side + authoritative, so every idle car reliably ages into the reap.
            if (_idleTime <= 0 && {count (crew _x) == 0}) then { _x setVariable ["idleTime", time, true]; _idleTime = time; };

            if (_idleTime > 0) then {_isKart = false;

                if (count (crew _x) == 0 || _isKart) then {_time = time;
                    _spawned = _x getVariable ["spawned", false];

                    if (_spawned) then { _delay = 2400; } else { _delay = 2400; };
                    // LooneyBin: owner 2026-07-01 -- idle empty vehicles reap at a firm 40min cap (2400s), spawned + stored alike, so cars stop lingering for days. (Was 1800/1800 = 30/30 in 5706ac7e; that commit's comment claimed 40/60 but the code was 30/30 -- and the reap never fired anyway, see the _object fix below.)

                    if (_isKart) then {if (_x distance (getMarkerPos "go_karts") > 150) then { _delay = 0; };};

                    if ((_time - _idleTime) >= _delay) then {
                        // owner 2026-06-20 (GHOST vehicle -- player026's upgraded tempest 47863 "disappeared"): read AP_dbInfo FIRST,
                        // falling back to legacy dbInfo. cleanup only read "dbInfo", but GARAGE-PULLED vehicles (fn_vehicleGaragePull /
                        // fn_gangGaragePull set only AP_dbInfo) never reliably have it server-side -> count 0 -> the active=0 serialize
                        // below was SKIPPED while deleteVehicle still ran = GHOST (DB active=1, world object gone, can't re-pull). Same
                        // root + fix as fn_vehicleDead (#406). AP_dbInfo = [uid,plate(,gangFlag)] -> param[3] (no alarm index -> select 3 throws).
                        _dbInfo = _x getVariable ["AP_dbInfo", []];

                        if (count _dbInfo == 0) then { _dbInfo = _x getVariable ["dbInfo", []]; };

                        if (count _dbInfo >= 2) then {_uid = _dbInfo select 0;
                            _plate = _dbInfo select 1;

                            // owner 2026-07-09: GANG vehicles auto-garage into gang_vehicles, not the personal table.
                            // fn_gangGaragePull stamps AP_dbInfo = [gangID, plate, true]; the old code fed that
                            // straight into DB_fnc_updateVehicle -> "UPDATE vehicles ... WHERE pid='<gangID>'" matched
                            // NOTHING, then deleteVehicle ran anyway -> gang_vehicles row stuck active=1 (hidden from
                            // the garage list) = gang car LOST until a manual reset. Mirror APS_fnc_gangGarageStore's
                            // active=0 fold (UPDATE-only: a PULLED gang vehicle always has its row, per #335) -- but
                            // like the personal reaper path, KEEP the whole trunk (contraband included, 07-04 QoL:
                            // the player didn't choose to store, so the cleanup mustn't void their cargo).
                            if ((_dbInfo param [2, false]) isEqualTo true) then {private _vinv  = _x getVariable ["AP_vinv", [[], 0]];
                                private _kept  = (_vinv param [0, []]) select { _x isEqualType [] && {count _x >= 2} };
                                private _wt = 0;
                                if (!isNil "AP_fnc_virtItemCfg") then {
                                    { private _iw = ["getItemWeight", (_x select 0)] call AP_fnc_virtItemCfg; if (_iw isEqualType 0) then { _wt = _wt + (_iw * (_x select 1)); }; } forEach _kept;
                                };
                                private _cargo = [getItemCargo _x, getWeaponCargo _x, getMagazineCargo _x, getBackpackCargo _x];
                                private _inv = str [[_kept, _wt], _cargo];
                                _inv = (_inv splitString "'") joinString "";   // SQL-safe: strip single-quotes
                                private _gangIDsql  = (format ["%1", _uid])   splitString "'" joinString "";
                                private _plateSql   = (format ["%1", _plate]) splitString "'" joinString "";
                                [format ["UPDATE gang_vehicles SET active = false, inventory='%1', fuel='%2', damage='%3' WHERE gang_id='%4' AND plate='%5'",
                                    _inv, round ((fuel _x) * 100), round ((damage _x) * 100), _gangIDsql, _plateSql]] call DB_fnc_asyncQuery;
                                // release the active-pull lock (twin of fn_gangGarageStore) so the plate can be pulled again
                                if (!isNil "AP_activeVehKeys") then { AP_activeVehKeys = AP_activeVehKeys - [format ["%1:%2", _uid, _plate]]; };
                                diag_log format ["[LooneyBin][reap] idle gang vehicle %1 (plate %2) auto-garaged to gang %3", typeOf _x, _plate, _uid];
                            }
                            else {_alarm = 0;

                                if (_dbInfo param [3, false]) then { _alarm = 1; };

                                _ammo = 0;

                                if ((typeOf _x) == "B_G_Offroad_01_armed_F") then {_maxAmmo = 400;
 {_ammo = _ammo + (_x select 1);} forEach (magazinesAmmoFull _x);

                                    _ammo = _ammo / _maxAmmo;};

                                // LooneyBin owner 2026-07-04 (QoL): keepIllegal=true (7th arg) -- an AUTO-reaped car
                                // keeps its trunk contraband (drugs) in the garage. The ONLY case illegal Y-inv survives
                                // a store: the player didn't choose to garage it, so the cleanup shouldn't void their drugs.
                                [_plate, _uid, _x, 0, _alarm, _ammo, false, true] call DB_fnc_updateVehicle;
                                diag_log format ["[LooneyBin][reap] idle vehicle %1 (plate %2) auto-garaged for %3", typeOf _x, _plate, _uid];
                            };
                            sleep 0.1;};

                        // deletes objects attached to the vehicle (cop lightbars, etc.)
                        // LooneyBin fix owner 2026-07-01: was `attachedObjects _object` --
                        // _object is undefined in this file (the loop var is _x), so this
                        // threw a runtime error and ABORTED the reap block before the
                        // deleteVehicle below -> the car was never removed (and DB active=0
                        // had already run at line 79 -> ghost). This broke ALL idle reaping.
                        private _vehicleCopObjects = attachedObjects _x;
                        private _vehicleHasCopObjects = _vehicleCopObjects isNotEqualTo [];

                        if (_vehicleHasCopObjects) then {private _objects = attachedObjects _x;

                            // run a for loop
                            {
                                // delete them
                                deleteVehicle _x;} forEach _objects;};

                        deleteVehicle _x;};};};}
        else {
            // owner 2026-07-04: wrecks LINGER 40min before the reaper clears them -- players can SEE + recover them
            // with a Wreckage Recovery Kit (matches the alive-vehicle idle cap). fn_vehicleDead stamps AP_wreckDeadAt
            // at the moment of death; an un-stamped wreck (Killed EH never fired / restored wreck) is stamped on first
            // sight here + its DB/insurance handling run once, then kept. Only clear once 40min have elapsed.
            // owner 2026-07-09: this block moved to its INTENDED home -- the dead-vehicle else of `if (alive _x)`.
            // 5706ac7e's phantom-else restructure had left it hanging off the "not a Car/Air/Ship" branch (only
            // parachutes and oddballs land there), so on top of the dead outer literal it was double-unreachable.
            // It replaces the pre-07-04 owner/Trunk instant-delete that used to live here (superseded: wrecks now
            // linger for recovery instead of vanishing the moment no owner/Trunk var is set).
            private _deadAt = _x getVariable ["AP_wreckDeadAt", -1];

            if (_deadAt < 0) then {_x setVariable ["AP_wreckDeadAt", serverTime, true];
                _x setVariable ["AP_isWreck", true, true];

                _spawned = _x getVariable ["spawned", false];
                _insured = _x getVariable ["insured", false];

                if (!_spawned && !_insured) then {[_x] spawn APS_fnc_vehicleDead;
                    sleep 0.1;};

                continue;};

            if ((serverTime - _deadAt) < 2400) then { continue };

            // owner 2026-07-04: was `_vehicle` (never defined in this file -> always nil -> dead code), so a reaped
            // wreck's attached cop objects (lightbar/pushbar from fn_createP3DObjects) were orphaned on the map
            // until restart. Use the loop var _x + delete the attachments before the wreck itself (line below).
            {deleteVehicle _x;} forEach (attachedObjects _x);

            deleteVehicle _x;};}
    else {_revive = _x getVariable ["Revive", nil];
        _owned = _x getVariable ["owner", nil];
        _trunk = _x getVariable ["Trunk", nil];
        _dropItem = _x getVariable ["item", nil];
        // LooneyBin: loot / Y-inventory drop marker (suitcases, money, gold). The Thing + GroundWeaponHolder loops below own its 30-min TTL -- loop 1 must NOT instant-kill a fresh drop that happens to lack an `owner` var (the random early despawn).
        _idleTime = _x getVariable ["idleTime", 0];

        // owner 2026-09-16: never junk-sweep a Land_ClutterCutter_small_F that something is attached to. That class is the
        // invisible parent for a parkour move (AP_fnc_parkour / AP_fnc_parkourMove) and a seated chair (AP_fnc_handleChair);
        // reaping it mid-use drops the player out of the move. An unused one (a disconnect orphan) has nothing attached
        // and is still reaped by the rule below.
        if (!((typeOf _x) in PLBObjectWhitelist) && !(((typeOf _x) isEqualTo "Land_ClutterCutter_small_F") && {(attachedObjects _x) isNotEqualTo []}) && (isNil {_x getVariable "AP_furniture"}) && isNil "_dropItem" && ((_x getVariable ["AP_droppedItems", []]) isEqualTo []) && ((_idleTime > 0 && (time - _idleTime) > 1800) || (_idleTime == 0 && isNil "_revive" && isNil "_owned" && isNil "_trunk" && (isNull (ropeAttachedTo _x))))) then
        {deleteVehicle _x;};};} forEach vehicles; {
    if ((typeOf _x) in ["Jonzie_Lightbar_Hwy", "Land_Axe_F", "Land_WoodPile_F", "Land_WoodenLog_F", "Land_ExtensionCord_F", "Land_Canteen_F", "Land_BakedBeans_F", "Land_PowderedMilk_F", "Land_BottlePlastic_V1_F", "Land_TacticalBacon_F", "Land_Can_V3_F", "Land_CanisterFuel_F", "Land_Can_V3_F", "Land_Money_F", "Land_Suitcase_F", "Land_Defibrillator_F", "Land_Screwdriver_V1_F", "Land_BloodBag_F", "Land_PainKillers_F", "Land_DuctTape_F", "Land_File_F", "Land_Bucket_F", "Land_DrillAku_F", "Land_Pliers_F", "Land_MultiMeter_F", "Land_Sleeping_bag_folded_F", "Bomb"]) then
    {if (isNull (attachedTo _x)) then {_item = _x getVariable "item";
            _owner = _x getVariable "owner";
            _idleTime = _x getVariable ["idleTime", 0];

            if (!isNil "_item" && isNil "_owner") then {if (_idleTime == 0) then {_x setVariable ["idleTime", time];}
                else {if ((time - _idleTime) > 1800) then { deleteVehicle _x; };};};
            // LooneyBin: was instant-delete when idleTime==0 -> fresh drops vanished on the next 5-min pass; now stamp-on-first-sight + 30min TTL
        };};} foreach (allMissionObjects "Thing"); {
    // LooneyBin: was an unconditional deleteVehicle on EVERY 5-min pass -> player ground-drops (weapons/gear) vanished within minutes. Now empty/transient holders reap immediately; loaded drops persist ~30min via an idleTime stamp.
    private _idle = _x getVariable ["idleTime", 0];

    if ((((count weaponCargo _x) + (count itemCargo _x) + (count magazineCargo _x) + (count backpackCargo _x)) isEqualTo 0) && ((_x getVariable ["AP_droppedItems", []]) isEqualTo [])) then { deleteVehicle _x; } else { if (_idle isEqualTo 0) then { _x setVariable ["idleTime", time]; } else { if ((time - _idle) > 1800) then { deleteVehicle _x; }; }; };
    // LooneyBin (#52): a holder carrying VIRTUAL items (AP_droppedItems) has 0 PHYSICAL cargo -> was reaped as "empty" on the next pass (felt like ~3 min). Treat virtual-item holders as non-empty.
} foreach (allMissionObjects "GroundWeaponHolder");

systemChat "Cleanup complete.";
