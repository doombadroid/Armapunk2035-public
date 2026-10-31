/*
    APS_fnc_srvSellHouse  (LooneyBin) -- sell a house back to the bank. Runs on the SERVER.
    2020 client args: [_house, _player]   (fn_sellHouse)

    Was a broken passthrough: `_this call DB_fnc_deleteHouse` fed deleteHouse `[_house, _player]`,
    but it reads arg0 as the oid and arg1 as the house -> it operated on the PLAYER as the house
    (getPos player / getBuildID player) -> wrong/no DB row deleted, and nothing ever told the seller's
    client to finalise -> "houses can't be sold" (txn hung: no money, house stayed, AP_houseTxn stuck).

    Now: delete the row by the house's oid (= AP_houseID, the unique key addHouse REPLACE'd on / receiveHouses
    loads), drop it from the server ownership list, then call AP_fnc_handleHouse mode 2 on the seller --
    which pays the sell price, removes it from AP_houses/AP_vehicles, deletes the marker, clears the
    house vars, and resets AP_houseTxn / AP_action_in_use.
*/
params [["_house", objNull, [objNull]], ["_player", objNull, [objNull]]];
if (isNull _house || isNull _player) exitWith {};

// owner 2026-09-26 SECURITY (audit TONd-0-2 / AUDIT A13): there was NO caller or ownership check -- any client
// could pass ANY house plus its own player and the server deleted the victim's row (storage/upgrades/keys),
// despawned their rigs, cleared their gang HQ, then paid the ATTACKER the sell price (mode 2). Now the seller
// is the NON-SPOOFABLE caller and must be the owner on the houses ROW (APS_fnc_houseRights), checked before
// anything is touched; the DELETEs below also carry `AND owners=<seller>` so no other player's row can go.
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
if (_src isNotEqualTo 0) then { _player = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull]; };
if (isNull _player) exitWith {};
private _uid = getPlayerUID _player;
private _rights = [_house, _player] call APS_fnc_houseRights;
if ((_rights select 1) isEqualTo "" || {(_rights select 1) isNotEqualTo _uid}) exitWith {
    ["-SEC-", _player, format ["BLOCKED srvSellHouse (not the owner) oid=%1 owner=%2 by %3", _rights select 0, _rights select 1, _uid]] call APS_fnc_logIt;
    // release the seller's txn lock + the sale lock fn_sellHouse set, or a legit-but-unregistered sale hangs
    AP_houseTxn = false; (owner _player) publicVariableClient "AP_houseTxn"; AP_action_in_use = false; (owner _player) publicVariableClient "AP_action_in_use";
    [_house] spawn { params ["_h"]; uiSleep 5; if (!isNull _h) then { _h setVariable ["AP_house_sold", nil, true]; }; };
};

// owner 2026-07-11 (Malden Makeover): a sale ends the makeover -- restore the original building BEFORE the
// row goes away (the swap registry is keyed by AP_houseID). revert DELETES the shell _house points at and
// returns the restored original -- continue the sale on THAT (getPosWorld objNull would derive posOid
// "00" and the row DELETE below would miss). No-op for non-maldened houses.
if (_house getVariable ["AP_malden", false]) then {localNamespace setVariable ["APS_maldenRevertOk", _house];   // one-shot token (fn_maldenSRV revert)
    private _restored = ["revert", _house, _rights select 0] call APS_fnc_maldenSRV;
    if (!isNull _restored) then { _house = _restored; };};

// owner 2026-06-17 (#318): the DELETE was gated on AP_houseID, which is ""/-1 whenever the boot ownership
// re-tag hasn't stamped the object (the #305/#307 timing). When empty, the sell PAID the seller and cleared
// their client (mode 2 below) but the DB row SURVIVED with owners=seller -> the shed read "already owned"
// forever and nobody could re-buy it (addHouse's theft pre-check refunded every buyer = the #318 report).
// The oid is deterministic from the house POSITION (the same getPosWorld hash addHouse builds), so derive it
// here and ALWAYS delete by it -- plus by AP_houseID too if it's a valid, different value (legacy oids).
private _oid = _house getVariable ["AP_houseID", ""];
private _p = getPosWorld _house;
private _posOid = format ["%1%2", round (_p select 0), round (_p select 1)];
// owner 2026-09-26 (houses review): NOT AP_houseID -- it is client-writable and _delIds also drives the rig despawn +
// house_rigs DELETE below (no owner filter there), so a forged tag on your own house wiped a victim's rigs on your sale.
private _delIds = [_posOid];
_delIds pushBackUnique (_rights select 0);   // the row the ownership check read (e.g. a Malden shell's / legacy oid)
{ ["DELETE FROM houses WHERE oid = %s AND owners = %s", 1, false, [_x, _uid]] call DB_fnc_asyncQuery; } forEach _delIds;

// owner 2026-07-22 (multi-rig): a sale takes any placed mining rigs with it -- despawn the compositions
// and drop their house_rigs rows, else the orphaned rows respawn rigs in a house the seller no longer
// owns at next boot. No auto-collect/refund: pack rigs up BEFORE selling (delete refunds the item).
private _rigs = localNamespace getVariable "APS_cryptoRigs";   // miningSRV's server-only registry (a client can't publicVariable it)
if (!isNil "_rigs") then {private _gone = 0; {private _rid = _x; private _rec = _y;
        if ((format ["%1", _rec param [3, ""]]) in _delIds) then {
            { if (!isNull _x) then { deleteVehicle _x; }; } forEach (_rec param [2, []]);
            _rigs deleteAt _rid;
            _gone = _gone + 1;};} forEach +_rigs;
    if (_gone > 0) then {{ ["DELETE FROM house_rigs WHERE oid = %s", 1, false, [_x]] call DB_fnc_asyncQuery; } forEach _delIds;
        [[format ["%1 mining rig%2 went with the house -- pack rigs up before selling next time.", _gone, ["s",""] select (_gone == 1)], "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
        ["-MINING-", _player, name _player, format ["sold house %1 with %2 rig(s) inside (forfeited)", _delIds param [0, ""], _gone]] call APS_fnc_logIt;
    };};

// owner 2026-06-21: if the sold house IS a gang house, CLEAR that gang's house_pos. Otherwise the gang HQ lingers
// pointing at a house someone else now owns (the reported bug: a leader sold their gang house ages ago and it
// stayed the gang HQ -> stale marker/spawn). AP_house_gang = the gang id tagged on the building by the boot
// re-tag (init.sqf gang-house block). Untag the object too so a later re-tag pass doesn't re-stamp it.
// owner 2026-09-26: the gang now comes from gangs.house_pos (APS_fnc_houseRights), not the client-writable
// AP_house_gang tag -- a forged tag on your own house cleared ANY gang's HQ (and went into the SQL raw).
private _ghGang = _rights select 3;
if (_ghGang > 0) then {["UPDATE gangs SET house_pos = NULL WHERE id = %s", 1, false, [_ghGang]] call DB_fnc_asyncQuery;
    _house setVariable ["AP_house_gang", -1, true];};

// server-side ownership bookkeeping (cleanup/ownership scans read AP_house_owners) -- drop by either oid
if (!isNil "AP_house_owners") then {
    private _i = AP_house_owners findIf { private _e = str (_x param [0, ""]); (_e isEqualTo _posOid) || {_e isEqualTo (str (_rights select 0))} };
    if (_i != -1) then { AP_house_owners deleteAt _i; };};

// finalise on the seller: mode 2 = sold -> pay sellPrice + drop from lists + marker + reset txn (whitelisted cb)
_house setVariable ["AP_houseName", "", true];   // owner 2026-07-10: drop the custom name when sold to bank/market
[2, _house, getPlayerUID _player] remoteExec ["AP_fnc_handleHouse", owner _player];

// owner 2026-06-17: CLEAR the sale lock. fn_sellHouse sets AP_house_sold=true (global) to lock the house WHILE
// the sale processes, but it was NEVER cleared anywhere -> every house sold back to the bank stayed "recently sold
// and still being processed by the server" FOREVER, so NOBODY could re-buy it (until a restart wiped the in-memory
// var). Clear it (global) a few seconds after the DELETE has committed AND the seller's client set-true has landed
// (the 2 broadcasts race -> the delay makes this one cleanly last), so the now-unowned house is buyable again.
[_house] spawn { params ["_h"]; uiSleep 5; if (!isNull _h) then { _h setVariable ["AP_house_sold", nil, true]; }; };

diag_log format ["[LooneyBin][srvSellHouse] sold oid=%1 by %2 (%3)", _oid, name _player, getPlayerUID _player];
