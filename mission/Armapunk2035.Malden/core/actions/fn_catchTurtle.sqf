private _turtleArray = nearestObjects[player, ["Turtle_F"], 5];
if (_turtleArray isEqualTo[]) exitWith {};
private _turtle = _turtleArray select 0;
if (isNull _turtle || alive _turtle) exitWith {};
if ([true, "turtle", 1] call AP_fnc_handleInv) then {deleteVehicle _turtle;
    titleText["You have taken some turtle meat", "PLAIN"];
    ["kill", "turtle", 1] call AP_fnc_handleQuest;
    AP_side_exp = AP_side_exp + 6;
    ["turtles", 1] call AP_fnc_statArrUpdate; [
        ["-GATHER-", player, profileName, format["gathered %1 %2 at position %3.", 1, "Turtle Meat", getPosATL player]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
} else {["You don't have enough inventory space for that.", "basic"] spawn AP_fnc_handleMessage;};