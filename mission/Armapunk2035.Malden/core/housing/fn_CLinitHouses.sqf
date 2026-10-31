if (AP_houses isEqualTo[]) exitWith {}; {private _position = parseSimpleArray(_x select 0);
    // owner 2026-07-04: prefer the nearest House whose TYPE is a real house type so a buyable shed resolves to the
    // INTACT Land_i_Shed_Ind_F, not the coincident derelict Land_u_Shed_Ind_F (keeps the phouse_<id> marker + the
    // AP_vehicles access entry on the same object the spawn list uses). Fall back to nearest for anything unusual.
    // owner 2026-07-09: radius 10 -> 18 to match the server restore (fn_receiveHouses / init.sqf re-tag). A shed row
    // whose worldspace is anchored on the immovable derelict can have its intact companion 10-18m away; at 10m the
    // client missed it and the keychain grabbed the derelict ("ghost unfinished shed"), while the wider-radius server
    // still owned the intact. The house-type filter keeps normal houses (own building at ~0m) unchanged.
    //
    // owner 2026-07-09 #2 (SPAWNPROBE: "can't spawn in my shed", sheds only, since forever): the replaced-shed
    // intact is a boot-time createVehicle object that STREAMS to the client AFTER login -- resolving here too
    // early found only the untagged terrain derelict, so the marker was created under the DB-id fallback name
    // (phouse_683) while the spawn menu, built later with the intact + its AP_houseID synced, asks for
    // phouse_<OID> (phouse_2125717115) -> getMarkerPos [0,0,0] -> "Error. Please wait a bit or try a different
    // spawn point." Normal houses are terrain (present instantly), so only sheds raced. Fix: WAIT (bounded ~20s)
    // for a house-type candidate carrying its AP_houseID tag before resolving; every consumer (marker name,
    // keychain entry, spawn list, spawn confirm) then agrees on the same object + the same phouse_<OID> name.
    // CLinitHouses runs spawned (scheduled), so the per-row uiSleep is legal; terrain houses resolve on the
    // first try with zero delay.
    private _house = objNull;
    for "_i" from 0 to 19 do {private _cands = nearestObjects[_position, ["House"], 18, true];
        // owner 2026-07-11 (Malden Makeover, "one house works the other doesn't"): big terrain houses refuse
        // setPosASL, so a maldened house's HIDDEN original still stands 0.2m from its visible Argo shell and
        // 2D-sort luck decided which one this bound (ghost in AP_vehicles = U/toggle-locks dead). A hidden
        // building is never a legit anchor -- skip them here and in the timeout fallback.
        _house = (_cands select { (typeOf _x) in AP_houseTypes && {!isObjectHidden _x} }) param[0, objNull];
        if (!isNull _house && {!isNil {_house getVariable "AP_houseID"}}) exitWith {};
        uiSleep 1;};
    if (isNull _house) then {
        // timeout: no intact/tagged object ever appeared (genuinely broken spot) -- old fallback behavior
        _house = ((nearestObjects[_position, ["House"], 18, true]) select { !isObjectHidden _x }) param[0, objNull];};
    if !(isNull _house) then {
        // LooneyBin: re-add owned houses to AP_vehicles so T-key storage access works after a relog
        // (AP_vehicles resets each session). Ownership/caps/storage on the object are restored
        // server-side by fn_receiveHouses; here we just rebuild the per-client access list + marker.
        if !(_house in AP_vehicles) then { AP_vehicles pushBack _house; };
        // owner 2026-07-10: player-set name (AP_houseName, set globally by fn_receiveHouses) wins over the type name.
        private _cn = _house getVariable ["AP_houseName", ""];
        private _houseName = if (_cn isEqualTo "") then { getText(configFile >> "CfgVehicles" >> typeOf _house >> "displayName") } else { _cn };
        private _marker = createMarkerLocal[format["phouse_%1", _house getVariable ["AP_houseID", _x select 1]], _position];
        _marker setMarkerTextLocal _houseName;
        _marker setMarkerColorLocal "ColorBlue";
        _marker setMarkerTypeLocal "mil_end";};
    // owner 2026-07-11 (Malden Makeover): observability for the "can't unlock doors after reboot" class of
    // bug -- mirror the FINAL resolve/registry state for MALDENED rows (or outright misses) to the server
    // RPT so it's diagnosable without client logs (APS_fnc_logIt idiom). Fires only for those rare rows.
    if (isNull _house || {_house getVariable ["AP_malden", false]}) then {
        [["-MALDEN-", player, format ["CLinit resolve @%1 -> %2 (houseID %3, inLifeVeh %4)",
            _position, typeOf _house, _house getVariable ["AP_houseID", -1], _house in AP_vehicles]],
            "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;};}
forEach AP_houses;
