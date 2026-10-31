// SPDX-License-Identifier: MIT
/*
    fn_profile.sqf -- resolve one AQ_Profile capability, and optionally call it.

    WHY THIS EXISTS
      AQ_Profile maps nine capabilities onto function NAMES the host supplies.
      Nothing in the library may compile a config string, so the only legal
      thing to do with one of those names is look it up in missionNamespace and
      call the code it finds. Doing that at every call site means every call
      site also decides what an unmapped entry means, and "unmapped" is exactly
      the case that must not become "silently did nothing" -- an unmapped
      payMoney that looks like a success is a completed quest with no reward.

    WHAT IT DOES
      Two arities, because two callers want two different things and giving them
      one function is what keeps the answers consistent:

        [_key]           -> STRING   the mapped function name, "" when unmapped.
                                     The payout uses this to pre-flight every
                                     grant it is about to make, so a missing
                                     entry blocks the whole payout before
                                     anything has been granted.

        [_key, _args]    -> ANY      look the name up and call it with _args,
                                     returning whatever it returned. Returns
                                     FALSE when the entry is unmapped or the
                                     name resolves to nothing, and logs why.

      `false` rather than nil on failure is deliberate: every caller tests the
      result's type (`_n isEqualType 0`, `_ok isEqualType true`), and a nil
      would make that test itself throw, far away from the missing entry.

    WHERE IT MAY BE CALLED
      Anything that pays, grants or consumes runs on the SERVER (DESIGN.md
      section 2). `playerUid` and `countItem` are also read on the client, by
      the objective watchers, because the whole reason watchers live on the
      client is that only the client knows what the player is carrying -- those
      two reads feed the local display and the watcher's own gating, never a
      payout. See docs/PROFILE.md.

    Usage:
        private _fnName = ["payMoney"] call aq_fnc_profile;            // name
        private _n = ["countItem", [_uid, "aq_scrap"]] call aq_fnc_profile;
*/

params [["_key", "", [""]]];

private _wantsCall = (count _this) > 1;
private _args      = _this param [1, [], [[]]];

if (_key isEqualTo "") exitWith {
    diag_log "[AQ] profile: refused, empty capability key";
    if (_wantsCall) then { false } else { "" }
};

private _cfg = configNull;
_cfg = (localNamespace getVariable ["aq_cfg", createHashMap]) getOrDefault ["profile", configNull];   // LOCAL PATCH (VENDORED.txt): localNamespace
if (isNull _cfg) then {
    _cfg = missionConfigFile >> "AQ_Profile";
    if (!isClass _cfg) then { _cfg = configFile >> "AQ_Profile"; };
};

private _name = "";
if (isClass _cfg && {isText (_cfg >> _key)}) then { _name = getText (_cfg >> _key); };

if (!_wantsCall) exitWith { _name };

if (_name isEqualTo "") exitWith {
    diag_log format ["[AQ] profile: AQ_Profile >> %1 is empty, so that capability is unavailable on this host. The call was refused rather than pretended.", _key];
    false
};

private _fn = missionNamespace getVariable [_name, {}];
if (_fn isEqualTo {}) exitWith {
    diag_log format ["[AQ] profile: AQ_Profile >> %1 names '%2', which is not a defined function. The call was refused.", _key, _name];
    false
};

_args call _fn
