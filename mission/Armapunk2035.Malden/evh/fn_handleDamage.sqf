params[["_unit", objNull, [objNull]], ["_hitBox", "", [""]], ["_damage", 0, [0]], ["_source", objNull, [objNull]], ["_projectile", "", [""]]];
private _curWep = "";
private _curMag = "";
private _copSource = side _source isEqualTo west;
if !(alive _unit) exitWith {};
// LooneyBin medic Healing Bullets: AEMT+ medic's green P07 in heal mode -> heal the hit player +10 hp, negate damage (no down, no aggressive flag)
if (_source != _unit && {isPlayer _source} && {side _source isEqualTo independent} && {(currentWeapon _source) isEqualTo "hgun_P07_khk_F"} && {(_source getVariable ["AP_medicGunMode", "taser"]) isEqualTo "heal"}) exitWith {
    // HandleDamage fires once PER hitpoint per bullet, and in MP those per-hitpoint events can spread
    // across several frames -> a diag_frameNo guard let a single shot heal many times (to full). Throttle
    // by TIME instead: at most one +10% heal per 0.35 s, so one shot = +10% no matter how the events land.
    if ((time - (_unit getVariable ["AP_healBulletTime", -1])) > 0.35) then {_unit setVariable ["AP_healBulletTime", time];
        _unit setDamage (((damage _unit) - 0.1) max 0);};
    0};
// LooneyBin: the medical revive drone is harmless to people — it hovers low over bodies to treat them,
// so a bump/contact must never injure, down, or kill anyone (the earlier ram-spangle was test-only).
if (_projectile isEqualTo "" && {!isNull _source} && {(typeOf _source) in ["I_UAV_06_medical_F", "C_IDAP_UAV_06_medical_F"]} && {_source != _unit} && {isPlayer _unit}) exitWith { 0 };
if (_source getVariable["AP_supertaze", false] && {(getPlayerUID _source in [])}) exitWith {_this spawn AP_fnc_forceRagdoll;};
if (!(_projectile in ["", "Sub_F_Signal_Green", "Sub_F_Signal_Red"])) then {[_source] spawn AP_fnc_setAggressive;};
if (isPlayer _source && _source isKindOf "CAManBase") then {_curWep = currentWeapon _source;
    _curMag = currentMagazine _source;};
// LooneyBin: P90 (5.7x28) rounds are armour-piercing WITHIN 50 m -- a head hit kills outright (even with a
// helmet) and torso hits kill in a fixed number of rounds (= what a 9 mm needs on a bare torso). PAST 50 m the
// round is left untouched (normal B_570x28_Ball). The P90 has a single mag (570x28 is P90-only), so this is
// all P90 fire. (A separate "SS198" premium mag would need a mod -- the mission can't add a real mag to a
// base-game gun, so we key off the only P90 mag instead.)
if (side _source != west && _source != _unit && {isPlayer _source} && {_curMag isEqualTo "50Rnd_570x28_SMG_03"} && {(_source distance _unit) < 50}) exitWith {
    private _hb = toLower _hitBox;
    if (_hb in ["head", "face_hub", "neck"]) exitWith { _unit setDamage 1; 0 };   // headshot: lethal, ignores helmet/armour
    if (_hb in ["body", "spine1", "spine2", "spine3", "pelvis"]) exitWith {
        private _apShots = 4;   // <-- shots to kill an unarmoured torso (matches a 9 mm). tune this ONE number.
        if (diag_frameNo > (_unit getVariable ["AP_apFrame", -1])) then {   // once per bullet (a shot fires several per-hitpoint events in the same frame)
            _unit setVariable ["AP_apFrame", diag_frameNo];
            _unit setDamage (((damage _unit) + (1.0 / _apShots)) min 1);     // fixed chunk, ignores the vest
            if (damage _unit == 1) then {

                private _sourceName = name _source;
                private _unitName = name _unit;
                systemChat format["%1 was killed by %2", _unitName, _sourceName];
                [[12,_source],"APS_fnc_wantedAdd",false,false] spawn AP_fnc_MP; // maybe? im not sure this mission file is old af and i dont know if this will work but it works in onPlayerKilled so ctrl C plus ctrl V
            };};
        0};
    _damage   // limbs + overall handle: untouched (normal P90)
};
if (_projectile isEqualTo "mini_Grenade") exitWith {[_source] spawn AP_fnc_handleFlashbang;
    0};
// LooneyBin (owner, 2026-06-11): passive-mode damage immunity REMOVED. New players are no longer invulnerable
// to civilians -- the whole passive system is stripped (no auto-start, no phone button). Everyone takes damage.
// owner 2026-06-15 (#217/#218/#219/#221 -- "tasers/PD guns 1-tap any armour"): read the cop's lethal/
// non-lethal toggle off the ACTUAL shooter. For a cop ON FOOT, `gunner _source` is objNull, so this always
// returned the default `true` -> EVERY cop weapon (incl. lethal rifles like the Spar-16 / MX) was flagged
// non-lethal -> the down-gate below fired on any torso hit (instant down on one shot) and the "Load Lethal
// Rounds" toggle did nothing. Use _source when the shooter is a man (on foot), gunner _source only for a
// vehicle turret. Now lethal rounds kill normally (armour applies); only true non-lethal rounds down.
private _shooter = if (_source isKindOf "CAManBase") then { _source } else { gunner _source };
private _nonLethal = _shooter getVariable ["AP_nonlethal", true];  // cops default non-lethal (down/taze). The 1-shot problem is fixed below by accumulating hits, not by changing this default.
// owner 2026-06-13: the "Tracer" mag check only means non-lethal for COPS (their rubber/tracer rounds). It was
// applying to EVERYONE -> any civ/rebel weapon firing TRACER ammo (e.g. an MK200 with 200Rnd_65x39_cased_Box_Tracer)
// was treated as a stun round and DOWNED instead of killed. Gate the tracer-stun to cop sources only.
private _bhSource = _shooter getVariable ["AP_isBountyHunter", false];
// owner 2026-06-16 (#281): a BOUNTY HUNTER downs (to capture) with the same stun WEAPONS as before PLUS the
// .45 Vermin (SMG_01), and any TRACER/"rubber" mag counts as a stun round for them too (e.g. a 5.56 tracer mag
// -- "5.56 rubber rounds"). Tracer was COP-only; BH-scoped here so it doesn't turn every civ tracer lethal
// into a down. SMG_01 is gated to BH so it stays a normal lethal SMG for rebels/gangs in firefights.
private _stunMag = (_copSource && (_nonLethal || ("Tracer" in _curMag))) || (_bhSource && ("Tracer" in _curMag));
private _isStunWep = (_curWep in ["SMG_02_F", "hgun_P07_F", "hgun_P07_khk_F", "hgun_P07_blk_F"]) || (_bhSource && {_curWep isEqualTo "SMG_01_F"});
if (_source != _unit && !((_source getVariable["AP_lethalBH", false]) && (_curWep in ["hgun_P07_F", "hgun_P07_khk_F", "hgun_P07_blk_F"])) && (_stunMag || _isStunWep)) then {
    if !(_projectile in ["GrenadeHand", "mini_Grenade", ""]) then {private _nonFatalHitboxes = ["arms", "hands", "legs"];
        if (!(_hitBox in _nonFatalHitboxes) && (_damage >= 1 || _stunMag || _isStunWep)) then {   // LooneyBin #60: civ/BH stun weapons (Sting/P07, normal 9x21 mags) entered this gate via the weapon whitelist but 9mm almost never does >=1 dmg per hit and civs have _stunMag=false (no Tracer mag, not cop) -> hits did chip damage and NEVER downed ("civs can't down civs"). A fatal-hitbox hit from a whitelisted stun WEAPON now downs outright, same as cop non-lethal. Lethal-BH P07 is already excluded at the outer gate.   // LooneyBin: a stun mag (rubber/tracer) often does too little dmg to reach the lethal (>=1) threshold, so the down never fired AND the low dmg never killed = "neither downs nor kills". A stun-mag hit to a fatal hitbox now downs on the hit. (Stun WEAPONS w/ a normal mag still need >=1.)
            _damage = 0;   // non-lethal: stun rounds never deplete health
            // owner 2026-06-16 (#242): a COP could not taze/down a fellow COP -- the down-accumulator below was
            // skipped for a west shooter hitting a west target.
            // owner 2026-06-27 REVERTED (owner wants cop-on-cop downs ALLOWED, just not restraint): run the
            // down-accumulator for cop->cop too, so an officer can taze/down a fellow officer. Restraining a
            // fellow cop stays blocked separately in fn_restrain.sqf ("(AP_effSide isEqualTo west) && (side _unit
            // isEqualTo west) exitWith {}"), so a downed cop can be revived but never zip-tied by another cop.
            if (true) then {
            // owner 2026-06-16 (#270 + ARMOR-SCALING): hits-to-down SCALES with the TARGET'S protection.
            // bare body = quick down; heavy plate carrier = several hits; mounted in an armoured vehicle
            // (Ifrit) = effectively can't be tazed through it. BULLETPROOF: never a 1-tap (floor 2), hard
            // ceiling so it's never literally impossible, missing config reads -> 0 (no crash). Counts once
            // per BULLET (diag_frameNo guard -- HandleDamage fires many hitbox events/round); the tally decays
            // after 6s of no stun hit (fresh volley starts over) and resets on the down. The 1s AP_downReqT
            // guard de-dupes the handleDowned call (the Nikki/Torch stuck-isDowned bug).
            if (diag_frameNo > (_unit getVariable ["AP_stunFrame", -1])) then {_unit setVariable ["AP_stunFrame", diag_frameNo];
                // a vest's body armour: HitpointsProtectionInfo Chest (modern vests), fallback ItemInfo.armor.
                private _armorOf = {params ["_cls"];
                    if (_cls isEqualTo "") exitWith { 0 };
                    private _ii = configFile >> "CfgWeapons" >> _cls >> "ItemInfo";
                    private _ch = _ii >> "HitpointsProtectionInfo" >> "Chest" >> "armor";
                    if (isNumber _ch && {(getNumber _ch) > 0}) exitWith { getNumber _ch };
                    getNumber (_ii >> "armor")};
                private _required = 0;
                // owner 2026-06-17: HEAD keeps its own rule (bare head = instant down, helmeted = 2). BODY now
                // reads EXACT hits from AP_downTable[vest level][calibre] (init.sqf) -- the owner's spec table.
                if ((toLower _hitBox) isEqualTo "head") then {_required = if ((headgear _unit) isEqualTo "") then {
                        missionNamespace getVariable ["AP_stunHeadBare",   1]} else {
                        missionNamespace getVariable ["AP_stunHeadHelmet", 2]};} else {
                    // 1) VEST LEVEL: 0 = bare, 1..5 ballistic, 6 = explosive-resistant. Explosive matched by
                    //    classname first; else the Chest armour split into 5 even bands between the light + heavy
                    //    reference vests (armour read LIVE from config, cached -> self-calibrating, mod-safe).
                    private _vestCls = vest _unit;
                    private _lvl = 0;
                    if (_vestCls isNotEqualTo "") then {private _lcv = toLower _vestCls;
                        private _isExp = (missionNamespace getVariable ["AP_downExplosiveVests", []]) findIf { (_lcv find _x) >= 0 };
                        if (_isExp > -1) then {_lvl = 6;} else {private _a = [_vestCls] call _armorOf;
                            if (_a > 0) then {private _lo = missionNamespace getVariable ["AP_downRefLightCache", -1];
                                private _hi = missionNamespace getVariable ["AP_downRefHeavyCache", -1];
                                if (_lo < 0) then {
                                    _lo = [missionNamespace getVariable ["AP_downRefLight", "V_TacVest_blk"]] call _armorOf;
                                    _hi = [missionNamespace getVariable ["AP_downRefHeavy", "V_PlateCarrierSpec_blk"]] call _armorOf;
                                    if (_lo <= 0) then { _lo = 16 };
                                    if (_hi <= _lo) then { _hi = _lo + 80 };
                                    missionNamespace setVariable ["AP_downRefLightCache", _lo];
                                    missionNamespace setVariable ["AP_downRefHeavyCache", _hi];};
                                _lvl = (1 + floor ((_a - _lo) / ((_hi - _lo) / 4))) max 1 min 5;};};};
                    if (_lvl isEqualTo 0) then {_required = missionNamespace getVariable ["AP_stunBase", 1];   // BARE body floor
                    } else {
                        // 2) CALIBRE column from the round's ammo class NAME (Arma names rounds by calibre).
                        //    9.3x64 (Navid LMG vs Cyrus/other) can't be split by ammo -> split by WEAPON class.
                        private _ci = 9;
                        private _am = if (_curMag isEqualTo "") then { "" } else { toLower getText (configFile >> "CfgMagazines" >> _curMag >> "ammo") };
                        private _wl = toLower _curWep;
                        switch (true) do {
                            case ((_am find "9x21") >= 0 || (_am find "9x19") >= 0 || (_am find "45acp") >= 0 || (_am find "10mm") >= 0): { _ci = 0 };   // 9mm / pistol+SMG
                            case ((_am find "556x45") >= 0): { _ci = 1 };
                            case ((_am find "58x42")  >= 0): { _ci = 2 };
                            case ((_am find "65x39")  >= 0): { _ci = 3 };
                            case ((_am find "762x51") >= 0 || (_am find "762x39") >= 0 || (_am find "762x54") >= 0): { _ci = 4 };
                            case ((_am find "338")    >= 0): { _ci = 5 };
                            case ((_am find "93x64")  >= 0): { _ci = if ((_wl find "mmg_02") >= 0) then { 6 } else { 7 } };   // Navid (MMG_02) vs Cyrus/other 9.3
                            case ((_am find "127x108") >= 0 || (_am find "127x99") >= 0 || (_am find "408") >= 0): { _ci = 8 };   // .50 / 12.7 / .408
                            default { _ci = 9 };   // bigger / unknown round -> "higher" column
                        };
                        private _row = (missionNamespace getVariable ["AP_downTable", []]) param [_lvl - 1, []];
                        _required = _row param [_ci, 1];
                        // mounted in a vehicle adds hits by its armour (kept -- can't taze a man inside an Ifrit)
                        private _vh = vehicle _unit;
                        if (_vh isNotEqualTo _unit) then {
                            _required = _required + floor ((getNumber (configFile >> "CfgVehicles" >> (typeOf _vh) >> "armor")) / (missionNamespace getVariable ["AP_stunVehDiv", 50]));
                        };};};
                _required = (_required max 1) min (missionNamespace getVariable ["AP_stunMax", 40]);
                // ONE per bullet -- the table already encodes the calibre, so no per-round weighting. Tally
                // decays after 6s of no stun hit (a fresh volley restarts) and resets on the down.
                private _sc = if ((time - (_unit getVariable ["AP_stunLast", -999])) > 6) then { 0 } else { _unit getVariable ["AP_stunCount", 0] };
                _sc = _sc + 1;
                _unit setVariable ["AP_stunLast", time];
                _unit setVariable ["AP_stunCount", _sc];
                if (_sc >= _required && {(AP_is_arrested param [0,0]) isEqualTo 0} && {(time - (_unit getVariable ["AP_downReqT", -1])) > 1}) then {
                    _unit setVariable ["AP_stunCount", 0];
                    _unit setVariable ["AP_downReqT", time];
                    [_source] spawn AP_fnc_handleDowned;};};};   // owner 2026-06-16 (#242): closes the cop-cannot-down-cop guard
        };};};
// VDM (run-over): a ramming vehicle reports _source as the VEHICLE itself, but the old check wanted
// _source to be the driver (driver(vehicle _source) isEqualTo _source) -> it never matched -> no
// damage-negate -> the victim just DIED, and it never called handleDowned anyway. Resolve the ram
// vehicle + driver whether _source is the car or a crewman, then DOWN the victim (pass the driver so
// handleDowned's _vehSource branch runs: 5s down + "run over by" broadcast + Hit-and-Run charge).
private _ramVeh = if (_source isKindOf "LandVehicle") then { _source } else { vehicle _source };
private _ramDriver = driver _ramVeh;
// owner 2026-06-15 (#231): require _projectile == "" (a real COLLISION). A vehicle WEAPON hit (e.g. the Qilin
// minigun) also reports _source as the vehicle, so without this it was misread as a run-over -> victim only
// got DOWNED + "the driver ran them over" instead of being shot/killed by the gunner. Gun hits now fall
// through to normal lethal bullet damage.
if ((_ramVeh isKindOf "LandVehicle") && {_projectile isEqualTo ""} && {
    !isNull _ramDriver && {_ramDriver != _unit} && {vehicle _unit isEqualTo _unit}}) then {
    if ((((getDammage _unit) + _damage) >= 0.95) || (_damage >= 0.95) || (_ramVeh isKindOf "Kart_01_base_F" && {_damage > 0.05})) then {  // LooneyBin: karts are too light to hit 0.95 -> any real kart ram still VDMs
        _damage = 0;
        if (((AP_is_arrested param [0,0]) isEqualTo 0) && {!AP_isDowned} && {(time - (_unit getVariable ["AP_downReqT", -1])) > 1}) then {   // LooneyBin: same per-victim 1s de-dupe as the stun path (a ram also fires multiple HandleDamage events)
            _unit setVariable ["AP_downReqT", time];
            [_ramDriver] spawn AP_fnc_handleDowned;};};};
if ((_unit getVariable["AP_restrained", false]) && !(_unit getVariable["AP_civRestrained", false])) then {
    if ((isPlayer _source) && (vehicle _unit != vehicle _source)) then {_damage = 0;};};
if (vest _unit isEqualTo "V_HarnessOGL_brn") then {if ((isPlayer _source) && (vehicle _unit != vehicle _source)) then {
        if ((!(_projectile in ["mini_Grenade", ""])) && (!(_stunMag || (_curWep in ["SMG_02_F", "hgun_P07_F", "hgun_P07_khk_F", "hgun_P07_blk_F"])))) then {
            if (((_damage > 0.4) && (_hitBox in ["spine1", "spine2"])) || (((_damage > 1) && (_hitBox isEqualTo "")) && (random(100) > 50))) then {
                if (AP_clothing_store isEqualTo "") then {if (_damage > 0.95) then {_damage = 0.95};
                    ["shot", _source] spawn AP_fnc_suicideVest;};};};};};
if !(isNull objectParent _unit) then {if ((vehicle _unit) isKindOf "Car") then {if (isNull _source || _source isEqualTo _unit) then {
            _damage = (_damage / 2.4);
            private _myDamage =
            if (_hitBox isEqualTo "") then {damage player} else {_unit getHit _hitBox};
            if (_damage < _myDamage) then {_damage = _myDamage};};};};
if ((_projectile in ["GrenadeHand", "mini_Grenade"]) && (side _unit isEqualTo west) && (_damage >= 0.90)) then {[
        ["civ_cops_grenaded", 1], "AP_fnc_statArrUpdate", _source] spawn AP_fnc_MP;};
if (AP_laser_inprogress) then {
    if (((((getDammage _unit) + _damage) >= 0.95) || (_damage >= 0.95)) && ((player getVariable["AP_laserTeam", 0]) != (_source getVariable["AP_laserTeam", 0]))) then {
        [_source] spawn AP_fnc_handleTagged;};
    _damage = 0;};
if (((AP_is_arrested param [0,0]) isEqualTo 1) || {(typeOf vehicle player isEqualTo "Steerable_Parachute_F" && _projectile isEqualTo "")
}) exitWith {0};
if (((AP_adminEvent select 2) isEqualTo 4) && {(_unit inArea "graveyardshift1")}) exitWith {0};
if (_unit distance2D(getMarkerPos "courtroom") < 150) exitWith {0};
// Super Male Vitality: ~30% damage resist while the supplement is active (owner 2026-07-15)
if ((missionNamespace getVariable ["AP_supermale_effect", [false]]) select 0) then { _damage = _damage * 0.7; };
if (_damage > 0) then {[] call AP_fnc_hudUpdate;};
_damage;