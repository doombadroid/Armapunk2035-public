/*
    AP_fnc_hudEdit -- open the HUD UI EDITOR. Entry point for the deck's Settings row.

        [] spawn AP_fnc_hudEdit;

    MUST BE SPAWNED. It closes whatever dialog the caller is standing in and then waits for the
    engine to actually take it down before creating its own -- createDialog on a frame where the
    old display is still up returns false and the player gets nothing, with no error.

    WHY A DIALOG AT ALL. The status HUD is an RscTitles LAYER (dialog\hudWeb.hpp): cut with
    cutRsc, never focused, and therefore never sent a mouse event. That is exactly what lets it
    sit over gameplay without eating input, and exactly what makes it undraggable. So the editor
    is a focused dialog showing the same page. See dialog\hudEdit.hpp.

    THE LIVE LAYER GOES DOWN FIRST. Two copies of the same HUD, one of them frozen and one of
    them being dragged, is not a thing anybody can edit against. AP_hudEditActive is what keeps
    it down: fn_hudWebInit's keeper asks once a second whether the layer should be up, and that
    flag is one of the answers -- so the cut below does not have to win a race with it, and the
    layer comes back on its own within a second of the flag clearing.
*/

if (!hasInterface) exitWith { false };

if (!isNull (findDisplay 938400)) exitWith {
    diag_log "[HUDEDIT] already open";
    false
};

if (isNil "webui_fnc_init") exitWith {
    ["The interface library is not loaded.", "basic"] call AP_fnc_handleMessage;
    false
};

// The editor places the vitals plates and the minimap, and the keeper does not draw either of
// them for a dead player -- there would be nothing on screen to drag.
if (!alive player || {missionNamespace getVariable ["AP_isDead", false]}) exitWith {
    ["You cannot rearrange the HUD right now.", "basic"] call AP_fnc_handleMessage;
    false
};

if !(missionNamespace getVariable ["AP_webHudEnabled", true]) exitWith {
    ["The web HUD is switched off -- there is nothing to arrange.", "basic"] call AP_fnc_handleMessage;
    false
};

// Set BEFORE the cut, or the keeper's next tick puts the layer straight back up.
AP_hudEditActive = true;
("AP_web_hud" call BIS_fnc_rscLayer) cutText ["", "PLAIN"];
uiNamespace setVariable ["AP_web_hud", displayNull];
uiNamespace setVariable ["AP_hudWebCtrl", controlNull];

// The caller is the deck (dialog 937500) and two dialogs cannot be open at once.
if (dialog) then { closeDialog 0; };
private _up = diag_tickTime + 3;
waitUntil { uiSleep 0.05; !dialog || { diag_tickTime > _up } };

if (!createDialog "AP_web_hudedit") exitWith {
    diag_log "[HUDEDIT] createDialog AP_web_hudedit refused";
    AP_hudEditActive = false;      // or the HUD never comes back
    ["Could not open the HUD editor.", "basic"] call AP_fnc_handleMessage;
    false
};

true
