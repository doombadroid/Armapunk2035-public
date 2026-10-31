/*
    AP_fnc_fabLBChange -- render the selected recipe: what it needs, what it costs in time, and
    whether you can start it.

    The ingredient colouring is the factory's (fn_factoryLBChange.sqf:71-83) and works the same way:
    green if you hold enough, red if you are short. Two things differ.

    First, there is no cash line, ever. Production costs materials and time; the only money in this
    feature is the price of a schematic. A currency entry in a parts list would be a design
    violation, and tools/fab_check.py fails the build on one.

    Second, the panel shows the RECURSIVE backbone total next to the direct one. A recipe listing
    34 filament that actually contains 71 is not obvious from its ingredient list, and that hidden
    number is what its schematic was priced on -- so it is worth showing rather than hiding.
*/
disableSerialization;
private _d = findDisplay 1810;
if (isNull _d) exitWith {};
private _list = _d displayCtrl 1850;
private _sel = lbCurSel _list;
if (_sel < 0) exitWith {};
private _key = _list lbData _sel;
if (_key isEqualTo "") exitWith {};

// In shop mode the panel describes a PURCHASE, not a build: what the schematic unlocks and what it
// costs. The price shown is the same derived number the server will charge -- both come from
// AP_fnc_fabFee, so the window cannot quote one figure and the till take another.
if ((missionNamespace getVariable ["AP_fabMode", "print"]) isEqualTo "shop") exitWith {
    private _srow = ["get", _key] call AP_fnc_fabSchemCfg;
    private _rrow = ["getRecipe", _key] call AP_fnc_fabCfg;
    private _fee = [_key] call AP_fnc_fabFee;
    private _price = _fee param [1, ""];
    lbClear (_d displayCtrl 1860);
    {
        _x params ["_var", "_need"];
        private _i = (_d displayCtrl 1860) lbAdd format ["%1 x %2", _need, ["getName", _var select [7]] call AP_fnc_virtItemCfg];
        (_d displayCtrl 1860) lbSetColor [_i, [0.72, 0.75, 0.78, 0.75]];
    } forEach (_rrow param [1, []]);
    (_d displayCtrl 1865) ctrlSetStructuredText parseText format [
        "<t size='1.0'>%1</t>   <t size='0.8' color='#7fb2c8'>%2 · L%3</t>", _key, _srow param [2, ""], _rrow param [0, 1]];
    (_d displayCtrl 1855) ctrlSetStructuredText parseText format [
        "<t size='0.85'>Unlocks this recipe permanently.<br/>Price <t color='#56d6e2'>%1 ND</t> — derived from the %2 filament it contains, not hand-set.</t>",
        _price, _fee param [0, 0]];
    ctrlEnable [1830, _price isNotEqualTo "" && {(parseNumber _price) <= AP_nd}];
    ctrlEnable [1832, false];   // nothing to burn in the shop -- these are the ones you do NOT own
};

private _row = ["getRecipe", _key] call AP_fnc_fabCfg;
if (_row isEqualTo []) exitWith {};
_row params ["_lvl", "_parts", "_flags"];

private _ing = _d displayCtrl 1860;
lbClear _ing;
private _canAfford = true;
{
    _x params ["_var", "_need"];
    private _have = missionNamespace getVariable [_var, 0];
    private _short = _have < _need;
    if (_short) then { _canAfford = false; };
    private _i = _ing lbAdd format ["%1 x %2      (have %3)", _need, ["getName", _var select [7]] call AP_fnc_virtItemCfg, _have];
    _ing lbSetColor [_i, if (_short) then {[0.86, 0.32, 0.32, 1]} else {[0.33, 0.85, 0.55, 1]}];
} forEach _parts;

private _anchor = missionNamespace getVariable ["AP_fabAnchor", objNull];
private _tier = _anchor getVariable ["AP_fabTier", 1];
private _tcfg = ["tier", _tier] call AP_fnc_fabCfg;
private _cap = _tcfg param [2, 10];
private _speed = _tcfg param [1, 1];
private _secs = (["duration", _key] call AP_fnc_fabCfg) / _speed;
private _plvl = missionNamespace getVariable ["AP_fabLevel", 1];
private _fee = [_key] call AP_fnc_fabFee;

// Free build silences the gates it actually bypasses -- level and materials -- but NOT the tier
// cap, because the server still enforces that one and a button that lies is worse than a grey one.
private _free = missionNamespace getVariable ["AP_fabFreeBuild", false];
private _why = "";
if (!_free && {_lvl > _plvl}) then { _why = format ["needs fabrication level %1", _lvl]; };
if (_why isEqualTo "" && {_lvl > _cap}) then { _why = format ["this machine tops out at L%1", _cap]; };
if (_why isEqualTo "" && {!_free} && {!_canAfford}) then { _why = "missing materials"; };
// Slots, not "is it busy". A CoreXY runs three jobs at once, so the block is only when every slot
// is taken. Bare AP_fabJobs would throw before the server's first push lands, which is exactly the
// window the player is in -- the menu opens before the reply arrives by design.
private _jobs = missionNamespace getVariable ["AP_fabJobs", []];
private _myId = _anchor getVariable ["AP_fabId", -1];
private _me = _jobs param [_jobs findIf { (_x select 0) isEqualTo _myId }, []];
private _slots = _me param [2, 1];
private _used = count (_me param [3, []]);
if (_why isEqualTo "" && {_used >= _slots}) then {
    _why = format ["every slot is running (%1/%2)", _used, _slots];
};

(_d displayCtrl 1865) ctrlSetStructuredText parseText format [
    "<t size='1.0'>%1</t>   <t size='0.8' color='#7fb2c8'>L%2</t>", _list lbText _sel, _lvl];
(_d displayCtrl 1855) ctrlSetStructuredText parseText format [
    "<t size='0.85'>Print time <t color='#56d6e2'>%1 min</t> at this machine's speed.<br/>"
  + "Contains <t color='#56d6e2'>%2</t> filament in total (%3 listed directly) — that total is what its schematic is priced on.%4</t>",
    (_secs / 60) toFixed 1,
    _fee param [0, 0],
    ([0] + (_parts select { (_x select 0) isEqualTo "AP_inv_filament" } apply { _x select 1 })) call BIS_fnc_sumArray,
    if (_why isEqualTo "") then {""} else {format ["<br/><t color='#e07a5a'>Cannot print: %1.</t>", _why]}];

ctrlEnable [1830, _why isEqualTo ""];
// Burn is legal only for a schematic you own. A noSchematic recipe (the intermediates tier, the i3)
// has nothing to give back, and the list also shows those.
ctrlEnable [1832, _key in (missionNamespace getVariable ["AP_fabSchem", []])];
