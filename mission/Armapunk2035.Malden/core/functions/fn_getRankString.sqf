params[["_side", west, [west]], ["_unit", objNull, [objNull]]];
private _return =
if (_side isEqualTo west) then {private _text = "";
    // owner 2026-06-20: OWNER cop rank -- a fully custom display title (set in-game via "Set My MaxSec Title", broadcast
    // on the unit + re-applied on spawn). Owner-only (locked UID). Overrides the normal MaxSec rank everywhere the rank
    // shows (kill feed, detain/downed, medic menus...). The owner still wields full Chief (7) POWERS (see queryRequest).
    if (((getPlayerUID _unit) isEqualTo "76561190000000001") && {(_unit getVariable ["AP_ownerCopTitle", ""]) isNotEqualTo ""}) exitWith {
        (_unit getVariable ["AP_ownerCopTitle", ""]) + " "};
    if (_unit getVariable["AP_unitCopRetiredLevel", 0] != 0) then {_text =
        switch (_unit getVariable["AP_unitCopRetiredLevel", 0]) do {case 4: {"Retired MaxSec Sergeant "};
            case 5: {"Retired MaxSec Lieutenant "};
            case 6: {"Retired MaxSec Captain "};
            default {""};};} else {_text =
        switch (_unit getVariable["AP_unitCopLevel", 0]) do {case 1: {"MaxSec Cadet "};
            case 2: {"MaxSec Patrol Officer "};
            case 3: {"MaxSec Corporal "};
            case 4: {"MaxSec Sergeant "};
            case 5: {"MaxSec Lieutenant "};
            case 6: {"MaxSec Captain "};
            case 7: {"MaxSec Chief of Police "};
            default {""};};};
    _text} else {if (_side isEqualTo independent) then {switch (_unit getVariable["AP_medLevel", 0]) do {case 99: {"TT EMT Volunteer "};
            case 1: {"TT Private "};
            case 2: {"TT Corporal "};
            case 3: {"TT Sergeant "};
            case 4: {"TT Warrant Officer "};
            case 5: {"TT Lieutenant "};
            case 6: {"TT Commander "};
            case 7: {"TT Marshal "};
            default {""};};} else {"";};};
_return
