/*
    AP_fnc_mentor  (LooneyBin, owner 2026-07-11)
    MENTOR PROGRAM -- Act 3 of onboarding. A veteran civ scrolls on a [NEW BLOOD] player and offers to
    mentor them; if the newbie accepts, the server links the pair (APS_fnc_intakeSRV "mentorlink") and
    when the newbie FINISHES the Parole Papers arc the mentor is paid $1,000,000 -- online (instant ack) or
    offline (direct DB bank credit; offline money is DB-authoritative in this codebase). One mentor per
    newbie; the link lives server-side for the session (a restart mid-arc just means re-offering).
    The strongest retention lever is a human who gives a damn -- so we pay the humans.

    Modes:
        ["offer"]                      veteran's scroll action (cursorTarget = the New Blood)
        ["prompt", _mName, _mUid]      pushed to the NEWBIE (any client may send; accepting is gated on
                                       actually BEING a new blood with the arc active -- spoof-useless)
        ["linked", _name]              server ack -> both sides toast (sender-gated ==2)
        ["paid", _newbieName]          server -> mentor on payout (sender-gated ==2)
*/
params [["_mode", "", [""]], ["_a1", ""], ["_a2", ""]];

if (_mode isEqualTo "offer") exitWith {private _t = cursorTarget;
    if (isNull _t || {!isPlayer _t} || {!(_t getVariable ["AP_newBlood", false])}) exitWith {};
    if ((_t getVariable ["AP_mentorUid", ""]) isNotEqualTo "") exitWith {
        ["They already have a mentor.", "basic"] spawn AP_fnc_handleMessage;};
    if (player getVariable ["AP_newBlood", false]) exitWith {
        ["You're still New Blood yourself. Finish your own parole first.", "basic"] spawn AP_fnc_handleMessage;};
    [["prompt", profileName, getPlayerUID player], "AP_fnc_mentor", _t] call AP_fnc_MP;
    [format ["Mentor offer sent to %1.", _t getVariable ["AP_name", name _t]], "basic"] spawn AP_fnc_handleMessage;};

if (_mode isEqualTo "prompt") exitWith {
    // only meaningful on an actual mid-arc New Blood -- anyone spoofing this at a veteran gets nothing
    if !(player getVariable ["AP_newBlood", false]) exitWith {};
    if ((missionNamespace getVariable ["AP_intakeStep", 255]) > 5) exitWith {};
    if (time - (missionNamespace getVariable ["AP_mentorLastPrompt", -60]) < 30) exitWith {};   // anti-spam
    AP_mentorLastPrompt = time;
    private _mName = format ["%1", _a1];
    private _mUid  = format ["%1", _a2];
    [_mName, _mUid] spawn {params ["_mName", "_mUid"];
        private _ok = [
            format ["<t size='1.1'>%1</t> offers to be your <t color='#00FF00'>Mentor</t>.<br/><br/>They'll show you the ropes -- and get paid by the state when you finish your parole. Costs you nothing.", _mName],
            "Mentor Offer", "Accept", "Decline"] call BIS_fnc_guiMessage;
        if (_ok) then {[["mentorlink", player, _mUid], "APS_fnc_intakeSRV", 2] call AP_fnc_MP;};};};

if (_mode isEqualTo "linked") exitWith {if (remoteExecutedOwner isNotEqualTo 2) exitWith {};
    [format ["<t color='#00FF00'>Mentor linked:</t> %1. Loonies help Loonies.", _a1], "basic"] spawn AP_fnc_handleMessage;};

if (_mode isEqualTo "paid") exitWith {if (remoteExecutedOwner isNotEqualTo 2) exitWith {};
    // _a2 = the encouragement line, tailored server-side to the mentee's intake path
    [format ["<t color='#c7a24e'>Mentor payout:</t> %1 finished their parole. The state thanks you -- <t color='#c7a24e'>$1,000,000</t> deposited.<br/>%2", _a1, _a2], "basic"] spawn AP_fnc_handleMessage;
};

if (_mode isEqualTo "notify") exitWith {
    // offline-payout catch-up, pushed by the server on the mentor's NEXT login (mentor_notify table)
    if (remoteExecutedOwner isNotEqualTo 2) exitWith {};
    [format ["%1", _a1], "basic"] spawn AP_fnc_handleMessage;};
