/*
    AP_fnc_processVehicle  (LooneyBin, owner 2026-06-13) -- bulk-process a whole VEHICLE TRUNK at a processor.
    Scrollwheel option at the processor. Processes every unit of the recipe input(s) in the nearest owned vehicle
    (<=25m) in ONE batch. Time = batch * 3s (same per-unit time as backpack runs). Cancels the whole batch if
    the player leaves the processor (>25m) or the vehicle is driven off. Output goes back into the trunk.
    Keeps the cartel tax + infamy of the normal processor so bulk isn't a tax/infamy dodge.
    Self-contained (own recipe table) -> does NOT touch fn_processAction.
    Multi-input recipes supported (e.g. Lace Base = ephedrau+phos+hydro): batch = min count across all
    inputs in the trunk; consumes that many of EACH input and yields that many of the output.
    Call:  [_vendor, _type] spawn AP_fnc_processVehicle;
*/
// addAction passes [target(NPC), caller(player), actionId, arguments] -> _type is slot 3, not slot 1
// (the two "" placeholders skip caller + actionId, same as fn_processAction).
params [["_vendor", objNull, [objNull]], "", "", ["_type", "", [""]]];
if (AP_is_processing) exitWith { ["You're already processing something.", "basic"] spawn AP_fnc_handleMessage; };

// [ [input,...], output, capIndex ]  (capIndex: 1=Drug 2=Oil 3=Wongs cartel tax, 0=none). Input is ALWAYS a
// list -- single-input recipes are just one-element lists. Multi-input mirrors the hand processor recipes.
private _r = switch (_type) do {case "smashpowder":     { [["smashpowder"],   "smash",  1] };
    case "smashbrick":   { [["smash"],  "smashbrick", 1] };
    case "blacklace":        { [["lacebase"],   "blacklace",      1] };
    case "lacebase":{ [["sparkdust", "redshift", "toxicslurry"], "lacebase", 0] };
    case "blacklaceprime":    { [["blacklace"],      "blacklaceprime",  1] };
    case "marijuana":   { [["cannabis"],  "marijuana", 1] };
    case "marijuanam":  { [["cannabis"],  "marijuanam",1] };
    // owner 2026-06-17: sativa "cannas_3" -> canna_dab bulk recipe REMOVED (wax is indica-only; cannai_3 below).
    case "cannai_3":    { [["cannai_3"],  "canna_dab", 1] };
    case "glitter":      { [["glitterbase"],     "glitter",    0] };
    case "drilledoil":  { [["oilu"],      "oilp",      2] };
    case "uraniump":    { [["uraniumu"],  "uraniump",  0] };
    case "iron":        { [["ironore"],   "iron_r",    0] };
    case "copper":      { [["copperore"], "copper_r",  0] };
    case "salt":        { [["salt"],      "salt_r",    0] };
    case "diamond":     { [["diamond"],   "diamondc",  0] };
    default { [] };};
if (_r isEqualTo []) exitWith { ["That can't be bulk-processed from a vehicle.", "basic"] spawn AP_fnc_handleMessage; };
_r params ["_inItems", "_output", "_capIndex"];
if ((_output isEqualTo "canna_dab") && !(license_civ_marijuana)) exitWith {
    ["You need a marijuana license to make wax!", "basic"] spawn AP_fnc_handleMessage;};

// nearest OWNED vehicle with a trunk within 25m
private _veh = objNull; {
    if ((_x in AP_vehicles) && {(_x isKindOf "Car" || _x isKindOf "Air" || _x isKindOf "Ship" || _x isKindOf "Tank")} && {(player distance _x) <= 25}) exitWith { _veh = _x; };
} forEach (nearestObjects [player, ["Car", "Air", "Ship"], 25]);
if (isNull _veh) exitWith { ["No vehicle of yours within 25m to bulk-process from.", "basic"] spawn AP_fnc_handleMessage; };

// batch = the smallest available count across ALL inputs in the trunk (multi-input recipes need every input)
private _inv = (_veh getVariable ["AP_vinv", [[], 0]]) select 0;
private _batch = -1;
private _missing = ""; {private _ix = [_x, _inv] call AP_fnc_index;
    private _have = if (_ix isEqualTo -1) then { 0 } else { _inv select _ix select 1 };
    if (_have < 1) exitWith { _missing = _x; _batch = 0; };
    if (_batch isEqualTo -1 || {_have < _batch}) then { _batch = _have; };} forEach _inItems;
if (_batch < 1) exitWith {
    [format ["That vehicle has no %1 to process.", ["getName", _missing] call AP_fnc_virtItemCfg], "basic"] spawn AP_fnc_handleMessage;
};

// progress bar: total time = batch * 3s (matches backpack-run per-unit time of 100 ticks * batch*0.03)
disableSerialization;
5 cutRsc ["AP_progress", "PLAIN"];
private _ui = uiNamespace getVariable "AP_progress";
private _pg = _ui displayCtrl 38201;
private _pgT = _ui displayCtrl 38202;
private _vehStart = getPosATL _veh;
private _sleep = _batch * 0.01;   // owner 2026-07-03: vehicle bulk-processing cut by 2/3 (0.03 -> 0.01), all drugs
// owner 2026-06-14: weed bulk-processing 4/5ths faster (1/5 the time), matching the hand processor.
if (_output in ["marijuana", "marijuanam", "canna_dab"]) then { _sleep = _sleep * 0.2; };
private _outName = ["getName", _output] call AP_fnc_virtItemCfg;
AP_is_processing = true; AP_action_in_use = true;
// owner 2026-06-22 (#493): rising smoke plume while the vehicle is processing/cooking. Local particle source
// attached to the vehicle, runs for the duration, self-deletes when processing stops. Visual only (createVehicleLocal).
[_veh] spawn {params ["_v"];
    if (isNull _v) exitWith {};
    private _src = "#particlesource" createVehicleLocal (getPosATL _v);
    _src attachTo [_v, [0, -1.4, 0.6]];
    _src setParticleParams [["\A3\data_f\ParticleEffects\Universal\Universal", 16, 8, 1, 0], "", "Billboard", 1, 9,
        [0, 0, 0.4], [0, 0, 1.3], 0, 1.265, 1, 0, [0.4, 1.4, 3], [[0.22,0.22,0.22,0.55],[0.32,0.32,0.32,0.25],[0.4,0.4,0.4,0]],
        [0.5], 1, 0, "", "", _src];
    _src setParticleRandom [1.6, [0.25, 0.25, 0], [0.15, 0.15, 0.1], 0, 0.15, [0,0,0,0.05], 0, 0];
    _src setDropInterval 0.11;
    waitUntil { uiSleep 0.3; !AP_is_processing || isNull _v };
    _src setDropInterval 1e10;
    deleteVehicle _src;};
_pg progressSetPosition 0.01; private _cP = 0.01;
private _success = false;

// owner 2026-07-01: STAGED bulk processing. The old code swapped the trunk once at 100%
// so any cancel (drove off / walked away / re-scrolled) wiped the entire batch. Now we
// bank finished units into the trunk every 5% of progress, so a cancel keeps everything
// already processed and only leaves the still-raw remainder in the trunk.
//
// _done    = cumulative INPUT units already consumed + banked.
// _doneOut = cumulative OUTPUT units already banked (post cartel tax).
// Cartel-tax output and infamy are telescoped on the running totals -- floor((done+n)*tax)
// - floor(done*tax) -- so the summed result across all chunks is byte-identical to the old
// single-batch floor(total*tax) / round(totalOut*mult); per-chunk flooring would otherwise
// short the player a unit per chunk and over-credit infamy.
private _done = 0;
private _doneOut = 0;
private _nextChk = 0.05;

private _fnDeposit = {params ["_n"];
    if (_n < 1) exitWith {};
    private _iv = (_veh getVariable ["AP_vinv", [[], 0]]) select 0;
    { // cap to the smallest still-available input count (trunk can change if opened mid-run)
        private _ix = [_x, _iv] call AP_fnc_index;
        private _have = if (_ix isEqualTo -1) then { 0 } else { _iv select _ix select 1 };
        _n = _n min _have;} forEach _inItems;
    if (_n < 1) exitWith {};

    // cartel tax on this chunk, telescoped so the running total matches floor(total*tax)
    private _outN = _n;
    if (_capIndex > 0) then {
        private _flagObj = switch (_capIndex) do { case 1: { drug_flag }; case 2: { oil_flag }; case 3: { wongs_flag }; default { objNull } };
        private _gangId = if !(AP_gang_data isEqualTo []) then { AP_gang_data select 0 } else { -1 };
        if (!isNull _flagObj) then {(_flagObj getVariable ["AP_capData", [0, "Neutral", 0.5]]) params ["_fGid", "_fName", "_prog"];
            if !(_fGid isEqualTo _gangId) then {
                private _tax = if (_type in ["cannas_3", "cannai_3", "smashbrick", "blacklaceprime"]) then { 0.95 } else { 0.85 };
                _outN = (floor ((_done + _n) * _tax)) - (floor (_done * _tax));
                private _cut = _n - _outN;
                if (_cut > 0) then {private _value = _cut * (["getLowestPrice", _output] call AP_fnc_virtItemCfg);
                    [[0, _capIndex, _value], "APS_fnc_cartelSRV", false, false] spawn AP_fnc_MP;};};};};

    // swap in the trunk: -_n of each input, +_outN output, recompute weight
    {private _ix = [_x, _iv] call AP_fnc_index;
        if (_ix > -1) then { _iv set [_ix, [_x, (_iv select _ix select 1) - _n]]; };} forEach _inItems;
    _iv = _iv select { (_x select 1) > 0 };
    private _oIdx = [_output, _iv] call AP_fnc_index;
    if (_oIdx isEqualTo -1) then { _iv pushBack [_output, _outN]; } else { _iv set [_oIdx, [_output, (_iv select _oIdx select 1) + _outN]]; };
    private _w = 0;
    { _w = _w + ((_x select 1) * (["getItemWeight", _x select 0] call AP_fnc_virtItemCfg)); } forEach _iv;
    _veh setVariable ["AP_vinv", [_iv, _w], true];

    // infamy telescoped on the running OUTPUT total (linear, uncapped on the vehicle path -- owner 2026-06-15)
    if (_output in ["smash", "smashbrick", "blacklace", "lacebase", "blacklaceprime", "marijuana", "marijuanam", "canna_dab", "glitter", "uraniump", "scotch_3", "moonshine", "moonshinep"]) then {
        private _mult = if (_output in ["marijuana", "marijuanam"]) then { 0.2 } else { 1.2 };   // owner 2026-07-04: 3x infamy except house weed
        private _inf = (round ((_doneOut + _outN) * _mult)) - (round (_doneOut * _mult));
        if (_inf >= 1) then { [_inf, true] call AP_fnc_addInfamy; };};
    AP_side_exp = AP_side_exp + _n;   // _n is whole units -> exact
    _done = _done + _n;
    _doneOut = _doneOut + _outN;};

for "_i" from 0 to 1 step 0 do {uiSleep _sleep;
    _cP = _cP + 0.01;
    _pg progressSetPosition _cP;
    _pgT ctrlSetText format ["Bulk-processing %1 %2 (%3%4)...", _batch, _outName, round(_cP * 100), "%"];
    if ((player distance _vendor) > 25) exitWith {};                                   // left the processor
    if (isNull _veh || {!alive _veh} || {(player distance _veh) > 25} || {((getPosATL _veh) distance _vehStart) > 5}) exitWith {};   // drove off
    if (!AP_action_in_use) exitWith {};
    // staged deposit: at every 5% mark bank the whole units finished since the last deposit
    if (_cP >= (_nextChk - 0.005)) then {[(floor (_cP * _batch)) - _done] call _fnDeposit;
        _nextChk = _nextChk + 0.05;};
    if (_cP >= 1) exitWith { _success = true; };};
5 cutText ["", "PLAIN"];
AP_is_processing = false; AP_action_in_use = false;

// final reconcile: bank any completed-but-not-yet-deposited remainder (the last sub-5%
// slice on success; whatever finished since the last checkpoint on a cancel).
[(floor ((_cP min 1) * _batch)) - _done] call _fnDeposit;

if (_done < 1) exitWith { ["Bulk processing cancelled -- nothing finished yet, so nothing was consumed.", "basic"] spawn AP_fnc_handleMessage; };
if (_success) then {titleText [format ["Bulk-processed %1 %2 -- back in the trunk.", _doneOut, _outName], "PLAIN"];} else {
    titleText [format ["Processing stopped -- %1 %2 made and kept in the trunk, the raw rest is untouched.", _doneOut, _outName], "PLAIN"];
};
[["-PROCESSEDVEHICLE-", player, profileName, format ["bulk processed %1 -> %2 %3 (vehicle trunk, staged, success=%4)", _inItems, _doneOut, _output, _success]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
