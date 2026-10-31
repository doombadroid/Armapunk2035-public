/*
    AP_fnc_warmBridge -- give the connect-time cache worker a way to report.

        [] call AP_fnc_warmBridge;      // core\init.sqf, in the same spawn that cuts the layer

    The worker is ui\html\warm.html, hosted by RscTitles class AP_map_warm (description.ext):
    idd 930450, one control, idc 930451, type 106. It pulls the map's three text assets, both
    satellite mips and every item icon through A3API at connect. This file is the ONLY reason
    any of that is visible from SQF -- without it the page still warms, in silence, exactly as
    it did before, and the landing screen's bar falls back to 100.

    A LAYER, NOT A DIALOG, AND THAT IS THE POINT. The landing dialog closes on DEPLOY and takes
    its in-flight fetches with it; a title layer is cut once at connect and never closed, so the
    cache keeps filling behind a player who deployed at 3%. Moving this work onto the landing
    page would undo the whole feature.

    THE DISPLAY COMES FROM uiNamespace, NOT findDisplay. dialog\hudWeb.hpp's header records the
    engine rule this depends on: a title layer is not findDisplay-able, so AP_map_warm carries
    an onLoad that parks its display in uiNamespace and an onUnload that clears it. The retry
    below is fn_hudWebInit's, verbatim in shape: cutRsc returns before the display exists, and a
    control resolved a frame too early is controlNull with no error anywhere.

    WEBUI_ctrl IS SAVED AND RESTORED AROUND webui_fnc_init, AND THAT IS LOAD-BEARING -- the same
    hazard fn_hudWebInit's header spells out. webui_fnc_init:51 publishes the control it just
    wired as uiNamespace "WEBUI_ctrl", and AP_fnc_landingBridge's landingReady handler pushes
    the landing payload into whatever is in that slot. This layer is cut 8 s after connect, which
    on a fast client can be AFTER the landing dialog opened -- and a re-wire that stole the slot
    would send the landing's own payload into a 0.02-wide invisible warmer instead. So the slot
    is put back exactly as it was found. Nothing here ever reads it; fn_warmProgress resolves the
    landing display by idd.

    EVERY FAILURE PATH SETS AP_warmPct TO 100, and the watchdog covers the one that cannot be
    detected here: a bridge that came up but a page that never speaks (webui.js failed to eval in
    the page, the layer was cut down by something else). A bar that sits at 0 forever is worse
    than a bar that was never real, because the player cannot tell it apart from a hung client --
    and PLAY is not gated on it either way, so 100 costs nothing but a lie the player never sees.

    NO CfgRemoteExec ENTRY AND NO SERVER FUNCTION. Everything the warmer reports is about this
    client's own texture cache; it is read by this client's own landing screen and by nothing
    else. The channel carries three Numbers and is clamped on arrival.
*/
disableSerialization;
if (!hasInterface) exitWith { false };

if (isNil "webui_fnc_init") exitWith {
    diag_log "[WARM] the webui library is not loaded -- the warmer still warms, it just cannot report";
    AP_warmPct = 100;
    false
};

// cutRsc returns before the layer's display exists. Same 5 s ceiling and same 0.1 s poll as
// fn_hudWebInit's re-cut branch; on expiry we report nothing and hand the bar its 100.
private _up = diag_tickTime + 5;
waitUntil {
    uiSleep 0.1;
    !isNull (uiNamespace getVariable ["AP_map_warm", displayNull]) || { diag_tickTime > _up }
};

private _d = uiNamespace getVariable ["AP_map_warm", displayNull];
private _c = if (isNull _d) then { controlNull } else { _d displayCtrl 930451 };
if (isNull _c) exitWith {
    diag_log "[WARM] AP_map_warm cut but control 930451 never appeared -- no progress channel";
    AP_warmPct = 100;
    false
};

// See the header: this slot belongs to whichever dialog is open, not to us.
private _prev = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
private _ok = [_c] call webui_fnc_init;
uiNamespace setVariable ["WEBUI_ctrl", _prev];

if (!_ok) exitWith {
    diag_log "[WARM] webui_fnc_init refused control 930451 -- no progress channel";
    AP_warmPct = 100;
    false
};

// NO webui_fnc_serve, deliberately, and for fn_hudWebInit's reason: serving replaces the live
// document with document.open()/write()/close(), which drops the page's queue mid-flight. This
// page ships in the PBO and stays as it was cut.
uiNamespace setVariable ["AP_warmCtrl", _c];
[_c, "warmProgress", { _this call AP_fnc_warmProgress }] call webui_fnc_on;

// THE WEAPON THUMBNAILS, AND WHY THE PAGE ASKS RATHER THAN BEING TOLD. The armory grid
// draws GAME CONTENT pictures out of CfgWeapons, so no list baked into the page can be
// right -- SQF has to enumerate them (AP_fnc_warmCatalogue). It is pushed in chunks, and
// webui_fnc_push replays only the LAST value on a channel to a late subscriber: a push
// that beat the page's WEBUI.on("warmGuns") would lose every chunk but one, silently. So
// the page calls US when it has subscribed, and the catalogue is built in the answer.
// _webuiCtrl is the calling control, published into the handler's scope by
// webui_fnc_init's CALL branch -- which spawns, so the config walk below does not run
// unscheduled and does not hold the page inside its alert().
[_c, "warmReady", { [_webuiCtrl] call AP_fnc_warmCatalogue }] call webui_fnc_on;

// THE WATCHDOG. 30 s is generous: the page's own first report goes out before its first fetch
// completes, and the ticker inside it retries every 500 ms until the bridge is up. Anything that
// has not spoken by then is not going to.
[] spawn {
    uiSleep 30;
    if !(missionNamespace getVariable ["AP_warmReported", false]) then {
        diag_log "[WARM] no progress in 30s -- assuming the page cannot report and filling the bar";
        AP_warmGaveUp = true;                 // read by fn_warmProgress: the bar stops moving
        AP_warmPct = 100;
        [] call AP_fnc_warmRepush;
    };
};

diag_log format ["[WARM] layer bridged, ctrl %1 t=%2", ctrlIDC _c, diag_tickTime toFixed 1];
true
