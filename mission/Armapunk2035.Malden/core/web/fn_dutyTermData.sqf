/*
    AP_fnc_dutyTermData -- ONE payload for the MaxSec duty terminal's "duty" channel, exactly the shape
    ui\html\duty_maxsec.html declares:

        { station, officer: { name, rank, scd }, counts: { patrol, warrant, medic, scd, all } }

    Usage:  [] call AP_fnc_dutyTermData

    EVERY FIELD IS FILLED, never left to the page's demo defaults, because the page assigns the three
    objects WHOLESALE (`if(d.officer)S.officer=d.officer`) rather than merging: a payload missing
    officer.scd would leave S.officer.scd undefined, i.e. falsy, i.e. the SCD row locked for a whitelisted
    officer, and a payload missing a count key would render "0 ON DUTY" for that role.

    THE LOCKS ARE THE OFFER FILTERS, NOT A SECOND POLICY, and nothing here is trusted. rank drives the
    page's rank locks and mirrors fn_dutyCfg's role gateCodes (warrant/medic >= 3, all >= 6); scd drives the
    SCD row's whitelist lock and mirrors that row's {AP_isSCD}. A lock only stops a row being clickable --
    AP_fnc_dutyTermBridge re-runs the gateCode on dutyStart, and APS_fnc_dutySRV re-runs the whole table
    from its own DB read (fn_dutySRV.sqf:356-367), which is the only thing that can actually grant a shift.

    KNOWN LIMIT, DELIBERATE AND WORTH NAMING: fn_dutyCfg's "all" gate is {copLevel >= 6 || adminLevel >= 3},
    and the page has no way to express the admin half -- it locks that row on rank alone. An admin of level
    3+ whose COP rank is below 6 therefore cannot select ALL at the kiosk, even though both the bridge and
    the server would grant it. Reporting them as rank 6 to unlock the row was rejected: the page prints the
    rank it is given ("CAPTAIN (6)"), so that would put a false rank on a public terminal to work around a
    missing field. The honest fix is a designer-side officer.cmd flag mirroring officer.scd; until then the
    role is reachable at any tablet whose dialog falls back to AP_fnc_dutyTerminal's picker.

    MIRROR CASE, same missing field: a rank-0 admin passes the signon gate (adminLevel >= 1) and this
    builder's clamp renders them "CADET (1)" -- a false rank on the same public screen. The officer.cmd
    flag fixes both ends at once; until then admin sign-on reads as Cadet at the kiosk.

    COUNTS ARE CLIENT-SIDE AND CHEAP: one pass over allPlayers reading the PUBLIC AP_unitCopRole variable
    that fn_dutyContext.sqf:70 and fn_onPlayerRespawn.sqf:68 already broadcast. No server call, no new wire
    traffic, and no roster read -- the roster is the server's and stays there. ttmedic is deliberately not
    tallied: this is the MaxSec terminal and Trauma is a different faction's board.

    Read the level constants through getVariable defaults rather than calling the __SETCONST__ globals bare,
    the same guard fn_landingData.sqf uses: a THROW here is not a wrong lock, it is a page that never
    receives its only push and therefore renders the designer's demo officer instead of the player.
*/
private _lvl = {
    private _v = call (missionNamespace getVariable [_this, {0}]);
    if (_v isEqualType 0) then { _v } else { 0 }
};

// RANKS[] in the page is 1..7 (CADET..CHIEF OF POLICE) with index 0 the empty string, and it prints
// RANKS[rank] unguarded -- so an unwhitelisted 0 would render "OFFICER <name> ·  (0)". Clamped, and the
// signon gate above this screen has already refused anyone who is not on the roster at all.
private _rank = (("AP_copLevel" call _lvl) min 7) max 1;

// profileName goes into the header strip via innerHTML. Angle brackets are stripped so a name containing
// one cannot break the row it is printed into; nothing else about the name is changed (no case fold --
// the designer's demo value is uppercase, but a player's name is theirs).
private _name = (profileName splitString "<>") joinString "";
if (_name isEqualTo "") then { _name = "OFFICER" };

private _ids = ["patrol", "warrant", "medic", "scd", "all"];
private _counts = createHashMapFromArray (_ids apply {[_x, 0]});
{
    private _r = _x getVariable ["AP_unitCopRole", ""];
    if (_r in _ids) then { _counts set [_r, (_counts get _r) + 1]; };
} forEach allPlayers;

// The station name has ONE owner -- dialog\function\fn_spawnPointCfg.sqf's west table, where cop_spawn_2 is
// "Emergency Response HQ", the MaxSec main station and the marker fn_setupActions.sqf's tablet block is
// sited from. Read out of that table rather than copied, so renaming the spawn renames the terminal too.
// Guarded twice: fn_spawnPointCfg's west case dereferences SRV_mobileHQ (server init.sqf:306,
// publicVariable'd), which a client that has not yet received the publish does not have, and a missing row
// must not take the payload down with it.
private _station = "EMERGENCY RESPONSE HQ";
if (!isNil "SRV_mobileHQ") then {
    private _rows = [west] call AP_fnc_spawnPointCfg;
    private _row = _rows param [_rows findIf {(_x param [0, ""]) isEqualTo "cop_spawn_2"}, []];
    private _label = _row param [1, ""];
    if (_label isEqualType "" && {_label isNotEqualTo ""}) then { _station = toUpper _label; };
};

createHashMapFromArray [
    ["station", _station],
    ["officer", createHashMapFromArray [
        ["name", _name],
        ["rank", _rank],
        ["scd",  (missionNamespace getVariable ["AP_isSCD", false]) isEqualTo true]
    ]],
    ["counts", _counts]
]
