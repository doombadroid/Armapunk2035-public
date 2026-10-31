params[["_item", "", [""]]];
if (_item isEqualTo "") exitWith {};
["use", _item, 1] spawn AP_fnc_handleQuest; (switch _item do {case "cannabis": {[0, 0.03]}; case "smash": {[1, 0.1]};
        case "blacklace": {[3, 0.3]};
        case "glitterbase": {[4, 0.5]};
        default {[-1, 0]};}) params["_index", "_addInc"];
private _add = AP_addiction select _index;
if (_add > 0.9) then {AP_drug_withdrawl = false};
AP_addiction set[_index, selectMin[_add + _addInc, 1]];
AP_used_drug set[_index, time];
if (AP_drug_level > 0.9) then {private _overdose = random 1;
    if (_overdose > 0.6) then {[] spawn AP_fnc_overdose;
        while {dialog}
        do {closeDialog 0};};}; (switch AP_effSide do {case civilian: {["AP_addictionCiv", "AP_drugsUsedCiv"]};
    case west: {["AP_addictionCop", "AP_drugsUsedCop"]};
    case independent: {["AP_addictionMedic", "AP_drugsUsedMedic"]};
    default {["", ""]};}) params["_addictionVariable", "_drugsUsedVariable"];
if !(_addictionVariable isEqualTo "") then {profileNamespace setVariable[_addictionVariable, AP_addiction];
    profileNamespace setVariable[_drugsUsedVariable, AP_used_drug];};