/*
    AP_fnc_deckRig -- the RIG CONSOLE deck app: control the resource extractor
    and pick what it mines.

    Everything here is advisory display + request forwarding: APS_fnc_rigSRV
    re-validates ownership, distance, speed, crew, the state machine, and that
    the chosen resource actually exists in the deposit under the truck.

    ["data"] / ["deploy"] / ["fold"] / ["start"] / ["stop"] / ["target", res]
    Processor: ["procstart"] / ["procstop"] / ["link", netId] / ["unlink", netId]
*/
params [["_verb", "", [""]], ["_a", "", [""]]];

private _no  = { params ["_m"]; createHashMapFromArray [["ok", false], ["msg", _m]] };
private _yes = { params ["_m"]; createHashMapFromArray [["ok", true],  ["msg", _m]] };
private _truck = missionNamespace getVariable ["AP_deckCtx", objNull];
if (isNull _truck || {(_truck getVariable ["AP_rigKind", ""]) isEqualTo ""}) exitWith {
    if (_verb isEqualTo "data") then { createHashMapFromArray [["gone", true]] } else { ["No rig in reach."] call _no }
};

// same zone table the server uses -- advisory only, the server re-derives
private _zoneOf = {
    private _zones = ["mine_1","mine_2","mine_3","mine_4","mine_5","mine_6","oil_1","oil_2","oil_3","rock_1","rock_2","rock_3","salt_1"];
    private _near = _zones select { markerType _x isNotEqualTo "" && {_truck distance2D (getMarkerPos _x) <= ([150, 70] select ((_x find "mine") != -1))} };
    _near param [0, ""]
};
private _lootOf = {
    params ["_zone"];
    switch (true) do {
        case (_zone find "mine" != -1): { ["ironore","copperore","sand","diamond"] };
        case (_zone find "oil"  != -1): { ["oilu"] };
        case (_zone find "rock" != -1): { ["redshift"] };
        case (_zone find "salt" != -1): { ["salt"] };
        default { [] };
    }
};

switch (toLower _verb) do {

case "data": {
    private _kind = _truck getVariable ["AP_rigKind", ""];
    private _zone = call _zoneOf;
    (_truck getVariable ["AP_vinv", [[], 0]]) params [["_inv", []], ["_used", 0]];
    // processor extras: resolved link rows + linkable extractors in feed range.
    // Advisory only -- the server re-validates range, keys, counts on "link".
    private _links = [];
    private _nearby = [];
    if (_kind isEqualTo "processor") then {
        {
            private _e = objectFromNetId _x;
            if (!isNull _e) then {
                private _raw = 0;
                { _raw = _raw + (_x select 1) } forEach ((_e getVariable ["AP_vinv", [[], 0]]) param [0, []]);
                _links pushBack (createHashMapFromArray [
                    ["nid", _x], ["dist", round (_truck distance _e)], ["raw", _raw],
                    ["state", _e getVariable ["AP_rigState", "?"]] ]);
            };
        } forEach (_truck getVariable ["AP_rigLinks", []]);
        private _lnids = _truck getVariable ["AP_rigLinks", []];
        {
            if ((_x getVariable ["AP_rigKind", ""]) isEqualTo "extractor"
                && {!((netId _x) in _lnids)}
                && {(_x getVariable ["AP_rigLinkedTo", ""]) isEqualTo ""}) then {
                _nearby pushBack (createHashMapFromArray [
                    ["nid", netId _x], ["dist", round (_truck distance _x)] ]);
            };
        } forEach (_truck nearEntities [["Truck_F"], 35]);
    };
    createHashMapFromArray [
        ["kind", _kind],
        ["state", _truck getVariable ["AP_rigState", "compact"]],
        ["zone", _zone],
        ["offer", ([_zone] call _lootOf) apply { createHashMapFromArray [
            ["id", _x], ["name", ["getName", _x] call AP_fnc_virtItemCfg] ] }],
        ["target", _truck getVariable ["AP_rigTarget", ""]],
        ["hopper", _inv apply { createHashMapFromArray [
            ["name", ["getName", _x select 0] call AP_fnc_virtItemCfg], ["qty", _x select 1] ] }],
        ["used", _used],
        ["cap", ([_truck, true] call AP_fnc_vehicleWeight) param [0, 0]],
        ["dist", round (player distance _truck)],
        ["links", _links],
        ["nearby", _nearby],
        ["linkedTo", (_truck getVariable ["AP_rigLinkedTo", ""]) isNotEqualTo ""]
    ]
};

case "deploy": { [["deploy", [player, _truck]], "APS_fnc_rigSRV", 2] spawn AP_fnc_MP; ["Deploying..."] call _yes };
case "fold":   { [["fold", [player, _truck]], "APS_fnc_rigSRV", 2] spawn AP_fnc_MP; ["Packing up..."] call _yes };
case "start":  { [["mineStart", [player, _truck]], "APS_fnc_rigSRV", 2] spawn AP_fnc_MP; ["Spinning up..."] call _yes };
case "stop":   { [["mineStop", [player, _truck]], "APS_fnc_rigSRV", 2] spawn AP_fnc_MP; ["Winding down..."] call _yes };
case "procstart": { [["procStart", [player, _truck]], "APS_fnc_rigSRV", 2] spawn AP_fnc_MP; ["Feed line opening..."] call _yes };
case "procstop":  { [["procStop", [player, _truck]], "APS_fnc_rigSRV", 2] spawn AP_fnc_MP; ["Shutting down..."] call _yes };
case "link": {
    private _e = objectFromNetId _a;
    if (isNull _e) exitWith { ["That extractor is gone."] call _no };
    [["link", [player, _truck, _e]], "APS_fnc_rigSRV", 2] spawn AP_fnc_MP; ["Linking..."] call _yes
};
case "unlink": { [["unlink", [player, _truck, _a]], "APS_fnc_rigSRV", 2] spawn AP_fnc_MP; ["Unlinked."] call _yes };
case "target": {
    [["setTarget", [player, _truck, _a]], "APS_fnc_rigSRV", 2] spawn AP_fnc_MP;
    [["The drill takes the deposit's own mix.", format ["Targeting %1.", ["getName", _a] call AP_fnc_virtItemCfg]] select (_a isNotEqualTo "")] call _yes
};

default { ["unknown rig verb"] call _no };
};
