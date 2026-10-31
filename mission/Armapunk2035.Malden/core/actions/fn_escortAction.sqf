params[["_unit", objNull, [objNull]]];
if !(isNull AP_escort) exitWith {["You can only escort one person at a time.", "basic"] spawn AP_fnc_handleMessage;};
// owner 2026-09-16: a player holds at most one of AP_escort / AP_dragging (fn_dragBody refuses the mirror case).
if !(isNull (missionNamespace getVariable ["AP_dragging", objNull])) exitWith {["You cannot escort someone while dragging a body.", "basic"] spawn AP_fnc_handleMessage;};
if (isNull _unit || {!isPlayer _unit} || {!(_unit isKindOf "CAManBase")}) exitWith {};
if !(_unit getVariable["AP_restrained", false]) exitWith {};
if (player distance2D[24973.1, 16740, 1] <= 25) exitWith {
    ["You can't escort people while in the courtroom", "basic"] spawn AP_fnc_handleMessage};
if (AP_passiveModeJIP) exitWith {
    ["You cannot escort people while in passive mode! You can disable it on your phone (Y).", "basic"] spawn AP_fnc_handleMessage;};
_unit attachTo[player, [0, 1, 0]];
_unit setVariable["AP_transporting", nil, true];
_unit setVariable["AP_escorting", true, true];
_unit setVariable["AP_escortee", player, true];
player setVariable["AP_escortObj", _unit];
AP_escort = _unit;
player reveal _unit;
if (AP_effSide isEqualTo civilian && isNil {_unit getVariable "AP_civRestrained"}) then {[
        [24, player], "APS_fnc_wantedAdd", 2] spawn AP_fnc_MP;};
// owner 2026-09-16 (body drag): also let go of an escortee who DIES. Their fn_onPlayerKilled clears AP_escorting,
// which makes fn_stopEscorting exit before its detach, so the corpse stayed welded to this player -- unrevivable
// (fn_revivePlayer's "being moved" gate) and blocking Drag Body -- until the escorter got into a vehicle.
// alive objNull is false, so the disconnect case still exits here as before.
[] spawn {waitUntil {!isNull objectParent player || {isNull AP_escort} || {!alive AP_escort}};
    if (!isNull objectParent player || {isNull attachedTo AP_escort} || {!alive AP_escort}) then {detach AP_escort;
        AP_escort setVariable["AP_escorting", false, true]};
    AP_escort = objNull;
    player setVariable["AP_escortObj", objNull];};