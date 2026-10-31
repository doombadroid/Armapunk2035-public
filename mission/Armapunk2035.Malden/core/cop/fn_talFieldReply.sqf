// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_talFieldReply.sqf  (AP_fnc_talFieldReply)
    LooneyBin 2026-07-20: runs on the SUSPECT's client when an officer runs a TAL field test. Alcohol
    and drug levels are client-local values (same ones the cop search already reports), so the suspect's
    machine reads them and sends the result back to the officer only.
*/
params [["_cop", objNull, [objNull]]];
if (isNull _cop) exitWith {};
if ((player distance _cop) > 8) exitWith {};
private _bac  = AP_alcohol_level;
private _drug = AP_drug_level;
["<t color='#4db8ff'>FIELD TEST</t> -- an officer just tested you.", "basic"] spawn AP_fnc_handleMessage;
private _verdict = if (_bac >= 0.4 || _drug >= 0.4) then { "<t color='#ff3b30'>POSITIVE -- IMPAIRED</t>" } else {
    if (_bac > 0 || _drug > 0) then { "<t color='#f0a01e'>TRACE -- under the limit</t>" } else { "<t color='#4db8ff'>NEGATIVE</t>" };};
[[format ["<t color='#f0a01e'>FIELD TEST -- %1</t><br/>%2<br/><t color='#7d8b9e'>Alcohol %3  |  Narcotics %4</t>",
    toUpper (name player), _verdict, (round (_bac * 100)) / 100, (round (_drug * 100)) / 100], "basic"],
    "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;
