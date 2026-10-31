/*
    AP_fnc_animSync  (LooneyBin NEW 2026-06-09 -- was referenced by fn_boltcutter but never existed,
    so every boltcutter use threw a script error each anim re-assert.)
    [unit, animation] broadcast to all: plays the unit's action animation on remote machines so
    bystanders see the cutting/working pose (local machine already switchMoved).
*/
params [["_unit", objNull, [objNull]], ["_anim", "", [""]], ["_fallback", "", [""]]];
// owner 2026-09-20: a state from the OPTIONAL client mod (parkour wall-run clip) does not exist on a machine without
// it, and switchMove to an unknown state does nothing. The sender names the vanilla state to play there instead.
if (!(_fallback isEqualTo "") && {!(isClass (configFile >> "CfgMovesMaleSdr" >> "States" >> _anim))}) then {_anim = _fallback};
if (isNull _unit || {_anim isEqualTo ""}) exitWith {};
if (local _unit) exitWith {};   // owner already plays it
_unit switchMove _anim;
