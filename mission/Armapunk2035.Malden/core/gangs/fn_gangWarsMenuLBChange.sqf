disableSerialization;
if ((AP_gang_data select 2) > 3) exitWith {};
params["_control", "_index"];
if (_index isEqualTo - 1) exitWith {};
private _enemyGang = parseNumber(_control lbData _index);
if ((AP_gang_data select 2) <= 3) then {switch (true) do {case (_enemyGang in AP_gang_wars): {ctrlEnable[9584, true]};
        case (_enemyGang in AP_gang_challenges && !(_enemyGang in AP_gang_wars)): {ctrlEnable[9583, true]};
        case !(_enemyGang in AP_gang_wars): {ctrlEnable[9582, true]};
        default {};};};