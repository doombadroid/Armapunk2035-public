/*
    fn_carRadioBridge.sqf -- CAR RADIO (web) bridge half, dialog AP_web_carRadio (515600/515601).
    onLoad target of dialog\web_carradio.hpp. Reference shape: fn_lootBridge.sqf / fn_mapOpen.sqf.

    CONTRACT -- copied from the design handoff's radial.html header verbatim (page defines it,
    this matches it):
        AP.on("radial", { stations:[{ id, label, color }], isDriver, apInstalled, on, st, apMode })
        AP.call("radialSet", ["station", i])                      -> { ok }
        AP.call("radialSet", ["off"])                              -> { ok }
        AP.call("radialSet", ["ap", "madmax"|"normal"|"sloth"])    -> { ok }
        AP.call("radialClose", [])                                 -> the page asks; we own TAB/ESC too

    STATION DATA -- read from the same place fn_radioRadial.sqf reads count/colors:
    missionConfigFile >> "AP_Radio_Cfg" >> "AutoRadio" (radioCfg.hpp). Colors use fn_radioRadial's
    OWN float-triplet -> hex conversion (copied verbatim into _fnHex below) so a station reads the
    identical color in both UIs. "id" and "label" are NOT read by fn_radioRadial.sqf itself (the
    native wedges carry no string id, and its hover/state readout hardcodes a local ["ORIGIN",
    "KHR", "PULSE", "CLASSICO", "ANARCHY"] array rather than touching cfg at all) -- there is no
    single "wherever it reads them" for those two fields, so this reads the closest thing cfg
    actually ships for that purpose: AUTORADIO_RadioStream (lowercase ids, already exactly what
    the page's built-in glyph set keys on: g-origin/g-khr/g-pulse/g-classico/g-anarchy) and
    AUTORADIO_StreamLabel ("ORIGIN FM"/"KHR"/"PULSE"/"CLASSICO"/"ANARCHY"). Both arrays exist
    today ONLY for the server's stream broadcast (server/AP_server/core/TON/fn_radioSRV.sqf) --
    reading them here is a new consumer, not new data. The one visible seam: the native radial's
    hover text says "ORIGIN", this page will say "ORIGIN FM". Flagged for the human comparison
    pass rather than silently copying the native radial's hardcoded array (which would duplicate
    station metadata in a THIRD place). AUTORADIO_RadioLogo is not read at all -- the page draws
    its own inline SVG glyph per known id (same reason fn_radioRadial.sqf itself stopped using
    AUTORADIO_RadioLogo's real logos for the wedge icon: "brand logos were mud at 40px").

    PLAYBACK -- nothing new decides it. "station"/"off" set AP_radioOn/AP_radioStation on the
    vehicle, the exact two setVariable calls fn_radioRadial.sqf's ButtonClick makes (fn_autoRadio.sqf
    makes the same ones from Q). "ap" calls ["start", _mode] call AP_fnc_gpsAutopilot -- identical
    to fn_radioRadial.sqf's own AP wedge. Actual playback (which .ogg, streaming, bystander
    say3D/distance) lives entirely in fn_radioListen.sqf, untouched, reading those same variables.
    This bridge never touches sound.

    apInstalled BUNDLES the driver check, exactly as fn_radioRadial.sqf's "_apOk" does
    (driver == player && LandVehicle && AP_autopilot), so a passenger never sees the AP ring at
    all. Splitting them -- reporting "installed" as a bare fact about the car and letting isDriver
    gate only the click -- reads more naturally from the field name, and was the first cut here.
    It is wrong for a PORT: it tells a passenger the car has an autopilot module, which the native
    radial deliberately does not. isDriver is still sent, because the click path still owes the
    non-driver toast when the seat changes while the page is open.

    NO AUDIO DUCKING (webui_fnc_volumeSlave): this page plays no sound of its own -- like the
    source mock, it is pure CSS animation (hub scanline flicker, ON AIR led, a toast). The volume
    slave exists for pages that emit audio through the OS mixer, bypassing Arma's sliders (see
    webui/functions/fn_volumeSlave.sqf); there is nothing here to slave. The actual radio audio is
    produced entirely outside this browser control by fn_radioListen.sqf, exactly as before this
    port existed, so nothing about ducking changes either way.

    VEHICLE EXIT / DESTRUCTION / SEAT CHANGE: fn_radioRadial.sqf does not handle this at all (its
    wedge refresh only re-reads `vehicle player` on the next hover/click, so it can sit open and
    stale). This bridge polls once per tick (see the watchdog spawn at the bottom): a seat change
    within the SAME vehicle just re-reads isDriver/on/st fresh next push (no special-casing
    needed); leaving the vehicle entirely or the vehicle dying closes the dialog outright, since
    there is nothing left to control. See the task report.
*/

params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith { diag_log "[CARRADIO] null display" };
disableSerialization;

private _ctrl = _display displayCtrl 515601;
if (isNull _ctrl) exitWith { diag_log "[CARRADIO] control missing" };
if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[CARRADIO] bridge init failed" };
// Let the SERVER replace this page's markup if it holds a newer copy, so UI ships
// without a client repack. No-op unless AP_fnc_webServeInit registered a fetcher and
// the server actually has the file -- otherwise the PBO page you just loaded stands.
[_ctrl, "ui\html\carradio.html"] call webui_fnc_serve;
[_ctrl] call AP_fnc_casinoFit;   // fills the safezone -- transparent; the page anchors its own dial bottom-left over the world, like the native radial

// Self-contained on purpose (fn_mapOpen.sqf's own scars: a helper declared as an opener-level
// private read as undefined the first time it was called from a later, different scope -- SQF
// resolves privates from the CALLER's scope, not the scope the code was written in). Every helper
// this needs is declared INSIDE it, so it is safe to hand to webui_fnc_on, a spawn, or uiNamespace
// and call it from anywhere later.
private _fnRadial = {
    private _veh = vehicle player;
    private _cfg = missionConfigFile >> "AP_Radio_Cfg" >> "AutoRadio";
    private _n = count getArray (_cfg >> "AUTORADIO_Radio");
    private _cols = getArray (_cfg >> "AUTORADIO_RadioColor");
    private _ids = getArray (_cfg >> "AUTORADIO_RadioStream");
    private _labels = getArray (_cfg >> "AUTORADIO_StreamLabel");
    // copied verbatim from fn_radioRadial.sqf's own _fnHex -- same cfg float triplet, same hex,
    // so a station is the identical color in both UIs
    private _fnHex = {
        params ["_rc"];
        ((_rc select [0, 3]) apply {
            private _v255 = floor ((_x * 255) min 255);
            format ["%1%2", "0123456789ABCDEF" select [floor (_v255 / 16), 1], "0123456789ABCDEF" select [_v255 mod 16, 1]]
        }) joinString ""
    };
    private _stations = [];
    for "_i" from 0 to (_n - 1) do {
        private _rc = parseSimpleArray (_cols select _i);   // matches fn_radioRadial.sqf: no bounds fallback here either -- same exposure if the arrays ever go out of sync, not a new one
        _stations pushBack (createHashMapFromArray [
            ["id",    _ids param [_i, str _i]],
            ["label", _labels param [_i, format ["STATION %1", _i + 1]]],
            ["color", format ["#%1", [_rc] call _fnHex]]
        ]);
    };
    // RESKIN (owner 2026-09-06): one wedge, shown only when the car has CHAMELEON PAINT fitted (mods slot 6,
    // published as AP_chameleon by fn_prepareVehicle / fn_restoreVehicles). Click = two seconds of static,
    // then a random stock livery -- fn_skinSwitch. A car with no stock liveries never shows it either.
    createHashMapFromArray [
        ["stations",    _stations],
        ["chameleon",   (_veh getVariable ["AP_chameleon", false]) && { ("true" configClasses (configFile >> "CfgVehicles" >> (typeOf _veh) >> "textureSources")) isNotEqualTo [] }],
        ["skinBusy",    _veh getVariable ["AP_skinBusy", false]],
        ["isDriver",    driver _veh isEqualTo player],
        ["apInstalled", (driver _veh isEqualTo player) && { (_veh isKindOf "LandVehicle") || {[_veh] call AP_fnc_isRotorcraft} } && { _veh getVariable ["AP_autopilot", false] }],
        ["on",          _veh getVariable ["AP_radioOn", false]],
        ["st",          _veh getVariable ["AP_radioStation", 0]],
        ["apMode",      if (missionNamespace getVariable ["AP_gpsAP", false]) then { missionNamespace getVariable ["AP_gpsAPMode", ""] } else { "" }]
    ]
};
// cross-scope handle for the "radialSet" verb's own re-push (same pattern as AP_lootData in
// fn_lootBridge.sqf) -- named AP_webCarRadio*, not AP_carRadio*, because fn_radioHud.sqf already
// owns the bare "AP_carRadio" rscLayer name for the existing now-playing toast; different
// mechanism, same neighbourhood, kept visibly distinct on purpose.
uiNamespace setVariable ["AP_webCarRadioData", _fnRadial];

// pages re-ask after a reload; answers the same builder the pusher uses (mirrors fn_mapOpen.sqf)
[_ctrl, "radial", _fnRadial] call webui_fnc_on;

[_ctrl, "radialSet", {
    params [["_kind", "", [""]], ["_val", 0, [0, ""]]];
    private _veh = vehicle player;
    if (_veh isEqualTo player) exitWith { createHashMapFromArray [["ok", false], ["msg", "not in a vehicle"]] };
    if !(driver _veh isEqualTo player) exitWith {
        ["Only the driver controls the radio.", "basic"] spawn AP_fnc_handleMessage;   // same string, same call fn_autoRadio.sqf/fn_radioRadial.sqf already use
        createHashMapFromArray [["ok", false], ["msg", "Only the driver controls the radio."]]
    };
    switch (_kind) do {
        case "station": {
            private _n = count getArray (missionConfigFile >> "AP_Radio_Cfg" >> "AutoRadio" >> "AUTORADIO_Radio");
            private _iRaw = if (_val isEqualType 0) then { _val } else { 0 };
            private _i = 0 max (_iRaw min (_n - 1));
            // identical to fn_radioRadial.sqf's ButtonClick: set the station, then turn on if it wasn't
            _veh setVariable ["AP_radioStation", _i, true];
            if !(_veh getVariable ["AP_radioOn", false]) then { _veh setVariable ["AP_radioOn", true, true]; };
        };
        case "off": {
            if (_veh getVariable ["AP_radioOn", false]) then { _veh setVariable ["AP_radioOn", false, true]; };
        };
        case "skin": {   // RESKIN: random stock livery; fn_skinSwitch gates on the fitted Chameleon Paint mod
            [_veh, "random"] call AP_fnc_skinSwitch;
        };
        case "ap": {
            private _mode = if (_val in ["madmax", "normal", "sloth"]) then { _val } else { "normal" };
            // identical to fn_radioRadial.sqf's AP wedge. gpsAutopilot owns every precondition
            // (module fitted, route set, on-road, undamaged, ...) and its own toast on refusal --
            // this does not duplicate or pre-check any of that.
            ["start", _mode] call AP_fnc_gpsAutopilot;
        };
        default {};
    };
    // instant reconcile, same idiom as fn_lootBridge.sqf's lootTake/lootAll re-push
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (!isNull _c) then { [_c, "radial", (call (uiNamespace getVariable "AP_webCarRadioData"))] call webui_fnc_push; };
    createHashMapFromArray [["ok", true]]
}] call webui_fnc_on;

// "the page asks; the display owns TAB/ESC in game" -- radial.html's own contract comment.
// AP mode selection follows this with its own call (see the page), so engaging autopilot and
// closing the dialog are two round-trips here rather than fn_radioRadial.sqf's single
// closeDialog-then-engage statement; gpsAutopilot does not look at dialog state either way.
[_ctrl, "radialClose", { closeDialog 0; true }] call webui_fnc_on;

// TAB / ESC close, same two DIK codes fn_radioRadial.sqf's own display handler consumes
_display displayAddEventHandler ["KeyDown", {
    params ["", "_k"];
    if (_k in [1, 15]) then { closeDialog 0; };
    false
}];

[_ctrl, "radial", (call _fnRadial)] call webui_fnc_push;

// Watchdog: fn_radioRadial.sqf never checks whether the player is still in the vehicle it opened
// for (it just goes stale until the next hover/click). This dialog polls once per tick instead --
// cheap, and the same idiom fn_radioListen.sqf (0.35s) and webui_fnc_volumeSlave (0.25s) already
// use for "watch vehicle/player state, act on change". A seat change inside the SAME vehicle just
// shows up in the next push (isDriver flips, nothing else needs to happen). Leaving the vehicle
// entirely, or the vehicle dying under them, closes the dialog outright -- there is nothing left
// for it to show.
[_ctrl] spawn {
    params ["_ctrl"];
    private _stop = false;
    while { !_stop && { !isNull _ctrl } && { !isNull (findDisplay 515600) } } do {
        private _veh = vehicle player;
        if ((_veh isEqualTo player) || { !alive _veh }) then {
            _stop = true;
        } else {
            [_ctrl, "radial", (call (uiNamespace getVariable "AP_webCarRadioData"))] call webui_fnc_push;
            uiSleep 0.3;
        };
    };
    if (_stop && { !isNull (findDisplay 515600) }) then { closeDialog 0; };
};

diag_log "[CARRADIO] ready";
