params[["_cash", 0, [0]], ["_victim", objNull, [objNull]], ["_isBH", false, [false]]];
if (_cash isEqualTo 0) then {titleText["They didn't have any cash...", "PLAIN"]} else {[
        [1, format["%1 has robbed %2 for $%3", profileName, name _victim, [_cash] call AP_fnc_numberText]], "AP_fnc_broadcast", -2] spawn AP_fnc_MP;
    AP_cash = AP_cash + _cash;
    AP_cashCacheB = ((AP_cash / 4) + 9);
    [0] call AP_fnc_ClupdatePartial;
    titleText[format["You stole $%1", [_cash] call AP_fnc_numberText], "PLAIN"];};
if (_cash isEqualTo 0 && !(_isBH)) exitWith {};
private _chance = 0;
if (8 in AP_side_talents) then {private _idx = AP_bounty_list findIf {(getPlayerUID _victim) in _x};
    if !(_idx isEqualTo - 1) then {_chance =
        switch (true) do {case (21 in AP_honor_talents): {30};
            case (20 in AP_honor_talents): {20};
            case (19 in AP_honor_talents): {10};
            default {0};};};};
if (47 in AP_side_talents) then {_chance = _chance + 20;};
if (((random 100) > _chance) && !(_victim in (units group player)) && _cash > 0) then {[
        [18, player], "APS_fnc_wantedAdd", 2] spawn AP_fnc_MP;};