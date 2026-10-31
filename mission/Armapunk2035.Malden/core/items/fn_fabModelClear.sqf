if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_anchor", objNull, [objNull]]];
/*
    AP_fnc_fabModelClear -- delete a fabricator's client-local visual before its anchor goes.

    Needed because the model is a client-local simple object, not a networked one: deleting the
    anchor on the server removes the anchor everywhere but leaves each client holding an orphaned
    p3d that is attached to nothing and will sit in the world until the mission ends. The mining
    rig avoids this by making every piece a real networked object; a client-local visual has to be
    told to go. A multi-part machine is the body plus every part in AP_fabParts; clearing
    AP_fabModel is also what ends that machine's AP_fnc_fabAnim loop.
*/
if (isNull _anchor) exitWith {};
if (!hasInterface) exitWith {};
private _o = _anchor getVariable ["AP_fabModel", objNull];
if (!isNull _o) then { detach _o; deleteVehicle _o; };
{
    _y params [["_p", objNull]];
    if (!isNull _p) then { detach _p; deleteVehicle _p; };
} forEach (_anchor getVariable ["AP_fabParts", createHashMap]);
_anchor setVariable ["AP_fabModel", nil];
_anchor setVariable ["AP_fabParts", nil];
_anchor setVariable ["AP_fabSpec", nil];
