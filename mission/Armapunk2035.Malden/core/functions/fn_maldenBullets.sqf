/*
    AP_fnc_maldenBullets  (LooneyBin, owner 2026-07-11)
    HEAVY-CALIBER damage reporter for MALDEN MAKEOVER shells -- client side, installed once at init
    (initPlayerLocal). Dynamically spawned buildings never enter the engine's projectile-damage pipeline
    AND bullets are local to the SHOOTER's machine, so the server can't see them: this taps the shooter's
    own projectiles (ProjectileCreated -> per-projectile HitPart), keeps only hits on maldened shells from
    heavy rounds (ammo `hit` >= 15: .338/12.7mm class; rifle calibers stay useless like on terrain houses),
    batches 2s, and reports [house, rounds, sumHit] to APS_fnc_maldenSRV mode "bullets" (which re-verifies
    range/rate server-side -- the client is a SENSOR, not an authority).
    Cost: ~microseconds per shot fired, one small message per 2s ONLY while actually shooting a shell.
*/
if (!hasInterface) exitWith {};
if (!isNil "AP_maldenBulletsUp") exitWith {};
AP_maldenBulletsUp = true;
AP_maldenHits = [];

// NB: ProjectileCreated passes ONE param, the projectile itself (a 2-param read left _proj nil and killed
// the EH body on every shot -- the "100 rounds, nothing" bug).
addMissionEventHandler ["ProjectileCreated", {params ["_proj"];
    if (isNull _proj) exitWith {};
    // stamp the ammo class now -- the projectile ref can be null inside a post-impact EH read
    _proj setVariable ["AP_ammo", typeOf _proj];
    _proj addEventHandler ["HitPart", {params ["_proj", "_hitObj"];
        if (!isNull _hitObj && {_hitObj getVariable ["AP_malden", false]}) then {
            private _hit = getNumber (configFile >> "CfgAmmo" >> (_proj getVariable ["AP_ammo", ""]) >> "hit");
            if (_hit >= 15) then { AP_maldenHits pushBack [_hitObj, _hit]; };};}];}];

// 2s batcher: one report per house per window
[] spawn {while {true} do {uiSleep 2;
        if (AP_maldenHits isNotEqualTo []) then {private _batch = AP_maldenHits;
            AP_maldenHits = [];
            private _byHouse = createHashMap; {_x params ["_h", "_hit"];
                private _k = hashValue _h;
                private _e = _byHouse getOrDefault [_k, [_h, 0, 0]];
                _e set [1, (_e select 1) + 1];
                _e set [2, (_e select 2) + _hit];
                _byHouse set [_k, _e];} forEach _batch; {_y params ["_h", "_n", "_sum"];
                if (!isNull _h) then {[["bullets", player, _h, _n, _sum], "APS_fnc_maldenSRV", 2] call AP_fnc_MP;};} forEach _byHouse;};
    };};
