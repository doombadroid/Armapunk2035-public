if (AP_protesting) exitWith {};
if !(isNull AP_object_inhand) exitWith {["You're already holding an object.", "basic"] spawn AP_fnc_handleMessage};
private _started = time;
AP_protesting = true;
if !("_salute" in (animationState player)) then {player playAction "Salute"};
waitUntil {"_salute" in (animationState player) || time - _started > 5};
if (time - _started > 5) exitWith {AP_protesting = false};
closeDialog 0;
titleText["Rabble rabble rabble!", "PLAIN"];
AP_object_inhand = "Land_Poster_04_F"
createVehicle[0, 0, 0];
AP_object_inhand attachTo[player, [0, 0, 0.6], "righthand"];
AP_object_inhand setVectorUp[0, 90, -1];
AP_object_inhand setMass 0;
waitUntil {!("_salute" in (animationState player))};
deleteVehicle AP_object_inhand;
AP_protesting = false;