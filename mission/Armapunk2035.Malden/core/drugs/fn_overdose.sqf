private _gesture = "GestureSpasm%1";
private _duration = ceil random 20;
systemChat "You have overdosed!";
disableUserInput true;
player playActionNow format[_gesture, 1];
for "_i"
from 1 to _duration do {switch _i do {case 5: {player playActionNow format[_gesture, 2]};
        case 10: {player playActionNow format[_gesture, 3]};
        case 15: {player playActionNow format[_gesture, 4]};}; uiSleep 2;}; disableUserInput false;
private _death = random 1;
if (_death > 0.7) then {systemChat "You have died of a drug overdose.";
    player setDamage 1;} else {player playActionNow "gestureNod";};
AP_drug_level = AP_drug_level - 1;