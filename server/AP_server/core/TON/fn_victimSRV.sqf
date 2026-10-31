/*
    APS_fnc_victimSRV -- the server hop for every player-on-player action whose effect runs on the
    VICTIM's own client (rob, baby oil, restrain, pull out, search, seize, disarm, shank, firing pin,
    revoke licence, blindfold, put in vehicle, staff admin-restrain).

        [_verb, _target, _args]   remoteExec'd by the actor's client (AP_fnc_MP, target 2)

    These used to go client -> client straight out of the actor's addAction, and the victim functions
    checked nothing: the addAction CONDITION was the only gate. CfgRE allowedTargets limits the target,
    never the sender, and live runs verifySignatures=0, so a modified client could zero anyone's cash,
    strip them, cuff them, eject them from a flying vehicle or empty their gear into its own car from
    anywhere on the map. The victim functions now refuse any remote sender but the server, and this is
    the one door in:
      * the actor is resolved from remoteExecutedOwner and is what gets forwarded -- the payload names
        no actor at all;
      * range and victim state restate each action's own addAction condition, with ~2 m of slack for
        position sync;
      * MaxSec-only verbs ask APS_fnc_isDutyCop (the duty roster), never the client's side; staff verbs
        re-read players_global.adminlevel, never the client's AP_adminLevel.
    Still client-claimed, because the server holds no copy: item costs (zip tie, baby oil, blindfold,
    shank), the talent flags on a rob, and the police-HQ polygon on an HQ seize (a duty cop within 8 m
    of a restrained suspect is required instead).
*/
params [["_verb", "", [""]], ["_target", objNull, [objNull]], ["_args", [], [[]]]];
private _src = remoteExecutedOwner;   // read before anything can suspend
if (_src isEqualTo 0) exitWith {};
private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
if (isNull _caller || {!alive _caller} || {isNull _target} || {_caller isEqualTo _target && {_verb isNotEqualTo "adminRestrain"}}) exitWith {};

private _d = _caller distance _target;
private _isCop = _caller call APS_fnc_isDutyCop;
private _v = { _target getVariable [_this, false] };
// staff = players_global.adminlevel >= 2 (the client gates of fn_restrain / fn_adminRestrain / fn_staffAct)
private _staff = {
    private _row = ["SELECT adminlevel FROM players_global WHERE playerid = %s", 2, true, [getPlayerUID _caller]] call DB_fnc_asyncQuery;
    (parseNumber format ["%1", (_row param [0, [0]]) param [0, 0]]) >= 2
};
// a police car the gear goes into: the cop-side picker is nearestObjects [_unit, ["Car","Air","Ship"], 30]
private _copBox = {
    _this isEqualType objNull && {alive _this} && {(_this getVariable ["AP_side", ""]) isEqualTo "cop"}
        && {(_this isKindOf "Car") || {_this isKindOf "Air"} || {_this isKindOf "Ship"}} && {(_this distance _target) <= 32}
};

// each case: [allowed, forwarded args, victim function]
private _fwd = switch (_verb) do {
    case "rob": {   // fn_robAction; Rob Person < 5 m, surrendered (or restrained, talent path)
        _args params [["_virt", false, [false]], ["_pistol", false, [false]]];
        [alive _target && {isPlayer _target} && {_d <= 7} && {("AP_surrendered" call _v) || {"AP_restrained" call _v}}
            && {!("AP_unitPassiveMode" call _v)}, [_caller, _virt, _pistol], "AP_fnc_robPerson"]
    };
    case "babyoil": {   // fn_babyOil; restrained, < 5 m
        [alive _target && {isPlayer _target} && {_d <= 7} && {"AP_restrained" call _v}, [], "AP_fnc_babyOilStrip"]
    };
    case "restrain": {   // fn_restrain: officers cuff any non-officer; everyone else needs surrendered/downed
        private _ok = alive _target && {isPlayer _target} && {_target isKindOf "CAManBase"} && {!("AP_restrained" call _v)}
            && {if (_isCop) then {(side _target) isNotEqualTo west} else {(("AP_surrendered" call _v) || {"AP_downed" call _v}) && {!("AP_unitPassiveMode" call _v)}}};
        // fn_restrain lets staff (adminlevel >= 2) reach past its 8 m: re-read that from the DB, never the client
        if (_ok && {_d > 10}) then { _ok = call _staff };
        [_ok, [_caller, _target, false], "AP_fnc_restrainAction"]
    };
    case "pullout": {   // fn_pulloutAction: <= 8 m of the vehicle; restrained/downed, or an officer, or a key holder
        private _veh = objectParent _target;
        [alive _target && {!isNull _veh} && {isNull objectParent _caller} && {(_caller distance _veh) <= 10}
            && {_isCop || {abs (speed _veh) < 5}}   // the civilian action wants speed < 2: no ejecting a pilot mid-air
            && {("AP_restrained" call _v) || {"AP_downed" call _v} || {_isCop}
                || {((_veh getVariable ["AP_vehOwners", []]) findIf { (_x param [0, ""]) isEqualTo (getPlayerUID _caller) }) > -1}},
            [_caller], "AP_fnc_pullOutVeh"]
    };
    case "search": {   // fn_searchAction; officer, restrained, <= 5 m
        [_isCop && {alive _target} && {isPlayer _target} && {_d <= 7} && {("AP_restrained" call _v) || {"AP_civRestrained" call _v}},
            [_caller], "AP_fnc_searchClient"]
    };
    case "seizeHQ": {   // fn_seizePlayerIllegal "HQ"; officer, restrained, < 6 m
        _args params [["_type", "", [""]]];
        [_isCop && {alive _target} && {isPlayer _target} && {_d <= 8} && {"AP_restrained" call _v} && {_type in ["ALL", "ITEM"]},
            [_type], "AP_fnc_seizePlayerIllegalAction"]
    };
    case "seizeField": {   // fn_seizePlayerIllegal "Field"; as above, into a live police car within 30 m
        _args params [["_box", objNull, [objNull]], ["_type", "", [""]]];
        [_isCop && {alive _target} && {isPlayer _target} && {_d <= 8} && {"AP_restrained" call _v} && {_type in ["ALL", "ITEM"]}
            && {_box call _copBox}, [_box, _type], "AP_fnc_seizeToVehicle"]
    };
    case "disarm": {   // fn_disarmAction; officer at a corpse (< 3 m), into a police car or "HQ"
        _args params [["_box", "", ["", objNull]]];
        [_isCop && {!alive _target} && {_target isKindOf "CAManBase"} && {!("AP_disarmed" call _v)} && {_d <= 5}
            && {(_box isEqualTo "HQ") || {_box call _copBox}}, [_caller, _box], "AP_fnc_disarmed"]
    };
    case "shank": {   // fn_useShank; a prisoner on a prisoner, < 2 m, inside 70 m of the jail
        [alive _target && {isPlayer _target} && {_d <= 4} && {"AP_arrested" call _v} && {!("AP_downed" call _v)}
            && {(_caller distance (getMarkerPos "jail_marker2")) <= 75}, [_caller, true], "AP_fnc_handleDowned"]
    };
    case "firingpin": {   // fn_removeFiringPin; officer, cop-cuffed civilian, < 4 m
        [_isCop && {isPlayer _target} && {(side _target) isEqualTo civilian} && {"AP_restrained" call _v} && {!("AP_civRestrained" call _v)}
            && {!("AP_gunBroken" call _v)} && {_d <= 7}, [], "AP_fnc_breakGuns"]
    };
    case "revoke": {   // fn_revokeLicense; officer, restrained civilian, < 5 m
        _args params [["_lic", "", [""]], ["_cycle", false, [false]]];
        [_isCop && {alive _target} && {isPlayer _target} && {(side _target) isEqualTo civilian} && {"AP_restrained" call _v} && {_d <= 7}
            && {_lic in ["driver", "bounty"]}, [_caller, _lic, _cycle], "AP_fnc_revokeLicenseAction"]
    };
    case "blindfold": {   // fn_blindfoldAction; 1 = put on a restrained player, 2 = take it off; < 5 m
        _args params [["_mode", 0, [0]]];
        [alive _target && {isPlayer _target} && {_d <= 7} && {if (_mode isEqualTo 1) then {("AP_restrained" call _v) && {!("AP_blinded" call _v)}}
            else {(_mode isEqualTo 2) && {(goggles _target) in ["G_blindfold_01_black_F", "G_blindfold_01_white_F"]}}},
            [_mode, _caller], "AP_fnc_blindfoldClient"]
    };
    case "putinveh": {   // fn_putInVeh; the restrained escortee (<= 20 m): wake them, then seat them in _veh
        _args params [["_veh", objNull, [objNull]], ["_seat", false, [false]]];
        [alive _target && {isPlayer _target} && {"AP_restrained" call _v} && {_d <= 22}
            && {!_seat || {alive _veh && {(_veh distance _target) <= 17}}},
            [[false], [_veh]] select _seat, ["AP_fnc_setUnconscious", "AP_fnc_putInVehAction"] select _seat]
    };
    case "adminRestrain": {   // fn_adminRestrain / staff deck "restrain": staff on any player, themselves included
        [isPlayer _target && {call _staff}, [_caller], "AP_fnc_unitRestrain"]
    };
    default {[false]};
};
_fwd params ["_ok", "_fargs", "_fn"];
if !(_ok) exitWith {
    ["-SEC-", _caller, format ["BLOCKED victimSRV '%1' by %2 on %3 (%4) at %5 m", _verb, getPlayerUID _caller, name _target, getPlayerUID _target, round _d]] call APS_fnc_logIt;
};
if (_verb isEqualTo "adminRestrain") then {   // what the admin's client used to do itself, in the same order
    [] remoteExec ["AP_fnc_closeMap", _target];
    _target setVariable ["AP_adminRestrain", true, true];
    _target setVariable ["AP_restrained", true, true];
};
_fargs remoteExec [_fn, _target];
