params[["_unit", objNull, [objNull]], "_weapon", "_muzzle", "_mode", ["_ammo", "", [""]], "_magazine", ["_projectile", objNull, [objNull]], "_vehicle"];
// medics normally can't fire projectiles -> EXEMPT the AEMT+ green medic P07 (heal/taser gun) so its rounds reach the target
if ((side _unit isEqualTo independent) && !("Chem" in _ammo || "Smoke" in _ammo) && !((_weapon isEqualTo "hgun_P07_khk_F") && ((call AP_medicLevel) >= 3)) && !((call AP_medicLevel) >= 1 && (call AP_medicLevel) <= 7) && ((call AP_adminLevel) <= 2)) then {
    deleteVehicle _projectile;};
if ((_unit getVariable["AP_restrained", false]) || (_unit getVariable["AP_civRestrained", false]) || (_unit getVariable["AP_downed", false]) || AP_passiveModeJIP) then {
    deleteVehicle _projectile;};
if ((_unit inArea "graveyardshift1") && ((AP_adminEvent select 2) isEqualTo 4)) then {deleteVehicle _projectile;
    [true] spawn AP_fnc_holsterWeapon;
    50 cutText["The 2020 LoonyBin Halloween event has strict security stopping you from doing that!", "PLAIN", 1];};
if ((primaryWeapon player != "arifle_sdar_F") && {((player modelToWorld(player selectionPosition "leftuplegroll")) select 2) < -0.35
}) exitWith {deleteVehicle _projectile;};
// owner 2026-06-25: BLOCK firing from the armed Gryphon jet + Marshall APC (both player-buyable as transport/show
// vehicles). The old check compared the EH's gunner OBJECT (_vehicle = param 7 -- the params line omits the gunner
// slot, so it's mis-mapped) to a STRING with isEqualTo -> ALWAYS false -> the block NEVER fired and anyone in those
// vehicles could shoot. Use vehicle _unit + typeOf (the unambiguous current-vehicle class).
if (typeOf (vehicle _unit) in ["I_Plane_Fighter_04_F", "O_APC_Wheeled_02_rcws_v2_F"]) exitWith {deleteVehicle _projectile;};
if (_unit distance2D(getMarkerPos "courtroom") < 150) exitWith {deleteVehicle _projectile;
    50 cutText["The Court room has strict security, stopping you from doing that!", "PLAIN", 1];};
