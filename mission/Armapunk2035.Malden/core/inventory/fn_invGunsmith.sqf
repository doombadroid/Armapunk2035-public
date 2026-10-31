/*
    fn_invGunsmith.sqf -- GUNSMITH: the primary / handgun's attachment sockets and magazine.
    INVENTORY_SPEC.md §9.4 (Gunsmith) and the 4a handoff.

        [_verb, _args] call AP_fnc_invGunsmith
        -> hashmap { ok, msg, took, put, spilled }      (mutating verbs)
        -> hashmap payload | objNull                     ("data")

    verbs
      "data"    [slot]              the `gunsmith` push: weapon, sockets, mag, magsInContainers, fits
      "open"    [slot]              gate + remember the open slot (uiNamespace AP_invGsOpen)
      "close"   []
      "mount"   [id, slot, socket]  an attachment row from an OWN container onto a socket ("" = its own)
      "detach"  [slot, socket]      socket -> backpack, vest, uniform, else the ground
      "unload"  [slot]              loaded magazine -> vest, backpack, uniform (with its rounds)
      "reload"  [slot, id]          a magazine row ("" = the fullest compatible one in the containers)

    Attachments come from an OWN container here. A row in the reach vehicle is staged into the
    vest/backpack by fn_invBridge (APS_fnc_invCargo "take") before it reaches this file, so the
    shared-cargo mutation stays on the server and this file stays local.

    Displacement (handoff rule): the attachment already in the socket goes to the container the
    new one came from if it fits, else vest -> backpack -> uniform, else the ground.
    Sockets present on a weapon = the WeaponSlotsInfo subclasses it declares (MuzzleSlot,
    CowsSlot, PointerSlot, UnderBarrelSlot); fit = BIS_fnc_compatibleItems, socket by ItemInfo>>type.
*/
params [["_verb", "", [""]], ["_args", [], [[], ""]]];
// a bare slot string is accepted as [slot]: three bridge sites passed one and params refused them with a
// -SCRIPTERR- (2026-09-07); the callers are fixed and this keeps the next one from failing silently
if (_args isEqualType "") then { _args = [_args]; };
["init", []] call AP_fnc_invLocal;

private _took = []; private _put = []; private _spilled = 0;
private _fnOK = { params ["_msg"]; createHashMapFromArray [["ok", true],  ["msg", _msg], ["took", _took], ["put", _put], ["spilled", _spilled]] };
private _fnNo = { params ["_msg"]; createHashMapFromArray [["ok", false], ["msg", _msg], ["took", []], ["put", []], ["spilled", 0]] };

private _fnWpn = { params ["_slot"]; switch (_slot) do { case "primary": { primaryWeapon player }; case "handgun": { handgunWeapon player }; default { "" } } };
private _fnWI  = { params ["_wpn"]; ((weaponsItems player) select { (_x select 0) isEqualTo _wpn }) param [0, [_wpn, "", "", "", [], [], ""]] };
private _fnAddItem = { params ["_slot", "_item"]; if (_slot isEqualTo "primary") then { player addPrimaryWeaponItem _item } else { player addHandgunItem _item }; };
private _fnRemItem = { params ["_slot", "_item"]; if (_slot isEqualTo "primary") then { player removePrimaryWeaponItem _item } else { player removeHandgunItem _item }; };
private _sockDefs = [["optic", "CowsSlot", 3], ["muzzle", "MuzzleSlot", 1], ["pointer", "PointerSlot", 2], ["bipod", "UnderBarrelSlot", 6]];
private _fnCompat = { params ["_wpn"]; ([_wpn] call BIS_fnc_compatibleItems) apply { toLower _x } };
private _fnMags = {
    params ["_wpn"];
    private _cw = configFile >> "CfgWeapons" >> _wpn;
    private _mags = (getArray (_cw >> "magazines")) apply { toLower _x };
    private _mw = getArray (_cw >> "magazineWell");
    if (_mw isNotEqualTo []) then {
        {
            private _well = configFile >> "CfgMagazineWells" >> _x;
            if (isClass _well) then {
                { _mags append ((getArray _x) apply { toLower _x }); } forEach configProperties [_well, "isArray _x", true];
            };
        } forEach _mw;
    };
    _mags
};
private _fnPlace = {
    // a displaced attachment / magazine row -> preferred loc, first room, else the ground
    params ["_row", "_prefer"];
    ([_row, _prefer] call AP_fnc_invPlaceOwn) params ["_where", "_gwh"];
    if (_where isEqualTo "ground") then { _spilled = _spilled + 1; _put pushBack [_gwh, _row get "cls"]; };
    _where
};
private _fnReachCont = {
    private _c = uiNamespace getVariable ["AP_invContainer", objNull];
    if (isNull _c || {!alive _c} || {_c getVariable ["AP_trunkLock", false]}) exitWith { objNull };
    private _u = _c getVariable ["AP_veh_in_use", objNull];
    if (!isNull _u && {_u != player}) exitWith { objNull };
    _c
};

switch (_verb) do {

    case "data": {
        _args params [["_slot", "", [""]]];
        private _wpn = [_slot] call _fnWpn;
        if (_wpn isEqualTo "") exitWith { objNull };
        private _i = [_wpn] call AP_fnc_invItemInfo;
        private _wi = [_wpn] call _fnWI;
        private _cw = configFile >> "CfgWeapons" >> _wpn >> "WeaponSlotsInfo";
        private _sockets = [];
        {
            _x params ["_key", "_cfgName", "_idx"];
            if (isClass (_cw >> _cfgName)) then {
                private _item = _wi param [_idx, ""];
                private _im = objNull;
                if (_item != "") then {
                    private _ii = [_item] call AP_fnc_invItemInfo;
                    _im = createHashMapFromArray [["cls", _item], ["name", _ii get "name"], ["icon", _ii get "icon"]];
                };
                _sockets pushBack (createHashMapFromArray [["type", _key], ["item", _im]]);
            };
        } forEach _sockDefs;
        private _magArr = _wi param [4, []];
        private _mag = objNull;
        if (_magArr isNotEqualTo []) then {
            private _mi = [_magArr select 0] call AP_fnc_invItemInfo;
            _mag = createHashMapFromArray [["cls", _magArr select 0], ["name", _mi get "name"], ["ammo", _magArr select 1], ["cap", _mi get "cap"]];
        };
        private _compat = [_wpn] call _fnCompat;
        private _magsOK = [_wpn] call _fnMags;
        private _fits = []; private _magsIn = 0;
        private _sources = [["uniform", uniformContainer player, "UNIFORM"], ["vest", vestContainer player, "VEST"], ["backpack", backpackContainer player, "BACKPACK"]];
        private _rc = call _fnReachCont;
        if (!isNull _rc) then { _sources pushBack ["container", _rc, toUpper getText (configFile >> "CfgVehicles" >> (typeOf _rc) >> "displayName")]; };
        {
            _x params ["_loc", "_obj", "_label"];
            if (!isNull _obj) then {
                {
                    private _r = _x;
                    if ((_r get "kind") isEqualTo "attach" && { (toLower (_r get "cls")) in _compat }) then {
                        _fits pushBack (createHashMapFromArray [
                            ["id", _r get "id"], ["cls", _r get "cls"], ["name", _r get "name"], ["icon", _r get "icon"],
                            ["mass", _r get "mass"], ["socket", _r get "socket"], ["loc", _loc], ["source", _label], ["qty", _r get "qty"]
                        ]);
                    };
                    if (_loc != "container" && {(_r get "kind") isEqualTo "mag"} && { (toLower (_r get "cls")) in _magsOK }) then {
                        _magsIn = _magsIn + (_r get "qty");
                    };
                } forEach ([_obj, _loc] call AP_fnc_invCargoRead);
            };
        } forEach _sources;
        createHashMapFromArray [
            ["slot", _slot],
            ["weapon", createHashMapFromArray [["cls", _wpn], ["name", _i get "name"], ["icon", _i get "icon"], ["mass", _i get "mass"], ["wide", true]]],
            ["sockets", _sockets], ["mag", _mag], ["magsInContainers", _magsIn], ["fits", _fits]
        ]
    };

    case "open": {
        _args params [["_slot", "", [""]]];
        if !(_slot in ["primary", "handgun"]) exitWith { ["ONLY THE PRIMARY AND THE HANDGUN OPEN HERE."] call _fnNo };
        if (([_slot] call _fnWpn) isEqualTo "") exitWith { ["THAT SLOT IS EMPTY."] call _fnNo };
        if (((assignedVehicleRole player) param [0, ""]) isEqualTo "Turret") exitWith { ["HOLSTER THE WEAPON TO EDIT IT."] call _fnNo };
        uiNamespace setVariable ["AP_invGsOpen", _slot];
        [""] call _fnOK
    };

    case "close": {
        uiNamespace setVariable ["AP_invGsOpen", ""];
        [""] call _fnOK
    };

    case "mount": {
        _args params [["_id", "", [""]], ["_slot", "", [""]], ["_socket", "", [""]]];
        private _wpn = [_slot] call _fnWpn;
        if (_wpn isEqualTo "") exitWith { ["THAT SLOT IS EMPTY."] call _fnNo };
        ([_id] call AP_fnc_invParseId) params ["_from", "", "", ""];
        if !(_from in ["uniform", "vest", "backpack"]) exitWith { ["THAT ATTACHMENT DOES NOT FIT THIS WEAPON."] call _fnNo };
        private _row = [_from, _id] call AP_fnc_invRowOf;
        if (_row isEqualType objNull) exitWith { ["THAT ITEM IS GONE."] call _fnNo };
        if ((_row get "kind") isEqualTo "mag") exitWith { ["reload", [_slot, _id]] call AP_fnc_invGunsmith };
        if ((_row get "kind") != "attach") exitWith { ["THAT ATTACHMENT DOES NOT FIT THIS WEAPON."] call _fnNo };
        private _sock = _row get "socket";
        if (_socket != "" && {_socket != _sock}) exitWith { ["THAT ATTACHMENT DOES NOT FIT THIS WEAPON."] call _fnNo };
        if !((toLower (_row get "cls")) in ([_wpn] call _fnCompat)) exitWith { ["THAT ATTACHMENT DOES NOT FIT THIS WEAPON."] call _fnNo };
        private _k = _sockDefs findIf { (_x select 0) isEqualTo _sock };
        if (_k < 0) exitWith { ["THAT ATTACHMENT DOES NOT FIT THIS WEAPON."] call _fnNo };
        private _def = _sockDefs select _k;
        if !(isClass (configFile >> "CfgWeapons" >> _wpn >> "WeaponSlotsInfo" >> (_def select 1))) exitWith { ["THAT ATTACHMENT DOES NOT FIT THIS WEAPON."] call _fnNo };
        private _old = ([_wpn] call _fnWI) param [_def select 2, ""];
        if (_old isEqualTo (_row get "cls")) exitWith { ["IT IS ALREADY MOUNTED."] call _fnNo };
        if !([_from, _row] call AP_fnc_invRemoveOwn) exitWith { ["THAT ITEM IS GONE."] call _fnNo };
        private _oldWhere = "";
        if (_old != "") then {
            [_slot, _old] call _fnRemItem;
            _oldWhere = [[_old] call AP_fnc_invRowFor, _from] call _fnPlace;
        };
        [_slot, _row get "cls"] call _fnAddItem;
        private _msg = format ["%1 MOUNTED.", toUpper (_row get "name")];
        if (_old != "") then { _msg = format ["%1 %2 → %3.", _msg, toUpper (([_old] call AP_fnc_invItemInfo) get "name"), toUpper _oldWhere]; };
        [_msg] call _fnOK
    };

    case "detach": {
        _args params [["_slot", "", [""]], ["_socket", "", [""]]];
        private _wpn = [_slot] call _fnWpn;
        if (_wpn isEqualTo "") exitWith { ["THAT SLOT IS EMPTY."] call _fnNo };
        private _k = _sockDefs findIf { (_x select 0) isEqualTo _socket };
        if (_k < 0) exitWith { ["NO SUCH SOCKET."] call _fnNo };
        private _item = ([_wpn] call _fnWI) param [(_sockDefs select _k) select 2, ""];
        if (_item isEqualTo "") exitWith { ["NOTHING THERE."] call _fnNo };
        [_slot, _item] call _fnRemItem;
        private _where = [[_item] call AP_fnc_invRowFor, "backpack"] call _fnPlace;
        [format ["%1 → %2.", toUpper (([_item] call AP_fnc_invItemInfo) get "name"), toUpper _where]] call _fnOK
    };

    case "unload": {
        _args params [["_slot", "", [""]]];
        private _wpn = [_slot] call _fnWpn;
        if (_wpn isEqualTo "") exitWith { ["THAT SLOT IS EMPTY."] call _fnNo };
        private _magArr = ([_wpn] call _fnWI) param [4, []];
        if (_magArr isEqualTo []) exitWith { ["NO MAGAZINE LOADED."] call _fnNo };
        [_slot, _magArr select 0] call _fnRemItem;
        private _where = [[_magArr select 0, _magArr select 1] call AP_fnc_invRowFor, "vest"] call _fnPlace;
        [format ["%1 (%2) → %3.", toUpper (([_magArr select 0] call AP_fnc_invItemInfo) get "name"), _magArr select 1, toUpper _where]] call _fnOK
    };

    case "reload": {
        _args params [["_slot", "", [""]], ["_id", "", [""]]];
        private _wpn = [_slot] call _fnWpn;
        if (_wpn isEqualTo "") exitWith { ["THAT SLOT IS EMPTY."] call _fnNo };
        private _magsOK = [_wpn] call _fnMags;
        private _from = ""; private _row = objNull;
        if (_id != "") then {
            ([_id] call AP_fnc_invParseId) params ["_loc", "", "", ""];
            if (_loc in ["uniform", "vest", "backpack"]) then { _from = _loc; _row = [_loc, _id] call AP_fnc_invRowOf; };
            if (!(_row isEqualType objNull) && {(_row get "kind") != "mag" || {!((toLower (_row get "cls")) in _magsOK)}}) then { _row = objNull; };
        } else {
            private _best = -1;
            {
                private _loc = _x;
                {
                    if ((_x get "kind") isEqualTo "mag" && { (toLower (_x get "cls")) in _magsOK } && { (_x get "ammo") > _best }) then {
                        _best = _x get "ammo"; _row = _x; _from = _loc;
                    };
                } forEach ([[_loc] call AP_fnc_invContOf, _loc] call AP_fnc_invCargoRead);
            } forEach ["vest", "backpack", "uniform"];
        };
        if (_row isEqualType objNull) exitWith { ["NO COMPATIBLE MAGAZINE IN YOUR CONTAINERS."] call _fnNo };
        private _cur = ([_wpn] call _fnWI) param [4, []];
        if !([_from, _row] call AP_fnc_invRemoveOwn) exitWith { ["THAT ITEM IS GONE."] call _fnNo };
        private _curWhere = "";
        if (_cur isNotEqualTo []) then {
            [_slot, _cur select 0] call _fnRemItem;
            _curWhere = [[_cur select 0, _cur select 1] call AP_fnc_invRowFor, _from] call _fnPlace;
        };
        player addWeaponItem [_wpn, [_row get "cls", _row get "ammo"], true];
        private _msg = format ["%1 (%2) LOADED.", toUpper (_row get "name"), _row get "ammo"];
        if (_cur isNotEqualTo []) then { _msg = format ["%1 PREVIOUS (%2) → %3.", _msg, _cur select 1, toUpper _curWhere]; };
        [_msg] call _fnOK
    };

    default { ["UNKNOWN VERB."] call _fnNo };
}
