if !(AP_effSide isEqualTo civilian) exitWith {};
if (AP_gang_data isEqualTo[]) exitWith {};
private _group = allGroups param[allGroups findIf {_x getVariable["gang_id", -1] isEqualTo(AP_gang_data select 0)}, grpNull];
if !(isNull _group) then {[player] join _group;
    if ((AP_gang_data select 2) isEqualTo 1) then {_group selectLeader player; [
            [player, _group], "AP_fnc_setGangGrpLdr", units _group] spawn AP_fnc_MP;};} else {_group = createGroup [civilian, true];
    [player] join _group;
    _group setVariable["gang_id", AP_gang_data select 0, true];
    _group setVariable["gang_name", AP_gang_data select 1, true];
    _group setGroupIdGlobal [AP_gang_data select 1];   // owner 2026-06-25 (Northhhhh): clean callsign (gang name) so side-chat shows the gang name, not the engine's auto group ID
    [[AP_gang_data select 0, "", _group], "APS_fnc_setGangTagSRV", 2] spawn AP_fnc_MP;};
AP_action_in_use = false;
setGroupIconsVisible [false, true];   // owner 2026-06-13: hide the MAP group icons (the purple-arrows bug) but KEEP the 3D HUD hexs over gang members (#159)
if !((AP_gang_data param[3, [0, 0, 0]]) isEqualTo[0, 0, 0]) then {[] spawn {private _hqPos = AP_gang_data select 3;
        // owner 2026-06-17 (#324): draw the gang-house MAP MARKER from the stored HQ position IMMEDIATELY,
        // independent of streaming the building object. The old code created the marker only AFTER finding the
        // building within 14m -- which needs you near the HQ when it streams in (<=90s). Logging in far from the
        // HQ -> the building never streams -> waitUntil times out -> the gang house was invisible "ever" (and
        // the leader saw only their blue owned-house marker = "normal house"). A map marker needs only the
        // position. The building-find below still runs, to wire AP_gangBuilding for spawn / access / unlock.
        private _gangID0 = AP_gang_data param [0, -1];
        deleteMarkerLocal AP_gangBldgMark;
        deleteMarkerLocal (format ["phouse_gang_%1", _gangID0]);
        AP_gangBldgMark = createMarkerLocal [format ["phouse_gang_%1", _gangID0], _hqPos];
        AP_gangBldgMark setMarkerTextLocal "Gang Building";
        AP_gangBldgMark setMarkerColorLocal "ColorGreen";
        AP_gangBldgMark setMarkerTypeLocal "mil_end";
        private _houseTypes = ["getHouses"] call AP_fnc_houseConfig;
        // owner 2026-06-14 (#208): RETRY the building-find instead of one-shotting it. Two bugs made gang
        // MEMBERS get no keys / map marker / spawn / vehicle-pull at a gang building:
        //   (1) buildings stream in ~20s after a restart, so a single nearestObjects ran too early, returned
        //       [] -> _building objNull -> the whole setup was skipped and NEVER retried (hit houses too).
        //   (2) an industrial SHED (Land_i_Shed_Ind_F) is NOT isKindOf "House_F", so the old ["House_F"]
        //       filter never matched a shed gang-HQ at all (the shed-specific half of the report).
        // Use a broad "Building" sweep filtered to the real house-type list, and wait until the building
        // exists AND has been re-tagged AP_house_gang by the server boot re-tag (init.sqf), up to 90s.
        private _building = objNull;
        private _t0 = time;
        waitUntil {uiSleep 1;
            _building = (nearestObjects [_hqPos, ["Building"], 14]) select { (typeOf _x) in _houseTypes } param [0, objNull];
            // owner 2026-06-16: the server boot re-tag (init.sqf) tags the building via `nearestBuilding` (ANY
            // building), but the client filtered to house-TYPES only -> if those resolve to DIFFERENT buildings
            // (shed HQ, or nearestBuilding picking a closer structure) the client waits on a tag that's on the
            // OTHER building -> times out -> "gang house gone after restart, re-assign needed". Match the server:
            // if the type-filtered find misses, fall back to nearestBuilding so both pick the same building.
            if (isNull _building) then {private _nb = nearestBuilding _hqPos;
                if (!isNull _nb && {(_nb distance _hqPos) < 14}) then { _building = _nb; };};
            (!isNull _building && {(_building getVariable ["AP_house_gang", -1]) isNotEqualTo -1}) || {(time - _t0) > 90}};
        if (isNull _building) exitWith {};
        private _gangID = _building getVariable["AP_house_gang", -1];
        private _gangOwner = _building getVariable["AP_homeOwner", ""];
        // owner 2026-06-16 (#305/#310): do NOT bail when AP_homeOwner is "" -- the gang building is validly
        // identified by AP_house_gang (server re-tags it at boot). The old `_gangOwner isEqualTo ""` bail meant
        // that whenever the house OWNER was offline (or a shed-type HQ the boot owner-tag's House_F filter missed)
        // the gang house went dead for every member. Owner is only used for the marker's unique name now; ""
        // still yields a unique-per-gang name. (Server boot tag in AP_server\init.sqf normally fills it in.)
        if (_gangID isEqualTo - 1) exitWith {};
        AP_gangBuilding = [_building, getPosATL _building];
        // owner 2026-06-17 (#324): the green map marker is now created up front from _hqPos (above), so the
        // gang house shows even before/without the building streaming in. Now that we DO have the building
        // object, snap the marker to its exact position (= _hqPos in practice) -- nothing else to do here.
        AP_gangBldgMark setMarkerPosLocal (getPosATL _building);};};
private _units = (units group player) apply {getPlayerUID _x}; [
    ["-GANGGRP-", player, profileName, format["joined the gang group: %1 (%3). Members: %2", AP_gang_data select 1, _units, AP_gang_data select 0]], "APS_fnc_logIt", 2] call AP_fnc_MP;