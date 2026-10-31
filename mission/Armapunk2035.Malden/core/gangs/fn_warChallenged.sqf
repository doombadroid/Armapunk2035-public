params[["_unit", objNull, [objNull]], ["_enemyGang", 0, [0]], ["_gangName", "", [""]]];
if (AP_gang_data isEqualTo[]) exitWith {};
if (_enemyGang in AP_gang_challenges) exitWith {};
AP_gang_challenges pushBack _enemyGang;
[format["<t color='#FF0000'><t size='2'>War Challenge!</t></t><br/><t color='#FFFFFF'>You have received a challenge of war from %1 of <t color='#FF0000'>%2</t>!", [name _unit] call AP_fnc_cleanName, _gangName], "basic"] spawn AP_fnc_handleMessage;
if !(isNull(findDisplay 9580)) then {
    [] spawn AP_fnc_gangWarsMenu   // LooneyBin #66: was AP_fnc_gangWars (doesn't exist) -> script error on receiving a challenge while the wars menu is open. gangWarsMenu waits on display 9580 + repopulates = a refresh.
};