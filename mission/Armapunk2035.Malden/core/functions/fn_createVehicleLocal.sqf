params[["_className", "", [""]], ["_position", [], [[]]
], ["_direction", 0, [0, []]], ["_code", "", [""]], ["_xIsServer", false], ["_loadout", [], [[]]],
    ["_id", -1, [0]], ["_model", "", [""]], ["_scale", 1, [0]], ["_lod", 1, [0]], ["_streamR", -1, [0]], ["_onServer", false, [false]]];
if ((_className isEqualTo "" && {_model isEqualTo ""}) || _position isEqualTo[]) exitWith {objNull};
// mapdb.md D5 -- which machine spawns what. is_server rows are GLOBAL on the dedicated server
// and never on a client; on_server rows are a LOCAL copy on the server (custom buildings: AI and
// vehicle collision) and a local copy on every client; everything else is client-only.
if (isDedicated && !_xIsServer && !_onServer) exitWith {objNull};
if (!isDedicated && _xIsServer) exitWith {objNull};
// Custom .p3d row: the recipe custom_p3ds/malden_buildings.sqf proved since 2026-06 -- the FINAL
// position goes to createSimpleObject (setPosASL does not move a fresh simple object), orientation
// next, setObjectScale LAST (setDir rebuilds the matrix and resets scale to 1).
if (_model isNotEqualTo "") exitWith {
    // A model under custom_p3ds is ours and lives in the mission; anything else (a3\... since the
    // 2026-09-09 tree anchors) is a game model and is named as it is.
    private _o = createSimpleObject [if ((toLower _model) find "custom_p3ds" == 0) then { getMissionPath _model } else { _model }, _position, true];
    if (isNull _o) exitWith { diag_log format ["[AP-MAP] model failed to load: %1", _model]; objNull };
    if (_direction isEqualType []) then { _o setVectorDirAndUp _direction; } else { _o setDir _direction; };
    if (_scale isNotEqualTo 1) then { _o setObjectScale _scale; };
    _o setVariable ["owner", "AP_customBuilding"];   // exempt from fn_cleanup's ownerless reap
    _o setVariable ["AP_mapId", _id];
    if !(_code isEqualTo "") then { private _c = _code; _o spawn (compile _c); };
    _o
};
// owner 2026-07-31: EVERY building and gate gets working doors. A simple object cannot animate,
// so any door-bearing class spawned that way is sealed shut -- the sheriff compound gate was the
// straw. numberOfDoors > 0 is the engine's own marker for "this has doors" and covers houses and
// every fence/wall gate; rubble, walls and props stay simple objects, which is the whole perf
// design of this array. Door state is per-client (these are local copies), same as everything else
// here.
private _plb_needSim = (getNumber (configFile >> "CfgVehicles" >> _className >> "numberOfDoors")) > 0;
// owner 2026-08-02: cargo CONTAINERS (20ft/40ft boxes) have doors so needSim came out true -- and
// PhysX bounced them all over the compound on load. Sim OFF for exactly those (doors seal shut,
// owner's call: sealed beats bouncing). Cargo TOWERS/houses keep their doors working. Flag poles
// are the inverse: door-less, so they froze as simple objects with a rigid cloth -- force them
// REAL with sim ON so every flag actually waves.
if ((_className select [0, 11]) in ["Land_Cargo2", "Land_Cargo4"]) then { _plb_needSim = false; };
if (_className isKindOf "FlagCarrier") then { _plb_needSim = true; };
// owner 2026-09-02: the floodlights sunk into the plaza around the Grand Palace must be LIT --
// but the fixture's own reflector, forced ON, was "WAY TOO BRIGHT" (it is a work light, and its
// brightness is config, not scriptable). So the fixture stays a simple object (dark, like every
// other placed lamp) and gets a SCRIPTED light of its own, tunable live: AP_fnc_mapLightAttach,
// knob = [0.3] call AP_fnc_floodTune. Per-client local, like everything spawned here.
private _plb_scriptedLight = _className in ["Land_FloodLight_F"];
private _vehicle =
if (isDedicated && _xIsServer) then {_className createVehicle[random 100, random 100, random 100];} else {
    // owner 2026-07-10: an entry carrying a LOADOUT (6th field, getUnitLoadout array from the Eden
    // round-trip) must be a REAL local unit -- simple objects are baked statues and can't wear gear.
    if (_code isEqualTo "" && {_loadout isEqualTo []} && {!_plb_needSim}) then {createSimpleObject[_className, [random 100, random 100, random 100], true];
    } else {_className createVehicleLocal[random 100, random 100, random 100];};};
waitUntil {!isNull _vehicle};
// owner 2026-07-31: freeze and de-damage FIRST. Creation happens up to 100 m in the air at the map
// corner, and until these two lines ran the unit could take a fall tick -- the occasional "oof" /
// "hey, wake up" voice line players heard on load-in was the NPCs briefly hurting themselves
// before allowDamage false arrived further down.
_vehicle enableSimulation false;
_vehicle allowDamage false;
clearBackpackCargo _vehicle;
clearWeaponCargo _vehicle;
clearMagazineCargo _vehicle;
clearItemCargo _vehicle;
if (isDedicated && _xIsServer) then {_vehicle enableSimulation true;} else {_vehicle enableSimulation _plb_needSim;};
if (_vehicle isKindOf "CAManBase") then {removeAllWeapons _vehicle;
    // owner 2026-07-10: apply the Eden-edited outfit/loadout AFTER the strip (mapExportAll captures
    // getUnitLoadout per NPC; empty = keep the class-default look exactly as before).
    if (_loadout isNotEqualTo []) then {_vehicle setUnitLoadout _loadout;
        _vehicle setVariable ["BIS_enableRandomization", false];
        _vehicle setVariable ["AP_hasLoadout", true];   // NPC init strips (fn_applyCop etc.) skip dressed NPCs
    };
    _vehicle switchMove "AmovPercMstpSnonWnonDnon";};
_vehicle allowDamage false;
_vehicle enableDynamicSimulation false;   // owner 2026-07-20: exported map objects never "wake up" via dynamic simulation (sim stays off + damage off)
// owner 2026-07-31: the array is in the WORLD frame (model centre) since the mapedit.md
// migration, so this is setPosWorld and not setPosATL. The two frames differ by the
// transformed bounding-centre offset, which is per-class AND changes with orientation --
// 326 of the designer's objects are tilted, one by 90 degrees -- so they are not
// interchangeable and there is no offline conversion between them.
// Orientation, then position, then scale (setDir resets scale): AP_fnc_mapPlace is that rule,
// shared with the server's in-place move of an edited is_server / on_server object.
[_vehicle, _direction, _position, _scale] call AP_fnc_mapPlace;
_vehicle setVariable ["AP_mapId", _id];
if (_plb_scriptedLight) then { [_vehicle] call AP_fnc_mapLightAttach; };
if !(_code isEqualTo "") then {private _plb_code = _code;
    _vehicle spawn(compile _plb_code);};
_vehicle;