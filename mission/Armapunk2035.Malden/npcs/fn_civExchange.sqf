params["_obj_main", "_stance"];
if (_obj_main isKindOf "CAManBase") then {};
_obj_main addAction["<t color='#4DF53E'>LoonyBin Grand Exchange</t>", AP_fnc_exchangeMenu, nil, 1.5, false, false, "", 'AP_effSide isEqualTo civilian', 5];
_obj_main addAction["<t color='#4DF53E'>LoonyBin Exchange Storage</t>", AP_fnc_exchangeStorageMenu, nil, 1.5, false, false, "", 'AP_effSide isEqualTo civilian', 5];
_obj_main addAction["<t color='#4DF53E'>LoonyBin Exchange - List Virtual Items</t>", AP_fnc_exchangeCreateListing, "virtualItem", 1.5, false, false, "", 'AP_effSide isEqualTo civilian', 5];
_obj_main addAction["<t color='#4DF53E'>LoonyBin Exchange - List Physical Items</t>", AP_fnc_exchangeCreateListing, "physicalItem", 1.5, false, false, "", 'AP_effSide isEqualTo civilian', 5];
_obj_main addAction["<t color='#FF7400'>Check Mailbox</t>", {[] call AP_fnc_checkMailbox
}, nil, 1.5, true, true, "", 'AP_effSide isEqualTo civilian', 5];