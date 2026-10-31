params["_obj_main", "_stance"];
// owner 2026-06-15: de-brand the cop BOUNTY NPC -- it wore the bare stock uniform (the stock upstream cop
// look). Was an empty CAManBase block. The 2026-06-15 fix was a sgt_grumpy MaxSec retexture; SUPERSEDED
// the next day (below) and the skin itself was deleted 2026-08-13, so no texture is applied here.
if (_obj_main isKindOf "CAManBase") then {
    // owner 2026-06-16: strip the uniform instead (naked) -- U_Rangemaster IS the stock cop look, so the
    // retexture added nothing over it. The de-brand is the strip, nothing else.
    // owner 2026-07-10: SKIP when the map data dressed this NPC with a custom
    // loadout (Eden round-trip, fn_createVehicleLocal tags AP_hasLoadout) -- stripping undid the outfit.
    if !(_obj_main getVariable ["AP_hasLoadout", false]) then { removeUniform _obj_main; };};
_obj_main addAction["Track Fugitive", {[] call AP_fnc_requestBounty
}, false, 1.5, false, false, "", 'AP_effSide isEqualTo west && AP_copRole in ["warrant","all"]', 5];