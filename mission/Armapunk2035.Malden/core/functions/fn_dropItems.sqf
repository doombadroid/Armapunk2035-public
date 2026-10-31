params[["_unit", objNull, [objNull]]];
if (isNull _unit || AP_effSide isEqualTo west || AP_effSide isEqualTo independent) exitWith {};
private _pos =
if (isNull objectParent _unit) then {getPosASL _unit;} else {private _tempPos = (vehicle _unit) modelToWorldWorld[0, -8, 0];
    _tempPos set[2, 0];
    AGLToASL _tempPos;};
private _hackDetected = false;
if (AP_effSide isEqualTo civilian) then {private _totalItemsActual = 0; {
        _totalItemsActual = _totalItemsActual + (missionNameSpace getVariable [_x, 0]);}
    forEach AP_invMonVars;
    if (_totalItemsActual > (AP_invMonitor - AP_invRVar) || _totalItemsActual >= 130) exitWith {_hackDetected = true;
        private _hackedItemArray = []; {if ((missionNameSpace getVariable [_x, 0]) > 0) then {
                _hackedItemArray pushBack[_x, (missionNameSpace getVariable [_x, 0])];};}
        forEach AP_invMonVars; [
            [player, [3, (AP_invMonitor - AP_invRVar), _totalItemsActual, str _hackedItemArray]], "APS_fnc_dongClient", 2] call AP_fnc_MP;
        [] spawn {uiSleep 2;
            diag_log "[LooneyBin] MemHackCash AC neutered (no kick)";};
        // BUGS.md #79/#80: same item-count monitor as fn_handleInv -- log + resync, don't block the drop
        AP_invMonitor = _totalItemsActual + AP_invRVar;
        _hackDetected = false;};};
if (_hackDetected) exitWith {};
private _items = [];
private["_item", "_value", "_shortName"]; {_item = _x;
    _value = missionNamespace getVariable [_item, 0];
    if (_value > 0) then {_shortName = ["getShortName", _item] call AP_fnc_virtItemCfg;
        if !(_shortName in ["firstAidKit", "giftAdmin", "giftHallo", "giftXmas"]) then {
            _items pushBackUnique[_shortName, _value];
            missionNamespace setVariable[_x, 0];};};}
forEach([1] call AP_fnc_virtItemCfg);
if (AP_cash > 0) then {_items pushBack["money", AP_cash]; [
        ["-CASHDROPPED-", player, (profileName), format["dropped $%1 at POS: %2", [AP_cash] call AP_fnc_numberText, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    if (AP_effSide isEqualTo civilian && {A_stats_civTime < 300 && AP_cash >= 74999}) then {[
            ["-MONEYWARNING-", player, profileName, format["dropped $%1 on death. Civ time: %2 minutes | Bank: $%3 | Position: %4 | Experience: %5.", [AP_cash] call AP_fnc_numberText, A_stats_civTime, [AP_atmcash] call AP_fnc_numberText, getPosATL player, [AP_side_exp] call AP_fnc_numberText]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
    };};
AP_cash = 0;
AP_cashCacheB = ((AP_cash / 4) + 9);
[0] call AP_fnc_ClupdatePartial;
if !(_items isEqualTo[]) then {[[_items, _pos, "Land_Suitcase_F", []], "APS_fnc_createItem", 2] spawn AP_fnc_MP;};