if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_class", "", [""]], ["_qty", 1, [0]]];
/*
    AP_fnc_fabGiveGear -- hand the player a PHYSICAL printed item (weapon, vest, optic, backpack).

    The server calls this only from APS_fnc_fabSRV's collect arm, after it has already cleared the
    job row and proved the clear committed. Virtual items never come through here -- those go
    through AP_fnc_handleInv, the inventory chokepoint.

    Physical gear cannot be granted from the server directly: weapons, vests and backpacks live in
    the player's own containers, which only their machine can write. So the grant crosses the wire
    and lands here. That means a modified client can decline delivery -- it cannot mint anything
    (the job is already spent server-side and the recipe was validated there), it can only throw
    away its own item, which is a loss it inflicts on itself.
*/
if (!hasInterface || {_class isEqualTo ""}) exitWith {};
_qty = (round _qty) max 1;

private _ok = 0;
for "_i" from 1 to _qty do {
    private _done = switch (true) do {
        case (isClass (configFile >> "CfgWeapons" >> _class)): {
            // Vests, uniforms, goggles and headgear are CfgWeapons too, so route by ItemInfo type
            // rather than by "is it in CfgWeapons" -- addWeapon on a vest silently does nothing.
            // ItemInfo type, not "is it in CfgWeapons" -- vests, uniforms, headgear and optics all
            // live there too, and addWeapon on a vest silently does nothing at all.
            private _t = getNumber (configFile >> "CfgWeapons" >> _class >> "ItemInfo" >> "type");
            // Every arm ends in a Boolean. addItemToBackpack / addItem return NOTHING, so the arms that used
            // them left _done undefined: the script died on line 49, the item was neither given nor dropped,
            // and the job was already spent (a pair of jeans, 2026-09-03). They also never checked for room.
            private _toPack = {
                if (player canAddItemToBackpack _class) then { player addItemToBackpack _class; true } else { false }
            };
            switch (true) do {
                case (_t isEqualTo 701): { if (vest player isEqualTo "") then { player addVest _class; true } else { call _toPack } };
                case (_t isEqualTo 801): { if (uniform player isEqualTo "") then { player addUniform _class; true } else { call _toPack } };
                case (_t isEqualTo 605): { if (headgear player isEqualTo "") then { player addHeadgear _class; true } else { call _toPack } };
                case (_t isEqualTo 616): { if (goggles player isEqualTo "") then { player addGoggles _class; true } else { call _toPack } };
                // Optics, muzzles, bipods, tools. SQF `switch` has no fall-through -- `case 101; case 201:`
                // is not valid here -- so these share one arm through `in`.
                case (_t in [101, 201, 301, 302, 303]): { if (player canAdd _class) then { player addItem _class; true } else { false } };
                default { player addWeapon _class; true };
            };
        };
        case (isClass (configFile >> "CfgMagazines" >> _class)): { player addMagazine _class; true };
        case (isClass (configFile >> "CfgVehicles" >> _class)): {
            if (backpack player isEqualTo "") then { player addBackpack _class; true }
            else { false };
        };
        default { false };
    };
    if (_done isEqualTo true) then { _ok = _ok + 1 };
};

if (_ok < _qty) then {
    // Say so rather than swallowing it: the job is already spent, so a player who cannot see what
    // happened would read the missing items as the printer eating their materials.
    [format ["No room for %1 of %2 -- dropped where you stand.", _qty - _ok, _class], "basic"] spawn AP_fnc_handleMessage;
    private _pos = getPosATL player;
    for "_i" from 1 to (_qty - _ok) do {
        private _wh = createVehicle ["GroundWeaponHolder", _pos, [], 1, "CAN_COLLIDE"];
        if (isClass (configFile >> "CfgMagazines" >> _class)) then { _wh addMagazineCargoGlobal [_class, 1]; }
        else { if (isClass (configFile >> "CfgVehicles" >> _class)) then { _wh addBackpackCargoGlobal [_class, 1]; }
               else { _wh addItemCargoGlobal [_class, 1]; }; };
    };
};
