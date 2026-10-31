params[["_medic", objNull, [objNull]], ["_hospital", false, [false]], ["_admin", false, [false]], ["_copMedic", false, [false]], ["_nextRevive", -1000, [0]]];
if !(AP_isDead) exitWith {};
AP_respawned = true;
private _gear =
if (AP_effSide isEqualTo west && {AP_activeMAXTAC || AP_eviSpawn}) then[{AP_deadcop_gear}, {AP_dead_gear}];
[_gear] call AP_fnc_loadDeadGear;
// LooneyBin: guard radioChannelInfo on the unset (String "") AP_radio_civ — see fn_spawnConfirm.
if (AP_sidechat && (AP_effSide isEqualTo civilian) && (AP_radio_civ isEqualType 0) && {!(player in ((radioChannelInfo AP_radio_civ) param[3, []]))}) then {
    [AP_sidechat] call AP_fnc_manageSidechat;};
// owner 2026-09-16 (body drag): admin, drone and hospital revives never pass fn_revivePlayer's "being moved"
// refusal, so a body can still be attached to a dragger here. Detach it (argument- and effect-global, this
// machine is enough) and clear the dragger's name before anything reads the body's position. The dragger's
// watchdog then releases as "detached-externally" and the revived player is placed where the body was
// dragged to, which is intended. The body is NOT repositioned here: the dragger's CONTINUOUS CLAMP keeps its
// position on his side of walls on every tick (fn_dragBody header, with its accepted residuals).
if (!(isNull AP_corpse) && {!(isNull attachedTo AP_corpse)}) then {
    detach AP_corpse;
    AP_corpse setVariable ["AP_draggedBy", nil, true];
};
if (_hospital) then {cutText["You wake up at a hospital, feeling much better.", "BLACK FADED"];
    0 cutFadeOut 6;
    private _hospitalLocations = ["revive", "revive_1", "revive_2", "revive_3", "revive_4"];
    private _nearestHospital = [_hospitalLocations, AP_corpse] call BIS_fnc_nearestPosition;
    player setPos(markerPos _nearestHospital);
    player setDir(markerDir _nearestHospital); [
        ["-REVIVE-", player, profileName, format["respawned at the hospital, POS: %1", getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
} else {
    // LooneyBin: a DOWNED (not dead) player never had AP_corpse set -> visiblePositionASL objNull =
    // [0,0,0] = debug island. Only teleport to a VALID corpse; else leave them where they were downed.
    if (!isNull AP_corpse && {!((getPosATL AP_corpse) isEqualTo [0,0,0])}) then {player setDir(getDir AP_corpse);
        player setPosASL(visiblePositionASL AP_corpse);};
    if (_admin) then {titleText[format["The admin %1 has revived you.", [name _medic] call AP_fnc_cleanName], "PLAIN"];
        if !(isNull(findDisplay 7300)) then {(findDisplay 7300) closeDisplay 0;};
        if !(isNull(findDisplay 938800)) then {(findDisplay 938800) closeDisplay 0;};} else {if (AP_effSide isEqualTo civilian && {
            player getVariable["AP_lowtime", false]}) then {
            [format["Due to being a newer player you've only been charged $300 for these services. In the future you will have to pay $%1 for these same services.", [call(AP_revive_fee)] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
        } else {
            [format["%1 has revived you and a fee of $%2 was taken from your bank account for their services.", [name _medic] call AP_fnc_cleanName, [call(AP_revive_fee)] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
        };}; [
        ["-REVIVE-", player, profileName, format["was revived by %1 (%2), POS: %3", name _medic, getPlayerUID _medic, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
};
// LooneyBin: force-close the DeathScreen (display 7300) on EVERY revive path. It was only explicitly closed
// on the _admin branch above; a normal medic/drone revive relied solely on the closeDialog 0 below, which
// misses if another dialog is focused -> the death screen stayed open while the player was alive again, and
// the handleDowned guard (checks isNull findDisplay 7300) then early-exited forever = "can't be downed at
// all" (the Torch/Nikki bug). Belt-and-suspenders with closeDialog 0.
// owner 2026-09-11: 938800 is the web death screen. The note above is why this line exists
// at all -- a death screen left open on a living player permanently fails fn_handleDowned's
// guard -- and that failure is display-agnostic, so both ids are closed here.
if !(isNull (findDisplay 7300))   then { (findDisplay 7300)   closeDisplay 0; };
if !(isNull (findDisplay 938800)) then { (findDisplay 938800) closeDisplay 0; };
closeDialog 0;
AP_deathCamera cameraEffect["TERMINATE", "BACK"];
camDestroy AP_deathCamera;
if (!_hospital && !_admin) then {private _cost =
    if ((side _medic) in [independent, west]) then {call AP_revive_fee} else {(call AP_revive_fee) + 1000};
    if (AP_effSide isEqualTo civilian && {player getVariable["AP_lowtime", false]}) then {
        [format["Due to being a newer player you've only been charged $300 for these services. In the future you will have to pay $%1 for these same services.", [_cost] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
        _cost = 300;};
    if (AP_atmcash > _cost) then {AP_atmcash = AP_atmcash - _cost;
        AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
        [1] call AP_fnc_ClupdatePartial;} else {AP_atmcash = 0;
        AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
        [1] call AP_fnc_ClupdatePartial;};};
if !(isNull _medic) then {["revived", "bymedic", 1] spawn AP_fnc_handleQuest;
    private _toSend = (allPlayers - [allDeadMen] - [player]) select {
        (side _x isEqualTo west && _x getVariable["AP_unitCopRole", ""] in ["medic", "all"]) || side _x isEqualTo independent}; [
        [player, _medic], "AP_fnc_medicRespondDone", _toSend] spawn AP_fnc_MP;};
if (!isNull _medic && AP_effSide != independent && !_hospital) then {
    // LooneyBin: the _copMedic exemption (4th arg) was DEAD -- every caller hardcodes false, so cop-medics were wrongly
    // penalized. Only CIVILIAN (amateur) revives should sting; EMS (independent, gated on L91) + all cops (who can only
    // revive via the medic/SCD talent anyway) stay exempt -> keeps real medics worth paying for.
    if (!_admin && side _medic isEqualTo civilian) then {[] spawn {
            player setVariable["AP_can_revive", (player getVariable["AP_can_revive", time]) + 600, true];
            private _plb_dmg = player;
            _plb_dmg setDamage 0.25;
            if (17 in AP_infamy_talents && license_civ_rebel && (random 10) < 1.5) exitWith {
                systemChat "You have been revived by an unprofessional. But you do not feel weakened.";};
            AP_revive_fatigue = time + 40;
            systemChat "You have been revived by an unprofessional. You feel weakened.";
            player forceWalk true;
            while {alive player && (time < AP_revive_fatigue)}
            do {if (getFatigue player < 0.9) then {player setFatigue 1;};
                uiSleep 1.5;}; if (alive player) then {systemChat "You feel a bit better now.";};
            player setFatigue 0.5;
            AP_revive_fatigue = 0;
            player forceWalk false;};};};
if !(isNil "AP_suicide") then {AP_suicide = nil}; {if !(isNil {player getVariable _x}) then {player setVariable[_x, nil, true];};}
forEach["AP_revivable", "AP_reviving", "AP_executing"];
if (AP_copRole in ["all", "medic"] && {20 in AP_cop_talents}) then {_nextRevive = time + 120};
if (16 in AP_infamy_talents && license_civ_rebel) then {_nextRevive = time + 120};
if (AP_effSide isEqualTo independent) then { _nextRevive = -1000; };
player setVariable["AP_next_revive", _nextRevive, true];
AP_isDead = false; localNamespace setVariable ["AP_isDead", false];
[] call AP_fnc_hudUpdate;
player switchMove "amovppnemstpsnonwnondnon";
[] spawn {uiSleep 3;
    [] call AP_fnc_ClupdateRequest;};
