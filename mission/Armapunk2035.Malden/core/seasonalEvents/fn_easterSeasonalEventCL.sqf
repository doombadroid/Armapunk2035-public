params[["_mode", "", [""]], ["_parameterArray", [], [[]]]];
if (_mode == "") exitWith {};
if !(AP_seasonalEvent select 0) exitWith {};
switch (_mode) do {case "pickupBunny": {_parameterArray params[["_bunnyObject", objNull, [objNull]]];
            if (_bunnyObject == objNull) exitWith {};
            if !(AP_effSide isEqualTo civilian) exitWith {};
            if (AP_carryWeight > 10) exitWith {
                ["You are too heavy to pickup this bunny. You need your weight to be 10 or below to pickup bunny's!", "basic"] spawn AP_fnc_handleMessage;
            };
            _bunnyObject setVariable["easterBunnyActive", false, true]; [
                ["pickupEasterBunny", _bunnyObject, player], "APS_fnc_easterSeasonalEvent", 2] spawn AP_fnc_MP;
        }; case "giveVirtualItemReward": {_parameterArray params[["_type", 0, [0]], ["_item", "", [""]], ["_qty", 0, [0]]];
                if (_type == 0 || _item == "" || _qty == 0) exitWith {};
                [true, _item, _qty] call AP_fnc_handleInv;
                ["<t color='#ff33cc' size='1.5' align='center'>EASTER EVENT</t><br/><br/>You have picked up one of the easter bunny's and gained a virtual item reward!<br/><br/>Quickly check your inventory to see what you have gained from the bunny!", "event"] spawn AP_fnc_handleMessage;
            };
        case "giveMoneyReward": {_parameterArray params[["_type", 0, [0]], ["_item", "", [""]], ["_qty", 0, [0]]];
                if (_type == 0 || _item == "" || _qty == 0) exitWith {};
                AP_cash = AP_cash + _qty;
                AP_cashCacheB = ((AP_cash / 4) + 9);
                ["<t color='#ff33cc' size='1.5' align='center'>EASTER EVENT</t><br/><br/>You have picked up one of the easter bunny's and gained a monetary reward!<br/><br/>Quickly rush to the ATM to store it!", "event"] spawn AP_fnc_handleMessage;
            };
        case "easterCLmessage": {
                ["<t color='#ff33cc' size='1.5' align='center'>EASTER EVENT</t><br/><br/>A easter event has started!<br/><br/>Bunny's have been distributed over athira go ahead and hunt them all, but make sure you have enough inventory space for the rewards!", "event"] spawn AP_fnc_handleMessage;
            };};