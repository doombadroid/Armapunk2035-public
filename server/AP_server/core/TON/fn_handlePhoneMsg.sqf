/*
    APS_fnc_handlePhoneMsg  (LooneyBin) -- emergency / text message ROUTER. Runs on the SERVER.
    2020 client (core/pmenu/fn_sendText.sqf) sends: [_mode, _caller, _target, _msg]
        mode 0  = player-to-player text      -> deliver to _target  (clientMessage type 0: rich box + inbox)
        mode 1  = !911 (police)              -> ALL MaxSec: copalert banner + tactical ping (LooneyBin redesign)
        mode 2  = !311 (medics)              -> ALL Trauma Team: clientMessage type 2 (EMS dispatch box + map marker + inbox)
        mode 3  = message The Admins         -> all ONLINE admins (players_global.adminlevel >= 2): type 3 box + marker
        mode 5  = admin "Message All"        -> everyone: type 5 "Admin Message" (phone twin of APS_fnc_adminMsg)
        mode 6  = admin -> single player     -> _target: type 6 "Admin Message"
        mode 10 = governor broadcast         -> everyone: type 10 "Gov Message"
    History: the deobf passthrough only routed 0/1/2 -- modes 3/5/6/10 fell through the switch and
    VANISHED (the sender still saw "You sent ... a message"), and mode 0 bypassed clientMessage so the
    text never landed in the receiver's phone inbox (AP_messages) and broke reply-tracking. BUGS.md #68.
*/
params [["_mode", -1, [0]], ["_caller", objNull, [objNull]], ["_target", objNull, [objNull]], ["_msg", "", [""]]];
if (isNull _caller || {_msg isEqualTo ""}) exitWith {};
// owner 2026-07-24 SECURITY (audit): CfgRE allowedTargets=2. _caller was a client-supplied object used for
// `name _caller` and the wiretap uid, so any message could be sent AS any player. Worse, modes 5 and 6
// (admin "Message All" / admin DM) and mode 10 (governor broadcast) had NO server-side authorisation at
// all -- the admin and governor gates existed only in the client's phone UI -- so any player could
// server-wide broadcast as "Admin Message" or "Gov Message".
// Fix: identity is forced to the real caller, then the privileged modes re-check authority server-side --
// adminlevel >= 2 from players_global for 5/6 (matching the client's admin gate), and the seated governor
// (SRV_governorData[0]) for 10. Modes 0/1/2/3 are unprivileged and unchanged.
private _srcPM = remoteExecutedOwner;   // 0 == server-internal = trusted
private _pmBlock = false;
if (_srcPM isNotEqualTo 0) then {private _pmCaller = (allPlayers select { owner _x isEqualTo _srcPM }) param [0, objNull];
    if (isNull _pmCaller) then { _pmBlock = true; } else {if (_pmCaller isNotEqualTo _caller) then {
            ["-SEC-", _pmCaller, format ["phone msg impersonation (mode %1): claimed %2", _mode, name _caller]] call APS_fnc_logIt;};
        _caller = _pmCaller;   // every downstream read (name, uid, grid) now uses the verified actor
        if (_mode in [5, 6, 10]) then {private _pmUid = getPlayerUID _pmCaller;
            private _authed = if (_mode isEqualTo 10) then {private _gov = format ["%1", (localNamespace getVariable ["SRV_governorData", []]) param [0, ""]];
                _gov = (_gov splitString "'") joinString "";   // the loader can wrap this value in quotes (see :40)
                (_pmUid isEqualTo _gov) && {_pmUid isNotEqualTo ""}} else {
                private _rows = [format ["SELECT adminlevel FROM players_global WHERE playerid='%1'", _pmUid], 2, true] call DB_fnc_asyncQuery;
                (parseNumber format ["%1", (_rows param [0, [0]]) param [0, 0]]) >= 2};
            if (!_authed) then {
                ["-SEC-", _pmCaller, format ["BLOCKED privileged phone broadcast mode %1 by %2", _mode, _pmUid]] call APS_fnc_logIt;
                _pmBlock = true;};};};};
if (_pmBlock) exitWith {};
private _name = name _caller;
private _grid = mapGridPosition _caller;

// ---- WIRETAP (owner 2026-07-21): live taps mirror matching traffic to the tapper. Rows are
// [tapperUid, victimUid, expiry, encrypted]. This is the ONLY place player text traffic is guaranteed to
// pass through, so the tap lives here rather than in the several client send paths. An Encrypted SIM victim
// still generates a mirror -- it just arrives as garbage, so the tapper learns that they tapped a hard line
// rather than silently receiving nothing and assuming the hack broke.
private _taps = (localNamespace getVariable ["APS_wiretaps", []]) select { (_x param [2, 0]) > serverTime };
localNamespace setVariable ["APS_wiretaps", _taps];   // server-only (qhSRV writes it): a client publicVariable could forge a tap
if (_taps isNotEqualTo []) then {private _callerUid = getPlayerUID _caller;
    private _targetUid = if (isNull _target) then { "" } else { getPlayerUID _target }; {
        _x params ["_tapper", "_victim", "", ["_enc", false]];
        if (_victim isEqualTo _callerUid || {_victim isNotEqualTo "" && {_victim isEqualTo _targetUid}}) then {
            private _tapperObj = (allPlayers select { (getPlayerUID _x) isEqualTo _tapper }) param [0, objNull];
            if (!isNull _tapperObj && {_tapperObj isNotEqualTo _caller}) then {
                // toArray first -- `apply` iterates arrays, not strings; mapping the char codes keeps the
                // garbage exactly as long as the real message so the tapper still sees traffic volume.
                private _body = if (_enc) then {((toArray _msg) apply { selectRandom ["#","%","&","@","*","?","!","$"] }) joinString ""
                } else { _msg };
                private _who = if (_victim isEqualTo _callerUid) then {format ["%1 -->", _name]} else {
                    format ["--> %1", (if (isNull _target) then { "?" } else { name _target })]};
                private _hdr = if (_enc) then { "<t color='#ff3b1e'>TAP (ENCRYPTED)</t>" } else { "<t color='#c9e21a'>TAP</t>" };
                [[0, format ["%1 %2", _hdr, _who], _body, objNull], "AP_fnc_clientMessage", _tapperObj, false, false] spawn AP_fnc_MP;
            };};} forEach _taps;};

switch (_mode) do {case 0: {   // player-to-player text -> rich "New Message" + phone inbox + reply target
        if (!isNull _target) then {[[0, _name, _msg, _caller], "AP_fnc_clientMessage", _target, false, false] spawn AP_fnc_MP;};};
    case 1: {   // !911 -> MaxSec : map ping (all cops) + larger alert bar (no grid) -- deliberate LooneyBin redesign
        private _cops    = allPlayers select { _x call APS_fnc_isDutyCop };
        private _bar     = format ["<t size='1.3' color='#4aa3ff'>911 - %1</t><br/><t size='1.05'>%2</t>", _name, _msg];
        private _pingPos = getPosATL _caller;
        private _pingTxt = format ["911: %1", _name]; {
            // copalert = badge-banner message type (duration 30, larger), not the small "basic" line
            [[_bar, "copalert"], "AP_fnc_handleMessage", _x, false, false] spawn AP_fnc_MP;
            // mil_dot map marker + 3D icon at caller pos, auto-deletes after 60s (same fn as Tactical Ping)
            [[_pingPos, _pingTxt], "AP_fnc_tacticalPing", _x, false, false] spawn AP_fnc_MP;} forEach _cops;};
    case 2: {   // !311 -> Trauma Team : proper EMS dispatch (green box + "EMS" map marker + inbox), was a bare text line
        {[[2, _name, _msg, _caller], "AP_fnc_clientMessage", _x, false, false] spawn AP_fnc_MP;
        } forEach (allPlayers select { _x call APS_fnc_isDutyMed });};
    case 3: {   // message The Admins -> online players with players_global.adminlevel >= 2
        // QUOTE(playerid): a bare 17-digit Steam64 would compile to a NUMBER and lose precision (> 2^53)
        private _rows = ["SELECT playerid FROM players_global WHERE adminlevel >= 2", 2, true] call DB_fnc_asyncQuery;
        private _uids = if (_rows isEqualType []) then { _rows apply { format ["%1", _x param [0, ""]] } } else { [] };
        private _admins = allPlayers select { (getPlayerUID _x) in _uids };
        if (_admins isEqualTo []) then {
            [["No admins are online right now — use !report in the Discord instead.", "basic"], "AP_fnc_handleMessage", _caller, false, false] spawn AP_fnc_MP;
        } else {{ [[3, _name, _msg, _caller], "AP_fnc_clientMessage", _x, false, false] spawn AP_fnc_MP; } forEach _admins;};};
    case 5: {   // admin "Message All" via the phone (twin of the admin-menu path APS_fnc_adminMsg)
        [[5, _name, _msg, objNull], "AP_fnc_clientMessage", -2, false, false] spawn AP_fnc_MP;
        [[990, objNull, format ["ADMIN MSG (phone) by %1: %2", _name, _msg]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;};
    case 6: {   // admin -> single player
        if (!isNull _target) then {[[6, _name, _msg, objNull], "AP_fnc_clientMessage", _target, false, false] spawn AP_fnc_MP;
            [[990, objNull, format ["ADMIN MSG (phone) by %1 to %2: %3", _name, name _target, _msg]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;
        };};
    case 10: {  // governor broadcast (client fn_sendText case 7 sends mode 10; 30-min client cooldown)
        [[10, _name, _msg, objNull], "AP_fnc_clientMessage", -2, false, false] spawn AP_fnc_MP;
        [[990, objNull, format ["GOV MSG by %1: %2", _name, _msg]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;};};
