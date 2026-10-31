params[["_vehicle", objNull, [objNull]]];
if (isNull _vehicle) exitWith {};
private _magTurrets =
switch (typeOf _vehicle) do {case ("I_Plane_Fighter_04_F"): {[["magazine_Fighter04_Gun20mm_AA_x250", -1], ["Laserbatteries", -1],
                ["240Rnd_CMFlare_Chaff_Magazine", -1], ["PylonMissile_Missile_BIM9X_x1", -1], ["PylonRack_Missile_AGM_02_x1", -1],
                ["PylonRack_Missile_AMRAAM_C_x1", -1]]}; case ("I_Plane_Fighter_03_CAS_F"): {[["300Rnd_20mm_shells", -1],
                    ["2Rnd_LG_scalpel", -1], ["2Rnd_AAA_missiles", -1], ["2Rnd_GBU12_LGB_MI10", -1], ["120Rnd_CMFlare_Chaff_Magazine", -1]]
            };
        case ("B_Boat_Armed_01_minigun_F"): {[["96Rnd_40mm_G_belt", 0]]};
        case ("B_APC_Wheeled_01_cannon_F"): {[["60Rnd_40mm_GPR_Tracer_Red_shells", 0], ["40Rnd_40mm_APFSDS_Tracer_Red_shells", 0]]};
        case ("O_Heli_Attack_02_black_F"): {[["250Rnd_30mm_APDS_shells", 0], ["8Rnd_LG_scalpel", 0], ["38Rnd_80mm_rockets", 0]]};
        case ("B_Heli_Transport_01_F"): {[["2000Rnd_65x39_Belt_Tracer_Red", 1], ["2000Rnd_65x39_Belt_Tracer_Red", 2]]};
        case ("B_Heli_Attack_01_F"): {[["1000Rnd_20mm_shells", 0], ["4Rnd_AAA_missiles", 0], ["24Rnd_PG_missiles", 0]]};
        case ("I_Plane_Fighter_03_CAS_F"): {[["250Rnd_30mm_APDS_shells", 0], ["8Rnd_LG_scalpel", 0], ["38Rnd_80mm_rockets", 0]]};
        case ("O_APC_Wheeled_02_rcws_v2_F"): {[["HMG_127_APC", 0], ["GMG_40mm", 0]]};
        case ("I_Heli_light_03_F"): {[["5000Rnd_762x51_Yellow_Belt", -1], ["5000Rnd_762x51_Belt", -1], ["24Rnd_missiles", -1]]};
        default {[]};}; { _x params["_magName", "_turretPath"];
    _vehicle removeMagazinesTurret[_magName, [_turretPath]];}
forEach _magTurrets;
clearWeaponCargoGlobal _vehicle;
clearMagazineCargoGlobal _vehicle;
clearItemCargoGlobal _vehicle;
// LooneyBin: the type-switch above lists no mags for the medic Xi'an, so it spawned fully armed. Empty
// every pylon + zero all ammo (incl. the side minigun) so medics can't fly it as a gunship.
if (typeOf _vehicle in ["O_T_VTOL_02_infantry_F", "O_T_VTOL_02_vehicle_F"]) then {
    { _vehicle setPylonLoadout [(_forEachIndex + 1), "", true]; } forEach (getPylonMagazines _vehicle);
    _vehicle setVehicleAmmo 0;};
// owner 2026-07-03: rebel-air-shop armed Orca "minus missiles" — clear every pylon carrying a guided
// missile or rocket, KEEP the gun pod(s). Name-matched so it survives whatever default pylon preset the
// dynamicLoadout spawns with.
if (typeOf _vehicle isEqualTo "O_Heli_Light_02_dynamicLoadout_F") then {{private _lc = toLower _x;
        if (["missile", "rocket", "scalpel", "dagr", "dar_", "skyfire"] findIf { (_lc find _x) > -1 } > -1) then {
            _vehicle setPylonLoadout [(_forEachIndex + 1), "", true];};} forEach (getPylonMagazines _vehicle);};
// owner 2026-07-05: the civ "Pawnee (Guns)" (B_Heli_Light_01_armed_F) is NOT a dynamicLoadout variant, so its
// rockets are FIXED TURRET magazines (not pylons) -- the Orca pylon-strip above never reached them, so it flew
// with DAR rockets. Name-match its turret mags: drop rockets/missiles, KEEP the minigun belt. (The ARMED Pawnee
// variant carries DAR pods by default -- correcting the earlier "guns-only" assumption.)
if (typeOf _vehicle isEqualTo "B_Heli_Light_01_armed_F") then {{_x params ["_magName", "_turretPath"];
        private _lc = toLower _magName;
        if (["missile", "rocket", "scalpel", "dagr", "dar_", "skyfire"] findIf { (_lc find _x) > -1 } > -1) then {
            _vehicle removeMagazinesTurret [_magName, _turretPath];};} forEach (magazinesAllTurrets _vehicle);};
// owner 2026-07-23: ND-shop AWC Nyx is sold as a TURRETLESS hull (civ_nyx preset hides the turret) --
// strip EVERY turret magazine generically (20mm + coax + smokes, no mag-name guessing so a future loadout
// change can't leak ammo), then zero any loaded belt remainder. The invisible gun must never fire.
if (typeOf _vehicle isEqualTo "I_LT_01_cannon_F") then {{_x params ["_magName", "_turretPath"];
        _vehicle removeMagazinesTurret [_magName, _turretPath];} forEach (magazinesAllTurrets _vehicle);
    _vehicle setVehicleAmmo 0;};