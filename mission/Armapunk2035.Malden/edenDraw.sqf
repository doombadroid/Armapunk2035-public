/*
    edenDraw.sqf  --  draw the real models on the staged anchors (mapedit.md / D2 pipeline)

    Run in the 3DEN debug console:
        call compile preprocessFileLineNumbers "edenDraw.sqf";

    WHY ANCHORS EXIST AT ALL: 3DEN can only place an entity that has a CfgVehicles class from an
    addon. The custom buildings are raw .p3d files shipped inside the mission, and the shop NPCs
    must stay client-local array rows rather than becoming one server-owned Eden AI. Both are
    therefore staged as Land_HelipadEmpty_F anchors, which render as nothing -- so this puts a
    visible model on each one.

    NOT the same thing as edenCB_refresh.sqf / edenNPC_refresh.sqf. Those belong to the older
    per-subsystem pipelines: they need the AP_cbAnchors / AP_npcAnchors globals that their own
    import scripts set, and they read AP_cbModel / AP_npcIdx off each anchor with setVariable.
    Anchors staged by map_codegen.py have none of that -- they carry everything in the entity's
    DESCRIPTION attribute, because that is what survives a 3DEN save and a reload. So those two
    scripts exit immediately here ("run edenCB_import.sqf first") and this one replaces both.

    The drawn models are createSimpleObject, NOT entities, so 3DEN will not select, save or bake
    them. Re-run after moving anything; it deletes the previous set first.
*/
if (isNil "AP_drawVis") then { AP_drawVis = []; };
{ deleteVehicle _x } forEach AP_drawVis;
AP_drawVis = [];
AP_drawPairs = [];
// drop any previous follow handler before installing a new one
if (!isNil "AP_drawEH") then { removeMissionEventHandler ["EachFrame", AP_drawEH]; };
AP_drawEH = nil;

private _missionPath = getMissionPath "custom_p3ds\";   // models live here since 2026-08-19
private _p3d = 0;
private _npc = 0;

{
    private _anchor = _x;
    private _desc = (_anchor get3DENAttribute "description") param [0, ""];
    if (!(_desc isEqualType "") || {_desc isEqualTo ""}) then { continue };

    private _model = "";
    private _scale = 1;
    private _isNpc = false;

    // Offsets are derived from the tokens with `count`, never hardcoded. They used to be
    // literal 8/10/8 for the PLB_-era spellings; the AP_ rename made every one of them
    // off-by-one, which silently truncated the model name rather than erroring.
    private _tP3D   = "AP_P3D=";
    private _tScale = "AP_SCALE=";
    private _tNpc   = "AP_NPC=";
    {
        private _tok = _x;
        if ((_tok select [0, count _tP3D]) isEqualTo _tP3D) then {
            // mission ROOT, matching malden_buildings.sqf's own `_MALDEN = getMissionPath ""`.
            // There is a second copy of these models under custom_p3ds\ that load.sqf uses;
            // taking that path here would load a different file than the one being edited.
            private _name = _tok select [count _tP3D];
            // a bare name is one of our custom_p3ds models; a path that starts with custom_p3ds\ is
            // the same thing named with its folder (the vending compositions do that -- measured
            // 2026-09-10, used verbatim it loaded nothing); any other path with a backslash is a game
            // model (a3\plants_f\... tree anchors) and is used as written
            _model = if ((toLower _name) select [0, 12] isEqualTo "custom_p3ds\") then { getMissionPath _name } else {
                if ((_name find "\") >= 0) then { _name } else { _missionPath + _name + ".p3d" }
            };
        };
        if ((_tok select [0, count _tScale]) isEqualTo _tScale) then {
            _scale = parseNumber (_tok select [count _tScale]);
        };
        if ((_tok select [0, count _tNpc]) isEqualTo _tNpc) then {
            _model = _tok select [count _tNpc];      // a CfgVehicles class, not a .p3d path -- see below
            _isNpc = true;
        };
    } forEach (_desc splitString "|");

    if (_model isEqualTo "") then { continue };

    /*
        A PERSON IS DRAWN AS A REAL LOCAL UNIT, NOT A SIMPLE OBJECT.

        createSimpleObject on a character .p3d succeeds -- it reported 61 created every time --
        but renders nothing usable: a character model needs its skeleton to hold a pose, and a
        simple object has none, so the mesh collapses and there is nothing to see. That is why
        the NPCs stayed invisible while the buildings appeared.

        createVehicleLocal makes a properly posed character. It is still NOT a 3DEN entity, so
        the editor will not select, save or bake it -- the same guarantee the simple objects give.
        Simulation off and a standing animation, matching what fn_createVehicleLocal does at
        runtime, so the pose here is the pose in game.
    */
    private _v = if (_isNpc) then {
        private _u = _model createVehicleLocal [0, 0, 0];
        if (!isNull _u) then {
            _u enableSimulation false;
            _u allowDamage false;
            _u enableDynamicSimulation false;
            removeAllWeapons _u;
            _u switchMove "AmovPercMstpSnonWnonDnon";
        };
        _u
    } else {
        createSimpleObject [_model, [0, 0, 0], true]
    };
    if (isNull _v) then {
        diag_log format ["[EDENDRAW] could not create %1", _model];
        continue;
    };
    // getPosWorld end to end: the sqm stores the model centre, the map array is in that same frame
    // since the mapedit.md migration, and createSimpleObject places by it. No ATL anywhere.
    _v setVectorDirAndUp [vectorDir _anchor, vectorUp _anchor];
    _v setPosWorld (getPosWorld _anchor);
    if (_scale != 1) then { _v setObjectScale _scale };   // setDir/setVectorDirAndUp resets scale
    AP_drawVis pushBack _v;
    AP_drawPairs pushBack [_anchor, _v, _scale];
    if (_isNpc) then { _npc = _npc + 1 } else { _p3d = _p3d + 1 };
} forEach (all3DENEntities select 0);

/*
    MAKE THE MODEL FOLLOW ITS ANCHOR, EVERY FRAME.

    Without this the anchor is invisible AND the model does not move with it, so dragging one
    gives no feedback whatsoever: it looks like nothing happened while the entity really moves.
    That is not a cosmetic problem -- it silently moved an NPC 548 m during the first real edit
    session, and the only reason anyone noticed was the apply diff.

    The visuals are simple objects, not entities, so 3DEN neither selects nor saves them; this
    handler just keeps them glued to the thing that IS editable.
*/
AP_drawEH = addMissionEventHandler ["EachFrame", {
    {
        _x params ["_a", "_v", "_s"];
        if (!isNull _a && {!isNull _v}) then {
            private _w = getPosWorld _a;
            if (!((getPosWorld _v) isEqualTo _w)
                || {!((vectorDir _v) isEqualTo (vectorDir _a))}) then {
                _v setVectorDirAndUp [vectorDir _a, vectorUp _a];
                _v setPosWorld _w;
                if (_s != 1) then { _v setObjectScale _s };
            };
        };
    } forEach AP_drawPairs;
}];

systemChat format ["edenDraw: %1 buildings + %2 NPCs drawn and now FOLLOWING their anchors. Drag an anchor and the model moves with it.",
    _p3d, _npc];
diag_log format ["[EDENDRAW] drew %1 p3d + %2 npc = %3, follow handler %4",
    _p3d, _npc, count AP_drawVis, AP_drawEH];

/*
    EDEN LIVE (several editors on this scenario at once, see docs/armapunk in the EdenLive repo).
    A peer's MOVE needs nothing: the follow handler above tracks the anchor every frame. A peer
    CREATING or DELETING an anchor does need a redraw, so the hook below re-runs this file, once,
    a second after the last such event. Harmless when Eden Live is not loaded.
*/
if (!isNil "ELIVE_fnc_initExtension") then {
    ELIVE_var_onRemoteApply = {
        params ["_e", "_op", "_id"];
        if !(_op in ["create", "delete"]) exitWith {};
        private _desc = if (isNull _e) then { "" } else { (_e get3DENAttribute "description") param [0, ""] };
        if (!(_desc isEqualType "") || {(_desc find "AP_P3D=") < 0 && {(_desc find "AP_NPC=") < 0}}) exitWith {};
        if (!isNil "AP_drawRedrawPending") exitWith {};
        AP_drawRedrawPending = true;
        [] spawn {
            uiSleep 1;
            AP_drawRedrawPending = nil;
            call compile preprocessFileLineNumbers "edenDraw.sqf";
        };
    };
    diag_log "[EDENDRAW] Eden Live hook installed: peer create/delete of an anchor redraws";
};
