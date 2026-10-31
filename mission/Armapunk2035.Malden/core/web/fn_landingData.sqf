/*
    AP_fnc_landingData -- ONE payload for the landing page's "landing" channel, exactly the shape
    ui\html\landing.html's header declares:

        { name, players, cap, build, loadPct, factions:[{ id, locked, note }] }

    The page renders pushes verbatim and keeps its demo default for anything omitted, so every field is
    filled here rather than left to fall back to "87 / 120 ONLINE".

    loadPct USED TO BE ALWAYS 100, and the reasoning was sound: the landing only ever opens from
    fn_landingOpen, which runs from fn_initCiv -- i.e. after core\init.sqf's waitUntil
    {AP_session_completed}, with the account already read, the gear already applied and the whitelist
    constants already set. The player's DATA really is loaded by then. It just was not the only thing
    worth waiting on: the connect-time cache worker (ui\html\warm.html) spends the same minutes pulling
    the map's assets, both satellite mips and every item icon into the engine's texture cache, and THAT
    is what the bar reports now -- AP_warmPct, via AP_fnc_warmProgress.

    IT DOES NOT GATE PLAY, AND THE PAGE WAS CHANGED SO IT CANNOT. landing.html's welcome->faction step
    used to require loadPct >= 100; feeding it the cache figure would have parked a player behind ~600
    asset fetches for no benefit at all, since every consumer already handles a cold asset. PLAY is live
    from the first frame and the bar is informational. Deploy at 3% and the cache keeps filling behind
    you -- the worker lives in a title layer precisely so closing this dialog does not abandon it.

    100 IS THE DEFAULT, NOT 0. core\init.sqf sets AP_warmPct to 0 before the layer is even cut, so the
    normal path starts empty and climbs. The default here catches the client where that never ran or the
    warmer could not report at all: a full bar is a small lie, an empty one that never moves is
    indistinguishable from a hung client.

    THE LOCKS ARE THE TERMINAL'S GATES, NOT A SECOND POLICY. maxsec and trauma mirror the two whitelist
    tests in AP_fnc_dutyGate ("signon"), which mirror the two APS_fnc_dutySRV re-runs from its own DB read.
    A lock here only stops the card being clickable; nothing about it is trusted, and the deploy verb
    re-runs the whole gate anyway.

    Usage:  [] call AP_fnc_landingData
*/
private _fnc_faction = {
    params ["_id", "_locked", "_note"];
    createHashMapFromArray [["id", _id], ["locked", _locked], ["note", _note]]
};

// AP_dutyEnabled off is not "roster full": say so, because the player can do nothing about it and the
// terminals are gone too. Solo is untouched -- an all-civilian world is a coherent world (DUTY_SOAK 0).
private _dutyOn = missionNamespace getVariable ["AP_dutyEnabled", false];

// Read through getVariable defaults rather than calling the __SETCONST__ globals bare. They are set
// unconditionally at fn_requestReceived.sqf:38/198/213, i.e. before AP_session_completed and therefore
// before this can run -- but a THROW here is not a wrong lock, it is a page that never receives its first
// push, which means PLAY stays greyed and the only way out is Esc. A predicate that decides what a card
// looks like must not be able to take the screen down with it.
private _lvl = {
    private _v = call (missionNamespace getVariable [_this, {0}]);
    if (_v isEqualType 0) then { _v } else { 0 }
};
private _maxsecOK = _dutyOn && {(("AP_copLevel" call _lvl) >= 1) || (("AP_adminLevel" call _lvl) >= 1)};
private _traumaOK = _dutyOn && {(("AP_medicLevel" call _lvl) >= 1) && {("AP_medicLevel" call _lvl) != 99}};
private _offNote  = "DUTY SYSTEM OFFLINE";

// Uppercase because the page prints the note into the card's footer strip, which is the designer's
// letterspaced all-caps row ("SELECT" / "SELECTED" / its own "ROSTER FULL" default).
private _factions = [
    ["solo", false, ""] call _fnc_faction,
    ["maxsec", !_maxsecOK, (if (_dutyOn) then {"NOT WHITELISTED"} else {_offNote})] call _fnc_faction,
    ["trauma", !_traumaOK, (if (_dutyOn) then {"NOT WHITELISTED"} else {_offNote})] call _fnc_faction
];

// maxPlayers lives in description.ext's Header class and nothing in this tree has ever read it back out;
// getNumber on a missing entry answers 0, so the literal is a floor, not a duplicate of the config.
private _cap = getNumber (missionConfigFile >> "Header" >> "maxPlayers");
if (_cap <= 0) then { _cap = 60 };

// allPlayers counts a headless client as a player. fn_atmMenu.sqf:38 is this tree's idiom for excluding it.
private _online = count (allPlayers select {!(_x isKindOf "HeadlessClient_F")});

// Both halves of "which build am I on": AP_version is the script-side twin of version.hpp's Alpha X.Y.Z
// (core\configuration.sqf:13, and until now it had no readers at all), missionName is the packed PBO, which
// is where the b0NNN deploy tag actually lives.
private _build = toUpper (missionNamespace getVariable ["AP_version", "ALPHA"]);
if (missionName isNotEqualTo "") then { _build = format ["%1  %2", _build, missionName] };

createHashMapFromArray [
    ["name",     profileName],
    ["players",  _online],
    ["cap",      _cap],
    ["build",    _build],
    ["loadPct",  missionNamespace getVariable ["AP_warmPct", 100]],
    ["factions", _factions]
]
