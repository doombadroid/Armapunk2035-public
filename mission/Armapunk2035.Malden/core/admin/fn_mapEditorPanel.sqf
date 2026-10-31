/*
    File: fn_mapEditorPanel.sqf  (AP_fnc_mapEditorPanel + its handlers)
    The optional panel: Eden's catalogue, and exact numbers.

    OPTIONAL BY DESIGN. Camera, selection, grab and nudge all run off display 46 and
    work with this closed; TAB opens it only for the two things that need a window --
    browsing the catalogue and typing a transform in. The typing half is the reason
    this tool was worth building at all rather than reusing Zeus, which has no way to
    say "put it at exactly 4291.170".

    Every button here is a REQUEST. The panel never writes the world.
*/
if (!hasInterface) exitWith {};

// EVERY handler is defined BEFORE createDialog. onLoad fires DURING createDialog, so a
// dialog created first would call AP_fnc_mapEditorPanelLoad while it was still nil --
// the panel would open completely empty, with no error.

if !(isFinal "AP_fnc_mapEditorPanelLoad") then {AP_fnc_mapEditorPanelLoad = compileFinal {
    disableSerialization;
    private _d = uiNamespace getVariable ["AP_mapEd_display", displayNull];
    if (isNull _d) exitWith {};
    private _cat = _d displayCtrl 12951;
    lbClear _cat;
    {
        _cat lbAdd (_x select 0);
        _cat lbSetValue [(lbSize _cat) - 1, _forEachIndex];
    } forEach ([] call AP_fnc_mapEditorCatalog);
    _cat ctrlAddEventHandler ["LBSelChanged", { [] call AP_fnc_mapEditorPanelCat; }];
    (_d displayCtrl 12952) ctrlAddEventHandler ["LBSelChanged", { [] call AP_fnc_mapEditorPanelSub; }];
    (_d displayCtrl 12961) ctrlSetText (str AP_mapEd_snap);
    [] call AP_fnc_mapEditorPanelSync;
}};

if !(isFinal "AP_fnc_mapEditorPanelCat") then {AP_fnc_mapEditorPanelCat = compileFinal {
    disableSerialization;
    private _d = uiNamespace getVariable ["AP_mapEd_display", displayNull];
    if (isNull _d) exitWith {};
    private _cat = _d displayCtrl 12951;
    private _i = lbCurSel _cat;
    if (_i < 0) exitWith {};
    private _subs = (([] call AP_fnc_mapEditorCatalog) select (_cat lbValue _i)) select 1;
    private _sub = _d displayCtrl 12952;
    lbClear _sub; lbClear (_d displayCtrl 12953);
    { _sub lbAdd (_x select 0); _sub lbSetValue [(lbSize _sub) - 1, _forEachIndex]; } forEach _subs;
}};

if !(isFinal "AP_fnc_mapEditorPanelSub") then {AP_fnc_mapEditorPanelSub = compileFinal {
    disableSerialization;
    private _d = uiNamespace getVariable ["AP_mapEd_display", displayNull];
    if (isNull _d) exitWith {};
    private _cat = _d displayCtrl 12951; private _sub = _d displayCtrl 12952;
    if (lbCurSel _cat < 0 || {lbCurSel _sub < 0}) exitWith {};
    private _list = ((([] call AP_fnc_mapEditorCatalog) select (_cat lbValue (lbCurSel _cat))) select 1)
                        select (_sub lbValue (lbCurSel _sub)) select 1;
    private _cls = _d displayCtrl 12953;
    lbClear _cls;
    {
        _cls lbAdd (_x select 0);
        _cls lbSetData [(lbSize _cls) - 1, _x select 1];   // the CLASSNAME rides on data
    } forEach _list;
}};

if !(isFinal "AP_fnc_mapEditorPanelPlace") then {AP_fnc_mapEditorPanelPlace = compileFinal {
    disableSerialization;
    private _d = uiNamespace getVariable ["AP_mapEd_display", displayNull];
    if (isNull _d) exitWith {};
    private _cls = _d displayCtrl 12953;
    if (lbCurSel _cls < 0) exitWith { hint "Pick an object first."; };
    [_cls lbData (lbCurSel _cls)] call AP_fnc_mapEdPlace;
}};

// Reflect the current selection into the numeric fields.
if !(isFinal "AP_fnc_mapEditorPanelSync") then {AP_fnc_mapEditorPanelSync = compileFinal {
    disableSerialization;
    private _d = uiNamespace getVariable ["AP_mapEd_display", displayNull];
    if (isNull _d) exitWith {};
    if (isNull AP_mapEd_sel) exitWith { (_d displayCtrl 12960) ctrlSetText "no selection"; };
    private _p = getPosWorld AP_mapEd_sel;
    (_d displayCtrl 12960) ctrlSetText (format ["row %1", AP_mapEd_sel getVariable ["AP_mapId", "?"]]);
    (_d displayCtrl 12955) ctrlSetText ((_p select 0) toFixed 3);
    (_d displayCtrl 12956) ctrlSetText ((_p select 1) toFixed 3);
    (_d displayCtrl 12957) ctrlSetText ((_p select 2) toFixed 3);
    (_d displayCtrl 12958) ctrlSetText ((getDir AP_mapEd_sel) toFixed 2);
}};

if !(isFinal "AP_fnc_mapEditorPanelApply") then {AP_fnc_mapEditorPanelApply = compileFinal {
    disableSerialization;
    private _d = uiNamespace getVariable ["AP_mapEd_display", displayNull];
    if (isNull _d || {isNull AP_mapEd_sel}) exitWith { hint "Select something first."; };

    private _snap = parseNumber (ctrlText (_d displayCtrl 12961));
    if (_snap > 0) then { AP_mapEd_snap = _snap; };

    private _o = AP_mapEd_sel;
    private _old = getPosWorld _o;
    private _new = [
        parseNumber (ctrlText (_d displayCtrl 12955)),
        parseNumber (ctrlText (_d displayCtrl 12956)),
        parseNumber (ctrlText (_d displayCtrl 12957))];
    // parseNumber returns 0 for anything unparseable, and [0,0,0] is a REACHABLE
    // position on this map's corner -- so a typo would silently teleport the object to
    // the map origin. Refuse an all-zero result unless the fields literally say 0.
    if (_new isEqualTo [0,0,0] && {!((ctrlText (_d displayCtrl 12955)) in ["0","0.000"])}) exitWith {
        hint "Could not parse those coordinates -- nothing sent.";
    };

    private _yaw = parseNumber (ctrlText (_d displayCtrl 12958));
    private _up  = vectorUp _o;
    private _d2  = [sin _yaw, cos _yaw, 0];
    _d2 = vectorNormalized (_d2 vectorDiff (_up vectorMultiply (_d2 vectorDotProduct _up)));
    if (vectorMagnitude _d2 < 0.001) exitWith { hint "That yaw is degenerate against this object's up vector."; };
    private _vdu = [_d2, vectorNormalized _up];

    private _id = _o call AP_fnc_mapEdIdOf;
    if (_id < 1) exitWith { hint "Not a map row."; };
    AP_mapEd_undo pushBack ["move", [_id, _old, [vectorDir _o, vectorUp _o]]];
    [["move", [_id, _new, _vdu]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
    hint "Exact transform sent.";
}};

// SECURITY 2026-09-26: core\init.sqf calls this with "boot" at client init, so the helpers above are
// defined (final) before another client can publicVariable a final copy of one first.
if (_this isEqualTo "boot") exitWith {};
if (isNil "AP_mapEd_active" || {!AP_mapEd_active}) exitWith { hint "Open the map editor first."; };
if (!isNull (uiNamespace getVariable ["AP_mapEd_display", displayNull])) exitWith { closeDialog 0; };

// ---- now that every handler exists, open it ------------------------------
createDialog "AP_map_editor";
