/*
    AP_fnc_deckSpray -- the reusable TEXTURE-GRID PICKER (approved mock
    deck-spray): one component, two datasets, per the utilities memo. Mode
    "spray" picks the spray-can image; mode "hex" picks the group hex icon and
    its colour. Both persist exactly what the natives persisted, including the
    hex 10-second limiter and the civilian-only publish.

    ["data", mode] / ["spray", idx] / ["hex", idx] / ["hexColor", idx]
*/
params [["_verb", "", [""]], ["_a", 0, [0, ""]]];

private _no  = { params ["_m"]; createHashMapFromArray [["ok", false], ["msg", _m]] };
private _yes = { params ["_m"]; createHashMapFromArray [["ok", true],  ["msg", _m]] };

private _HEXCOLORS = [["Active Elements", [1, 1, 1, 0.5]], ["Red", [1, 0, 0, 1]], ["Orange", [1, 0.647, 0, 1]],
    ["Yellow", [1, 1, 0, 1]], ["Chartreuse Green", [0.498, 1, 0, 1]], ["Green", [0, 0.501, 0, 1]],
    ["Spring Green", [0, 1, 0.498, 1]], ["Cyan", [0, 1, 1, 1]], ["Azure", [0, 0.498, 1, 1]], ["Blue", [0, 0, 1, 1]],
    ["Violet", [0.93, 0.509, 0.93, 1]], ["Magenta", [1, 0, 1, 1]], ["Rose", [1, 0.894, 0.882, 1]],
    ["Black", [0, 0, 0, 1]], ["White", [1, 1, 1, 1]]];

switch (toLower _verb) do {

case "data": {
    private _mode = if (_a isEqualType "") then { _a } else { "spray" };
    private _cfg = if (_mode isEqualTo "hex") then { ["getCfg"] call AP_fnc_hexIconCfg } else { ["getCfg"] call AP_fnc_sprayCanCfg };
    private _curSpray = (profileNamespace getVariable ["AP_savedSprayImage", [0]]) param [0, 0];
    private _curHex = ((profileNamespace getVariable ["AP_coloredHexesData", [[-1, ""], [0, 0, 0, 1]]]) param [0, [-1, ""]]) param [0, -1];
    createHashMapFromArray [
        ["mode", _mode],
        ["rows", (_cfg select { _x param [3, false] }) apply { createHashMapFromArray [
            ["id", _x select 0], ["name", _x select 1], ["path", _x select 2],
            ["current", (_x select 0) isEqualTo ([_curSpray, _curHex] select (_mode isEqualTo "hex"))]
        ] }],
        ["colors", _HEXCOLORS apply { _x select 0 }],
        ["hexAvail", true]
    ]
};

case "spray": {
    private _cfg = ["getCfg"] call AP_fnc_sprayCanCfg;
    private _row = _cfg param [_cfg findIf { (_x select 0) isEqualTo _a }, []];
    if (_row isEqualTo [] || {!(_row param [3, false])}) exitWith { ["You do not own that spray."] call _no };
    profileNamespace setVariable ["AP_savedSprayImage", _row];
    [format ["Spray set: %1.", _row select 1]] call _yes
};

case "hex": {
    private _cfg = ["getCfg"] call AP_fnc_hexIconCfg;
    private _row = _cfg param [_cfg findIf { (_x select 0) isEqualTo _a }, []];
    if (_row isEqualTo [] || {!(_row param [3, false])}) exitWith { ["You do not own that icon."] call _no };
    if !((time - 10) > AP_lastHexChange) exitWith { ["One change every 10 seconds."] call _no };
    AP_lastHexChange = time;
    _row params ["_idx", "_name", "_path"];
    profileNamespace setVariable ["AP_coloredHexesData", [[_idx, _path],
        ((profileNamespace getVariable ["AP_coloredHexesData", [[-1, ""], [0, 0, 0, 1]]]) param [1, [0, 0, 0, 1]])]];
    if (AP_effSide isEqualTo civilian) then { player setVariable ["AP_coloredHexesData", _path, true]; };
    [format ["Group hex icon: %1.", _name]] call _yes
};

case "hexcolor": {
    private _c = _HEXCOLORS param [_a max 0, []];
    if (_c isEqualTo []) exitWith { ["bad colour"] call _no };
    profileNamespace setVariable ["AP_coloredHexesData", [
        ((profileNamespace getVariable ["AP_coloredHexesData", [[-1, ""], [0, 0, 0, 1]]]) param [0, [-1, ""]]),
        _c select 1]];
    [format ["Hex colour: %1.", _c select 0]] call _yes
};

default { ["unknown spray verb"] call _no };
};
