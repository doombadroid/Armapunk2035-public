/*
    fn_staffAct.sqf  (AP_fnc_staffAct) -- the STAFF DECK's verb router.

    One entry point for every button on ui\html\staff.html:

        [_action, _targetUid, _args] call AP_fnc_staffAct;   -> HashMap {ok, msg, ...}

    WHY THIS IS A ROUTER AND NOT A SET OF CALLS INTO THE NATIVE MENU. Every
    player-targeted function in core\admin resolves its target the same way:

        missionNamespace getVariable (lbData [12901, lbCurSel 12901])

    -- the admin dialog's own listbox. With display 12900 closed, lbData answers
    "" and each of them exits silently. They cannot be called from a page as they
    stand, and re-plumbing fourteen of them for a menu that dies with the native
    phone is more churn than it is worth. So this file performs the same payloads
    the buttons do, and each verb names the file it came from. Anything that is
    already callable without the dialog (godmode, invis, ESP, weather, restart,
    fun guns, stimmy, fed, event menu, economy, spectate, gifts) is CALLED, not
    copied.

    GATES. The level numbers below are the ones in the native code, not the ones
    in ADMIN_SPEC.md, wherever those two disagree -- the code is what the server
    and the other clients actually enforce. The known disagreement: the brief
    puts the restart ladders at level 2; fn_srvCycAdjust refuses below 3. Level 3
    wins here, and the page's own gate is cosmetic either way.

    CONFIRMS. The page arms-then-commits every destructive verb itself (the
    engine sandboxes confirm() out), so nothing here opens BIS_fnc_guiMessage --
    that would be a second prompt behind a page the admin already answered.
*/
// The page sends [action, targetUid|null, args]. fromJSON turns that null into
// nil, and params falls back to the default for a nil element -- so "no target"
// arrives here as "" rather than as a type error.
params [["_action", "", [""]], ["_targetUid", "", [""]], ["_args", [], [[]]]];

private _lvl = call AP_adminLevel;
if (_lvl < 2) exitWith { createHashMapFromArray [["ok", false], ["msg", "staff only"]] };

private _ok   = { params [["_m", ""]]; createHashMapFromArray [["ok", true],  ["msg", _m]] };
private _no   = { params [["_m", ""]]; createHashMapFromArray [["ok", false], ["msg", _m]] };
private _need = { params ["_n"]; format ["needs level %1 -- you are level %2", _n, _lvl] };

// The target, when there is one. Resolved from allPlayers by uid: the page can
// only ever name someone it was shown, and a stale uid answers objNull.
private _t = objNull;
if (_targetUid isNotEqualTo "") then {
    _t = allPlayers param [allPlayers findIf { (getPlayerUID _x) isEqualTo _targetUid }, objNull];
};
private _hasT = !isNull _t;

// Verbs that need the world rather than a page close the deck first. The dialog
// is closed here rather than on the page because the page cannot close a dialog.
private _shut = { if (!isNull (findDisplay 937600)) then { closeDialog 0 } };

private _logA = {
    params ["_what"];
    [["-ADMINACTION-", player, profileName, _what], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
};
private _logSpawn = {
    params ["_what", "_u"];
    [["-ADMINSPAWN-", player, profileName, format ["admin-spawned %1 for %2 at POS: %3", _what, name _u, getPosATL _u]],
        "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
};

switch (toLower _action) do {

    // ---------------------------------------------------------- dossier ----
    // fn_adminQuery's round trip: the TARGET's client answers with its own live
    // cash/bank (AP_fnc_adminPlayerQuery -> AP_fnc_adminInfo), which caches
    // into AP_staffDossier. The reply cannot be awaited -- a webui handler must
    // return synchronously or the page hangs -- so this answers with everything
    // readable locally plus whatever the last query left in the cache, and the
    // next 1 Hz payload carries the fresh numbers.
    case "info": {
        if (!_hasT) exitWith { ["no such player online"] call _no };
        [[player], "AP_fnc_adminPlayerQuery", _t, false] spawn AP_fnc_MP;

        private _dn = { params ["_c", "_root"];
            if (_c isEqualTo "") exitWith { "None" };
            getText (configFile >> _root >> _c >> "displayName") };
        private _cached = (missionNamespace getVariable ["AP_staffDossier", createHashMap]) getOrDefault [_targetUid, createHashMap];
        private _gang = (_t getVariable ["gang_data", []]) param [1, ""];

        private _lic = [];
        // Licences are the target's own client state and do not cross the wire;
        // the dossier shows what this client can see rather than inventing rows.
        private _out = createHashMapFromArray [["ok", true], ["msg", format ["queried %1", name _t]]];
        _out set ["info", createHashMapFromArray [
            ["steam",     _cached getOrDefault ["steam", ""]],
            ["gang",      if (_gang isEqualTo "") then { "—" } else { _gang }],
            ["primary",   [primaryWeapon _t,   "CfgWeapons"] call _dn],
            ["secondary", [secondaryWeapon _t, "CfgWeapons"] call _dn],
            ["handgun",   [handgunWeapon _t,   "CfgWeapons"] call _dn],
            ["vest",      [vest _t,            "CfgWeapons"] call _dn],
            ["backpack",  [backpack _t,        "CfgVehicles"] call _dn],
            ["licenses",  _lic]
        ]];
        _out
    };

    // ------------------------------------------------------------ coords ----
    // fn_adminGetPos / fn_adminSetPos. The page owns the coords box, so the
    // reply carries the position instead of writing control 12929.
    case "getpos": {
        private _u = if (_hasT) then { _t } else { player };
        if (isNull _u) exitWith { ["that player is no longer online"] call _no };
        private _p = (getPosATL _u) apply { (round (_x * 100)) / 100 };
        copyToClipboard (str _p);
        private _out = createHashMapFromArray [["ok", true],
            ["msg", format ["%1 @ %2 (grid %3)", if (_hasT) then { name _u } else { "you" }, _p, mapGridPosition _u]]];
        _out set ["pos", _p];
        _out
    };

    // The [0,0,0] refusal is fn_adminSetPos's hard-won guard (owner 2026-07-11,
    // the debug-island incident). The page refuses it too; this is the backstop.
    case "setpos": {
        private _p = _args select [0, 3];
        if (count _p < 2 || { !((_p param [0, ""]) isEqualType 0) } || { !((_p param [1, ""]) isEqualType 0) }) exitWith {
            ["that is not a position"] call _no };
        if (count _p < 3) then { _p pushBack 0 };
        if (((_p select 0) < 1) && { (_p select 1) < 1 }) exitWith {
            ["refusing [0,0,0] -- that is the debug island"] call _no };
        private _u = if (_hasT) then { _t } else { player };
        if (isNull _u) exitWith { ["that player is no longer online"] call _no };
        _u setPosATL _p;
        [format ["SET POS %1 -> %2", name _u, _p]] call _logA;
        [format ["moved %1 to %2", if (_hasT) then { name _u } else { "you" }, _p]] call _ok
    };

    // ------------------------------------------------------- teleporting ----
    case "tptome": {          // fn_adminTP [true, false]
        if (!_hasT) exitWith { ["no target"] call _no };
        (vehicle _t) setPosATL (getPosATL player);
        if (_t getVariable ["AP_timeTrialActive", false]) then { _t setVariable ["AP_timeTrialActive", false, true] };
        [format ["TPed %1 (%2) to self. Nearby players: %3.", name _t, getPlayerUID _t,
            (allPlayers select { _x distance player < 100 }) apply { name _x }]] call _logA;
        [format ["brought %1", name _t]] call _ok
    };
    case "tptothem": {        // fn_adminTP [false, true]
        if (!_hasT) exitWith { ["no target"] call _no };
        player setPosATL (getPosATL vehicle _t);
        [format ["TPed to %1 (%2). Nearby players: %3.", name _t, getPlayerUID _t,
            (allPlayers select { _x distance player < 100 }) apply { name _x }]] call _logA;
        [format ["went to %1", name _t]] call _ok
    };
    case "tpfacing": { [] call AP_fnc_adminTeleportFacing; ["teleported 10 m ahead"] call _ok };

    // MALDEN GRID owns map-click teleport (fn_adminTP's own comment says so).
    case "tpmapclick": {
        call _shut;
        uiNamespace setVariable ["AP_mapTpArm", true];
        [] spawn { uiSleep 0.15; [] call AP_fnc_webMap };
        ["grid opening, armed for teleport"] call _ok
    };
    case "openmap": {
        call _shut;
        [] spawn { uiSleep 0.15; [] call AP_fnc_webMap };
        ["grid opening"] call _ok
    };

    // ------------------------------------------------------ police work ----
    case "jail": {            // fn_adminJail
        if (!_hasT) exitWith { ["no target"] call _no };
        if (_t isEqualTo player) exitWith { ["not on yourself"] call _no };
        [[57, _t], "APS_fnc_wantedAdd", 2] spawn AP_fnc_MP;
        [[player, _t, [true]], "APS_fnc_handleJail", 2] spawn AP_fnc_MP;
        [format ["jailed %1 (%2)", name _t, getPlayerUID _t]] call _logA;
        [format ["jailed %1", name _t]] call _ok
    };
    case "revive": {          // fn_adminRevive mode 1
        if (!_hasT) exitWith { ["no target"] call _no };
        [[player, false, true, false], "AP_fnc_revived", _t] spawn AP_fnc_MP;
        _t setVariable ["AP_suicideVestDeath", false, true];
        [format ["admin revived %1.", name _t]] call _logA;
        [format ["revived %1", name _t]] call _ok
    };
    case "reviveall": {       // fn_adminRevive mode 2
        [[player, false, true, false], "AP_fnc_revived", allPlayers] spawn AP_fnc_MP;
        ["admin revived all players."] call _logA;
        ["revived everyone"] call _ok
    };
    case "restrain": {        // fn_adminRestrain
        if (!_hasT) exitWith { ["no target"] call _no };
        if (!isPlayer _t) exitWith { ["not a player"] call _no };
        if (_t getVariable ["AP_adminRestrain", false]) exitWith { ["already restrained"] call _no };
        [["adminRestrain", _t], "APS_fnc_victimSRV", 2, false] spawn AP_fnc_MP;   // server re-reads adminlevel, sets the flags, forwards AP_fnc_unitRestrain
        [format ["Restrained %1", name _t]] call _logA;
        [format ["restrained %1", name _t]] call _ok
    };
    case "unrestrain": {      // fn_adminUnrestrain
        if (!_hasT) exitWith { ["no target"] call _no };
        {
            _x params ["_var", "_value"];
            if (_t getVariable [_var, true]) then { _t setVariable [_var, _value, true] };
        } forEach [["AP_adminRestrain", false], ["AP_restrained", false], ["AP_escorting", false], ["AP_transporting", false]];
        detach _t;
        [format ["un-restrained %1", name _t]] call _logA;
        [format ["released %1", name _t]] call _ok
    };
    case "kick": {            // fn_adminKick -- server re-verifies (APS_fnc_adminKickBan)
        if (_lvl < 3) exitWith { [[3] call _need] call _no };
        if (!_hasT) exitWith { ["no target"] call _no };
        if (_t isEqualTo player) exitWith { ["not on yourself"] call _no };
        private _reason = _args param [0, ""];
        if (_reason isEqualTo "") exitWith { ["a kick needs a reason"] call _no };
        [[getPlayerUID _t, name _t, false, player], "APS_fnc_adminKickBan", 2] spawn AP_fnc_MP;
        [format ["kicked %1 (%2): %3", name _t, getPlayerUID _t, _reason]] call _logA;
        [format ["kick sent for %1", name _t]] call _ok
    };
    case "ban": {             // fn_adminBan
        if (_lvl < 4) exitWith { [[4] call _need] call _no };
        if (!_hasT) exitWith { ["no target"] call _no };
        if (_t isEqualTo player) exitWith { ["not on yourself"] call _no };
        private _reason = _args param [0, ""];
        if (_reason isEqualTo "") exitWith { ["a ban needs a reason"] call _no };
        [[getPlayerUID _t, name _t, true, player], "APS_fnc_adminKickBan", 2] spawn AP_fnc_MP;
        [format ["BANNED %1 (%2): %3", name _t, getPlayerUID _t, _reason]] call _logA;
        [format ["ban sent for %1", name _t]] call _ok
    };

    // ----------------------------------------------------------- toggles ----
    // These four are already dialog-free, so they are called rather than copied.
    case "godmode":   { [] call AP_fnc_adminGodmode; ["godmode toggled"] call _ok };
    case "invisible": { [] call AP_fnc_adminInvis;   ["invisibility toggled"] call _ok };
    case "adminmode": { [] call AP_fnc_adminMode;    ["admin ESP toggled"] call _ok };
    case "markers";
    case "eventvehmarkers": {   // admin_menu "Show Vehicles"
        if (isNil "AP_admin_showVeh") then { AP_admin_showVeh = true } else { AP_admin_showVeh = nil };
        [] spawn AP_fnc_eventVehMarkers;
        [format ["vehicle markers %1", ["off", "on"] select (!isNil "AP_admin_showVeh")]] call _ok
    };

    // --------------------------------------------------------- the world ----
    case "spectate":    { call _shut; [] spawn AP_fnc_adminSpectate; ["spectating -- F8 exits"] call _ok };
    case "spectateesp": { call _shut; [] spawn AP_fnc_spectateESP;   ["ESP spectate"] call _ok };
    case "bulletcam":   { call _shut; [] call AP_fnc_adminBulletCam; ["bullet cam"] call _ok };
    case "admincam": {
        if (_lvl < 3) exitWith { [[3] call _need] call _no };
        call _shut; [] spawn AP_fnc_adminCam; ["admin camera"] call _ok
    };
    case "eventmenu": { call _shut; [] spawn AP_fnc_adminEventMenu; ["event menu"] call _ok };
    case "fixtrunk": {
        // The native button acts on cursorObject, which needs the world, not a
        // full-screen page -- so this closes and says what to do next.
        call _shut;
        private _o = cursorObject;
        if (isNull _o) exitWith {
            ["Look at the vehicle and press FIX TRUNK again -- it acts on what your cursor is on.", "basic"] spawn AP_fnc_handleMessage;
            ["deck closed -- aim at the vehicle and fire it again"] call _ok
        };
        _o setVariable ["AP_activeTrunk", nil, true];
        [format ["cleared a stuck trunk on %1", typeOf _o]] call _ok
    };
    case "giftall": {
        [[0], "AP_fnc_giveGift", civilian] spawn AP_fnc_MP;
        ["gave out gifts to the server."] call _logA;
        ["gifts sent to every civilian"] call _ok
    };
    case "adminmessage": {
        private _msg = _args param [0, ""];
        if (_msg isEqualTo "") exitWith { ["type a message first"] call _no };
        if (_hasT) then {
            // One player. AP_fnc_broadcast is already client->all whitelisted;
            // aiming it at a single unit is the same message to one machine.
            [[[0, 1], format ["STAFF: %1", _msg]], "AP_fnc_broadcast", _t, false] spawn AP_fnc_MP;
            [format ["messaged %1 (%2): %3", name _t, getPlayerUID _t, _msg]] call _logA;
        } else {
            // Everyone. Relayed by the server so it passes handleMessage's
            // adminall anti-spoof gate (fn_adminMessage's own note).
            [[profileName, _msg], "APS_fnc_adminMsg", 2] spawn AP_fnc_MP;
            [format ["admin message to all: %1", _msg]] call _logA;
        };
        [if (_hasT) then { format ["sent to %1", name _t] } else { "sent to every player" }] call _ok
    };
    case "newsbroadcast": {
        if (_lvl < 5) exitWith { [[5] call _need] call _no };
        private _msg = _args param [0, ""];
        if (_msg isEqualTo "") exitWith { ["type the news first"] call _no };
        [[[0, 1], format ["SERVER NEWS: %1", _msg]], "AP_fnc_broadcast", -2, false] spawn AP_fnc_MP;
        [["-NEWSBROADCAST-", player, profileName, _msg], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
        ["broadcast sent"] call _ok
    };

    // ------------------------------------------------------------ money ----
    // fn_adminAddMoney, both modes, same bounds.
    case "addmoneyself";
    case "addmoneysel": {
        if (_lvl < 3) exitWith { [[3] call _need] call _no };
        private _val = round (_args param [0, 0]);
        if (_val < 100) exitWith { ["minimum is $100"] call _no };
        if (_val > 9999999) exitWith { ["maximum is $9,999,999"] call _no };
        if ((toLower _action) isEqualTo "addmoneysel") then {
            if (!_hasT) exitWith { ["no target"] call _no };
            [[_val, player, _t, _val, [1]], "APS_fnc_handleWireTransfer", 2, false, false] spawn AP_fnc_MP;
            [format ["added $%1 to %2's bank account.", _val, name _t]] call _logA;
            [format ["$%1 -> %2", [_val] call AP_fnc_numberText, name _t]] call _ok
        } else {
            AP_atmcash = (round (AP_atmcash + _val)) max 0;
            AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
            [format ["added $%1 to their bank account.", _val]] call _logA;
            [format ["$%1 -> your bank", [_val] call AP_fnc_numberText]] call _ok
        }
    };

    // ---------------------------------------------------------------- nd ----
    // Staff New Drachma grant. Same UI bounds spirit as money; the SERVER
    // re-checks the level and owns the credit (APS_fnc_adminNdSRV ->
    // APS_fnc_ndCreditSrv), so this client gate is courtesy only.
    case "addndself";
    case "addndsel": {
        if (_lvl < 3) exitWith { [[3] call _need] call _no };
        private _val = round (_args param [0, 0]);
        if (_val < 1) exitWith { ["minimum is 1 ND"] call _no };
        if (_val > 1000000) exitWith { ["maximum is 1,000,000 ND"] call _no };
        if ((toLower _action) isEqualTo "addndsel") then {
            if (!_hasT) exitWith { ["no target"] call _no };
            [[_t, str _val], "APS_fnc_adminNdSRV", 2, false, false] spawn AP_fnc_MP;
            [format ["%1 ND -> %2", _val, name _t]] call _ok
        } else {
            [[objNull, str _val], "APS_fnc_adminNdSRV", 2, false, false] spawn AP_fnc_MP;
            [format ["%1 ND -> you", _val]] call _ok
        }
    };

    // ---------------------------------------------------------- weather ----
    case "weather": {         // fn_adminWeather, minus its confirm
        // LEVEL 4, not the brief's 3: APS_fnc_changeWeather re-queries the caller's
        // adminlevel from the DB and refuses below 4, and fn_adminWeather's own
        // client gate says the same. The page's badge said 3 and was wrong.
        if (_lvl < 4) exitWith { [[4] call _need] call _no };
        private _w = toLower (_args param [0, ""]);
        if !(_w in ["snow", "rain", "day", "night"]) exitWith { ["unknown weather"] call _no };
        // NOT through AP_fnc_adminWeather. That function opens BIS_fnc_guiMessage,
        // and a modal raised while the deck is up TEARS DOWN dialog 937600 -- browser
        // control and all -- so the reply never reaches the page and the call dies as
        // "CALL FAILED: WEATHER" ten seconds later. The page armed this itself, so the
        // confirm is redundant; same bypass the restart ladder uses for fn_srvCycAdjust.
        [_w] remoteExec ["APS_fnc_changeWeather", 2];
        [format ["set the weather to %1", _w]] call _logA;
        [format ["weather -> %1", _w]] call _ok
    };

    // ---------------------------------------------------------- restart ----
    // fn_srvCycAdjust modes, per APS_fnc_changeServCycle: 13/4/5/6/7 = hard at
    // 0/1/10/30/60 min, 14/8/9/10/11 = the same ladder for an update restart.
    // fn_srvCycAdjust opens its own confirm; the page already armed, so the
    // remoteExec it would make is made here instead.
    case "restart": {
        if (_lvl < 3) exitWith { [[3] call _need] call _no };
        private _kind = toLower (_args param [0, ""]);
        private _mins = round (_args param [1, -1]);
        private _idx  = [0, 1, 10, 30, 60] find _mins;
        if (_idx < 0 || { !(_kind in ["hard", "update"]) }) exitWith { ["unknown restart"] call _no };
        private _mode = ([[13, 4, 5, 6, 7], [14, 8, 9, 10, 11]] select (_kind isEqualTo "update")) select _idx;
        [[_mode, player, getPlayerUID player], "APS_fnc_changeServCycle", 2] spawn AP_fnc_MP;
        [format ["set a %1 restart in %2 min", _kind, _mins]] call _logA;
        [format ["%1 restart in %2 min", _kind, _mins]] call _ok
    };


    // ------------------------------------------------------ owner tools ----
    case "economy": {
        if (_lvl < 5) exitWith { [[5] call _need] call _no };
        call _shut;
        [] spawn { uiSleep 0.15; createDialog "AP_economy_menu" };
        ["economy editor"] call _ok
    };
    case "stimmy": {
        if (_lvl < 5) exitWith { [[5] call _need] call _no };
        private _on = (toLower (_args param [0, ""])) isEqualTo "on";
        [[_on, player], "APS_fnc_stimmySRV", 2] spawn AP_fnc_MP;
        AP_stimmy = _on;
        [format ["stimmy checks %1", ["off", "on (10x cartel)"] select _on]] call _ok
    };
    // FABRICATOR FREE BUILD. Level 3 -- the same gate APS_fnc_fabDebugSRV enforces
    // against the database, which is the one that actually decides. While it is on,
    // every fabricator ignores a recipe's ingredients, its fab level and its
    // schematic; the machine, its KIND, the job time and the fail-closed collect
    // are all still enforced, so what you are testing still behaves like production.
    // The flag is NOT set locally here: the server owns it and publicVariable's it
    // back, and the roster pushes it into "toggles" once a second. A refused flip
    // therefore leaves the pill reading OFF instead of lying about an override that
    // was never granted.
    case "fabfree": {
        if (_lvl < 3) exitWith { [[3] call _need] call _no };
        private _on = (toLower (_args param [0, ""])) isEqualTo "on";
        [["free", [_on]], "APS_fnc_fabDebugSRV", 2] spawn AP_fnc_MP;
        [format ["fabricator free build %1", ["off", "on -- no materials, level or schematic"] select _on]] call _ok
    };
    case "fedreset": {
        if (_lvl < 5) exitWith { [[5] call _need] call _no };
        [["reset", player], "APS_fnc_fedOverrideSRV", 2] spawn AP_fnc_MP;
        ["fed / bank lockout reset"] call _ok
    };
    case "fedoverride": {
        if (_lvl < 5) exitWith { [[5] call _need] call _no };
        private _on = (toLower (_args param [0, ""])) isEqualTo "on";
        [[["off", "on"] select _on, player], "APS_fnc_fedOverrideSRV", 2] spawn AP_fnc_MP;
        [format ["fed override %1", ["off", "on -- no cop requirements, no cooldowns"] select _on]] call _ok
    };
    case "fungun": {
        if (_lvl < 5) exitWith { [[5] call _need] call _no };
        private _gun = toLower (_args param [0, ""]);
        private _who = toLower (_args param [1, "me"]);
        if !(_gun in ["lynx", "subcannon", "off"]) exitWith { ["unknown fun gun"] call _no };
        [[_gun, ["self", "all"] select (_who isEqualTo "all")], "APS_fnc_funGunSRV", 2] spawn AP_fnc_MP;
        [format ["%1 -> %2", _gun, _who]] call _ok
    };
    case "chargeself": {
        if (_lvl < 5) exitWith { [[5] call _need] call _no };
        call _shut;
        [] spawn AP_fnc_selfCharge;
        ["charging yourself"] call _ok
    };
    case "spawndummy": {
        if (_lvl < 5) exitWith { [[5] call _need] call _no };
        call _shut;
        { deleteVehicle _x } forEach ((player nearObjects ["Man", 300]) select { _x getVariable ["AP_testDummy", false] });
        private _ai = createVehicle ["C_man_polo_1_F", player getRelPos [4, 0], [], 0, "CAN_COLLIDE"];
        _ai setPosATL (player getRelPos [4, 0]);
        _ai setDir ((getDir player) + 180);
        removeAllWeapons _ai;
        _ai setCaptive true;
        _ai setVariable ["AP_testDummy", true, true];
        _ai addEventHandler ["HandleDamage", {
            params ["_u", "_hb", "_dmg", "_src", "_proj"];
            if (isPlayer _src && { _src != _u } && { time > (_u getVariable ["AP_t", 0]) }) then {
                _u setVariable ["AP_t", time + 0.4];
                private _m = currentMagazine _src;
                diag_log format ["[Armapunk][BHtest] wep=%1 mag=%2 proj=%3 rawDmg=%4 hb=%5", currentWeapon _src, _m, _proj, _dmg, _hb];
                systemChat format ["DUMMY hit -> mag: %1 | rawDmg: %2 | proj: %3", _m, _dmg, _proj];
            };
            0
        }];
        ["test dummy 4 m ahead"] call _ok
    };

    // --------------------------------------------------------- spawners ----
    // fn_adminWeaponMenu / fn_adminClothingMenu / fn_adminSpawnVehicle, minus
    // their listboxes: the class comes off the page, the target is the roster
    // selection or yourself (the same _fnTarget rule those files use).
    case "giveweapon";
    case "givekit": {
        if (_lvl < 3) exitWith { [[3] call _need] call _no };
        private _cls = _args param [0, ""];
        if (_cls isEqualTo "" || { !isClass (configFile >> "CfgWeapons" >> _cls) }) exitWith { ["no such weapon"] call _no };
        private _u = if (_hasT && { alive _t }) then { _t } else { player };
        private _kit = (toLower _action) isEqualTo "givekit";
        if (_kit) then {
            private _mags = getArray (configFile >> "CfgWeapons" >> _cls >> "magazines");   // primary barrel first
            if (_mags isEqualTo []) then { _mags = [_cls] call AP_fnc_weaponAllMags };
            private _mag = _mags param [0, ""];
            if (_mag isNotEqualTo "") then { [["mag", _mag, 3], "AP_fnc_adminGearReceive", _u, false] call AP_fnc_MP };
        };
        [["weapon", _cls, 1], "AP_fnc_adminGearReceive", _u, false] call AP_fnc_MP;   // after the mags so it spawns loaded
        [format ["1x %1%2", _cls, ["", " + 3 mags"] select _kit], _u] call _logSpawn;
        [format ["%1 -> %2", getText (configFile >> "CfgWeapons" >> _cls >> "displayName"), name _u]] call _ok
    };
    case "weaponacc": {
        private _cls = _args param [0, ""];
        if (_cls isEqualTo "" || { !isClass (configFile >> "CfgWeapons" >> _cls) }) exitWith { ["no such weapon"] call _no };
        private _acc = [];
        {
            private _dn = getText (configFile >> "CfgMagazines" >> _x >> "displayName");
            if (_dn isNotEqualTo "") then { _acc pushBack (createHashMapFromArray [["cls", _x], ["name", format ["[MAG] %1", _dn]]]) };
        } forEach ([_cls] call AP_fnc_weaponAllMags);
        // every WeaponSlotsInfo compatibleItems class, not the shop pool
        private _compat = [];
        {
            private _ci = _x >> "compatibleItems";
            if (isArray _ci) then { { _compat pushBack _x } forEach getArray _ci };
            if (isClass _ci) then { { if (getNumber _x >= 1) then { _compat pushBack configName _x } } forEach configProperties [_ci, "isNumber _x", true] };
        } forEach configProperties [configFile >> "CfgWeapons" >> _cls >> "WeaponSlotsInfo", "isClass _x", true];
        {
            private _dn = getText (configFile >> "CfgWeapons" >> _x >> "displayName");
            if (_dn isNotEqualTo "") then { _acc pushBack (createHashMapFromArray [["cls", _x], ["name", format ["[ATT] %1", _dn]]]) };
        } forEach (_compat arrayIntersect _compat);
        private _out = createHashMapFromArray [["ok", true], ["msg", format ["%1 compatible", count _acc]]];
        _out set ["acc", _acc];
        _out
    };
    case "giveaddon": {
        if (_lvl < 3) exitWith { [[3] call _need] call _no };
        private _cls = _args param [0, ""];
        private _n   = (round (_args param [1, 1])) max 1;
        if (_cls isEqualTo "") exitWith { ["nothing selected"] call _no };
        private _isMag = isClass (configFile >> "CfgMagazines" >> _cls);
        if (!_isMag && { !isClass (configFile >> "CfgWeapons" >> _cls) }) exitWith { ["no such item"] call _no };
        private _u = if (_hasT && { alive _t }) then { _t } else { player };
        [[["item", "mag"] select _isMag, _cls, _n], "AP_fnc_adminGearReceive", _u, false] call AP_fnc_MP;
        [format ["%1x %2 (%3)", _n, _cls, ["attachment", "magazine"] select _isMag], _u] call _logSpawn;
        [format ["%1x %2 -> %3", _n, _cls, name _u]] call _ok
    };
    case "spawnvehicle": {
        if (_lvl < 3) exitWith { [[3] call _need] call _no };
        private _cls = _args param [0, ""];
        if (_cls isEqualTo "" || { !isClass (configFile >> "CfgVehicles" >> _cls) }) exitWith { ["no such vehicle"] call _no };
        [1, player, _cls, position player, []] remoteExec ["APS_fnc_createAdminVeh", 2];
        [format ["Spawned vehicle %1", _cls]] call _logA;
        [format ["spawning %1", getText (configFile >> "CfgVehicles" >> _cls >> "displayName")]] call _ok
    };
    case "deleteadminvehicles": {
        if (_lvl < 3) exitWith { [[3] call _need] call _no };
        [2, player] remoteExec ["APS_fnc_createAdminVeh", 2];
        ["deleted all admin vehicles."] call _logA;
        ["admin vehicles deleted"] call _ok
    };
    case "wearclothing";
    case "giveclothing": {
        if (_lvl < 3) exitWith { [[3] call _need] call _no };
        private _cls = _args param [0, ""];
        if (_cls isEqualTo "") exitWith { ["nothing selected"] call _no };
        // kind decides the slot, exactly as fn_adminClothingMenu indexes it
        private _kind = switch (true) do {
            case (isClass (configFile >> "CfgGlasses" >> _cls)): { 3 };
            case (isClass (configFile >> "CfgVehicles" >> _cls) && { _cls isKindOf "Bag_Base" }): { 4 };
            default {
                switch (getNumber (configFile >> "CfgWeapons" >> _cls >> "ItemInfo" >> "type")) do {
                    case 801: { 0 }; case 701: { 1 }; case 605: { 2 }; default { -1 };
                }
            }
        };
        if (_kind < 0) exitWith { ["that is not clothing"] call _no };
        private _u = if (_hasT && { alive _t }) then { _t } else { player };
        private _wear = ((toLower _action) isEqualTo "wearclothing") || { _kind in [3, 4] };   // goggles/backpacks always equip
        if (_wear) then {
            [[(["uniform", "vest", "headgear", "goggles", "backpack"] select _kind), _cls, 1], "AP_fnc_adminGearReceive", _u, false] call AP_fnc_MP;
        } else {
            [["item", _cls, 1], "AP_fnc_adminGearReceive", _u, false] call AP_fnc_MP;
        };
        [format ["1x %1 (%2, %3)", _cls, ["uniform", "vest", "headgear", "goggles", "backpack"] select _kind, ["give", "wear"] select _wear], _u] call _logSpawn;
        [format ["%1 %2 for %3", ["gave", "equipped"] select _wear, _cls, name _u]] call _ok
    };

    default { [format ["unknown verb: %1", _action]] call _no };
};
