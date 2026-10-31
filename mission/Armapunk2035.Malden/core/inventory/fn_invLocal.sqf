/*
    fn_invLocal.sqf -- own-body inventory mutations for the I-screen. INVENTORY_SPEC.md §9.4.

        [_verb, _args] call AP_fnc_invLocal
        -> hashmap { ok, msg, took:[[container, cls]...], put:[[container, cls]...], spilled:n }

    verbs
      "init"     []                        define the shared helpers only (fn_invGunsmith uses them)
      "move"     [fromLoc, id, toLoc, qty] uniform/vest/backpack -> uniform/vest/backpack
      "equip"    [fromLoc, id, slot]       a row from an own container into a worn slot
                                           (slot "" = where it belongs, by kind)
      "unequip"  [slot, toLoc]             a worn slot into a container ("" = first with room),
                                           or "ground" (a fresh holder)
      "spill"    [rows]                    displaced gear -> a fresh GroundWeaponHolder

    LOCAL ONLY. Everything here touches the player's own body and, for spills, a holder this
    function creates and fills with the player's own displaced gear (the AP_fnc_forceDropItem
    pattern). Vehicles, crates and EXISTING holders are shared state and go through
    APS_fnc_invCargo, the one serialised mutator -- never from here.

    HOW A UNIT MOVES. The engine's remove-by-class commands cannot say WHICH magazine they remove,
    so a magazine leaves a container by rebuilding that container's magazine cargo without one
    [cls, ammo] pair (magazinesAmmoCargo -> clearMagazineCargoGlobal -> addMagazineAmmoCargo) --
    a 17/30 stays a 17/30. Weapons leave the same way on the weapon cargo, carrying their
    weaponsItems array (addWeaponWithAttachmentsCargoGlobal), so an MX keeps its RCO. Everything
    else is a plain class: removeItemFromX / addItemToX. Every add is preceded by canAdd on the
    destination, so the engine's mass rules decide, not this file.

    The helpers below are published as global AP_fnc_invXxx functions (at client init) so fn_invGunsmith.sqf can
    move attachments and magazines with the same primitives instead of a second implementation.

    Take/Put: moves inside the player's own gear never fired the engine's Take/Put handlers under the
    native dialog either, so `took`/`put` are empty here except for spills, which the native fired
    "Put" for (that handler sets the holder's 450 s clean time and logs -STOREDITEM-).
*/
params [["_verb", "", [""]], ["_args", [], [[]]]];

// ---------------------------------------------------------------- helpers --
// Each helper guards itself (security 2026-09-26): one isNil guard over the block let a value published
// under that one name skip every definition. core\init.sqf defines them all at client init ("boot"/"init").
    if !(isFinal "AP_fnc_invContOf") then {AP_fnc_invContOf = compileFinal {
        params ["_loc"];
        switch (_loc) do {
            case "uniform":  { uniformContainer player };
            case "vest":     { vestContainer player };
            case "backpack": { backpackContainer player };
            default          { objNull };
        }
    }};
    // "loc|cls|ammo[|k]" -> [loc, cls, ammo, k]
    if !(isFinal "AP_fnc_invParseId") then {AP_fnc_invParseId = compileFinal {
        params ["_id"];
        private _p = _id splitString "|";
        [_p param [0, ""], _p param [1, ""], parseNumber (_p param [2, "-1"]), _p param [3, ""]]
    }};
    // the live row for an id inside an own container, or objNull
    if !(isFinal "AP_fnc_invRowOf") then {AP_fnc_invRowOf = compileFinal {
        params ["_loc", "_id"];
        private _c = [_loc] call AP_fnc_invContOf;
        if (isNull _c) exitWith { objNull };
        private _rows = [_c, _loc] call AP_fnc_invCargoRead;
        private _i = _rows findIf { (_x get "id") isEqualTo _id };
        if (_i < 0) then { objNull } else { _rows select _i }
    }};
    // a synthetic row for a class that is not in any container right now (a worn item on its way out)
    if !(isFinal "AP_fnc_invRowFor") then {AP_fnc_invRowFor = compileFinal {
        params ["_cls", ["_ammo", -1], ["_wi", []]];
        private _i = [_cls] call AP_fnc_invItemInfo;
        private _id = format ["hand|%1|%2|%3", _cls, _ammo, round (random 1e6)];
        if (_wi isNotEqualTo []) then {
            private _m = uiNamespace getVariable "AP_invWI";
            if (isNil "_m") then { _m = createHashMap; uiNamespace setVariable ["AP_invWI", _m]; };
            _m set [_id, _wi];
        };
        createHashMapFromArray [
            ["id", _id], ["cls", _cls], ["name", _i get "name"], ["icon", _i get "icon"], ["kind", _i get "kind"],
            ["mass", _i get "mass"], ["qty", 1], ["ammo", _ammo], ["cap", _i get "cap"], ["socket", _i get "socket"],
            ["wide", _i get "wide"], ["loc", "hand"]
        ]
    }};
    if !(isFinal "AP_fnc_invWIOf") then {AP_fnc_invWIOf = compileFinal {
        params ["_row"];
        (uiNamespace getVariable ["AP_invWI", createHashMap]) getOrDefault [_row get "id", [_row get "cls", "", "", "", [], [], ""]]
    }};
    // can ONE unit of this row go into this own container?
    if !(isFinal "AP_fnc_invCanAddOwn") then {AP_fnc_invCanAddOwn = compileFinal {
        params ["_loc", "_row"];
        private _c = [_loc] call AP_fnc_invContOf;
        if (isNull _c) exitWith { false };
        if ((_row get "kind") isEqualTo "backpack" && {_loc != "backpack"}) exitWith { false };
        if ((_row get "kind") isEqualTo "mag") then { _c canAdd [_row get "cls", 1] } else { _c canAdd (_row get "cls") }
    }};
    // remove ONE unit of a row from an own container. true on success.
    if !(isFinal "AP_fnc_invRemoveOwn") then {AP_fnc_invRemoveOwn = compileFinal {
        params ["_loc", "_row"];
        private _c = [_loc] call AP_fnc_invContOf;
        if (isNull _c) exitWith { false };
        private _cls = _row get "cls";
        switch (_row get "kind") do {
            case "mag": {
                private _ammo = _row get "ammo";
                private _all = magazinesAmmoCargo _c;
                private _i = _all findIf { (_x select 0) isEqualTo _cls && {(_x select 1) isEqualTo _ammo} };
                if (_i < 0) exitWith { false };
                _all deleteAt _i;
                clearMagazineCargoGlobal _c;
                { _c addMagazineAmmoCargo [_x select 0, 1, _x select 1]; } forEach _all;
                true
            };
            case "weapon": {
                private _wi = [_row] call AP_fnc_invWIOf;
                private _all = weaponsItemsCargo _c;
                private _i = _all findIf { _x isEqualTo _wi };
                if (_i < 0) then { _i = _all findIf { (_x select 0) isEqualTo _cls }; };
                if (_i < 0) exitWith { false };
                _all deleteAt _i;
                clearWeaponCargoGlobal _c;
                { _c addWeaponWithAttachmentsCargoGlobal [_x, 1]; } forEach _all;
                true
            };
            case "backpack": {
                if (_loc != "backpack") exitWith { false };
                (getBackpackCargo _c) params [["_bcls", []], ["_bqty", []]];
                private _i = _bcls find _cls;
                if (_i < 0) exitWith { false };
                _bqty set [_i, (_bqty select _i) - 1];
                clearBackpackCargoGlobal _c;
                { if ((_bqty select _forEachIndex) > 0) then { _c addBackpackCargoGlobal [_x, _bqty select _forEachIndex]; }; } forEach _bcls;
                true
            };
            default {
                if !(_cls in (itemCargo _c)) exitWith { false };
                switch (_loc) do {
                    case "uniform": { player removeItemFromUniform _cls };
                    case "vest":    { player removeItemFromVest _cls };
                    default         { player removeItemFromBackpack _cls };
                };
                true
            };
        }
    }};
    // add ONE unit of a row to an own container. Checks room. true on success.
    if !(isFinal "AP_fnc_invAddOwn") then {AP_fnc_invAddOwn = compileFinal {
        params ["_loc", "_row"];
        if !([_loc, _row] call AP_fnc_invCanAddOwn) exitWith { false };
        private _c = [_loc] call AP_fnc_invContOf;
        private _cls = _row get "cls";
        switch (_row get "kind") do {
            case "mag":      { _c addMagazineAmmoCargo [_cls, 1, _row get "ammo"]; };
            case "weapon":   { _c addWeaponWithAttachmentsCargoGlobal [[_row] call AP_fnc_invWIOf, 1]; };
            case "backpack": { _c addBackpackCargoGlobal [_cls, 1]; };
            default {
                switch (_loc) do {
                    case "uniform": { player addItemToUniform _cls };
                    case "vest":    { player addItemToVest _cls };
                    default         { player addItemToBackpack _cls };
                };
            };
        };
        true
    }};
    // the first own container with room for one unit of the row, or ""
    if !(isFinal "AP_fnc_invFirstRoom") then {AP_fnc_invFirstRoom = compileFinal {
        params ["_row"];
        private _order = switch (_row get "kind") do {
            case "mag"; case "attach": { ["vest", "backpack", "uniform"] };
            case "weapon"; case "uniform"; case "vest"; case "backpack"; case "binocular": { ["backpack", "vest", "uniform"] };
            default { ["uniform", "vest", "backpack"] };
        };
        private _hit = "";
        { if ([_x, _row] call AP_fnc_invCanAddOwn) exitWith { _hit = _x }; } forEach _order;
        _hit
    }};
    // displaced gear -> ONE fresh holder at the player's feet. Returns [holder, count].
    if !(isFinal "AP_fnc_invSpill") then {AP_fnc_invSpill = compileFinal {
        params ["_rows"];
        private _n = 0;
        if (_rows isEqualTo []) exitWith { [objNull, 0] };
        private _gwh = createVehicle ["GroundWeaponHolder", getPosATL player, [], 0, "CAN_COLLIDE"];
        {
            private _r = _x;
            for "_k" from 1 to (_r getOrDefault ["qty", 1]) do {
                switch (_r get "kind") do {
                    case "mag":      { _gwh addMagazineAmmoCargo [_r get "cls", 1, _r get "ammo"]; };
                    case "weapon":   { _gwh addWeaponWithAttachmentsCargoGlobal [[_r] call AP_fnc_invWIOf, 1]; };
                    case "backpack": { _gwh addBackpackCargoGlobal [_r get "cls", 1]; };
                    default          { _gwh addItemCargoGlobal [_r get "cls", 1]; };
                };
                _n = _n + 1;
            };
        } forEach _rows;
        [[_gwh, 450], "APS_fnc_setCleanTime", 2] spawn AP_fnc_MP;
        [_gwh, _n]
    }};
    // put a row somewhere on the player: preferred loc, else first room, else the ground. Returns
    // [loc-or-"ground", holder-or-objNull].
    if !(isFinal "AP_fnc_invPlaceOwn") then {AP_fnc_invPlaceOwn = compileFinal {
        params ["_row", ["_prefer", ""]];
        private _loc = _prefer;
        if (_loc != "" && {!([_loc, _row] call AP_fnc_invCanAddOwn)}) then { _loc = "" };
        if (_loc isEqualTo "") then { _loc = [_row] call AP_fnc_invFirstRoom; };
        if (_loc != "") exitWith { [_loc, _row] call AP_fnc_invAddOwn; [_loc, objNull] };
        ([[_row]] call AP_fnc_invSpill) params ["_gwh", ""];
        ["ground", _gwh]
    }};
if (_verb isEqualTo "init") exitWith { true };

// ---------------------------------------------------------------- verbs ----
private _took = []; private _put = []; private _spilled = 0;
private _fnOK = { params ["_msg"]; createHashMapFromArray [["ok", true],  ["msg", _msg], ["took", _took], ["put", _put], ["spilled", _spilled]] };
private _fnNo = { params ["_msg"]; createHashMapFromArray [["ok", false], ["msg", _msg], ["took", []], ["put", []], ["spilled", 0]] };
private _fnNoteSpill = { params ["_gwh", "_n", "_rows"]; if (_n > 0) then { _spilled = _spilled + _n; _put pushBack [_gwh, (_rows select 0) get "cls"]; }; };

switch (_verb) do {

    case "move": {
        _args params [["_from", "", [""]], ["_id", "", [""]], ["_to", "", [""]], ["_qty", 1, [0]]];
        if !(_from in ["uniform", "vest", "backpack"] && {_to in ["uniform", "vest", "backpack"]}) exitWith { ["NOT AN OWN-BODY MOVE."] call _fnNo };
        if (_from isEqualTo _to) exitWith { ["IT IS ALREADY THERE."] call _fnNo };
        private _row = [_from, _id] call AP_fnc_invRowOf;
        if (_row isEqualType objNull) exitWith { ["THAT ITEM IS GONE."] call _fnNo };
        private _n = (_qty max 1) min (_row get "qty");
        private _moved = 0;
        for "_k" from 1 to _n do {
            if !([_to, _row] call AP_fnc_invCanAddOwn) then { break };
            if !([_from, _row] call AP_fnc_invRemoveOwn) then { break };
            if !([_to, _row] call AP_fnc_invAddOwn) then { [_from, _row] call AP_fnc_invAddOwn; break };
            _moved = _moved + 1;
        };
        if (_moved isEqualTo 0) exitWith { [format ["NO ROOM IN YOUR %1.", toUpper _to]] call _fnNo };
        [format ["%1 × %2 → %3", _moved, toUpper (_row get "name"), toUpper _to]] call _fnOK
    };

    case "equip": {
        _args params [["_from", "", [""]], ["_id", "", [""]], ["_slot", "", [""]]];
        if !(_from in ["uniform", "vest", "backpack"]) exitWith { ["NOT AN OWN-BODY MOVE."] call _fnNo };
        private _row = [_from, _id] call AP_fnc_invRowOf;
        if (_row isEqualType objNull) exitWith { ["THAT ITEM IS GONE."] call _fnNo };
        private _cls = _row get "cls";
        private _kind = _row get "kind";
        private _wtype = getNumber (configFile >> "CfgWeapons" >> _cls >> "type");
        // where it belongs
        private _home = switch (_kind) do {
            case "weapon":   { switch (_wtype) do { case 1: { "primary" }; case 2: { "handgun" }; case 4: { "launcher" }; default { "" } } };
            case "uniform":  { "uniform" }; case "vest": { "vest" }; case "backpack": { "backpack" };
            case "headgear": { "headgear" }; case "facewear": { "facewear" }; case "binocular": { "binocular" };
            case "nvg":      { "assigned:nvg" };
            case "assigned": {
                switch (getText (configFile >> "CfgWeapons" >> _cls >> "simulation")) do {
                    case "ItemMap": { "assigned:map" }; case "ItemGPS": { "assigned:gps" }; case "ItemRadio": { "assigned:radio" };
                    case "ItemCompass": { "assigned:compass" }; case "ItemWatch": { "assigned:watch" }; default { "" };
                }
            };
            default { "" };
        };
        if (_home isEqualTo "") exitWith { ["THAT DOES NOT GO ON YOU."] call _fnNo };
        if (_slot != "" && {_slot != _home}) exitWith { [format ["THAT GOES IN %1, NOT %2.", toUpper _home, toUpper _slot]] call _fnNo };
        _slot = _home;

        // worn containers: the migration dance
        if (_kind in ["uniform", "vest", "backpack"]) exitWith {
            private _oldCls = switch (_slot) do { case "uniform": { uniform player }; case "vest": { vest player }; default { backpack player } };
            if !([_from, _row] call AP_fnc_invRemoveOwn) exitWith { ["THAT ITEM IS GONE."] call _fnNo };
            // read what the old garment holds AFTER the new one left it (they may be the same container)
            private _oldRows = if (_oldCls != "") then { [[_slot] call AP_fnc_invContOf, _slot] call AP_fnc_invCargoRead } else { [] };
            switch (_slot) do {
                case "uniform":  { removeUniform player; player forceAddUniform _cls; };
                case "vest":     { removeVest player;    player addVest _cls; };
                case "backpack": {
                    removeBackpack player; player addBackpack _cls;
                    // config-default contents are not what the stored pack held
                    private _bc = backpackContainer player;
                    clearMagazineCargoGlobal _bc; clearItemCargoGlobal _bc; clearWeaponCargoGlobal _bc; clearBackpackCargoGlobal _bc;
                };
            };
            private _leftover = [];
            {
                private _r = _x;
                for "_k" from 1 to (_r get "qty") do {
                    if !([_slot, _r] call AP_fnc_invAddOwn) then {
                        private _one = +_r; _one set ["qty", 1];
                        _leftover pushBack _one;
                    };
                };
            } forEach _oldRows;
            // the old garment itself: back where the new one came from if that container still exists
            if (_oldCls != "") then {
                private _oldRow = [_oldCls] call AP_fnc_invRowFor;
                private _prefer = if (_from isEqualTo _slot) then { "" } else { _from };
                ([_oldRow, _prefer] call AP_fnc_invPlaceOwn) params ["_where", "_gwh"];
                if (_where isEqualTo "ground") then { [_gwh, 1, [_oldRow]] call _fnNoteSpill; };
            };
            if (_leftover isNotEqualTo []) then {
                ([_leftover] call AP_fnc_invSpill) params ["_gwh", "_n"];
                [_gwh, _n, _leftover] call _fnNoteSpill;
            };
            switch (_slot) do {
                case "uniform":  { [uniform player, "setUniform", ""] call AP_fnc_clothingTextures; };
                case "backpack": { [backpack player, "setBackpack", ""] call AP_fnc_clothingTextures; [true] call AP_fnc_invisBag; };
            };
            [if (_spilled > 0) then { format ["%1 ON. %2 ITEMS SPILLED TO THE GROUND.", toUpper (_row get "name"), _spilled] } else { format ["%1 ON.", toUpper (_row get "name")] }] call _fnOK
        };

        // weapons
        if (_kind isEqualTo "weapon") exitWith {
            private _oldCls = switch (_slot) do { case "primary": { primaryWeapon player }; case "handgun": { handgunWeapon player }; default { secondaryWeapon player } };
            private _wi = [_row] call AP_fnc_invWIOf;
            if !([_from, _row] call AP_fnc_invRemoveOwn) exitWith { ["THAT ITEM IS GONE."] call _fnNo };
            if (_oldCls != "") then {
                private _oldWI = ((weaponsItems player) select { (_x select 0) isEqualTo _oldCls }) param [0, [_oldCls, "", "", "", [], [], ""]];
                player removeWeapon _oldCls;
                private _oldRow = [_oldCls, -1, _oldWI] call AP_fnc_invRowFor;
                ([_oldRow, _from] call AP_fnc_invPlaceOwn) params ["_where", "_gwh"];
                if (_where isEqualTo "ground") then { [_gwh, 1, [_oldRow]] call _fnNoteSpill; };
            };
            player addWeapon _cls;
            { if (_x != "") then { player addWeaponItem [_cls, _x, true]; }; } forEach [_wi param [1, ""], _wi param [2, ""], _wi param [3, ""], _wi param [6, ""]];
            private _magArr = _wi param [4, []];
            if (_magArr isNotEqualTo []) then {
                // addWeapon may already have chambered a magazine out of a container; the weapon's own
                // magazine then goes back into a container with its round count rather than vanishing
                private _loaded = switch (_slot) do { case "primary": { primaryWeaponMagazine player }; case "handgun": { handgunMagazine player }; default { secondaryWeaponMagazine player } };
                if (_loaded isEqualTo []) then {
                    player addWeaponItem [_cls, [_magArr select 0, _magArr select 1], true];
                } else {
                    private _magRow = [_magArr select 0, _magArr select 1] call AP_fnc_invRowFor;
                    ([_magRow, ""] call AP_fnc_invPlaceOwn) params ["_where", "_gwh"];
                    if (_where isEqualTo "ground") then { [_gwh, 1, [_magRow]] call _fnNoteSpill; };
                };
            };
            [format ["%1 EQUIPPED.", toUpper (_row get "name")]] call _fnOK
        };

        // headgear / facewear / binocular / assigned
        private _oldCls = switch (_slot) do {
            case "headgear":  { headgear player };
            case "facewear":  { goggles player };
            case "binocular": { binocular player };
            default {
                private _key = (_slot splitString ":") param [1, ""];
                private _hit = "";
                {
                    private _cw = configFile >> "CfgWeapons" >> _x;
                    private _k = switch (getText (_cw >> "simulation")) do {
                        case "ItemMap": { "map" }; case "ItemGPS": { "gps" }; case "ItemRadio": { "radio" };
                        case "ItemCompass": { "compass" }; case "ItemWatch": { "watch" };
                        default { if ((getNumber (_cw >> "ItemInfo" >> "type")) isEqualTo 616) then { "nvg" } else { "" } };
                    };
                    if (_k isEqualTo _key) exitWith { _hit = _x };
                } forEach (assignedItems player);
                _hit
            };
        };
        if !([_from, _row] call AP_fnc_invRemoveOwn) exitWith { ["THAT ITEM IS GONE."] call _fnNo };
        if (_oldCls != "") then {
            switch (_slot) do {
                case "headgear":  { removeHeadgear player };
                case "facewear":  { removeGoggles player };
                case "binocular": { player removeWeapon _oldCls };
                default           { player unlinkItem _oldCls };
            };
            private _oldRow = [_oldCls] call AP_fnc_invRowFor;
            ([_oldRow, _from] call AP_fnc_invPlaceOwn) params ["_where", "_gwh"];
            if (_where isEqualTo "ground") then { [_gwh, 1, [_oldRow]] call _fnNoteSpill; };
        };
        switch (_slot) do {
            case "headgear":  { player addHeadgear _cls };
            case "facewear":  { player addGoggles _cls };
            case "binocular": { player addWeapon _cls };
            default           { player linkItem _cls };
        };
        [format ["%1 ON.", toUpper (_row get "name")]] call _fnOK
    };

    case "unequip": {
        _args params [["_slot", "", [""]], ["_to", "", [""]]];
        // the page names an assigned cell by its key ("map"); the slot grammar is "assigned:map"
        if (_slot in ["map", "gps", "radio", "compass", "watch", "nvg"]) then { _slot = "assigned:" + _slot; };
        private _cls = switch (_slot) do {
            case "primary":   { primaryWeapon player };  case "handgun": { handgunWeapon player }; case "launcher": { secondaryWeapon player };
            case "uniform":   { uniform player };        case "vest":    { vest player };          case "backpack": { backpack player };
            case "headgear":  { headgear player };       case "facewear": { goggles player };      case "binocular": { binocular player };
            default {
                private _key = (_slot splitString ":") param [1, ""];
                private _hit = "";
                {
                    private _cw = configFile >> "CfgWeapons" >> _x;
                    private _k = switch (getText (_cw >> "simulation")) do {
                        case "ItemMap": { "map" }; case "ItemGPS": { "gps" }; case "ItemRadio": { "radio" };
                        case "ItemCompass": { "compass" }; case "ItemWatch": { "watch" };
                        default { if ((getNumber (_cw >> "ItemInfo" >> "type")) isEqualTo 616) then { "nvg" } else { "" } };
                    };
                    if (_k isEqualTo _key) exitWith { _hit = _x };
                } forEach (assignedItems player);
                _hit
            };
        };
        if (_cls isEqualTo "") exitWith { ["THAT SLOT IS EMPTY."] call _fnNo };
        if (_slot in ["uniform", "vest", "backpack"] && {(loadAbs ([_slot] call AP_fnc_invContOf)) > 0}) exitWith { ["EMPTY IT FIRST."] call _fnNo };
        if (_to in ["uniform", "vest", "backpack"] && {_to isEqualTo _slot}) exitWith { ["IT CANNOT HOLD ITSELF."] call _fnNo };
        private _wi = ((weaponsItems player) select { (_x select 0) isEqualTo _cls }) param [0, []];
        private _row = [_cls, -1, _wi] call AP_fnc_invRowFor;
        // room first, then the slot is cleared -- the row never exists in two places
        private _dest = if (_to isEqualTo "ground") then { "ground" } else {
            if (_to != "" && {[_to, _row] call AP_fnc_invCanAddOwn}) then { _to } else { [_row] call AP_fnc_invFirstRoom }
        };
        if (_dest isEqualTo "" && {_to != ""}) exitWith { [format ["NO ROOM IN YOUR %1.", toUpper _to]] call _fnNo };
        if (_dest isEqualTo "") then { _dest = "ground" };
        switch (_slot) do {
            case "primary"; case "handgun"; case "launcher"; case "binocular": { player removeWeapon _cls };
            case "uniform":  { removeUniform player };
            case "vest":     { removeVest player };
            case "backpack": { removeBackpack player };
            case "headgear": { removeHeadgear player };
            case "facewear": { removeGoggles player };
            default          { player unlinkItem _cls };
        };
        if (_dest isEqualTo "ground") then {
            ([[_row]] call AP_fnc_invSpill) params ["_gwh", "_n"];
            [_gwh, _n, [_row]] call _fnNoteSpill;
        } else {
            [_dest, _row] call AP_fnc_invAddOwn;
        };
        if (_slot isEqualTo "backpack") then { [true] call AP_fnc_invisBag; };
        [format ["%1 → %2.", toUpper (_row get "name"), toUpper _dest]] call _fnOK
    };

    case "spill": {
        _args params [["_rows", [], [[]]]];
        ([_rows] call AP_fnc_invSpill) params ["_gwh", "_n"];
        [_gwh, _n, _rows] call _fnNoteSpill;
        [format ["%1 ITEMS ON THE GROUND.", _n]] call _fnOK
    };

    default { ["UNKNOWN VERB."] call _fnNo };
}
