/*
    Create the six cartel flags and their capture markers. Server-side, global, JIP-persistent.

    WHY THIS EXISTS: the inherited cartel system addresses its flags as NAMED GLOBAL OBJECTS
    (arms_flag, drug_flag, oil_flag, wongs_flag) placed in the Altis mission.sqm, and its capture
    menu reads positions from MARKERS named arms_cartel / drug_cartel / oil_cartel / wongs_cartel.
    Malden's mission.sqm has neither -- the designer marked the six cartels with plain mil_flag
    markers and nothing else. Every one of those globals is therefore undefined here, and an
    undefined variable THROWS in SQF rather than reading as null, so the whole cartel stack was dead.

    RUN ORDER MATTERS: this must execute BEFORE AP_server/init.sqf, whose cartel jobs
    (cartelOwnSave, oilRubber, the auto-deposit loop) `waitUntil` on these flag objects existing.
    initServer calls it immediately before spawning the server core.

    LEGACY ALIASES: four of the six also get the old Altis global name pointing at the SAME object.
    That is what lets ~30 untouched call sites -- fn_getDiscount, fn_buyClothes, fn_equipLoadout,
    fn_weaponShopMenu, fn_virtualShopMenu/Manage, fn_factory, fn_craftRecipe, fn_ncShop,
    fn_processAction, fn_processVehicle, fn_placeObject, fn_onPlayerKilled, fn_spawnPointCfg --
    keep working against the new roster with no edit. The mapping is by ROLE, not by name:
        arms_flag  -> Blacksite  (rebel money + illegal-goods discount)
        drug_flag  -> Ashfall    (narcotics production)
        oil_flag   -> Boomtown   (oil + rubber, free gas)
        wongs_flag -> Bayview    (Wong's revenue)
    Grimstone and Wreckridge are new and have no legacy alias.
*/
if (!isServer) exitWith {};

private _roster = [] call AP_fnc_cartelCfg;
private _made = 0;

{
    _x params ["_id", "_name", "_flagVar", "_markerName", "_pos", "_legacy", "_payout", "_perk"];

    // ---- capture marker ----------------------------------------------------------------------
    // The capture menu resolves a cartel's position with getMarkerPos, and a MISSING marker returns
    // [0,0,0] silently rather than erroring -- which would put every cartel on the debug island.
    deleteMarker _markerName;
    createMarker [_markerName, _pos];
    _markerName setMarkerShape "ICON";
    _markerName setMarkerType "mil_flag";
    _markerName setMarkerColor "ColorEAST";
    _markerName setMarkerText _name;

    // ---- flag object -------------------------------------------------------------------------
    private _old = missionNamespace getVariable [_flagVar, objNull];
    if (!isNull _old) then { deleteVehicle _old; };   // a reload must not stack flags

    // PortableFlagPole_01_F: the class the map designer already used at these six spots. The
    // duplicate decorative copies were removed from allLocalMapEntities (they had been swept into it
    // by the sqm export and spawn client-local, so the server cannot own one) -- this is now the
    // ONLY flag at each cartel, and it is a real networked object the server can hold AP_capData on.
    private _flag = createVehicle ["PortableFlagPole_01_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
    _flag setPosATL [_pos select 0, _pos select 1, 0];
    _flag allowDamage false;
    _flag enableSimulationGlobal false;
    // tag it so fn_cleanup's ownerless-object reap cannot delete it (it deletes anything without
    // an `owner` variable -- a documented way custom objects have vanished before)
    _flag setVariable ["owner", "cartel", true];
    _flag setVariable ["AP_cartelId", _id, true];

    // Neutral until captured, or until cartelOwnSave restores the DB row at boot. Seeded here so
    // the many `getVariable ["AP_capData", ...]` reads have a real value from the first frame.
    if (isNil { _flag getVariable "AP_capData" }) then {
        _flag setVariable ["AP_capData", [0, "Neutral", 0], true];
    };

    missionNamespace setVariable [_flagVar, _flag, true];
    if (_legacy isNotEqualTo "") then {
        missionNamespace setVariable [_legacy, _flag, true];
        // legacy MARKER alias too (arms_cartel/drug_cartel/oil_cartel/wongs_cartel), for any code
        // still naming the Altis cartels rather than reading the config
        private _lm = (_legacy select [0, (count _legacy) - 5]) + "_cartel";
        deleteMarker _lm; createMarker [_lm, _pos];
        _lm setMarkerShape "ICON"; _lm setMarkerType "mil_dot"; _lm setMarkerAlpha 0;
    };

    _made = _made + 1;
    diag_log format ["[Armapunk2035][cartel] %1 (%2) flag at %3  marker '%4'%5",
        _name, _flagVar, _pos, _markerName,
        if (_legacy isEqualTo "") then { "" } else { format ["  alias %1", _legacy] }];
} forEach _roster;

diag_log format ["[Armapunk2035][cartel] %1 of %2 cartel flags created", _made, count _roster];

// ---- remove the designer's duplicate cartel icons ------------------------------------------------
// The sqm already carries a static mil_flag marker at each cartel (marker_25..32: Ashfall,
// Wreckridge, Boomtown, Bayview, Blacksite, Grimstone), so every site was showing TWO icons once we
// added <id>_cartel. Ours has to be the survivor, not theirs: AP_fnc_captureCartel writes live
// ownership into format["%1_cartel", id] ("Grimstone - <gang>", "... (Contested)"), so the
// designer's static label can never update.
// Matched by POSITION and type rather than by marker_NN name, so a designer re-export that renumbers
// its markers does not quietly bring the duplicates back.
private _mine = _roster apply { _x select 3 };
private _dropped = 0;
{
    private _cpos = _x select 4;
    {
        if (!(_x in _mine) && {(markerType _x) isEqualTo "mil_flag"} && {(getMarkerPos _x) distance2D _cpos < 60}) then {
            deleteMarker _x; _dropped = _dropped + 1;
        };
    } forEach allMapMarkers;
} forEach _roster;
diag_log format ["[Armapunk2035][cartel] removed %1 duplicate designer cartel markers", _dropped];

// ---- ALTIS TURF SYSTEM: OFF --------------------------------------------------------------------
// Rodopoli / Zaros / Panagia are Altis towns. Malden has no equivalent and the designer marked no
// turfs, so the three-turf rotation is retired here. Rather than surgically delete it from the ~25
// files that consult it (gathering, crafting, robbery, chop shop, the turf shop/dealer/vehicle NPCs,
// spawn gating, shop pricing), publish the three flag globals as objNull:
//   * `count [rodo_flag, zaros_flag, panagia_flag]` style checks evaluate to 0 = no active turf
//   * `objNull getVariable ["AP_turf_data", <default>]` returns the DEFAULT, so every ownership
//     test cleanly reads "not owned" instead of throwing
// An UNDEFINED variable throws and aborts the enclosing script; objNull does not. That difference is
// the entire bug behind the rodo_flag errors in AP_server/init.sqf:676 and fn_queryCaptures.
// The turf scheduler and its DB restore are disabled at source (AP_turfSystem) -- see
// AP_server/init.sqf and core/DB/fn_queryCaptures.sqf.
AP_turfSystem = false; publicVariable "AP_turfSystem";
// Same treatment for the Mental Asylum gates: AP_mentalGate1/2/3 are Altis sqm objects that
// fn_loonyBinSRV reads unconditionally, throwing on every boot here.
{ missionNamespace setVariable [_x, objNull, true]; } forEach
    ["rodo_flag", "zaros_flag", "panagia_flag", "AP_mentalGate1", "AP_mentalGate2", "AP_mentalGate3"];
diag_log "[Armapunk2035][cartel] Altis turf system disabled (rodo/zaros/panagia -> objNull)";
