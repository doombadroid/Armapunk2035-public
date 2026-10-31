/*
    fn_invCargoRead.sqf -- one container's engine cargo as I-screen rows (INVENTORY_SPEC.md §9.0 #5/#6).

        [_container, _loc] call AP_fnc_invCargoRead
        -> [ hashmap { id, cls, name, icon, kind, mass, qty, ammo, cap, socket, wide, loc } ... ]

    _container : uniformContainer/vestContainer/backpackContainer player, a vehicle, a crate or a
                 ground WeaponHolder -- anything the *Cargo commands read.
    _loc       : the location tag the ids are built from ("vest", "container", "ground:<netId>").

    IDENTITY. The engine has no item ids, so rows are keyed deterministically:
        loc|cls|ammo          magazines (ammo = round count), items, attachments, clothing, backpacks
        loc|cls|-1|k          weapons -- never grouped (k = ordinal among same-class weapons here),
                              because two MXs can carry different attachments
    Identical (cls, ammo) pairs group into one row with qty. The same container in the same state
    always yields the same ids, so the page can patch rows in place across pushes.

    Weapons keep their full weaponsItems array ([wpn, muzzle, pointer, optic, [mag, ammo],
    [mag2, ammo], bipod]) in uiNamespace AP_invWI keyed by id, so the mutators can move an MX with
    its RCO as one object (addWeaponWithAttachmentsCargoGlobal) instead of a bare class.
*/
params [["_c", objNull, [objNull]], ["_loc", "", [""]]];
if (isNull _c) exitWith { [] };

private _wiMap = uiNamespace getVariable "AP_invWI";
if (isNil "_wiMap") then { _wiMap = createHashMap; uiNamespace setVariable ["AP_invWI", _wiMap]; };

private _rows = [];
private _byId = createHashMap;
private _fnAdd = {
    params ["_cls", "_ammo", "_n", ["_id", ""]];
    if (_id isEqualTo "") then { _id = format ["%1|%2|%3", _loc, _cls, _ammo]; };
    private _r = _byId get _id;
    if (isNil "_r") then {
        private _i = [_cls] call AP_fnc_invItemInfo;
        _r = createHashMapFromArray [
            ["id", _id], ["cls", _cls], ["name", _i get "name"], ["icon", _i get "icon"],
            ["kind", _i get "kind"], ["mass", _i get "mass"], ["qty", 0], ["ammo", _ammo],
            ["cap", _i get "cap"], ["socket", _i get "socket"], ["wide", _i get "wide"], ["loc", _loc]
        ];
        _byId set [_id, _r];
        _rows pushBack _r;
    };
    _r set ["qty", (_r get "qty") + _n];
    _r
};

// weapons first (one row each), with their attachment/magazine state remembered by id
private _ord = createHashMap;
{
    private _cls = _x select 0;
    private _k = _ord getOrDefault [_cls, 0];
    _ord set [_cls, _k + 1];
    private _id = format ["%1|%2|-1|%3", _loc, _cls, _k];
    [_cls, -1, 1, _id] call _fnAdd;
    _wiMap set [_id, _x];
} forEach (weaponsItemsCargo _c);

// magazines with their round counts -- a 17/30 is its own row, never merged into the 30/30 stack
{ [_x select 0, _x select 1, 1] call _fnAdd; } forEach (magazinesAmmoCargo _c);

// items (attachments, first-aid kits, tools, spare clothing)
(getItemCargo _c) params [["_icls", []], ["_iqty", []]];
{ [_x, -1, _iqty select _forEachIndex] call _fnAdd; } forEach _icls;

// backpacks inside a backpack / a crate
(getBackpackCargo _c) params [["_bcls", []], ["_bqty", []]];
{ [_x, -1, _bqty select _forEachIndex] call _fnAdd; } forEach _bcls;

_rows
