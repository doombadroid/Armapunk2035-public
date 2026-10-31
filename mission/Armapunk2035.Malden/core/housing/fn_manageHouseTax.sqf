params[["_caseType", "", [""]], ["_data", [], [[]]]];
switch (_caseType) do {
        // The taxMenu case opened AP_housetax_menu and is gone with it (2026-08-14):
        // HOUSING is a deck app now. What survives is the ARITHMETIC -- the deck's
        // housing list and fn_housePayTax both price tax through calculateTax, and
        // it is the only price authority either of them may use.
        case ("calculateTax"): {_data params[["_houseObject", objNull, [objNull]]];
                private _return = 0;
                if (isNull _houseObject) exitWith {0};
                private _houseData = _houseObject getVariable["AP_house_tax", []];
                if (_houseData isEqualTo[]) exitWith {0};
                private _houseType = typeOf _houseObject;
                private _houseConfig = [_houseType] call AP_fnc_houseConfig;
                if (_houseConfig isEqualTo[]) exitWith {0};
                private _upkeep = _houseConfig select 4;
                _houseData params["_overdue", "_canPayTax", "_playtime", "_lastPayed"];
                if (_lastPayed <= 0) exitWith {0};
                private _reduction = 1;
                private _houseCount = count AP_houses;
                private _playtimeHours = _playtime / 60;
                private _timeArrayConfig = [[1.0, 0.9, 0.8, 0.6, 0.4, 0.25], [1.2, 1.2, 1.1, 1.1, 1.0, 1.0, 0.8, 0.6, 0.5, 0.4, 0.25],
                    [1.3, 1.3, 1.2, 1.2, 1.1, 1.1, 1.0, 0.9, 0.8, 0.6, 0.5, 0.4, 0.4, 0.3, 0.3, 0.25],
                    [1.5, 1.5, 1.5, 1.4, 1.4, 1.4, 1.3, 1.3, 1.2, 1.1, 1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.4, 0.3, 0.3, 0.25],
                    [2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 1.9, 1.8, 1.7, 1.6, 1.5, 1.4, 1.3, 1.2, 1.1, 1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.4, 0.3, 0.3, 0.25]
                ];
                private _selectTimeConfig = _timeArrayConfig select(_houseCount - 1);
                private _selectReduction = floor _playtimeHours;
                if (_selectReduction > ((count _selectTimeConfig) - 1)) then {_reduction = 0.25;} else {
                    _reduction = _selectTimeConfig select _selectReduction;};
                if (_reduction < 0.25) then {_reduction = 0.25;};
                if (_reduction > 2.0) then {_reduction = 2.0;};
                if (_overdue && _lastPayed > 32) then {_reduction = _reduction + 0.2;};
                private _houseTax = _lastPayed * _upkeep * _reduction;
                if (210 in AP_side_talents) then { _houseTax = _houseTax * 0.6; };   // HOMESTEADER -40% property tax
                _return = _houseTax;
                _return;};
        case ("taxPaySelected"): {private _plb_display = findDisplay 13000;
                if (isNull _plb_display) exitWith {};
                private _houseTaxList = _plb_display displayCtrl 13002;
                private _houseButtonPaySel = _plb_display displayCtrl 13005;
                _houseButtonPaySel ctrlEnable false;
                if (AP_taxHouses isEqualTo[]) exitWith {};
                if ((lbCurSel _houseTaxList) isEqualTo - 1) exitWith {
                    ["You did not select a house.", "basic"] spawn AP_fnc_handleMessage;};
                private _houseObject = AP_taxHouses select(lbCurSel _houseTaxList);
                if (isNull _houseObject) exitWith {};
                private _houseID = _houseObject getVariable["AP_houseID", -1];
                if (_houseID isEqualTo - 1) exitWith {};
                private _houseData = _houseObject getVariable["AP_house_tax", []];
                if (_houseData isEqualTo[]) exitWith {};
                _houseData params["_overdue", "_canPayTax", "_playtime", "_lastPayed"];
                if (!_canPayTax) exitWith {};
                private _taxPrice = ["calculateTax", [_houseObject]] call AP_fnc_manageHouseTax;
                if (_taxPrice <= 0) exitWith {["Something went wrong!", "basic"] spawn AP_fnc_handleMessage;};
                private _action = [format["You are going to pay $%1 tax for the selected house. Are you sure you want to continue?", [_taxPrice] call AP_fnc_numberText], "Pay House Tax", "Yes", "No"] call BIS_fnc_GUIMessage;
                if !(_action) exitWith {["You decided not to pay.", "basic"] spawn AP_fnc_handleMessage;};
                if (serverRestartLock) exitWith {
                    ["You cannot pay your tax right now. Try again after the restart!", "basic"] spawn AP_fnc_handleMessage;};
                if (AP_atmcash < _taxPrice) exitWith {["You can't afford to pay the house tax!", "basic"] spawn AP_fnc_handleMessage;};
                if (AP_houseTxn) exitWith {
                    ["You are currently in the process of paying house taxes.", "basic"] spawn AP_fnc_handleMessage;};
                AP_houseTxn = true;
                closeDialog 0;
                // server debits after validating + writing (APS_fnc_houseTaxSRV -> AP_fnc_uC); no local subtract (2026-09-04)
                ["Sending tax to the Altis Realtor...", "basic"] spawn AP_fnc_handleMessage; [
                    ["paySingleHouse", [player, _houseObject, _houseID]], "APS_fnc_houseTaxSRV", 2] call AP_fnc_MP;
                ["buy", "housetax", _taxPrice] spawn AP_fnc_handleQuest;};
        case ("taxPayALL"): {if (AP_taxHouses isEqualTo[]) exitWith {};
                private _taxHouses = [];
                private _taxPriceTotal = 0;
                private _houseIDLog = ""; {private _houseObject = _x;
                    if (!isNull _houseObject) then {private _houseID = _houseObject getVariable["AP_houseID", -1];
                        if (_houseID isEqualTo - 1) exitWith {};
                        private _houseData = _houseObject getVariable["AP_house_tax", []];
                        if (_houseData isEqualTo[]) exitWith {};
                        _houseData params["_overdue", "_canPayTax", "_playtime", "_lastPayed"];
                        if (!_canPayTax) exitWith {};
                        private _taxPrice = ["calculateTax", [_houseObject]] call AP_fnc_manageHouseTax;
                        if (_taxPrice <= 0) exitWith {};
                        _taxPriceTotal = _taxPriceTotal + _taxPrice;
                        _taxHouses pushBack[_houseObject, _houseID];
                        if (_houseIDLog isEqualTo "") then {_houseIDLog = format["%1", _houseID];} else {
                            _houseIDLog = _houseIDLog + format[", %1", _houseID];};};}
                forEach AP_taxHouses;
                if (_taxHouses isEqualTo[] || _taxPriceTotal <= 0) exitWith {
                    ["You do not have any houses that can pay tax yet.", "basic"] spawn AP_fnc_handleMessage;};
                private _action = [format["You are going to pay $%1 for %2 house(s) that needs to pay tax. Are you sure you want to continue?", [_taxPriceTotal] call AP_fnc_numberText, count _taxHouses], "Pay House Tax", "Yes", "No"] call BIS_fnc_GUIMessage;
                if !(_action) exitWith {["You decided not to pay.", "basic"] spawn AP_fnc_handleMessage;};
                if (serverRestartLock) exitWith {
                    ["You cannot pay your tax right now. Try again after the restart!", "basic"] spawn AP_fnc_handleMessage;};
                if (AP_atmcash < _taxPriceTotal) exitWith {
                    ["You can't afford to pay the house tax!", "basic"] spawn AP_fnc_handleMessage;};
                if (AP_houseTxn) exitWith {
                    ["You are currently in the process of paying house taxes.", "basic"] spawn AP_fnc_handleMessage;};
                AP_houseTxn = true;
                closeDialog 0;
                // server debits after validating + writing (APS_fnc_houseTaxSRV -> AP_fnc_uC); no local subtract (2026-09-04)
                ["Sending tax to the Altis Realtor...", "basic"] spawn AP_fnc_handleMessage; [
                    ["payAllHouses", [player, _taxHouses]], "APS_fnc_houseTaxSRV", 2] call AP_fnc_MP;
                ["buy", "housetax", _taxPriceTotal] spawn AP_fnc_handleQuest;};
        case "houseTaxReminder": {_data params[["_warningCount", 0, [0]]];
                if (_warningCount isEqualTo 0) exitWith {};
                waitUntil {!isNil "AP_quitWelcomeUI" && {AP_quitWelcomeUI}};
                uiSleep 10;
                private _message = format["House Tax: %1 house(s) require tax attention. Open the Housing app on your phone to pay the house tax.", _warningCount];
                [_message, "warning"] spawn AP_fnc_handleMessage;
                systemChat _message;};
        case "houseTaxAccess": {
                ["This house has tax overdue, house tax has to be paid to gain access again.", "basic"] spawn AP_fnc_handleMessage;};
        default {};};