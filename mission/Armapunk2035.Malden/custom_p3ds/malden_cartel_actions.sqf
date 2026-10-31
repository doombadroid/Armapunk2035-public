/*
    Scroll action on each cartel flag: collect what it has produced.

    The inherited AP_fnc_getCartelRubber was registered in Functions.h but attached to NOTHING --
    its action lived on the Altis mission.sqm flag object, which does not exist here, so cartel
    collection has never worked on this map. The flags are created at runtime
    (custom_p3ds/malden_cartels.sqf), so the action is added here, client-side, once they exist.

    The action only sends a cartel ID. The server reads the stock, decides the amount and pushes the
    result back -- see APS_fnc_cartelCollectSRV for why no amount is ever put on the wire.

    Blacksite has no action: it pays straight into the gang bank, so there is nothing to collect.
*/
if (!hasInterface) exitWith {};

[] spawn {
    private _roster = [] call AP_fnc_cartelCfg;
    waitUntil { uiSleep 2;
        ({!isNull (missionNamespace getVariable [(_x select 2), objNull])} count _roster) isEqualTo (count _roster) };

    {
        _x params ["_id", "_name", "_flagVar", "", "", "", "_payout", ""];
        private _bankPaid = ((_payout param [0, ""]) isEqualTo "money") && {(_payout param [3, "flag"]) isEqualTo "bank"};
        if (!_bankPaid) then {
            private _flag = missionNamespace getVariable [_flagVar, objNull];
            _flag addAction [
                format ["<t color='#e7c757'>Collect from %1</t>", _name],
                { params ["", "_caller", "", "_args"]; [[_args select 0, _caller], "APS_fnc_cartelCollectSRV", 2] spawn AP_fnc_MP; },
                [_id], 6, false, true, "",
                // visible only to a living member of the gang that FULLY holds this cartel, at the flag
                "alive _this"
                + " && {(_this distance2D _target) < 8}"
                + " && {((_target getVariable ['AP_capData', [0, '', 0]]) param [2, 0]) >= 1}"
                + " && {((_this getVariable ['gang_data', [0]]) param [0, 0])"
                + "      isEqualTo ((_target getVariable ['AP_capData', [0, '', 0]]) param [0, -1])}"
            ];
        };
    } forEach _roster;
    // ---- kill the designer's duplicate cartel icons ON THIS CLIENT -------------------------------
    // mission.sqm markers are created LOCALLY on every machine, including JIP clients. The
    // server-side deleteMarker in malden_cartels.sqf removes them from machines already present, but
    // a client connecting afterwards rebuilds its own copy straight from the sqm and never sees that
    // deletion -- so every joining player still saw two flags per cartel while the server log
    // correctly reported six removed. Repeat it locally on join.
    // Ours must be the survivor: AP_fnc_captureCartel writes live ownership into
    // format["%1_cartel", id], so the designer's static label can never show who holds the cartel.
    private _mine = _roster apply { _x select 3 };
    private _dropped = 0;
    {
        private _cpos = _x select 4;
        {
            if (!(_x in _mine) && {(markerType _x) isEqualTo "mil_flag"} && {(getMarkerPos _x) distance2D _cpos < 60}) then {
                deleteMarkerLocal _x; _dropped = _dropped + 1;
            };
        } forEach allMapMarkers;
    } forEach _roster;
    diag_log format ["[Armapunk2035][cartel] removed %1 duplicate cartel icons locally", _dropped];

    diag_log "[Armapunk2035][cartel] collect actions attached";
};
