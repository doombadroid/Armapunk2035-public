params[["_shop", "", [""]], ["_purchase", false, [false]], ["_item", "", [""]]];
if (_shop isEqualTo "questBuffs") exitWith {private _discount =
    switch (true) do {default {0};}; _discount ;};
private _discount = 1;
_shop = toLower(_shop);

// ---- Armapunk 2035 cartel perks (core/config/fn_cartelCfg.sqf) --------------------------------
// Blacksite's "Discount on Illegal Items" needs no code here: blacksite_flag is aliased onto
// arms_flag, so the existing 15% rebel-shop discount below already IS that perk.
//
// Boomtown "Free Gas" returns EARLY and unclamped -- the civilian floor further down is 0.8 (20% off
// max), so a discount routed through the normal path could never reach free.
if (_purchase && {AP_effSide isEqualTo civilian}) then {
    private _myGang = AP_gang_data param [0, -1];
    private _fnOwns = {
        private _f = missionNamespace getVariable [_this, objNull];
        !isNull _f && {((_f getVariable ["AP_capData", [0, "Neutral", 0]]) param [0, -2]) isEqualTo _myGang}
            && {((_f getVariable ["AP_capData", [0, "Neutral", 0]]) param [2, 0]) >= 1}
    };
    if (_item isEqualTo "fuelF" && {"boomtown_flag" call _fnOwns}) exitWith { 0 };
    // Wreckridge: "Discount on Explosive Items"
    if (_item in ["demoCharge", "thermite", "breachkit", "phonebomb", "speedbomb", "ignitionbomb"]
        && {"wreckridge_flag" call _fnOwns}) then { _discount = _discount - 0.15; };
};

if (_purchase) then {if (3 in AP_achievements) then {_discount = _discount - 0.02;};
    if (AP_effSide isEqualTo civilian) then {
        if (_shop in ["rebelwep", "rebel", "rebcloth"] && {   // LooneyBin: arms cartel now discounts ALL rebel purchases (weapons + virtual items + clothing), not just weapons -- owning the Arms Dealer was only cutting rebelwep prices before.
            (arms_flag getVariable["AP_capData", [0, "Neutral", 0.5]] select 0) isEqualTo(AP_gang_data select 0)}) then {
            _discount = _discount - 0.15;};
        if (_shop isEqualTo "vehshop" && {14 in AP_side_talents}) then {_discount = _discount - 0.10;};
        if (_shop isEqualTo "rebel" && {1 in AP_gang_talents}) then {_discount = _discount - 0.10;};
        if (_shop isEqualTo "rebcloth" && {2 in AP_gang_talents}) then {_discount = _discount - 0.05;};
        if (_shop isEqualTo "rebelwep" && {3 in AP_gang_talents}) then {_discount = _discount - 0.05;};
        if (_shop isEqualTo "vehshop" && {(AP_veh_shop select 0) isEqualTo "reb_car" && 30 in AP_infamy_talents && license_civ_rebel
        }) then {_discount = _discount - 0.10;};
        _discount = selectMax[_discount, 0.8];};
    if (AP_effSide isEqualTo west) then {if (_shop in ["cop", "police_weapons", "police_equipment"] && {SRV_communityEvent param [1, false]
        }) then {_discount = 0.5};
        _discount = selectMax[_discount, 0.5];};
    if (AP_effSide isEqualTo independent) then {_discount;};} else {if (AP_effSide isEqualTo civilian) then {
        if (_shop in ["wongs", "heroin"] && {4 in AP_gang_talents}) then {_discount = _discount + 0.05;};
        if (_shop isEqualTo "heroin" && {5 in AP_gang_talents}) then {_discount = _discount + 0.02;};
        if (_shop isEqualTo "wongs" && {6 in AP_gang_talents}) then {_discount = _discount + 0.02;};
        // owner 2026-06-18: SRV_bustBonusActive is READ here but never SET anywhere (no server writer) -> every
        // shop discount calc threw "Undefined variable: srv_bustbonusactive" (recurring -SCRIPTERR-). Guard the
        // read with a false default so it can't error; if the bust-bonus EVENT is ever wired server-side
        // (publicVariable SRV_bustBonusActive), this picks it up automatically.
        if ((missionNamespace getVariable ["SRV_bustBonusActive", false]) && _shop in ["rebel", "wongs", "heroin", "fishmarket", "diamond", "salt", "commod", "blackmarket", "market", "turf"]) then {
            _discount = _discount + 0.12;};
        if (_shop in ["rebel", "wongs", "heroin"] && {26 in AP_infamy_talents && license_civ_rebel}) then {_discount = _discount + 0.07;
        };};
    if (AP_effSide isEqualTo west) then {_discount;};
    if (AP_effSide isEqualTo independent) then {_discount;};
    _discount = selectMax[_discount, 0.8];};
_discount;