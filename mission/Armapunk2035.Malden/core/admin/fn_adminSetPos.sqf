// owner 2026-06-14: SET POS -- teleport SELF (arg true) or the SELECTED player to the coords in the SET POS
// box (idc 12929). owner 2026-07-11: HARDENED -- the box DEFAULTS to "[0, 0, 0]", so any accidental fire
// (a mis-click landing here instead of GET POS, an un-filled box) teleported the admin to [0,0,0] = DEBUG
// ISLAND. Refuse an empty / malformed / origin position outright; a real teleport always fills the box first.
params[["_self", true, [true]]];
if ((call AP_adminLevel) <= 1) exitWith {closeDialog 0;};
private _plb_pos = parseSimpleArray(ctrlText 12929);
if (isNil "_plb_pos" || {!(_plb_pos isEqualType [])} || {count _plb_pos < 2} || {!((_plb_pos param [0, ""]) isEqualType 0)} || {!((_plb_pos param [1, ""]) isEqualType 0)}) exitWith {
    ["SET POS: the position box isn't a valid [x, y, z]. Click GET POS first (or paste real coords).", "basic"] spawn AP_fnc_handleMessage;
};
if (((_plb_pos select 0) < 1) && {(_plb_pos select 1) < 1}) exitWith {
    ["SET POS: refusing to teleport to [0, 0, 0] (debug island). Fill the box with a real position first.", "basic"] spawn AP_fnc_handleMessage;
};
if (_self) then {player setPosATL _plb_pos;} else {if ((lbCurSel 12901) isEqualTo - 1) exitWith {
        ["You did not select a player.", "basic"] spawn AP_fnc_handleMessage;};
    private _unit = lbData[12901, lbCurSel 12901];
    _unit = missionNamespace getVariable _unit;
    if (isNull _unit) exitWith { ["That player is no longer online.", "basic"] spawn AP_fnc_handleMessage; };
    _unit setPosATL _plb_pos;};
