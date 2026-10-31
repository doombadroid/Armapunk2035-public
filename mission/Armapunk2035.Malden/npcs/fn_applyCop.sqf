params["_obj_main", "_stance"];
if (_obj_main isKindOf "CAManBase") then {
    // LoonyBin (owner 2026-06-13): cop NPCs were put in the "SGT Grumpy" MaxSec rank uniform (was MaxTac
    // combat uniform). SUPERSEDED owner 2026-06-16: strip the uniform instead (naked) -- U_Rangemaster IS
    // the stock cop look, so the retexture added nothing over it. No texture is set here.
    // owner 2026-07-10: SKIP when the map data dressed this NPC with a custom
    // loadout (Eden round-trip, fn_createVehicleLocal tags AP_hasLoadout) -- stripping undid the outfit.
    // 2026-08-13: the MaxSec custom skins were deleted repo-wide; this line only strips, so it is unaffected.
    if !(_obj_main getVariable ["AP_hasLoadout", false]) then { removeUniform _obj_main; };};
_obj_main addAction["Join the Police", AP_fnc_policeRecruit, "", 1.5, false, false, "", ' AP_effSide isEqualTo civilian ', 5];