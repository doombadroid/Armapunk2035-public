/*
    AP_fnc_fabMode -- flip the fabricator between PRINT and BUY SCHEMATICS.

    One window, two lists. The vendor is here rather than on its own NPC because the moment a
    player learns they need a schematic is the moment they are standing at the machine being told
    they cannot print something -- and because placing an NPC means a 3DEN pass through the
    generated edenNPC_data table, which is a map job, not a code job.
*/
disableSerialization;
private _d = findDisplay 1810;
if (isNull _d) exitWith {};

AP_fabMode = if ((missionNamespace getVariable ["AP_fabMode", "print"]) isEqualTo "print") then {"shop"} else {"print"};
(_d displayCtrl 1816) ctrlSetText (if (AP_fabMode isEqualTo "shop") then {"Back to Printing"} else {"Buy Schematics"});
(_d displayCtrl 1830) ctrlSetText (if (AP_fabMode isEqualTo "shop") then {"Buy"} else {"Print"});
AP_fabRowCache = [];   // the two modes list different things
[] call AP_fnc_fabMenuFill;
