/*
    AP_fnc_storageVaultRecv  (LooneyBin, owner 2026-07-11)
    Server -> client push for THE STORAGE WORKER (CfgRE allowedTargets=1). Receives the two panels the
    server built (APS_fnc_storageVaultSRV) and repaints the open dialog. Also caches them GLOBAL so the
    pack/unpack buttons can read the selected row's identifiers + weight.

    args: [ _slots, _houses, _status ]
        _slots  = [ [slot_id, label (house name/town), src_class, weight, ""], ... ]
        _houses = [ [oid, class, town, virtualWt, physWt, vcap, phys_cap, customName], ... ]
        _status = one-line result/notice ("" = just refreshed)
        _charge = fee to deduct NOW (>0 only after a confirmed PACK; server-authoritative)
*/
#define IDD_VAULT   515700
#define IDC_HOUSES  515710
#define IDC_SLOTS   515720
#define IDC_STATUS  515730

if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_slots", [], [[]]], ["_houses", [], [[]]], ["_status", "", [""]], ["_charge", 0, [0]]];
AP_vaultSlots  = _slots;
AP_vaultHouses = _houses;

private _disp = findDisplay IDD_VAULT;
if (isNull _disp) exitWith {};

// ── properties panel ──────────────────────────────────────────────────────────────────────────
private _hLb = _disp displayCtrl IDC_HOUSES;
lbClear _hLb; {_x params [["_oid", ""], ["_cls", ""], ["_town", ""], ["_vWt", 0], ["_pWt", 0], ["_vcap", 0], ["_pcap", 0], ["_cname", ""]];
    private _wt  = round ((_vWt + _pWt) max 0);
    private _cap = round ((_vcap + _pcap) max 0);
    // player-set name when there is one (houses.custom_name), else the default type label
    private _name = if (_cname isNotEqualTo "" && {_cname isNotEqualTo "NULL"}) then { _cname } else { [_cls] call AP_fnc_vaultClassLabel };
    private _i = _hLb lbAdd (format ["%1 - %2  (%3/%4 wt)", _name, _town, _wt, _cap]);
    _hLb lbSetData [_i, _oid];
    if (_wt <= 0) then { _hLb lbSetColor [_i, [0.537, 0.576, 0.627, 1]]; };   // muted when empty
} forEach _houses;

// ── vault panel ─────────────────────────────────────────────────────────────────────────────────
private _sLb = _disp displayCtrl IDC_SLOTS;
lbClear _sLb; {_x params [["_sid", -1], ["_lab", ""], ["_sc", ""], ["_wt", 0], ["_dt", ""]];
    private _typeLbl = [_sc] call AP_fnc_vaultClassLabel;
    private _i = _sLb lbAdd (format ["%1 - %2  (%3 wt)", _lab, _typeLbl, round _wt]);
    _sLb lbSetData [_i, str _sid];} forEach _slots;

// ── status / hint ────────────────────────────────────────────────────────────────────────────
private _txt = if (_status isNotEqualTo "") then {format ["<t color='#37e8f0' size='0.9'>%1</t>", _status]} else {
    if (_slots isEqualTo [] && {_houses isEqualTo []}) then {"<t color='#8993a0' size='0.9'>You don't own any property yet.</t>"} else {
        "<t color='#8993a0' size='0.9'>Pack a property into the vault, or unpack a slot into another property you own.</t>"};};
(_disp displayCtrl IDC_STATUS) ctrlSetStructuredText parseText _txt;

// server-confirmed pack fee -> deduct now (cash first, else bank; the fn_upgradeProperty idiom)
if (_charge > 0) then {if (AP_cash >= _charge) then {AP_cash = AP_cash - _charge;
        AP_cashCacheB = ((AP_cash / 4) + 9);} else {AP_atmcash = AP_atmcash - _charge;
        AP_atmcashCacheB = ((AP_atmcash / 4) + 11);};
    [6] call AP_fnc_ClupdatePartial;};
["cash"] call AP_fnc_storageVault;
