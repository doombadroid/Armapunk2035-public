/*
    AP_fnc_storageVault  (LooneyBin, owner 2026-07-11)
    THE STORAGE WORKER dialog -- client side. A player-owned holding vault: for a per-weight fee the worker
    PACKS a whole house's storage into a vault slot, and later UNPACKS a slot into a DIFFERENT house (partial
    fill -- overflow stays in the vault). You can't browse the vault; it's a transfer buffer only. Also the
    planned cross-map migration point.

    Server does every authoritative move (APS_fnc_storageVaultSRV) and pushes both panels back via
    AP_fnc_storageVaultRecv. This fn only opens the Night City dialog, charges the fee locally (the standard
    purchase idiom -- the fee is a sink), and relays pack/unpack requests.

    Actions (button onButtonClick / open call):
        []          / ["open"]     open the dialog + request the current state
        ["pack"]                   confirm + charge + pack the SELECTED house into a new slot
        ["unpack"]                 unpack the SELECTED slot into the SELECTED house
*/
#define VAULT_RATE   10         // $ per unit of stored weight to pack a house
#define IDD_VAULT    515700
#define IDC_HOUSES   515710
#define IDC_SLOTS    515720
#define IDC_STATUS   515730
#define IDC_CASH     515740
#define IDC_PACKLBL  515741

params [["_action", "open", [""]]];

// ── OPEN ────────────────────────────────────────────────────────────────────────────────────────
if (_action isEqualTo "open") exitWith {if (!isNull findDisplay IDD_VAULT) exitWith {};
    AP_vaultHouses = [];
    AP_vaultSlots  = [];
    if (!createDialog "AP_StorageVault") exitWith {};
    ["cash"] call AP_fnc_storageVault;
    [["list", player], "APS_fnc_storageVaultSRV", 2] call AP_fnc_MP;};

private _disp = findDisplay IDD_VAULT;
if (isNull _disp) exitWith {};

// ── refresh the cash readout ─────────────────────────────────────────────────────────────────────
if (_action isEqualTo "cash") exitWith {
    (_disp displayCtrl IDC_CASH) ctrlSetText format ["$%1", [(AP_cash + AP_atmcash)] call AP_fnc_numberText];};

// ── PACK the selected house ──────────────────────────────────────────────────────────────────────
if (_action isEqualTo "pack") exitWith {private _lb  = _disp displayCtrl IDC_HOUSES;
    private _sel = lbCurSel _lb;
    if (_sel < 0) exitWith { ["Pick one of your properties to pack up first.", "basic"] spawn AP_fnc_handleMessage; };
    private _h = AP_vaultHouses param [_sel, []];
    if (_h isEqualTo []) exitWith {};
    _h params ["_oid", "_cls", "_town", "_vWt", "_pWt", "_vcap", "_pcap", ["_cname", ""]];
    private _wt  = round ((_vWt + _pWt) max 0);
    if (_wt <= 0) exitWith { ["That property's storage is empty.", "basic"] spawn AP_fnc_handleMessage; };
    private _fee = round (_wt * VAULT_RATE);
    if (_fee > AP_cash && {_fee > AP_atmcash}) exitWith {
        [format ["Packing that up costs $%1 and you can't cover it.", [_fee] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
    };
    private _name = if (_cname isNotEqualTo "" && {_cname isNotEqualTo "NULL"}) then { _cname } else { [_cls] call AP_fnc_vaultClassLabel };
    private _ok = [
        format ["Move everything from %1 (%2, %3 wt) into the vault for $%4?<br/><br/>You won't be able to take items out of the vault directly, but you can drop it all into another house you own later.",
            _name, _town, _wt, [_fee] call AP_fnc_numberText],"Storage Worker", "Pack it", "Cancel"] call BIS_fnc_guiMessage;
    if (!_ok) exitWith {};
    // re-check funds at confirm time, but DON'T deduct here -- the server confirms the pack and echoes the
    // authoritative fee back via AP_fnc_storageVaultRecv, which does the deduction. That way a refused pack
    // (house open / not owner / already empty) never costs the player money.
    if (_fee > AP_cash && {_fee > AP_atmcash}) exitWith { ["You can't cover the fee.", "basic"] spawn AP_fnc_handleMessage; };
    [["pack", player, _oid], "APS_fnc_storageVaultSRV", 2] call AP_fnc_MP;
    (_disp displayCtrl IDC_STATUS) ctrlSetStructuredText parseText "<t color='#8993a0'>Working...</t>";};

// ── UNPACK the selected slot into the selected house ─────────────────────────────────────────────
if (_action isEqualTo "unpack") exitWith {private _slotLb = _disp displayCtrl IDC_SLOTS;
    private _hLb    = _disp displayCtrl IDC_HOUSES;
    private _si = lbCurSel _slotLb;
    private _hi = lbCurSel _hLb;
    if (_si < 0) exitWith { ["Pick a vault slot to unpack.", "basic"] spawn AP_fnc_handleMessage; };
    if (_hi < 0) exitWith { ["Pick which of your properties to unpack it into.", "basic"] spawn AP_fnc_handleMessage; };
    private _slot = AP_vaultSlots  param [_si, []];
    private _h    = AP_vaultHouses param [_hi, []];
    if (_slot isEqualTo [] || {_h isEqualTo []}) exitWith {};
    private _slotId = _slot param [0, -1];
    private _oid    = _h    param [0, ""];
    [["unpack", player, _slotId, _oid], "APS_fnc_storageVaultSRV", 2] call AP_fnc_MP;
    (_disp displayCtrl IDC_STATUS) ctrlSetStructuredText parseText "<t color='#8993a0'>Working...</t>";};
