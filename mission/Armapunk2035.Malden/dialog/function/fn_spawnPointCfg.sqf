private _return = [];
params[["_side", civilian, [civilian]], ["_isRedeploy", false, [false]], ["_withReasons", false, [false]]];
// owner 2026-09-11: _withReasons is the web spawn screen's flag (AP_fnc_spawnPointList). OFF it changes
// NOTHING -- every row is the same two-element [id, label] the native menu (dialog 38500) has always read,
// and every row this builder used to drop is still dropped. ON, a row that is merely UNUSABLE is KEPT and
// carries a third element: the reason, "" when the point is fine. The distinction matters: a turf you do
// not hold or a governor office you were not elected to is not a spawn point at all and is still absent,
// while your own house inside an active war zone is a spawn point you cannot use right now and says so.
// The reasons for turf / cartel / heist are deliberately generic -- naming the event would tell a spawning
// player where a live heist is, which dropping the row never did.
// owner 2026-07-31: Malden cop spawns. The seven Altis entries (Kavala HQ...) pointed at markers
// that were never on this map, so every row dropped the spawning cop at [0,0,0] in the sea -- the
// same dead-row trap the civ comment below documents. List ONLY markers that exist in mission.sqm;
// the five below were placed from the designer's own police-station markers (La Trinite is a
// Sheriff's Office the owner built NE of town, 2026-07-31).
switch (_side) do {case west: {_return = [["cop_spawn_1", "La Trinite Sheriff's Office"], ["cop_spawn_2", "Emergency Response HQ"],
                ["cop_spawn_3", "La Port PD"], ["cop_spawn_4", "Chapoi PD"], ["cop_spawn_5", "La Pessagne PD"]];
            if !(isNull(SRV_mobileHQ select 1)) then {if !(speed(SRV_mobileHQ select 1) > 0) then {
                    private _spawnPoint = getPos(SRV_mobileHQ select 1);
                    _spawnPoint set[0, (_spawnPoint select 0) + 1.5];
                    _spawnPoint set[1, (_spawnPoint select 1) + 1.5];
                    _return pushBack[_spawnPoint, "Mobile HQ"];};};};
    case civilian: {// Malden: the Altis spawn markers (civ_spawn_2/3/4, donor_town) are not in this mission.sqm.
        // civ_spawn_1 is created at runtime from the world config by custom_p3ds/malden_markers.sqf.
        // Listing a marker that does not exist puts a dead row in the spawn menu that drops the player at [0,0,0].
        // owner 2026-07-30: Larche added. civ_spawn_2 is the town's menu entry and fallback point; the
        // five lh_civspawn_* scatter markers it spawns onto are placed in the map layer and read by
        // fn_spawnConfirm's table. Both markers are in mission.sqm, so neither is a runtime creation.
        // owner 2026-09-11: the other three towns. Each row's marker AND its five <town>_cspawn_*
        // scatter markers are in the map layer; the scatter points were not placed by eye -- every
        // one of them was found by debug\probe_townspawn.sqf, which walks a 12 m grid over the town
        // and keeps only the squares where the engine says a player stands on open ground (no roof
        // overhead, no wall within 1.2 m, flat, dry). fn_spawnConfirm's table picks one at random.
        _return = [["civ_spawn_1", "La Trinite"], ["civ_spawn_2", "Larche"], ["civ_spawn_3", "La Port"],
                ["civ_spawn_4", "Chapoi"], ["civ_spawn_5", "La Pessagne"]];
            if (AP_houses isNotEqualTo[]) then {{private _pos = parseSimpleArray(_x select 0);
                    private _notInActiveTurf = ({
                        _pos distance(getPos _x) <= 800 && (_x getVariable["AP_turf_data", [-1, "Unknown", false, "Unknown"]] select 2)}
                    count[rodo_flag, zaros_flag, panagia_flag] isEqualTo 0);
                    private _notInCartelOrWarzone = (({_pos distance(getPos _x) <= 600}
                    count[arms_flag, drug_flag, wongs_flag, oil_flag] isEqualTo 0));
                    // owner 2026-07-28: was getMarkerPos "AP_jewelryEmporiumMarker". That marker does NOT
                    // exist on Malden -- zero hits in mission.sqm and nowhere else in the tree -- so
                    // getMarkerPos returned [0,0,0], roughly 13 km from every Malden spawn, the <= 800 test
                    // was never true and the whole anti-spawn-camp rule was dead: during the 20-minute
                    // window the crew's gang could house-spawn straight into the emporium, and so could
                    // responding cops. Every other heist has this rule. AP_JEWEL_CENTRE is the server's
                    // published emporium centre (publicVariable'd in APS_fnc_maldenJewelSRV). Read GUARDED:
                    // the [0,0,0] default reproduces exactly today's behaviour on a client that has not yet
                    // received the publish, rather than raising inside a spawn-menu builder.
                    private _notInActiveJewelry = !((_pos distance2D (missionNamespace getVariable ["AP_JEWEL_CENTRE", [0,0,0]]) <= 800) && ((missionNamespace getVariable ["SRV_jewelryEmporiumSRV", [false,false]]) param[1, false]));
                    private _blk = "";
                    if (!_notInActiveTurf || {!_notInCartelOrWarzone}) then { _blk = "CONTESTED -- ACTIVE WAR ZONE"; };
                    if (_blk isEqualTo "" && {!_notInActiveJewelry}) then { _blk = "CONTESTED -- ACTIVE HEIST"; };
                    if (_withReasons || {_blk isEqualTo ""}) then {
                        // owner 2026-07-04: pick the nearest House whose TYPE is a real house type, NOT a bare
                        // param[0]. At a buyable-shed spot the derelict Land_u_Shed_Ind_F sits on the intact
                        // Land_i_Shed_Ind_F (both "House", both dist 0); param[0] grabbed the derelict, whose type
                        // is NOT in AP_houseTypes -> the shed was silently dropped from the spawn list (house menu
                        // worked because ownership is tagged on the intact, but this builder re-resolves by nearest).
                        private _house = ((nearestObjects[_pos, ["House"], 10]) select { (typeOf _x) in AP_houseTypes }) param[0, objNull];
                        if !(isNull _house) then {
                            private _cn = _house getVariable ["AP_houseName", ""];   // owner 2026-07-10: player-set house name
                            private _houseName =
                            if (_house getVariable["AP_house_gang", -1] isNotEqualTo - 1) then {"Gang Building"} else {
                                if (_cn isEqualTo "") then { getText(configFile >> "CfgVehicles" >> typeOf _house >> "displayName") } else { _cn }
                            };
                            private _houseType = typeOf _house;
                            // owner 2026-09-11: the tax test was fused into this condition. Split, so the tax
                            // block is a REASON and not an identical-looking disappearance: a type that is not a
                            // house type is not a spawn point (still dropped), an unpaid house is one you cannot
                            // use (kept and labelled under _withReasons).
                            if (_houseType in AP_houseTypes) then {
                                private _r = _blk;
                                if (_r isEqualTo "" && {(_house getVariable["AP_house_tax", [false]]) select 0}) then { _r = "TAXES UNPAID"; };
                                if (_withReasons || {_r isEqualTo ""}) then {
                                    private _row = [format["phouse_%1", _house getVariable ["AP_houseID", _x select 1]], _houseName];
                                    if (_withReasons) then { _row set [2, _r]; };
                                    _return pushBack _row;};};};};}
                forEach AP_houses;};
            // owner 2026-06-18 (#343/344/345/347): gang-building spawn REWRITTEN. Driven off the PERSISTED gang HQ
            // pos (AP_gang_data param 3, synced from gangs.house_pos to EVERY member) so ANY member can spawn there
            // even with the building's owner OFFLINE -- was keyed to the AP_gangBuilding OBJECT (nil when the owner
            // is away) AND pushed a spawn name (phouse_<gid><uid>) that matched NO marker -> getMarkerPos [0,0,0] ->
            // "Error/ocean". Spawn point is now "gangbldg", resolved to the HQ pos in fn_spawnConfirm (no marker dep).
            // Dedup is a real findIf (the old `... forEach _return) >= 0` returned only the LAST element's find ->
            // 50/50 show/hide). Still hidden during a nearby active turf/cartel/fortress/jewelry event (owner: keep).
            // Tax check is best-effort -- the building object may not be loaded when you're far / owner offline, so a
            // not-found building defaults to ALLOWING the spawn.
            if !((AP_gang_data param[3, [0, 0, 0]]) isEqualTo[0, 0, 0]) then {private _pos = AP_gang_data select 3;
                private _alreadyListed = (_return findIf { ((_x param[1, ""]) find "Gang Building") >= 0 }) >= 0;
                if (!_alreadyListed) then {private _notInActiveTurf = ({
                        _pos distance(getPos _x) <= 800 && (_x getVariable["AP_turf_data", [-1, "Unknown", false, "Unknown"]] select 2)}
                    count[rodo_flag, zaros_flag, panagia_flag] isEqualTo 0);
                    private _notInCartelOrWarzone = (({_pos distance(getPos _x) <= 600}
                    count[arms_flag, drug_flag, wongs_flag, oil_flag] isEqualTo 0));
                    // owner 2026-07-28: was getMarkerPos "AP_jewelryEmporiumMarker". That marker does NOT
                    // exist on Malden -- zero hits in mission.sqm and nowhere else in the tree -- so
                    // getMarkerPos returned [0,0,0], roughly 13 km from every Malden spawn, the <= 800 test
                    // was never true and the whole anti-spawn-camp rule was dead: during the 20-minute
                    // window the crew's gang could house-spawn straight into the emporium, and so could
                    // responding cops. Every other heist has this rule. AP_JEWEL_CENTRE is the server's
                    // published emporium centre (publicVariable'd in APS_fnc_maldenJewelSRV). Read GUARDED:
                    // the [0,0,0] default reproduces exactly today's behaviour on a client that has not yet
                    // received the publish, rather than raising inside a spawn-menu builder.
                    private _notInActiveJewelry = !((_pos distance2D (missionNamespace getVariable ["AP_JEWEL_CENTRE", [0,0,0]]) <= 800) && ((missionNamespace getVariable ["SRV_jewelryEmporiumSRV", [false,false]]) param[1, false]));
                    private _ghc = nearestObjects[_pos, ["House"], 18, true];
                    private _gh = (_ghc select { (typeOf _x) in AP_houseTypes }) param [0, (_ghc param [0, objNull])];   // owner 2026-07-09: shed-proof resolve (twin of fn_spawnConfirm)
                    private _taxOk = isNull _gh || !((_gh getVariable["AP_house_tax", [false]]) select 0);
                    // owner 2026-09-11: same split as the house loop above -- the four tests become a reason
                    // instead of a silent disappearance when _withReasons is on. Order matches the house loop
                    // so the two cannot report the same state differently.
                    private _r = "";
                    if (!_notInActiveTurf || {!_notInCartelOrWarzone}) then { _r = "CONTESTED -- ACTIVE WAR ZONE"; };
                    if (_r isEqualTo "" && {!_notInActiveJewelry}) then { _r = "CONTESTED -- ACTIVE HEIST"; };
                    if (_r isEqualTo "" && {!_taxOk}) then { _r = "TAXES UNPAID"; };
                    if (_withReasons || {_r isEqualTo ""}) then {
                        private _row = ["gangbldg", "Gang Building"];
                        if (_withReasons) then { _row set [2, _r]; };
                        _return pushBack _row;};};}; {
                if ((AP_gang_data select 0) isEqualTo(_x getVariable["AP_turf_data", [-1, "Unknown", false, "Unknown"]] select 0) && !(_x getVariable["AP_turf_data", [-1, "Unknown", false, "Unknown"]] select 2)) then {
                    private _text =
                    switch (_forEachIndex) do {case 0: {"Rodopoli"};
                        case 1: {"Zaros"};
                        case 2: {"Panagia"};}; _return pushBack[format["turf_label_%1", _x], _text];};}
            forEach[rodo_flag, zaros_flag, panagia_flag];
            if (getPlayerUID player isEqualTo(SRV_governorData param[0, "GovUID"])) then {_return pushBack["gov", "Governor Office"];};
            // AP_gangBoatFortressObject is defined NOWHERE on this map -- fn_zoneCreator.sqf
            // says so at length and guards its own read. This site was missed, so opening the
            // spawn menu threw "Undefined variable in expression" on every client. Same guard,
            // same reasoning: drop the anchor in and the Gang Boat spawn returns by itself.
            private _boatAnchor = missionNamespace getVariable ["AP_gangBoatFortressObject", objNull];
            private _boatData = _boatAnchor getVariable ["AP_gang_fortress_data", [-1, "Uncontrolled", false]];
            if (!isNull _boatAnchor && {!(_boatData param [2, false])} && {(_boatData param [0, -1]) isEqualTo (AP_gang_data param [0, -1])}) then {
                if (AP_gang_data isNotEqualTo[]) then {_return pushBack["gangboat_label", "Gang Boat"];};};};
    // owner 2026-08-19: Malden Trauma Team spawns. The six rows here were the Altis ones (Kavala /
    // Pyrgos / Athira / Sofia / Air / Dump) and named markers that were never on this map -- exactly the
    // dead-row trap the cop comment at the top of this file documents, so every one of them dropped the
    // spawning medic at [0,0,0] in the sea. The four below are the med_spawn_* markers now IN
    // mission.sqm: the main hospital, which is also where the Trauma duty terminal stands
    // (core\fn_setupActions.sqf), plus the three loc_Hospital map icons.
    case independent: {_return = [["med_spawn_1", "Main Hospital"], ["med_spawn_2", "La Port"],
                ["med_spawn_3", "Chapoi"], ["med_spawn_4", "La Pessagne"]];};}; private _return =
_return;
if (AP_effSide in [west, civilian] && !(AP_disabled_spawns isEqualTo[]) && !_isRedeploy) then {
    // owner 2026-09-11: same gate, two outcomes. The native menu still DROPS a staff-disabled point; the web
    // screen keeps the row and greys it, because a row that vanishes is indistinguishable from a point that
    // was deleted and players asked about exactly that. `set` extends a two-element row, so no row needs
    // pre-padding and every other caller still sees [id, label].
    if (_withReasons) then {
        {
            if (((_x select 0) in AP_disabled_spawns) && {(_x param [2, ""]) isEqualTo ""}) then {
                _x set [2, "DISABLED BY STAFF"];};
        } forEach _return;
    } else {
        _return = _return select { !((_x select 0) in AP_disabled_spawns) };
    };
};
// owner 2026-09-06: evidenceLaptop is an Altis-era Eden object that does not exist on Malden; unguarded it threw on
// every MaxSec spawn menu (first cop clock-on after the bounty gate came off). Nil-safe, lazy.
if (AP_effSide isEqualTo west && {!isNil "evidenceLaptop"} && {(evidenceLaptop getVariable["AP_laptopstatus", 2] isEqualTo 2)} && {AP_evidence_spawns < 2}) then {
    _return pushBack["armory_marker", "Evidence Lockup"];};
// owner 2026-09-11: every row carries a third element under _withReasons, so the consumer never has to ask
// whether a row was built by a branch that knew about reasons. "" is the usable case.
if (_withReasons) then { { if (count _x < 3) then { _x set [2, ""]; }; } forEach _return; };
_return;