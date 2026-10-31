/*
    File: fn_handleLicense.sqf  (AP_fnc_handleLicense)
    Grant a licence to THIS client and persist it. Called server -> client via
    AP_fnc_MP from AP_fnc_aqGrantLicense (core/quests/fn_aqProfile.sqf) --
    CfgRE.hpp whitelists it allowedTargets=1.

    This mission had no grant primitive: licences are client variables
    (license_<side>_<name>, side one of civ/cop/med -- confirmed against
    core/actions/fn_buyLicense.sqf), and fn_buyLicense sets them inline as
    part of the purchase flow. ArmaQuest's profile needs a grant that is not a
    purchase, so this is it: the smallest function that sets the variable --
    branched on the CALLING player's own current side, since this runs on the
    target player's own machine and AP_effSide is meaningful there, the same
    way fn_buyLicense and fn_ClupdatePartial's own side-flag switches are --
    and puts it through the existing save path.

    Persistence is ClupdatePartial mode 2, which is the case that walks
    AP_licenses and saves the ones matching the player's side
    (core/session/fn_ClupdatePartial.sqf).
*/
params [["_lic", "", [""]]];
// CALLER GUARD -- same reasoning as core/functions/fn_handleInv.sqf: this is
// remoteExec-able (CfgRE.hpp, allowedTargets = 1), and allowedTargets limits the
// TARGET of a call, never its ORIGIN. 0 = ordinary local call, 2 = dispatched by
// the server; anything else is another client granting licences on this machine.
if (!(remoteExecutedOwner in [0, 2])) exitWith {};
if (!hasInterface) exitWith { false };
if (_lic isEqualTo "") exitWith { false };
private _sideTag = switch (AP_effSide) do { case west: {"cop"}; case independent: {"med"}; default {"civ"} };
private _var = format ["license_%1_%2", _sideTag, _lic];
missionNamespace setVariable [_var, true];
[2] call AP_fnc_ClupdatePartial;
true
