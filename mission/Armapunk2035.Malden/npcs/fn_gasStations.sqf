params["_obj_main", "_stance"];
if (_obj_main isKindOf "CAManBase") then {};
_obj_main addAction["<t color='#ADFF2F'>ATM</t>", {[] call AP_fnc_atmMenu}, nil, 2, true, true, "", 'isNull objectParent player', 5];
_obj_main addAction["<t color='#FFFF2F'>Gang Account</t>", {[] call AP_fnc_gangAtmMenu
}, nil, 2, true, true, "", '(count AP_gang_data > 0)', 5];
_obj_main addAction["Gas Station", AP_fnc_weaponShopMenu, "gas", 1.5, false, false, "", '', 5];
_obj_main addAction["Gas Market", AP_fnc_virtualShopMenu, "gas", 1.5, false, false, "", '', 5];
_obj_main addAction["Get Lottery Jackpot", {[0] call AP_fnc_lottoTix}, "", 1.5, false, false, "", 'isNull objectParent player', 5];
_obj_main addAction["<t color='#00BFFF'>Buy Lottery Ticket ($2,000)</t>", {[1] spawn AP_fnc_lottoTix
}, "", 0, false, false, "", 'isNull objectParent player', 5];