params[["_unit", objNull, [objNull]], ["_msg", "", [""]]];
if (_unit isNotEqualTo player) exitWith {};
if (_unit getVariable["AP_restrained", false]) exitWith {
    ["Your restraints are preventing you from making that movement!", "basic"] spawn AP_fnc_handleMessage;};
if (_unit getVariable["AP_downed", false]) exitWith {["Your body cannot move while downed!", "basic"] spawn AP_fnc_handleMessage;};
if (_unit getVariable["AP_inAnim", false]) exitWith {["You are currently already in an animation!", "basic"] spawn AP_fnc_handleMessage;
};
if !(isNull objectParent _unit) exitWith {
    ["It is dangerous to make movements like that while you're in a vehicle!", "basic"] spawn AP_fnc_handleMessage;};
private _defaultEmotes = [["facepalm", "Acts_Ambient_Facepalm_2"], ["hi", "gesturehi"], ["ninja", "AmovPercMstpSnonWnonDnon_exerciseKata"],
    ["nod", "gestureNod"], ["nuhuh", "gesturehiB"], ["piss", "Acts_AidlPercMstpSlowWrflDnon_pissing"], ["point", "Acts_Pointing_Front"],
    ["pushup", "AmovPercMstpSnonWnonDnon_exercisePushup"], ["slowmo", "AmovPpneMstpSrasWrflDnon_AmovPercMsprSlowWrflDf_2"],
    ["squat", "AmovPercMstpSnonWnonDnon_exercisekneeBendB"], ["squat2", "AmovPercMstpSnonWnonDnon_exercisekneeBendA"],
    ["stop", "gesturehiC"], ["thebird", "Acts_Briefing_SB_Out"]];
private _donor7to10 = [["briefing", "Acts_B_briefings", 25], ["hide", "Acts_Taking_Cover_From_Jets_action", 10],
    ["idle", "HubStandingUC_idle1", 10], ["tpose", "TransAnimBase_noIK", 6]];
private _subOnly = [["badass", "Acts_Ambient_Relax_4", 6], ["risefromdead", "Acts_Undead_Coffin", 7],
    ["sitcuffed", "Acts_AidlPsitMstpSsurWnonDnon_loop", 7], ["stargaze", "Acts_Stargazer", 10]];

    _defaultEmotes append _subOnly;

    _defaultEmotes append _donor7to10;
private _emote = (_defaultEmotes param[_defaultEmotes findIf {_msg == (_x select 0)}, ""]) param[1, ""];
if !(isNull objectParent player) exitWith {};
if (_emote isEqualTo "") exitWith {private _string = "";
    private _emoteNames = _defaultEmotes apply {_x select 0}; {switch (true) do {case (_forEachIndex isEqualTo 0): {
                    _string = format["%1", _x];};
            case (_forEachIndex isEqualTo((count _emoteNames) - 1)): {_string = _string + format[", and %1", _x];};
            default {_string = _string + format[", %1", _x];};};}
    forEach _emoteNames;
    systemChat format["The valid emotes you can use are: %1", _string];};
switch (true) do {
    case (_emote in ["TransAnimBase_noIK", "HubStandingUC_idle1", "Acts_B_briefings", "Acts_Taking_Cover_From_Jets_action", "Acts_Undead_Coffin", "Acts_Stargazer"]):
        {private _delay = (_defaultEmotes param[_defaultEmotes findIf {_msg == (_x select 0)}, ""]) param[2, 0]; [
                [_emote, _delay, "switchMove", player], "AP_fnc_handleAnim", (allPlayers select {(_x distance player) <= 100
                })] spawn AP_fnc_MP;};
    case (_emote in ["gesturehi", "gesturehiB", "gesturehiC", "gestureNod"]): {player playActionNow _emote;};
    default {player playMove _emote};};