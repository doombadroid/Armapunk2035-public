/*
    custom_p3ds\vcity_tower.sqf -- place the Vertical City tower (ap_vcity addon) in La Trinite.

    Replaces skyscraper30 (owner 2026-09-22): the old tower's map_objects row 9649 and the Luxe
    Suites kiosk row 13678 were soft-deleted in the same change, which is what turns Luxe Suites
    off (every suite path resolves the tower by the skyscraper30 model and exits on null). The 19
    placed street pieces inside the new footprint were soft-deleted with them; all 21 rows are
    backed up as SQL in deploy/map_backups/vcity_site_20260922.sql (tombstones are purged after
    7 days, so the backup is the restore path).

    The tower is an ADDON, not a mission-root p3d: 199 simulated Land_vc_* objects from
    VCITY_fnc_assemble (real doors, breach, glass damage, building positions). The mission lists
    ap_vcity in mission.sqm addons[], so every client needs the @Armapunk2035 client mod; the
    server and the headless client load it with -mod=@Armapunk2035.

    Site: skyscraper30's centre and heading (vdir 0.83867,0.544639 -> 57.0 deg). Measured on a
    loopback server (design/vertical-city/hardsurface/site_probe.py): terrain under the whole
    footprint is 165.48-165.93 m ASL, so the lobby floor goes at 165.90 m and nothing is flattened.

    SERVER ONLY: hideObjectGlobal on terrain objects only takes effect (and JIP-persists) when it
    runs on the server -- same law as lux_footprint.sqf / replace_sheds.sqf.
    Kill switch: SRV_vcityEnabled (server_init.sqf). False = no tower at all (the old one is
    deleted); the rollback is restoring the backed-up rows, then flipping this off.
*/
if (!isServer) exitWith {};
[] spawn {
    private _t0 = diag_tickTime;
    waitUntil { uiSleep 1; !isNil "SRV_vcityEnabled" || {diag_tickTime - _t0 > 60} };
    if !(missionNamespace getVariable ["SRV_vcityEnabled", true]) exitWith { diag_log "[VCITY] disabled by SRV_vcityEnabled"; };
    if (!isNil "AP_vcityTower") exitWith { diag_log "[VCITY] already placed"; };
    if (!isClass (configFile >> "CfgPatches" >> "ap_vcity")) exitWith {
        diag_log "[VCITY] ERROR: ap_vcity addon not loaded on the server (-mod=@Armapunk2035) -- tower NOT placed";
    };
    private _c = [7115.09, 7897.79];
    private _h = 57;
    private _lobbyASL = 165.90;

    // Clear terrain objects whose centre lies inside the tower's ground footprint (local frame:
    // x -31..33, y -35..22; +y = tower back, -y = podium/entrance). Same rotation as the assembler.
    private _hidden = 0;
    {
        private _d = (getPosASL _x) vectorDiff [_c#0, _c#1, 0];
        private _lx = (_d#0) * cos _h - (_d#1) * sin _h;
        private _ly = (_d#0) * sin _h + (_d#1) * cos _h;
        if (_lx > -31 && {_lx < 33} && {_ly > -35} && {_ly < 22}) then { _x hideObjectGlobal true; _hidden = _hidden + 1; };
    } forEach nearestTerrainObjects [_c, [], 75, false, true];

    private _originATL = [_c#0, _c#1, _lobbyASL - getTerrainHeightASL _c];
    AP_vcityTower = [_originATL, _h, 0, false] call VCITY_fnc_assemble;
    diag_log format ["[VCITY] placed %1 objects at %2 heading %3 (lobby %4 m ASL), hid %5 terrain objects",
        count AP_vcityTower, _c, _h, _lobbyASL, _hidden];
};
