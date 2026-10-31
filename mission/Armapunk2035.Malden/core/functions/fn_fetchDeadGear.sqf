params[["_unit", objNull, [objNull]]];
if (isNull _unit) exitWith {};
private _primitems = [];
private _secitems = [];
private _handgunitems = [];
private _primary =
if (AP_primaryWeaponOnDeath isEqualTo[]) then {primaryWeapon _unit} else {AP_primaryWeaponOnDeath param[0, ""]};
private _launcher = secondaryWeapon _unit;
if (_launcher != "") then {
    _secitems = (secondaryWeaponItems _unit) select { _x != "" };   // LooneyBin 2026-06-10: launcher attachments were never captured
};
private _handgun = handGunWeapon _unit;
private _magazines = magazinesAmmo _unit;
private _uniform = uniform _unit;
private _vest = vest _unit;
private _backpack = backpack _unit;
private _items = assignedItems _unit;
private _primitems =
if (AP_primaryWeaponOnDeath isEqualTo[]) then {
    (primaryWeaponItems _unit) select {_x != ""}   // LooneyBin: was [] -> primary attachments (suppressor/optic/pointer/bipod) were NEVER captured, so death->revive (loadDeadGear) restored a bare weapon. Capture the real attachments now.
} else {AP_primaryWeaponOnDeath param[1, []]};
if (handgunWeapon _unit != "") then {_handgunItems = handgunItems _unit;};
private _headgear = headgear _unit;
private _goggles = goggles _unit;
private _uitems = [];
private _vitems = [];
private _bitems = [];
if (_uniform != "") then {_uitems = (uniformItems _unit) select {!(_x in magazines _unit)};};
if (_vest != "") then {_vitems = (vestItems _unit) select {!(_x in magazines _unit)};};
if (_backpack != "") then {_bitems = (backPackItems _unit) select {!(_x in magazines _unit)};};
if (primaryWeapon _unit != "" && count(primaryWeaponMagazine _unit) > 0) then {
    _magazines pushBack[(primaryWeaponMagazine _unit) select 0, _unit ammo primaryWeapon _unit];};
if (secondaryWeapon _unit != "" && count(secondaryWeaponMagazine _unit) > 0) then {
    _magazines pushBack((secondaryWeaponMagazine _unit) select 0);};
if (handgunWeapon _unit != "" && count(handgunMagazine _unit) > 0) then {
    _magazines pushBack[(handgunMagazine _unit) select 0, _unit ammo handgunWeapon _unit];};
if (isNil "_handgunItems") then {_handgunItems = ["", "", ""];};
[_primary, _launcher, _handgun, _magazines, _uniform, _vest, _backpack, _items, _primitems, _secitems, _handgunitems, _uitems, _vitems, _bitems, _headgear, _goggles];