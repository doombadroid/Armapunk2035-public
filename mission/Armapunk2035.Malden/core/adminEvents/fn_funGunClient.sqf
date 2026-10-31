/*
    AP_fnc_funGunClient  (LooneyBin -- admin-event FUN GUN, CLIENT effect)
    Server (APS_fnc_funGunSRV, admin-gated) remoteExecs this onto every player:
      ["lynx"]      -> GM6 (.50 anti-materiel) + UNLIMITED ammo + RAPID AUTO (hold LEFT MOUSE)
      ["subcannon"] -> same, and every shot fires a NETWORKED SDV submarine out of the muzzle
      ["off"]       -> remove the guns/handlers, stop the auto loop
    Local effects only (Fired EH / forceWeaponFire / mouse EH). Sub spawns are done SERVER-side
    (networked, visible to everyone) via a Fired EH that calls APS_fnc_funGunSRV ["spawnsub",...].
    Whitelisted server->client (CfgRE allowedTargets=1).
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_mode", "", [""]]];

// -- tear down any prior state (re-grant / mode switch / off) --
if (!isNil "AP_funGunAmmoEH") then { player removeEventHandler ["Fired", AP_funGunAmmoEH]; AP_funGunAmmoEH = nil; };
if (!isNil "AP_funGunSubEH")  then { player removeEventHandler ["Fired", AP_funGunSubEH];  AP_funGunSubEH = nil; };
AP_funGun_auto   = false;   // stops any running rapid-fire loop
AP_funGun_firing = false;

if (toLower _mode isEqualTo "off") exitWith {["Fun gun disabled.", "info"] spawn AP_fnc_handleMessage;};
if (!alive player) exitWith {};

// -- give the Lynx + scope + a mag --
if !("srifle_GM6_F" in (weapons player)) then {player addWeapon "srifle_GM6_F";
    player addPrimaryWeaponItem "optic_LRPS";
    player selectWeapon "srifle_GM6_F";};
if (({_x isEqualTo "5Rnd_127x108_Mag"} count (magazines player)) < 1) then { player addMagazine "5Rnd_127x108_Mag"; };

// -- SUB CANNON also gets the SMG_02 (Sting): native full-auto -> rapid-fire submarine hose --
if (toLower _mode isEqualTo "subcannon") then {if !("SMG_02_F" in (weapons player)) then {player addWeapon "SMG_02_F";
        player selectWeapon "SMG_02_F";                                  // start on the fast one
    };
    if (({_x isEqualTo "30Rnd_45ACP_Mag_SMG_02"} count (magazines player)) < 1) then { player addMagazine "30Rnd_45ACP_Mag_SMG_02"; };};

// -- UNLIMITED ammo: refill whichever weapon just fired (covers GM6 + Sting) --
AP_funGunAmmoEH = player addEventHandler ["Fired", { params ["_u", "_wep"]; _u setAmmo [_wep, 30]; }];

// -- SUB CANNON: each shot asks the server to spawn a networked SDV out the muzzle.
//    8 m stand-off + the server's high launch speed keep back-to-back subs from colliding. --
if (toLower _mode isEqualTo "subcannon") then {AP_funGunSubEH = player addEventHandler ["Fired", {params ["_u", "_wep"];
        private _dir = _u weaponDirection _wep;
        private _pos = (eyePos _u) vectorAdd (_dir vectorMultiply 8);
        [["spawnsub", _pos, _dir], "APS_fnc_funGunSRV", 2, false, false] spawn AP_fnc_MP;}];};

// -- RAPID AUTO: forceWeaponFire in a loop while LEFT MOUSE is held (bolt gun -> full-auto feel) --
// hook the mouse ONCE per session (a re-grant reuses the same flags)
if (isNil "AP_funGun_mouseHooked") then {AP_funGun_mouseHooked = true;
    private _disp = findDisplay 46;
    _disp displayAddEventHandler ["MouseButtonDown", { if ((_this select 1) isEqualTo 0) then { AP_funGun_firing = true  }; false }];
    _disp displayAddEventHandler ["MouseButtonUp",   { if ((_this select 1) isEqualTo 0) then { AP_funGun_firing = false }; false }];};
AP_funGun_auto = true;
[] spawn {while { AP_funGun_auto } do {
        if (AP_funGun_firing && {alive player} && {(currentWeapon player) isEqualTo "srifle_GM6_F"}) then {
            player forceWeaponFire [currentWeapon player, currentWeaponMode player];};
        sleep 0.05;   // ~20 shots/sec
    };};

[format ["FUN GUN: %1 -- unlimited ammo + rapid auto. Hold LEFT MOUSE!", toUpper _mode], "info"] spawn AP_fnc_handleMessage;
