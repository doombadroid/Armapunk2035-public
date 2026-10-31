params [["_unit", player, [objNull]]];
// Single source of truth for "is this unit's healing currently suppressed?".
// Stored as a PUBLIC object variable, not a missionNamespace one: a medic healing
// someone else runs setDamage on THEIR OWN client, so the gate has to be readable
// from any machine. Mirrors the existing AP_can_revive pattern.
private _until = _unit getVariable ["AP_healBlock", 0];
if (_until <= time) exitWith { false };
true
