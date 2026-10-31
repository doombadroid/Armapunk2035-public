// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_cyberdeckATM.sqf  (AP_fnc_cyberdeckATM)
    LooneyBin 2026-07-20 (cdfeatures.md #2): Cyberdeck "Jackpot Hack" -- a 6-symbol Sequence Breach on a
    WORLD ATM (Land_Atm_01_F / Land_Atm_02_F only -- NOT the base-game banking/NPC ATMs). On a win the
    SERVER rolls a weighted $100-50,000 payout and hands it over as PHYSICAL CASH (walk it to a bank and
    deposit it yourself), flags that ATM as drained until the next restart, and opens a 15-min deck cooldown.
    The amount + both limits are server-authoritative (APS_fnc_cyberdeckSRV "atmJackpot"); the client only
    gates, runs the minigame, and eats the Cyber Crime charge.
*/
params [["_atm", objNull, [objNull]]];
if (isNull _atm) exitWith {};
if !((typeOf _atm) in ["Land_Atm_01_F", "Land_Atm_02_F"]) exitWith {
    ["That ATM isn't on a network your deck can reach.", "basic"] spawn AP_fnc_handleMessage;};
if (!(call AP_fnc_hasDeck)) exitWith { ["You need a Cyberdeck for that.", "basic"] spawn AP_fnc_handleMessage; };
// QUEST HOOKS. These lived in fn_qhConsoleFire.sqf, which called itself "the single
// place all four breach tools route through" -- true only of that console, which had
// no opener, so `qhbreach` could never actually fire. The console was deleted
// 2026-09-04 with the rest of the retired cyberdeck cluster; the hooks move HERE, to
// where a breach is actually attempted, so every surface (visor, launcher router,
// world action, keybind) counts rather than one retired dialog.
// Placed AFTER the gates on purpose: a refused attempt is not a breach.
["action", "qhbreach", 1] spawn AP_fnc_handleQuest;
["action", "breach_atm", 1] spawn AP_fnc_handleQuest;
["qhbreach", [1]] call aq_fnc_event;   // ArmaQuest: aq_fx2_breach

// ATMs are createSimpleObject/createVehicleLocal -> LOCAL, no network id, so the OBJECT arrives null on the
// server. Pass its POSITION instead; the server resolves its own local ATM copy there. Per-ATM done-state is
// a position-key list the server broadcasts (AP_atmDoneKeys) so we can pre-gate before wasting a breach.
private _apos = getPosATL _atm;
private _akey = format ["%1_%2", round (_apos select 0), round (_apos select 1)];
if (_akey in (missionNamespace getVariable ["AP_atmDoneKeys", []])) exitWith {
    ["This ATM's already been drained this restart -- find another one.", "basic"] spawn AP_fnc_handleMessage;};
if (diag_tickTime < (missionNamespace getVariable ["AP_atmHackCd", 0])) exitWith {
    private _min = ceil (((missionNamespace getVariable ["AP_atmHackCd", 0]) - diag_tickTime) / 60);
    [format ["Your deck's still cooling down -- ~%1 min before the next ATM.", _min], "basic"] spawn AP_fnc_handleMessage;};

private _r = [6] call AP_fnc_cyberdeckSeq;
if !(_r isEqualTo 1) exitWith {};
if (isNull _atm || {(_atm distance player) > 6}) exitWith {};

AP_atmHackCd = diag_tickTime + (if (2 in (player getVariable ["AP_cdMods", []])) then { 600 } else { 900 });   // client cooldown (Cooling Rig 10min); server re-checks authoritatively
[["atmJackpot", _apos, player], "APS_fnc_cyberdeckSRV", 2] spawn AP_fnc_MP;   // POSITION, not the local object; server rolls + pays cash + alarms
[[112, player], "APS_fnc_wantedAdd", 2] spawn AP_fnc_MP;                      // Cyber Crime
