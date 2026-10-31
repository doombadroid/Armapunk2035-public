/*
    fn_shopDiag.sqf — dump what a virtual shop CHARGES, with the modifiers shown.

    For cross-referencing the web shop against the native one after the price
    chains were extracted (b0449/b0450). Both now call the same two functions, so
    they cannot disagree with each other -- what this proves is that the extracted
    chain still produces the number it produced before, and it shows every input so
    a wrong figure can be traced to the modifier that caused it.

    Run it in the debug console:   ["market"] call AP_fnc_shopDiag;

    Prints to the RPT. Everything below is a READ -- it charges nothing.
*/

params [["_shopType", "market", [""]]];

private _info = [_shopType] call AP_fnc_virt_shops;
_info params [["_title", "", [""]], ["_buy", [], [[]]], ["_sell", [], [[]]]];
if (_title isEqualTo "") exitWith { diag_log format ["[SHOPDIAG] no such shop: %1", _shopType]; };

private _tax = call AP_fnc_getGovTax;
private _disB = [_shopType, true]  call AP_fnc_getDiscount;
private _disS = [_shopType, false] call AP_fnc_getDiscount;

diag_log "==================================================================";
diag_log format ["[SHOPDIAG] %1  (%2)", _title, _shopType];
diag_log format ["[SHOPDIAG] gov tax %1  |  buy discount %2  |  sell discount %3",
    _tax, _disB, _disS];
diag_log format ["[SHOPDIAG] cash %1  |  load %2 / %3",
    AP_cash,
    missionNamespace getVariable ["AP_carryWeight", 0],
    missionNamespace getVariable ["AP_maxWeight", 0]];
diag_log "[SHOPDIAG] item             base   fctr     BUY      low     SELL   own";
diag_log "------------------------------------------------------------------";

private _seen = [];
{
    private _id = _x;
    if (_id isEqualType "" && { !(_id in _seen) }) then {
        _seen pushBack _id;
        private _base = ["getBasePrice",   _id] call AP_fnc_virtItemCfg;
        private _low  = ["getLowestPrice", _id] call AP_fnc_virtItemCfg;
        private _f    = [_id] call AP_fnc_marketFactor;
        private _b    = if (_id in _buy)  then { round ([_shopType, _id] call AP_fnc_virtShopPrice) } else { -1 };
        private _s    = if (_id in _sell) then { round ([_shopType, _id, _buy, _sell] call AP_fnc_virtShopSellPrice) } else { -1 };
        diag_log format ["[SHOPDIAG] %1 %2 %3 %4 %5 %6 %7",
            [_id, 16] call AP_fnc_padDiag,
            [str _base, 6] call AP_fnc_padDiag,
            [(_f toFixed 2), 6] call AP_fnc_padDiag,
            [(if (_b < 0) then { "-" } else { str _b }), 8] call AP_fnc_padDiag,
            [str _low, 8] call AP_fnc_padDiag,
            [(if (_s < 0) then { "-" } else { str _s }), 8] call AP_fnc_padDiag,
            str (missionNamespace getVariable [format ["AP_inv_%1", _id], 0])];
    };
} forEach (_buy + _sell);
diag_log "==================================================================";
