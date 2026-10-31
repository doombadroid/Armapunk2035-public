/*
    custom_p3ds\replace_sheds.sqf   (LooneyBin Altis)
    Owner 2026-07-03: swap every DERELICT industrial shed (Land_u_Shed_Ind_F, a map/terrain
    object -- damage 0, the "broken" look is baked into the model) for an INTACT, buyable one
    (Land_i_Shed_Ind_F, already a House in fn_houseConfig -> $200k / up to 3000 storage).

    WHY SERVER-ONLY:
      - hideObjectGlobal on a TERRAIN object only takes (and JIP-persists) when run on the
        SERVER -- a client debug-console call no-ops (confirmed live). Same idiom the mission
        already uses to hide the loony-bin gates in fn_loonyBinSRV.sqf.
      - createVehicle is a GLOBAL command -> one server-side spawn replicates to every client
        + JIP. (custom_p3ds\load.sqf uses createSimpleObject with local=true -- different
        tool, decoration only, no doors. A buyable House must be a real createVehicle object.
        NB createSimpleObject is only local when you pass that third argument; it defaults to
        GLOBAL since Arma 3 1.96.)

    PERSISTENCE: housing is POSITION-keyed (str getPosATL). The intact shed is spawned at the
    broken shed's exact transform; the terrain is identical every boot, so the same 40 sheds
    land at the same spots every restart -> owned-house lookups keep matching. No baked list.

    Idempotent: AP_shedsReplaced guard -> can never run twice (no stacking).
*/
if (!isServer) exitWith {};
if (missionNamespace getVariable ["AP_shedsReplaced", false]) exitWith {};
AP_shedsReplaced = true;

[] spawn {uiSleep 6;   // let the world/terrain settle before querying + spawning (mirrors load.sqf)

    private _broken = nearestObjects [[15000, 15000, 0], ["Land_u_Shed_Ind_F"], 22000];
    private _done = 0;
    private _hidOK = 0;
 {private _shed = _x;
        // capture the transform BEFORE hiding (hide doesn't move it, but be explicit)
        private _pos = getPosASL _shed;
        private _vd  = vectorDir _shed;
        private _vu  = vectorUp  _shed;

        // clear the broken shed (server-side hide + kill its sim/collision so the new shed
        // has nothing to fight -> no PhysX overlap, no frame drop)
        _shed hideObjectGlobal true;
        _shed enableSimulationGlobal false;
        if (isObjectHidden _shed) then { _hidOK = _hidOK + 1; };
        // BANISH the derelict off the spot. Housing is POSITION-keyed: a hidden u_shed left at _pos still
        // answers nearestObjects["House"], so a buyer's ownership (bought via cursorObject = the intact
        // spawn) can bind to the DERELICT instead (owner 2026-07-04: Jeff owned a Land_u_Shed at a
        // fixed-shed spot). deleteVehicle can't remove a terrain object, but setPos CAN move it. Park all
        // of them in the SW ocean corner, underground; enableSimulationGlobal false above keeps it there.
        _shed setPosASL [1, 1, -80];

        // drop the intact, buyable shed into the cleared spot at the same transform
        private _new = createVehicle ["Land_i_Shed_Ind_F", ASLToATL _pos, [], 0, "CAN_COLLIDE"];
        _new setPosASL _pos;
        _new setVectorDirAndUp [_vd, _vu];
        // exempt from the server-side ownerless-object reap (fn_cleanup deletes world objects
        // with no "owner" var) -- same guard custom_p3ds\load.sqf uses.
        _new setVariable ["owner", "AP_customBuilding", true];

        _done = _done + 1;} forEach _broken;

    diag_log format [
        "[LB-SHEDS] replaced %1/%2 broken sheds (Land_u_Shed_Ind_F -> buyable Land_i_Shed_Ind_F); server-hide confirmed on %3",
        _done, count _broken, _hidOK];

    // owner 2026-07-10: tag house ownership NOW. fn_receiveHouses (the boot tagger) ran BEFORE these sheds
    // existed, and the init.sqf houseTax re-tag doesn't fire until ~+5 min (scheduler runAtStart=false) -- so
    // every owned shed spent the first 5 minutes of each restart untagged: House Menu offered to SELL you your
    // own shed, the keychain missed it, and renames were refused (AP_houseID=-1) or silently un-applied.
    // The sheds exist as of this line, so run the extracted tag pass immediately (it stamps ownership, oid,
    // keys, caps, lock state AND custom_name/AP_houseName for every DB house, sheds included).
    private _tagged = call APS_fnc_tagHousesSRV;
    diag_log format ["[LB-SHEDS] immediate post-spawn house tag pass: %1 house(s) tagged", _tagged];};
