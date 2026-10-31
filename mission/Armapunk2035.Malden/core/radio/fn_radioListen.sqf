/*
    fn_radioListen.sqf  (AP_fnc_radioListen) -- persistent per-client radio PLAYBACK loop (spawned once at spawn).
    Finds the radio-on vehicle this client should hear (riding in it, else nearest within AP_radioRange), reads its
    STATION, and plays that station's current track from the SERVER broadcast AP_radioNow[station]=[songId,startSrvTime]:

      - PACKED station (songId is a local CfgMusic class):
          OCCUPANT  -> playMusic [songId, elapsed] = SEEK-synced; BYSTANDER -> say3D on the car (positional).
      - STREAM station (songId = "STREAM|<mount>|<LABEL>", Malden Radio):
          with @MaldenRadio        -> extension plays the icecast mount; volume model lives in the DLL
                                      (occupant flat, bystander distance-ducked to AP_radioRange); per-tick "tick".
          without the addon        -> OCCUPANTS hear the packed promo loop (radio_promo_maldenradio,
                                      re-issued every AUTORADIO_PromoLen s); bystanders hear nothing.

    Server drives all transitions (APS_fnc_radioSRV). Nothing here is broadcast. No new fns are registered:
    the extension is called inline ("maldenradio" callExtension ...), detected once via CfgPatches.
*/
if (!isNil "AP_radioListening") exitWith {};
AP_radioListening = true;
AP_radioRange = 20;                                    // bystander audible radius (m) -- owner 2026-07-07: doubled 10->20
AP_radioModded = isClass (configFile >> "CfgPatches" >> "MaldenRadio");
if (AP_radioModded) then {
    // Mission end must silence the stream (belt) -- the DLL's 5 s tick watchdog is the braces
    // for abrupt teardown paths this handler never sees (alt-F4, crash-to-menu).
    addMissionEventHandler ["Ended", { "maldenradio" callExtension ["stop", []]; }];
};

private _cfg  = missionConfigFile >> "AP_Radio_Cfg" >> "AutoRadio";
private _stns = getArray (_cfg >> "AUTORADIO_Radio");
private _promoLen = getNumber (_cfg >> "AUTORADIO_PromoLen") max 10;
private _lastKey = "";
private _mode = 0;                                       // 0 none | 1 occupant (playMusic) | 2 bystander (say3D) | 3 stream (extension) | 4 promo loop
private _promoAt = 0;                                    // serverTime of the last promo (re)start
private _hudShown = false;                               // a HUD toast was shown for the CURRENT playback -> the OFF toast is earned

private _fnStop = {if (_mode in [1, 4]) then { playMusic ""; };
    _hudShown = false;
    if (_mode isEqualTo 2 && {!isNil "AP_radioEmitter"} && {!isNull AP_radioEmitter}) then { AP_radioEmitter setDamage 1; };
    if (_mode isEqualTo 3) then { "maldenradio" callExtension ["stop", []]; };
    _mode = 0;
    _lastKey = "";};

while { true } do {uiSleep 0.35;

    if (!alive player) then {if (_lastKey isNotEqualTo "") then { private _wasLoud = _hudShown; call _fnStop; if (_wasLoud) then { [-1] call AP_fnc_radioHud; }; };
        continue;};

    // which vehicle's radio should this client hear?
    private _veh = objNull;
    private _occupant = false;
    private _pv = vehicle player;
    if (_pv isNotEqualTo player && {_pv getVariable ["AP_radioOn", false]}) then {_veh = _pv; _occupant = true;} else {
        { if ((_x getVariable ["AP_radioOn", false]) && {alive _x} && {(_x distance player) <= AP_radioRange}) exitWith { _veh = _x; }; } forEach (nearestObjects [player, ["Car", "Ship", "Tank"], AP_radioRange]);
    };

    if (isNull _veh || {!(_veh getVariable ["AP_radioOn", false])} || {isNil "AP_radioNow"}) then {
        if (_lastKey isNotEqualTo "") then { private _wasLoud = _hudShown; call _fnStop; if (_wasLoud) then { [-1] call AP_fnc_radioHud; }; };   // owner 2026-08-02: only if a toast was ever shown (bystanders walking away got RADIO OFF)
        continue;};

    private _st   = ((_veh getVariable ["AP_radioStation", 0]) max 0) min ((count _stns) - 1);
    private _slot = if (_st < count AP_radioNow) then { AP_radioNow select _st } else { ["", 0] };
    _slot params [["_songId", ""], ["_start", 0]];
    if (_songId isEqualTo "") then { continue; };

    private _isStream = (_songId select [0, 7]) isEqualTo "STREAM|";

    // stream maintenance runs EVERY pass (not just on key change): volume follows distance live
    if (_isStream && {AP_radioModded} && {_mode isEqualTo 3}) then {
        "maldenradio" callExtension ["tick", [[0, 1] select _occupant, player distance _veh]];
        if (isNil "AP_radioTitleAt") then { AP_radioTitleAt = 0; AP_radioTitle = ""; };
        if ((serverTime - AP_radioTitleAt) >= 5) then {AP_radioTitleAt = serverTime;
            private _stt = ("maldenradio" callExtension ["status", []]) param [0, "stopped"];
            private _title = (_stt splitString "|") param [2, ""];
            if (_title isNotEqualTo "" && {_title isNotEqualTo AP_radioTitle}) then {AP_radioTitle = _title;
                // owner 2026-08-02: HUD is an IN-CAR instrument -- bystanders hear the faint
                // stream but never see toasts, not even on track change
                if (_occupant) then { [-2, _st, toUpper _title] call AP_fnc_radioHud; };};};};
    // promo loop: re-issue when a full spot has elapsed
    if (_mode isEqualTo 4 && {(serverTime - _promoAt) >= _promoLen}) then {
        playMusic "radio_promo_maldenradio"; _promoAt = serverTime;};

    // key includes _occupant (the method); existing occupants keep the same key when others get in/out -> no restart
    private _key = format ["%1|%2|%3|%4", _veh, _st, _start, _occupant];
    if (_key isEqualTo _lastKey) then { continue; };

    call _fnStop;                                       // stop whatever was playing (method-aware)
    _lastKey = _key;

    if (_isStream) then {
        private _parts = _songId splitString "|";                 // ["STREAM", mount, LABEL]
        private _label = _parts param [2, "MALDEN RADIO"];
        if (AP_radioModded) then {_mode = 3;
            "maldenradio" callExtension ["play", [_parts param [1, ""]]];
            "maldenradio" callExtension ["tick", [[0, 1] select _occupant, player distance _veh]];
            if (_occupant) then { _hudShown = true; [-2, _st, _label] call AP_fnc_radioHud; };} else {   // owner 2026-08-02: no toasts outside the car
            if (_occupant) then {_mode = 4;
                playMusic "radio_promo_maldenradio"; _promoAt = serverTime;
                _hudShown = true; [-3, _st, _label] call AP_fnc_radioHud;};};     // bystander w/o addon: silence, no HUD
        continue;};

    if (_occupant) then {_mode = 1;
        playMusic [_songId, ((serverTime - _start) max 0)];   // SEEK to the station's current position
        private _songs = getArray (_cfg >> (_stns select _st));
        private _songIdx = _songs findIf { _x isEqualTo _songId };
        if (_songIdx >= 0) then { _hudShown = true; [_songIdx, _st] call AP_fnc_radioHud; };} else {_mode = 2;
        if (isNil "AP_radioEmitter" || {isNull AP_radioEmitter}) then { AP_radioEmitter = "Land_HelipadEmpty_F" createVehicleLocal (getPosATL _veh); };
        AP_radioEmitter attachTo [_veh, [0, 0, 0]];
        AP_radioEmitter setDamage 1; uiSleep 0.05; AP_radioEmitter setDamage 0;
        AP_radioEmitter say3D [_songId, AP_radioRange];};};
