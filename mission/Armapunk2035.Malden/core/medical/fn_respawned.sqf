AP_use_atm = true;
APV_hunger = 100;
APV_thirst = 100;
AP_carryWeight = 0;
AP_preRespawnUniformBackpackSkins = AP_uniformBackpack_skins;
AP_uniformBackpack_skins = [-1, -1];
AP_respawned = true;
AP_isDead = false; localNamespace setVariable ["AP_isDead", false];
if !(AP_effSide isEqualTo west) then {AP_cash = 0;
    AP_cashCacheB = ((AP_cash / 4) + 9);};
player playMove "amovpercmstpsnonwnondnon"; {if !(isNil {player getVariable _x}) then {player setVariable[_x, nil, true];};}
forEach["AP_revivable", "AP_reviving", "AP_executing"];
private _handle = scriptNull;
// FACTION REWORK (2026-08-19): THIS DISPATCH IS ALREADY THE DUTY DISPATCH -- checked, not assumed, and
// written down so the next reader does not re-derive it. PR2 moved the switch off playerSide onto
// AP_effSide, and AP_effSide is exactly what AP_fnc_dutyContext sets to the faction's side for the length
// of a shift. The two duty rows' defaultLoadoutCode (fn_dutyCfg.sqf:41, :47) are literally
// {[] call AP_fnc_copLoadout} and {[] call AP_fnc_medicLoadout}, i.e. these same two branches, so routing
// through the cfg row here would add a dependency and change nothing. Neither loadout function reads
// `side player`; both are driven off AP_copRole / AP_cop_talents / AP_side_talents, all of which
// AP_fnc_dutyClient loads from the duty character before the shift starts. A duty officer therefore
// respawns in their FACTION kit, and an off-duty player -- AP_effSide civilian, on duty or not in this
// tree's whole history -- still gets AP_fnc_civLoadout, untouched.
// The faction DEFAULT is also the right kit rather than the pre-death one: death resets gear on purpose
// (fn_onPlayerKilled strips the unit, and modes 11/12/13 write the reset packet back), which is the same
// deal a login-side cop or medic has always had.
switch (AP_effSide) do {case west: {_handle = [] spawn AP_fnc_copLoadout};
    case civilian: {_handle = [] spawn AP_fnc_civLoadout};
    case independent: {_handle = [] spawn AP_fnc_medicLoadout};}; waitUntil {scriptDone _handle};
AP_deathCamera cameraEffect["TERMINATE", "BACK"];
camDestroy AP_deathCamera;
if ((AP_is_arrested param [0,0]) isEqualTo 1) exitWith {AP_is_arrested set[0, 0];
    [player, false] spawn AP_fnc_jailPlayer;
    [] call AP_fnc_ClupdateRequest;};
[] call AP_fnc_ClupdateRequest;
[] call AP_fnc_hudUpdate;

// owner 2026-07-12: everyone carries a GPS -- the map's G-search / route HUD is gated on it
if !("ItemGPS" in assignedItems player) then { player linkItem "ItemGPS"; };
