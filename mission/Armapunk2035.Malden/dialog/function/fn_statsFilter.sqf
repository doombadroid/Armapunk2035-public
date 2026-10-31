params[["_selectedType", "", [""]], ["_controlData", [], [[]]]];
if (_selectedType isEqualTo "" || _controlData isEqualTo[]) exitWith {};
_controlData params["_control", "_selectedIndex"];
private _plb_display = findDisplay 877000;
private _menuTitle = _plb_display displayCtrl 877002;
private _mainFilterList = _plb_display displayCtrl 877003;
private _mainListGroup = _plb_display displayCtrl 877005;
private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
private _filterType = _control lbData _selectedIndex; {_x ctrlSetFade 1.00;
    _x ctrlCommit 0.00;}
forEach[_mainItemList]; {_x lbSetCurSel - 1}
forEach[_mainItemList];
lbClear _mainItemList;
private _statArray = ["Civilian - Cops Killed", "Defibrillators Used", "Successful Lockpicks", "Failed Lockpicks", "Time Spent In Prison", "Speedbombs Detonated", "Suicide Vest Detonated", "Banks Drilled", "Gold Bars Sold", "Adrenaline Shot Used", "Coffee Used", "RedGull Used", "Boltcut Used", "Bloodbag Used", "Berries Ate", "Kebabs Ate", "Meat Cooked", "Fuelcans Used", "Ironeore Mined", "Flawless Diamond Mined", "Donuts Eaten", "Glitter Processed", "Black Lace Processed", "Heroin Processed", "Treasure Gathered", "Weed Processed", "Organs Ate", "Wreck Excavator Used", "Homebrew Moonshine Processed", "Scotch Sold", "Shanks Used", "Salt Processed", "Rubber From Processing", "Plates Processed", "Timber Processed", "Fish Caught", "Turtles Catched", "Zipties Used", "Bank Money Broken Down", "Evidences Done", "Gas Stations Robbed", "Casino Money Loss", "Casino Money Gained", "Lottery Money Loss", "Lottery Money Gained", "Money Picked Up", "Gas Station Money Robbed", "Vehicles Chopped", "Fugitives Arrested", "Tickets Paid", "Money Spent On Tickets", "Tickets Given", "Tickets Given Amount", "Unused", "Unused", "Unused", "Unused", "Server Cycle Quests Done", "Seasonal Quests Done", "Black Lace Prime Processed", "Black Lace Prime Sold", "Uranium Processed", "Uranium Sold", "Smash Bricks Processed", "Smash Bricks Sold", "RPG Vehicle Hits", "Civilian - Cops Downed", "Civilian - Restrained", "Civilian - Grenaded", "Civilian - MaxTac Killed", "Civilian - Cops Headshotted", "War Kill Headshots", "Civilian - Cops Vested", "Civilian - Cops Speedbombed", "Turfs Captured", "Cartels Captured", "Drug Runner Planes Delivered", "Drug Runner Boats Delivered", "Players Bolt Cutted", "Weapons Crafted", "Vehicles Crafted", "Money Spent At Rebel", "Money Spent For Bail", "Money Spent Buying Houses", "Fed Safes Opened", "Kills By Armed Offroad", "Kills By Armed Quilin", "Kills By Armed Jeep", "Money Earned on Cop", "Money Earned on Medic", "Homebrew Moonshine Processed", "Homebrew Moonshine Sold", "White Lightning Processed", "White Lightning Sold", "Distance Walked", "Distance Drove", "Graveyard Events Won", "Battle Royale Events Won", "Gun Game Events Won", "Barley Gathered", "Corn Gathered", "Cooked Oysters Processed", "Cooked Oysters Sold", "Fried Oysters Processed", "Fried Oysters Sold", "Blackjack Won", "Blackjack Lost", "Slots Won", "Slots Lost", "Prisons Done", "Convoys Done", "Convoy Money Earned", "Banks Done", "Bank Money Stolen", "Loony Bin's Breached", "Executed By Electric Chair", "Pardoned By Governor", "Retired Stat", "Ignition Bombs Detonated", "Loot Crates Opened", "Giveaway Money Won", "Login Bonus Crates Opened", "House Fires Taken Out", "Jewelry Emporium Cases Opened", "Jewelry Emporiums Drilled", "Remote Explosives Activated", "Money Spent Electric Bills", "Gang Fortress Captures", "Crypto Coins Sold", "Jewelry Emporiums Completed", "Civilian - Cops Killed At Jewelry Emporium", "Unused", "Unused", "Unused"];
switch (_filterType) do {case ("MyLoonyBin Statistics"): {{private _statValue = _x;
                private _statName = _statArray select _forEachIndex;
                private _formatValue =
                switch (true) do {case ((_statName find "Money") != -1): {format["$%1", [_statValue] call AP_fnc_numberText]};
                    case ((_statName find "Distance") != -1): {format["%1 KM", [_statValue] call AP_fnc_numberText]};
                    case ((_statName find "Time") != -1): {format["%1 Minutes", [(_statValue / 60)] call AP_fnc_numberText]};
                    default {format["%1", [_statValue] call AP_fnc_numberText]};
                }; private _rowIndex = _mainItemList lnbAddRow[format["%1", _statName], _formatValue];
                _mainItemList lnbSetValue[[_rowIndex, 1], _statValue];} forEach APV_statTotals;}; case ("Other Statistics"): {{
                    _x params["_statValue", "_statName"];
                    private _formatValue =
                    switch (true) do {case ((_statName find "Time") != -1): {
                                format["%1 Hours", [(_statValue / 60)] call AP_fnc_numberText]};
                        default {format["%1", [_statValue] call AP_fnc_numberText]};
                    }; private _rowIndex = _mainItemList lnbAddRow[format["%1", _statName], _formatValue];
                    _mainItemList lnbSetValue[[_rowIndex, 1], _statValue];}
                forEach[[A_stats_warKills, "War Kills"], [A_stats_warDeaths, "War Deaths"], [A_stats_warRating, "War Rating"], [A_stats_warPoints, "War Points"], [A_stats_civArrests, "Civ Arrests"], [A_stats_civKills, "Civ Kills"], [A_stats_civDeaths, "Civ Deaths"], [A_stats_civRevives, "Civ Revives"], [A_stats_civExecutes, "Civ Executes"], [A_stats_apbEvades, "APB Evades"], [A_stats_copArrests, "Cop Arrests"], [A_stats_copLethals, "Cop Lethals"], [A_stats_copDeaths, "Cop Deaths"], [A_stats_medRevives, "Medic Revives"], [A_stats_civTime, "Civ Time"], [A_stats_copTime, "Cop Time"], [A_stats_medTime, "Med Time"]];
            };
        case ("Monthly Gang Wins"): {{_x params["_xGangName", "_xGangWon"];
                    private _rowIndex = _mainItemList lnbAddRow[format["%1", _xGangName], str _xGangWon];
                    _mainItemList lnbSetValue[[_rowIndex, 1], _xGangWon];}
                forEach(SRV_rebelStats select 0);};
        case ("Monthly Gang Money Won"): {{_x params["_xGangName", "_xMoneyWon"];
                    private _rowIndex = _mainItemList lnbAddRow[format["%1", _xGangName], format["$%1", [_xMoneyWon] call AP_fnc_numberText]];
                    _mainItemList lnbSetValue[[_rowIndex, 1], _xMoneyWon];}
                forEach(SRV_rebelStats select 1);};
        case ("Top 35 - Kills"): {{_x params["_xPlayerName", "_xKills"];
                    private _rowIndex = _mainItemList lnbAddRow[format["%1", _xPlayerName], str _xKills];
                    _mainItemList lnbSetValue[[_rowIndex, 1], _xKills];}
                forEach(SRV_rebelStats select 2);};
        case ("Top 35 - K/Ds"): {{_x params["_xPlayerName", "_xKDRatio"];
                    private _rowIndex = _mainItemList lnbAddRow[format["%1", _xPlayerName], _xKDRatio];
                    _mainItemList lnbSetValue[[_rowIndex, 1], parseNumber _xKDRatio];}
                forEach(SRV_rebelStats select 3);};
        case ("Top New Drachma"): {{_x params["_xPlayerName", "_xNd"];
                    private _rowIndex = _mainItemList lnbAddRow[format["%1", _xPlayerName], format["%1 ND", [_xNd] call AP_fnc_ndText]];
                    _mainItemList lnbSetValue[[_rowIndex, 1], parseNumber format["%1", _xNd]];}
                forEach(SRV_rebelStats select 4);};}; { private _itemListGroupX = _x;
    private _itemListX = _itemListGroupX controlsGroupCtrl 1000;
    private _headerButtons = (allControls(ctrlParent _itemListGroupX)) select {
        ((ctrlClassName _x) isEqualTo "AP_RscListNBoxHeaderButton") && ((ctrlParentControlsGroup _x) isEqualTo _itemListGroupX)}; {
        _x ctrlEnable((lbSize _itemListX) >= 1)}
    forEach _headerButtons;}
forEach[_mainListGroup]; {private _itemListX = _x;
    ctrlSetFocus _itemListX;
    if (_filterType in ["MyLoonyBin Statistics", "Other Statistics"]) then {[_itemListX, 0, false, false] call AP_fnc_listNBoxSort;
    } else {[_itemListX, 1, false, true] call AP_fnc_listNBoxSort;};
    _itemListX ctrlSetFade 0.00;
    _itemListX ctrlCommit 0.00;}
forEach[_mainItemList];