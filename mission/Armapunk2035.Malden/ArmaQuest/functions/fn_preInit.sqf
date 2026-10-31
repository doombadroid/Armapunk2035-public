// SPDX-License-Identifier: MIT
/*
    fn_preInit.sqf -- build every index once, register the built-in plugins,
    validate the catalogue, and decide whether the system is allowed to arm.

    WHY THIS EXISTS
      Two failure modes, both silent, both expensive:
        1. Per-event catalogue scans. If the engine walks the config to find
           out which objectives care about an event, the cost of playing grows
           with the amount of content authored -- the system punishes the one
           thing it exists to encourage. Every lookup the runtime needs is
           built here, once, into a HashMap.
        2. A catalogue that is broken in a way nothing reports. A quest whose
           prerequisite names a deleted quest, an objective of an unregistered
           type, a profile entry pointing at a function that does not exist --
           none of those produce an error in play, they produce content that
           never appears. So validation runs here, and a failed validation
           leaves the system disarmed rather than half-working.

    WHAT IT DOES
      - Resolves the five config roots (mission first, then game config).
      - Indexes quests, per-quest objective order, templates, pools and givers.
      - Registers the eight shipped objective types and the addAction giver
        trigger driver, each through the registrar that probes the contract.
      - Runs aq_fnc_validate and sets aq_ready from the result.
      - Client only: brings up the journal bridge and the native task mirror.

      Idempotent: safe to call again at any time. Indexes are rebuilt from
      scratch, registration overwrites by name, and the journal bridge
      re-attaches rather than double-registering.

    Usage:  call aq_fnc_preInit;          // from CfgFunctions preInit=1
*/

private _fnName = "aq_fnc_preInit";

// ------------------------------------------------------------- profile stubs
/*
    The profile stubs are registered ahead of this file and normally already
    exist by now (see CfgFunctions.hpp, ORDERING). "Normally" is not a
    guarantee: the assumption that preInit functions run in config declaration
    order is unverified, and if it is wrong then validation below reports every
    profile entry as undefined and the system refuses to arm — a total failure
    caused by an ordering detail. So the assumption is defended rather than
    documented: if the profile's own required entry is missing and the stub file
    is available, it is run here first.
*/
if (isNil "aq_life_fnc_playerUid" && {!isNil "aq_fnc_profileDefault"}) then {
    diag_log "[AQ] preInit: profile stubs were not defined yet; calling aq_fnc_profileDefault before validation.";
    call aq_fnc_profileDefault;
};

// ----------------------------------------------------------------- globals
/*
    Engine globals, all missionNamespace, all owned by this file:
      (LOCAL EDIT, VENDORED.txt: aq_types, aq_triggers and aq_quests -- and
       aq_worlds -- live in localNamespace instead. They hold CODE (plugins,
       drivers, teardown handles), and a client's publicVariable writes a
       missionNamespace global on every machine, the server included.
       aq_cfg too: aq_fnc_setting reads the server's gates (serverFacts[],
       factRateLimit, maxActive) through it, and a forged non-CONFIG entry
       there broke those reads and left the serverFacts gate open.)

      aq_ready       BOOL     validation passed; nothing arms while false
      aq_cfg         HashMap  root name -> CONFIG   ("quests","templates",
                                                     "pools","givers",
                                                     "settings","profile")
      aq_idxQuest    HashMap  questId    -> CONFIG (the quest class)
      aq_idxObj      HashMap  questId    -> ARRAY of [objId, CONFIG], in
                                            declaration order
      aq_idxTemplate HashMap  templateId -> CONFIG
      aq_idxPool     HashMap  poolId     -> CONFIG
      aq_idxGiver    HashMap  giverId    -> CONFIG
      aq_types       HashMap  typeName   -> CODE   (objective plugins)
      aq_triggers    HashMap  driverName -> CODE   (giver interaction drivers)
      aq_quests      HashMap  questId    -> quest record (see below); the
                                            server's view, mirrored to the
                                            client, never authored locally
      aq_subs        HashMap  eventName  -> ARRAY of [questId, objId, typeName]
                                            (the type travels with the entry so
                                            routing never reads config)
      aq_armedObj    HashMap  "quest|obj"-> TRUE
      aq_tasks       HashMap  questId    -> TASK (native task mirror)

    Quest record (HashMap; produced by the server, consumed by the client):

      "id"          STRING   quest id, or "<templateId>#<serial>" for a
                             radiant instance
      "state"       STRING   offered|active|completed|failed|expired|abandoned
      "title"       STRING   already resolved and substituted
      "summary"     STRING
      "description" STRING
      "giver"       STRING   giver id
      "icon"        STRING   setSimpleTaskType icon name
      "remaining"   NUMBER   seconds left when the server last spoke, 0 = no
                             limit. Not a stamp: the server's clock is absolute
                             and the client cannot read it, so the wire carries
                             a difference and the page anchors that to its own
                             clock on arrival
      "progress"    HashMap  objId -> [cur, max, "text"], the server's own
                             figures. The type's `progress` verb fills the gap
                             between pushes; this is what the player is shown
                             the moment the server has spoken
      "subst"       HashMap  slot name -> value; empty for authored quests
      "order"       ARRAY    objective ids, declaration order
      "objectives"  HashMap  objId -> objective state HashMap

    Objective state HashMap. The owning type owns every key except these,
    which the engine reads:

      "events"   ARRAY  event names the type subscribed to during `arm`
      "handles"  ARRAY  teardown handles (see aq_fnc_disarmObjective)
      "done"     BOOL   type's own view; advisory only, the server decides
*/

if (isNil {localNamespace getVariable "aq_types"})     then { localNamespace setVariable ["aq_types", createHashMap]; };
if (isNil {localNamespace getVariable "aq_triggers"})  then { localNamespace setVariable ["aq_triggers", createHashMap]; };
if (isNil {localNamespace getVariable "aq_quests"})    then { localNamespace setVariable ["aq_quests", createHashMap]; };
if (isNil "aq_subs")      then { aq_subs      = createHashMap; };
if (isNil "aq_armedObj")  then { aq_armedObj  = createHashMap; };
if (isNil "aq_tasks")     then { aq_tasks     = createHashMap; };

aq_ready = false;   // stays false until validation says otherwise

// ------------------------------------------------------------ config roots
// Mission config wins, so a host can ship the library in an addon and still
// author quests in the mission. A root that exists in neither place is not
// fatal on its own -- a mission with no templates is a legitimate install --
// but AQ_Quests missing almost certainly means the #include never happened.
private _root = {
    params ["_name"];
    private _c = missionConfigFile >> _name;
    if (!isClass _c) then { _c = configFile >> _name; };
    if (!isClass _c) then { _c = configNull; };
    _c
};

private _cfgRoots = createHashMap;
localNamespace setVariable ["aq_cfg", _cfgRoots];
{
    _cfgRoots set [_x select 0, [_x select 1] call _root];
} forEach [
    ["quests",    "AQ_Quests"],
    ["templates", "AQ_Templates"],
    ["pools",     "AQ_Pools"],
    ["givers",    "AQ_Givers"],
    ["settings",  "AQ_Settings"],
    ["profile",   "AQ_Profile"]
];

if (isNull (_cfgRoots get "quests")) then {
    diag_log "[AQ] preInit: no AQ_Quests class found in missionConfigFile or configFile -- is the config #include missing from description.ext?";
};

// ---------------------------------------------------------------- indexing
// UNVERIFIED: configProperties returns entries in declaration order. The
// objective order in the journal and the task HUD depends on it. Confirm by
// authoring a quest with objectives named z, a, m and checking that
// [_id, "objectives"] call aq_fnc_cfgQuest reports z, a, m -- not a, m, z.
private _subclasses = {
    params ["_cfg"];
    if (isNull _cfg) exitWith { [] };
    configProperties [_cfg, "isClass _x", true]
};

aq_idxQuest    = createHashMap;
aq_idxObj      = createHashMap;   // id -> [[objId, CONFIG], ...] ordered
aq_idxObjMap   = createHashMap;   // id -> HashMap objId -> CONFIG, for O(1)
aq_idxTemplate = createHashMap;
aq_idxPool     = createHashMap;
aq_idxGiver    = createHashMap;

// Both shapes are built for the same objectives: the array keeps declaration
// order for display, the map answers "which objective is this?" in constant
// time on the event path. Two views of one thing, built together so they
// cannot disagree.
private _indexObjectives = {
    params ["_ownerId", "_ownerCfg"];
    private _objs = [];
    private _map  = createHashMap;
    {
        _objs pushBack [configName _x, _x];
        _map set [configName _x, _x];
    } forEach ([_ownerCfg >> "objectives"] call _subclasses);
    aq_idxObj    set [_ownerId, _objs];
    aq_idxObjMap set [_ownerId, _map];
    _objs
};

{
    private _questId = configName _x;
    aq_idxQuest set [_questId, _x];

    // Objectives are indexed with the quest, not on demand: an event that
    // reaches an armed objective must never touch the config tree.
    private _objs = [_questId, _x] call _indexObjectives;

    if (_objs isEqualTo []) then {
        diag_log format ["[AQ] preInit: quest '%1' declares no objectives", _questId];
    };
} forEach ([_cfgRoots get "quests"] call _subclasses);

{
    private _tid = configName _x;
    aq_idxTemplate set [_tid, _x];

    // A radiant instance resolves its objectives through its template, so
    // the template's objectives are indexed exactly as a quest's are.
    [_tid, _x] call _indexObjectives;
} forEach ([_cfgRoots get "templates"] call _subclasses);

{ aq_idxPool  set [configName _x, _x]; } forEach ([_cfgRoots get "pools"]  call _subclasses);
{ aq_idxGiver set [configName _x, _x]; } forEach ([_cfgRoots get "givers"] call _subclasses);

diag_log format ["[AQ] preInit: indexed %1 quests, %2 templates, %3 pools, %4 givers",
    count aq_idxQuest, count aq_idxTemplate, count aq_idxPool, count aq_idxGiver];

// ------------------------------------------------------- objective context
/*
    aq_fnc_ctx -- build the context HashMap an objective type is called with.

    Defined here rather than as its own CfgFunctions entry because four
    engine files need it and none of them should each grow their own copy of
    the context shape; a context assembled in four places drifts in four
    directions. It is engine-internal: types receive the result, they never
    call this.

    Returns an empty HashMap when the quest or objective is unknown, which
    every caller treats as "do nothing, loudly".

    Usage:  private _ctx = ["copper_run", "have"] call aq_fnc_ctx;
*/
if !(isFinal "aq_fnc_ctx") then {aq_fnc_ctx = compileFinal {   // LOCAL EDIT: final, see VENDORED.txt
    params [["_questId", "", [""]], ["_objId", "", [""]]];

    private _rec = (localNamespace getVariable "aq_quests") getOrDefault [_questId, createHashMap];
    if (count _rec isEqualTo 0) exitWith {
        diag_log format ["[AQ] ctx: no quest record for '%1'", _questId];
        createHashMap
    };

    private _objs = _rec getOrDefault ["objectives", createHashMap];
    if (isNil { _objs get _objId }) then { _objs set [_objId, createHashMap]; };
    _rec set ["objectives", _objs];

    private _cfg = [_questId, "objective", _objId] call aq_fnc_cfgQuest;
    if (isNull _cfg) exitWith {
        diag_log format ["[AQ] ctx: quest '%1' has no objective '%2' in config", _questId, _objId];
        createHashMap
    };

    createHashMapFromArray [
        ["quest",     _questId],
        ["objective", _objId],
        ["cfg",       _cfg],
        ["state",     _objs get _objId],
        ["player",    if (hasInterface) then { player } else { objNull }],
        // Radiant slot values. Authored quests carry an empty map. A type that
        // reads text or numbers through aq_fnc_text gets substitution for free;
        // one that reads config directly sees the raw %SLOT% token, which is
        // why aq_fnc_text is the documented way to read a config value.
        ["subst",     _rec getOrDefault ["subst", createHashMap]]
    ]
}};

// -------------------------------------------------------- built-in plugins
// Registration goes through aq_fnc_registerType so the shipped types are held
// to exactly the contract a host's own type is held to. A shipped type that
// forgot `describe` should fail here, in front of the author, not in front of
// a player looking at a blank offer screen.
private _missing = [];
{
    _x params ["_typeName", "_fncName"];
    if (isNil _fncName) then {
        _missing pushBack _fncName;
    } else {
        if (!([_typeName, missionNamespace getVariable _fncName] call aq_fnc_registerType)) then {
            _missing pushBack _fncName;
        };
    };
} forEach [
    ["gather",   "aq_fnc_typeGather"],
    ["sell",     "aq_fnc_typeSell"],
    ["craft",    "aq_fnc_typeCraft"],
    ["deliver",  "aq_fnc_typeDeliver"],
    ["zoneHold", "aq_fnc_typeZoneHold"],
    ["visit",    "aq_fnc_typeVisit"],
    ["kill",     "aq_fnc_typeKill"],
    ["talk",     "aq_fnc_typeTalk"],
    ["action",   "aq_fnc_typeAction"]
];

if !(_missing isEqualTo []) then {
    diag_log format ["[AQ] preInit: built-in objective types unavailable or rejected: %1 -- check CfgFunctions includes the types/ folder", _missing];
};

/*
    The addAction giver driver.

    A trigger driver has two jobs when the player interacts: fire the
    interaction as an event, and open the offer screen. This one hangs a scroll
    action on the giver's object that does both. It is registered as inline code
    rather than shipped as a file because it is a handful of lines of engine glue
    with no configuration of its own; a host that wants anything richer registers
    its own driver instead of editing this.

    Called as: [_giverId, _giverObject, _giverConfig] call <driver>
    on the CLIENT, by aq_fnc_postInit, once the giver's object exists there.
*/
["addAction", {
    params [["_giverId", "", [""]], ["_obj", objNull, [objNull]], ["_cfg", configNull, [configNull]]];

    if (_giverId isEqualTo "") exitWith { diag_log "[AQ] addAction driver: empty giver id"; false };
    if (isNull _obj) exitWith {
        diag_log format ["[AQ] addAction driver: giver '%1' has no object to attach to", _giverId];
        false
    };
    // Idempotent: a giver re-registered after a respawn must not end up with
    // two identical scroll entries.
    if (_obj getVariable ["aq_actionArmed", false]) exitWith { true };

    private _label = if (isNull _cfg) then { "" } else { [_cfg >> "name"] call aq_fnc_text };
    if (_label isEqualTo "") then { _label = "Work available"; };

    _obj addAction [
        _label,
        // Arguments arrive as the 4th element; nothing here is compiled from
        // config, so a giver name can never become code.
        //
        // The interaction itself is an event, and firing it is the driver's
        // second obligation: a `talk` objective completes on the interaction
        // and on nothing else, so a driver that only opened the offer screen
        // would leave every "go back and report in" beat impossible to finish.
        // A host registering its own driver must fire this line too.
        {
            (_this select 3) params ["_id"];
            ["aq_talked", [_id, (_this select 0)]] call aq_fnc_event;
            [_id] call aq_fnc_openOffers;
        },
        [_giverId],
        1.5,
        true,
        true,
        "",
        "alive _target",
        4
    ];
    _obj setVariable ["aq_actionArmed", true];
    true
}] call aq_fnc_registerTrigger;

// -------------------------------------------------------------- validation
/*
    Nothing arms until the catalogue has been checked. A validator that is
    missing counts as a failed validation, not as a pass: an install where
    diagnostics/ never loaded is an install where nothing else can be trusted
    either, and a quest system that quietly runs unvalidated content is the
    exact failure this library exists to remove.

    aq_fnc_validate may answer BOOL (true = clean) or ARRAY (the problems it
    found, empty = clean); both readings are accepted so the diagnostics side
    can report detail without breaking this gate.
*/
if (isNil "aq_fnc_validate") then {
    diag_log "[AQ] preInit: aq_fnc_validate is not defined -- refusing to arm. The diagnostics functions are part of the library, not optional scaffolding; check CfgFunctions.";
    aq_ready = false;
} else {
    // [true] = the preInit run: the mission world does not exist yet, so marker
    // checks are deferred rather than failed, and the report is not announced in
    // systemChat on every client.
    private _result = [true] call aq_fnc_validate;
    aq_ready = switch (true) do {
        case (_result isEqualType true):  { _result };
        case (_result isEqualType []):    { _result isEqualTo [] };
        default { false };
    };
    if (!aq_ready) then {
        // aq_fnc_validate returns a BOOL and leaves the detail in
        // aq_validate_problems / aq_validate_warnings. Logging _result here
        // printed "Problems: false" -- technically the return value, and
        // useless: it told an operator that validation failed without telling
        // them what failed, while the information sat in a variable one line
        // away. The per-problem [AQ-VALIDATE] lines are already in the RPT
        // above this; this line now says how many to go looking for.
        private _probs = missionNamespace getVariable ["aq_validate_problems", []];
        diag_log format ["[AQ] preInit: validation FAILED, system disarmed. %1 problem(s); see the [AQ-VALIDATE] lines above.", count _probs];
    };
};

// ------------------------------------------------------------ client wiring
if (hasInterface) then {
    // The journal degrades to native tasks when arma-webui is absent, so this
    // is safe to call unconditionally.
    ["init"] call aq_fnc_journal;
    ["init"] call aq_fnc_task;
};

diag_log format ["[AQ] preInit: complete, ready=%1", aq_ready];
aq_ready
