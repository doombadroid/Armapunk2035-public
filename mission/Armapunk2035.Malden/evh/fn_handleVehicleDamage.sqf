params[["_unit", objNull, [objNull]], ["_hitBox", "", [""]], ["_damage", 0, [0]], ["_source", objNull, [objNull]], ["_projectile", "", [""]]];
private _heavyVehicles = ["O_Heli_Light_02_unarmed_F", "O_Heli_Transport_04_F", "O_Heli_Transport_04_bench_F", "B_MRAP_01_F", "I_MRAP_03_F", "O_MRAP_02_F", "B_Truck_01_box_F", "B_Truck_01_transport_F", "B_Truck_01_fuel_F", "B_T_Truck_01_covered_F", "I_Heli_Transport_02_F", "B_Heli_Transport_01_F"];

// vehicle hitpoint damage protection
private _protectedVehicles = ["lsv"]; // lsv = qilin
{
	// get the model info
    private _info = getModelInfo _unit;

	// check if the model name matches
    if (_x in (_info select 0)) then {

		// set damage first time
		{if ("fuel" in _x || "hull" in _x || "body" in _x) then {_unit setHitIndex [_forEachIndex, 0];};
		} forEach (getAllHitPointsDamage _unit select 0);

		// secondary check because sometimes eventhandlers dont handle events properly (script fail)
		if (((_unit getHitIndex 4) > 0) || ((_unit getHitIndex 5) > 0)) then {_unit setHitIndex [4, 0];
			_unit setHitIndex [5, 0];};};} forEach _protectedVehicles;

// owner 2026-06-25 (Northhhhh: "RPGs don't blow up Ifrits, just disable Orcas"): the old check compared the OBJECT
// _unit to a STRING with isEqualTo -- ALWAYS false -- so this RPG damage amplifier NEVER fired and the _heavyVehicles
// list above was dead code. Fix: an RPG/PG7 hit on any listed heavy vehicle, on the OVERALL hitbox (""), is a
// guaranteed kill (the intended 5000). TUNE: edit the _heavyVehicles array above to add/remove what an RPG one-shots.
if ((typeOf _unit) in _heavyVehicles && {_projectile in ["R_PG7_F", "ammo_Penetrator_PG7"]} && {_hitBox isEqualTo ""}) then {_damage = 5000
};
if (_projectile isNotEqualTo "") then {if (!(isNull _unit)) then {if (local _unit) then {[_source] spawn AP_fnc_setAggressive} else {[
                [_source], "AP_fnc_setAggressive", _unit, false, false] spawn AP_fnc_MP;};};};
if (_hitBox isNotEqualTo "?") then {private _oldDamage =
    if (_hitBox isEqualTo "") then {damage _unit} else {_unit getHit _hitBox};
    if !(isNil "_oldDamage") then {if (isNull _source && _projectile isEqualTo "") exitWith {private _scale =
            if (_hitBox select[0, 5] == "wheel") then {0.15} else {0.35};
            _damage = ((_damage - _oldDamage) * _scale) + _oldDamage;};};};
if (_projectile isEqualTo "mini_Grenade") then {_damage = 0;};
if (_hitBox isEqualTo "palivo") then {_damage = _damage / 3};
// LooneyBin: transport helis (Huron / Ghosthawk / Mohawk) pop their rotor in under a mag at stock armor.
// Per-caliber damage scaling so they tank small-arms but still go down to heavy weapons:
//   .50 cal (12.7mm) -> 0.60  (~5 rounds)       shotgun slug (12Gauge) -> 0.10  (~10 rounds)
//   7.62 + everything else -> 0.05  (~6 mags, dialed in)      RPG/PG7 left at full.
// Lower scale = tankier vs that caliber. Round counts are approximate, tune to taste.
private _armoredHelis = ["B_Heli_Transport_01_F", "B_Heli_Transport_03_unarmed_F", "B_Heli_Transport_03_F", "I_Heli_Transport_02_F"];
if (((typeOf _unit) in _armoredHelis) && {_projectile isNotEqualTo ""} && {!isNull _source} && {!(_projectile in ["R_PG7_F", "ammo_Penetrator_PG7"])}) then {
    private _hbDmg = if (_hitBox isEqualTo "") then { damage _unit } else { _unit getHit _hitBox };
    if (isNil "_hbDmg") then { _hbDmg = 0 };
    private _scale = 0.05;                                          // 7.62 and everything else (~6 mags)
    if ((_projectile find "127x") >= 0) then { _scale = 0.60 };     // .50 cal (12.7mm) -- ~5 rounds
    if ((_projectile find "12Gauge") >= 0) then { _scale = 0.10 };  // shotgun slug / pellets -- ~10 rounds
    _damage = ((_damage - _hbDmg) * _scale) + _hbDmg;};
// LooneyBin (#43): the Orca main rotor shrugs off fire to the point of feeling immortal. Floor
// rotor-selection damage so a sustained burst actually downs it (>=0.1/hit -> ~10 rounds), overriding
// whatever low value the engine/config hands back.
if (((typeOf _unit) in ["O_Heli_Light_02_F", "O_Heli_Light_02_unarmed_F"]) && {_projectile isNotEqualTo ""} && {!isNull _source} && {(_hitBox find "vrtule") >= 0}) then {
    private _rb = _unit getHit _hitBox; if (isNil "_rb") then { _rb = 0 };
    _damage = _damage max (_rb + 0.1);};
// owner 2026-07-23: AWC Nyx (blood shop) caliber gate -- "nothing under 7.62 penetrates". BULLETS ONLY:
// rockets/grenades/mines/collisions keep stock behavior (an RPG still wrecks it, on purpose). Sub-7.62
// rounds are clamped to existing damage = zero effect anywhere (hull, tracks, optics). Penetrator rounds
// grind the overall ("") hitbox down via a per-hit floor; component hitboxes take stock damage once the
// caliber passes. TUNE: the two _inc values (0.06 = ~17 rds of 7.62 to kill, 0.12 = ~9 rds of .50/cannon).
private _nyxHeavy = ["B_127", "B_408", "B_19mm", "B_20mm", "B_25mm", "B_30mm", "B_35mm", "B_40mm", "Gatling_"];
if (((typeOf _unit) isEqualTo "I_LT_01_cannon_F") && {_projectile isNotEqualTo ""} && {_projectile isKindOf ["BulletBase", configFile >> "CfgAmmo"]}) then {
    if ((["B_762", "B_338", "B_93x"] + _nyxHeavy) findIf { (_projectile find _x) isEqualTo 0 } > -1) then {if (_hitBox isEqualTo "") then {
            private _inc = if (_nyxHeavy findIf { (_projectile find _x) isEqualTo 0 } > -1) then { 0.12 } else { 0.06 };
            _damage = _damage max ((damage _unit) + _inc);};} else {
        // sub-7.62: clamp to the hitpoint's existing value ("?" hitbox has no getHit -- clamp to 0)
        private _hb = 0;
        if (_hitBox isEqualTo "") then { _hb = damage _unit; } else {
            if (_hitBox isNotEqualTo "?") then { _hb = _unit getHit _hitBox; if (isNil "_hb") then { _hb = 0 }; };};
        _damage = _hb;};};
if ((_projectile in ["R_PG7_F"]) && !(_unit getVariable["AP_vehRpged", false]) && (alive _unit)) then {
    _unit setVariable["AP_vehRpged", true, true];
    [_unit] spawn {params["_unit"];
        uiSleep 3;
        _unit setVariable["AP_vehRpged", false, true];}; [["rpg_vehhits", 1], "AP_fnc_statArrUpdate", _source] spawn AP_fnc_MP;};
// owner 2026-07-13 (MOTORIST -- Pit Boss talent): 40% less collision/ram damage (no projectile = impact)
if (_projectile isEqualTo "" && {_unit getVariable ["AP_pitBoss", false]}) then {_damage = _damage * 0.6;};
private _damage =
_damage;