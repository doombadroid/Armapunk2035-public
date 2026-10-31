params[["_animal", objNull, [objNull]]];
if (isNull _animal || alive _animal) exitWith {};
if !(isNil {_animal getVariable "AP_skinning"}) exitWith {};
_animal setVariable["AP_skinning", true, true];
private _meat =
switch (typeOf _animal) do {case "Cock_random_F": {"chicken"}; case "Hen_random_F": {"chicken"}; case "Fin_random_F": {
                    "dog"}; case "Alsatian_Random_F": {"dog"}; case "Goat_random_F": {"goat"}; case "Sheep_random_F": {
                                "sheep"}; case "Rabbit_F": {"rabbit"}; case "Snake_random_F": {"snake"};
                                    default {""};}; if (_meat isEqualTo "") exitWith {};
if ([true, _meat, 1] call AP_fnc_handleInv) then {AP_side_exp = AP_side_exp + 3;
    player playMoveNow "AinvPknlMstpSlayWrflDnon";
    titleText[format["You gathered 1 raw %1 meat.", _meat], "PLAIN"]; [
        ["-SKINANIMAL-", player, (profileName), format["skinned a %1 at POS: %2", typeOf _animal, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    deleteVehicle _animal;} else {["You cannot carry anymore meat.", "basic"] spawn AP_fnc_handleMessage;};