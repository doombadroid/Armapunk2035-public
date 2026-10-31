params[["_val", "", ["", 0]], ["_total", "", ["", 0]], ["_arrester", objNull, [objNull]], ["_original", 0, [0]]];
// Server-origin guard: only the server (fn_wantedBounty / fn_claimBodybagSRV via AP_fnc_MP, owner 2)
// legitimately invokes this; it credits bank cash + honor, so a local call must not self-award a bounty.
if (remoteExecutedOwner != 2) exitWith {};
private _bonus = 0;
if (_val <= 0) exitWith {};
private _originalValue = _val;
if (AP_effSide isEqualTo civilian && player isEqualTo _arrester) then {AP_honor_exp = AP_honor_exp + (_original / 50);
    ["action", "honor", AP_honor_exp] spawn AP_fnc_handleQuest;
    ["action", "bountyarrest", 1] spawn AP_fnc_handleQuest;
    [14] call AP_fnc_ClupdatePartial;
    systemChat format["You've received %1 honor for an arrest", [round(_original / 50)] call AP_fnc_numberText];
    if (count units player > 1) then {[["AP_honor_exp", _original / 100], "AP_fnc_netSetVar", units group player - [player]
        ] spawn AP_fnc_MP;};
    private _isSkiptracer = ({player distance2D getMarkerPos _x < 20}
    count["marker_607", "marker_608", "marker_611", "marker_612"] > 0 && 11 in AP_honor_talents && 8 in AP_side_talents);
    if (_isSkiptracer) then {private _value = selectMin[_val, AP_arrest_cap];
        _bonus = round(_value * 0.2);
        if (_bonus > 25000) then {_bonus = 25000;};};};
private _multiplier =
switch (true) do {case (107 in AP_side_talents || AP_effSide isEqualTo civilian): {1};
    case (106 in AP_side_talents): {0.85};
    case (105 in AP_side_talents): {0.75};
    default {0.6};}; private _arrestCap =
if (side _arrester isEqualTo west) then {1000000} else {AP_arrest_cap};
_val = selectMin[_val * _multiplier, _arrestCap];
_total = selectMin[_total * _multiplier, _arrestCap];
// owner 2026-09-26 SECURITY (AUDIT A6): the officers' cash is paid by the SERVER (APS_fnc_wantedBounty / claimBodybagSRV ->
// APS_fnc_copSplit, capped + charged to the arrester's budget there). This client no longer names a pool; it only does prestige + UI.
if (AP_effSide isEqualTo west) then {[floor(_val / 50)] spawn AP_fnc_earnPrestige;
    if (_val isEqualTo _total) then {titleText["You and your fellow officers have been rewarded for this arrest.", "PLAIN"];} else {
        titleText["You and your fellow officers have been rewarded for killing this criminal, if you had arrested him you would have received much more.", "PLAIN"];
    };
    if (_originalValue > 5000) then {if !(16 in AP_achievements) then {[16] call AP_fnc_achievementGrant};
        [6, 1] call AP_fnc_updateRemoteStat;};
    if (_originalValue > 75000 && !(17 in AP_achievements)) then {[17] call AP_fnc_achievementGrant};
    if (_originalValue > 250000 && !(18 in AP_achievements)) then {[18] call AP_fnc_achievementGrant};} else {
    AP_atmcash = AP_atmcash + _val + _bonus;
    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
    [1] call AP_fnc_ClupdatePartial;
    if (_originalValue > 5000) then {[7, 1] call AP_fnc_updateRemoteStat;};
    systemChat format["You've been awarded $%1 for your part in an arrest. Good work.", [_val] call AP_fnc_numberText];};