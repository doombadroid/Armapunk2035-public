/*
    AP_fnc_loveBombHeal -- LooneyBin (owner 2026-06-11): runs on each player within 1km of an Ultimate
    Healing Sunshine Love Bomb (remoteExec'd by APS_fnc_loveBombSRV). Heal to full + revive if downed, and
    go briefly invincible so the (cosmetic) blast can't hurt you.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
if (!alive player) exitWith {};   // fully dead -> respawns on its own
player allowDamage false;
// stay invincible long enough to ride out the blast + the building collapse/debris before re-enabling damage --
// this protects against the cosmetic explosion itself, so it runs even if the heal below is blocked.
[] spawn { uiSleep 15; if (alive player) then { player allowDamage true; }; };

// Black Lace: the heal (and the down-recovery bundled with it) is suppressed while blocked. Genuine revival
// (defibrillator, drone revive, a medic's civilian revive) is a separate code path and is untouched by this.
if ([player] call AP_fnc_healBlocked) exitWith {
    ["You feel the Love Bomb's warmth, but something in your system won't let it heal you.", "basic"] spawn AP_fnc_handleMessage;
};

player setDamage 0;

// revive if incapacitated/downed
if (AP_isDowned || {player getVariable ["AP_revivable", false]} || {player getVariable ["AP_reviving", false]}) then {
    AP_isDowned = false;
    AP_isDead = false; localNamespace setVariable ["AP_isDead", false];
    // owner 2026-09-11: close whichever death screen is up. Only one can be, so the other
    // closeDisplay is a no-op on a null display.
    if !(isNull (findDisplay 7300))   then { (findDisplay 7300)   closeDisplay 0; };
    if !(isNull (findDisplay 938800)) then { (findDisplay 938800) closeDisplay 0; };
    closeDialog 0;
    { player setVariable [_x, nil, true]; } forEach ["AP_revivable", "AP_reviving", "AP_executing"];
    player setUnconscious false;
    player setDamage 0;
    player switchMove "amovppnemstpsnonwnondnon";
    [] call AP_fnc_hudUpdate;};

player setDamage 0;
["<t color='#ff66cc' size='1.3'>You feel the Sunshine Love!</t><br/>The Ultimate Healing Sunshine Love Bomb healed you to full health.", "basic"] spawn AP_fnc_handleMessage;
