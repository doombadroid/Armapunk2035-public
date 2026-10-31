/*
    AP_fnc_priceOv  (LooneyBin Economy, owner request 2026-06-11)
    Returns the live price-override row for an item, or [] if none.
      [_family, _key] call AP_fnc_priceOv  ->  [family, key, p0, p1, p2]  |  []
    Families + slot meaning:
      "virt"  p0=base(buy)  p1=lowest(sell)  p2=max(market)
      "weap"  p0=price
      "veh"   p0=buy        p1=garage sell-back
      "cloth" p0=price
    A slot of -1 means "leave the hardcoded config value for that slot".
    AP_priceOv (server-owned, publicVariable'd) is a flat array of these rows; overrides are few
    (only items the owner has touched) so a linear findIf is cheaper than maintaining a hashmap.
*/
params [["_family", "", [""]], ["_key", "", [""]]];
if (_family isEqualTo "" || {_key isEqualTo ""}) exitWith { [] };
// ON THE SERVER, READ THE SERVER'S OWN LIST (audit Lsec-0-1). APS_fnc_srvSellVehicle and APS_fnc_chopShopSell
// price sell-back through here, and AP_priceOv in missionNamespace is the published copy any client can
// publicVariable over; APS_fnc_economySRV keeps the authoritative one in localNamespace.
private _ov = if (isServer) then { localNamespace getVariable ["AP_priceOv", []] } else { missionNamespace getVariable ["AP_priceOv", []] };
if !(_ov isEqualType []) exitWith { [] };
private _i = _ov findIf { ((_x select 0) isEqualTo _family) && {(_x select 1) isEqualTo _key} };
if (_i isEqualTo -1) exitWith { [] };
_ov select _i
