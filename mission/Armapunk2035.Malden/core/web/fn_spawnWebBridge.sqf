/*
    AP_fnc_spawnWebBridge -- dialog\web_spawn.hpp (938700) onLoad: wire the spawn page's verbs.

        [_display] spawn AP_fnc_spawnWebBridge;

    THE PAGE DEFINES THE CONTRACT (ui\html\spawn.html's header); this file matches it and adds nothing:

        spawnReady   []          -> answered with the first "spawn" PUSH, not a return value. The page
                                    discards this call's result, exactly as landing.html does.
        spawnDeploy  [rowIndex]  -> { ok, msg }. ok: the teleport is under way and SQF owns the screen
                                    from here. msg on a refusal is printed in the page's status strip
                                    and DEPLOY is re-enabled.
        spawnCancel  []          -> closes the display. The opener then hands the screen to the native
                                    menu rather than leaving a held player with nothing in front of them.

    NOTHING NEW IS AUTHORISED HERE. The row index the page sends is re-resolved against a FRESHLY
    BUILT list, so a row that became contested between the push and the click is refused on its current
    reason, not the one the page was drawing. The deploy itself is the same AP_fnc_spawnConfirm the
    native SPAWN button calls, with AP_spawn_point set to the same two-element [id, label] row the
    native list selection writes. No new CfgRemoteExec entry and no new server function: anyone who can
    run JS in this page could already call spawnConfirm from the debug console (core\web\README.md's
    security note), so the boundary that matters is the one inside spawnConfirm and the server, and
    this path does not widen it.

    THE DEPLOY VERB RETURNS IMMEDIATELY AND SPAWNS THE CONFIRM. A page verb runs inside the JSDialog
    handler, which is an alert() -- the browser is blocked until it returns, so anything slow in here
    freezes the page it is trying to drive. spawnConfirm is also genuinely suspending on the redeploy
    path (a 15 s abort countdown with uiSleep), which is why the native redeploy button uses `spawn`
    and the native spawn button uses `call`. One `spawn` covers both and is correct for both.

    THE 2 s REPUSH IS THE NATIVE MENU'S REFRESH THREAD, done once. fn_spawnMenu and fn_redeployMenu
    each spin their own waitUntil watching AP_disabled_spawns and the turf flags to rebuild the
    listbox; this pushes the whole row payload on a fixed 2 s tick while the display lives, so a point
    that becomes contested, taxed or staff-disabled while the screen is open greys out in place. A
    fixed tick rather than a change-watcher because the payload now carries positions and player
    counts, which change constantly and which no watcher was ever written for.
*/
// ONE payload builder, used by the ready handshake and by the repush tick, so the two cannot drift.
if !(isFinal "AP_fnc_spawnWebPayload") then {AP_fnc_spawnWebPayload = compileFinal {
    private _redeploy = missionNamespace getVariable ["AP_spawnWebRedeploy", false];
    createHashMapFromArray [
        ["rows",     [_redeploy] call AP_fnc_spawnPointList],
        ["side",     switch (AP_effSide) do { case west: {"cop"}; case independent: {"med"}; default {"civ"} }],
        ["redeploy", _redeploy],
        // The respawn path and the connect path want different words on the same screen.
        ["respawned", missionNamespace getVariable ["AP_respawned", false]]
    ]
}};
// SECURITY 2026-09-26: core\init.sqf calls this with "boot" at client init, so the helper above is
// defined (final) before another client can publicVariable a final copy of it first.
if (_this isEqualTo "boot") exitWith {};

params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith { diag_log "[SPAWNWEB] bridge: null display"; };
disableSerialization;

private _ctrl = _display displayCtrl 938701;          // idc is idd + 1 (see web_spawn.hpp)
if (isNull _ctrl) exitWith { diag_log "[SPAWNWEB] bridge: control 938701 missing"; };
if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[SPAWNWEB] bridge: init failed"; };
// Let the SERVER replace this page's markup if it holds a newer copy, so UI ships without a client
// repack. No-op unless AP_fnc_webServeInit registered a fetcher and the server actually has the file.
[_ctrl, "ui\html\spawn.html"] call webui_fnc_serve;

[_ctrl, "spawnReady", {
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (!isNull _c) then { [_c, "spawn", (call AP_fnc_spawnWebPayload)] call webui_fnc_push; };
    createHashMapFromArray [["ok", true], ["err", ""]]
}] call webui_fnc_on;

[_ctrl, "spawnDeploy", {
    params [["_idx", -1, [0]]];
    private _fnc_no = { createHashMapFromArray [["ok", false], ["msg", _this]] };

    private _redeploy = missionNamespace getVariable ["AP_spawnWebRedeploy", false];
    // REBUILT, not remembered. The page is drawing a payload that is up to 2 s old and a row can go
    // contested inside that window; re-resolving here means the refusal text is the current reason.
    private _rows = [_redeploy] call AP_fnc_spawnPointList;
    if (_idx < 0 || {_idx >= count _rows}) exitWith { "NO SUCH WAKE POINT -- PICK ANOTHER" call _fnc_no };

    private _row = _rows select _idx;
    private _reason = _row getOrDefault ["reason", ""];
    if (_reason isNotEqualTo "") exitWith {
        diag_log format ["[SPAWNWEB] deploy refused: %1 -- %2", _row getOrDefault ["label", "?"], _reason];
        (format ["DEPLOY REFUSED -- %1", _reason]) call _fnc_no
    };

    // The cfg row, in the two-element shape fn_spawnConfirm reads: param[0] is the id (a marker name,
    // or the Mobile HQ position array), select 1 is the label it prints and the Mobile HQ test keys on.
    private _cfg = ([AP_effSide, _redeploy, true] call AP_fnc_spawnPointCfg) param [_idx, []];
    if (_cfg isEqualTo []) exitWith { "WAKE POINT LIST MOVED -- PICK AGAIN" call _fnc_no };
    AP_spawn_point = [_cfg select 0, _cfg select 1];

    // From here the screen belongs to SQF: spawnConfirm closes the dialog on every committing path,
    // and AP_fnc_spawnWebOpen reads this flag to decide whether the player deployed or dismissed.
    AP_spawnWebDeployed = true;
    diag_log format ["[SPAWNWEB] deploy %1 (redeploy=%2)", _cfg select 1, _redeploy];
    [_redeploy] spawn AP_fnc_spawnConfirm;

    createHashMapFromArray [["ok", true], ["msg", format ["WAKING AT %1", toUpper (_cfg select 1)]]]
}] call webui_fnc_on;

[_ctrl, "spawnCancel", {
    diag_log "[SPAWNWEB] cancel -- handing the screen to the native menu";
    closeDialog 0;
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

// The repush tick. Dies with the display; never outlives it, and never runs while a teleport is
// settling (AP_spawnSettling), because rebuilding the list mid-teleport would cost a DB-free but not
// free walk over every house the player owns for a screen that is already closing.
[_ctrl] spawn {
    params ["_c"];
    while { !isNull (findDisplay 938700) } do {
        uiSleep 2;
        if (isNull (findDisplay 938700)) exitWith {};
        if !(missionNamespace getVariable ["AP_spawnSettling", false]) then {
            [_c, "spawn", (call AP_fnc_spawnWebPayload)] call webui_fnc_push;
        };
    };
};
