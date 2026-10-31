/*
    APS_fnc_newsPush  (LooneyBin -- Ben Bones reacts to the world). SERVER-side; called from event fire points.
      [_cat, _headline, _loonMsg]  post _loonMsg to Looner as @BenBones (verified) + rebroadcast the feed.
    No CfgRE/remoteExec: other SERVER fns call this directly; clients only get the loon feed
    (AP_fnc_loonerReceive is already whitelisted server->client).

    2026-09-04: the DataBattle half is gone with databattle.com -- this used to ALSO prepend _headline to the
    AP_newsHeadlines public var for that page to render. Nothing reads that var any more, so the var and its
    broadcast were removed and the fn kept: its second job feeds looner.com, which survives as TWATTER's port
    target. _cat and _headline are still in the signature so the nine call sites did not have to change;
    _headline is now dead weight and a caller that passes only two args simply posts nothing.
*/
if (!isServer) exitWith {};
params [["_cat", "NEWS", [""]], ["_headline", "", [""]], ["_loon", "", [""]]];
if (_headline isEqualTo "") exitWith {};

if (_loon isNotEqualTo "") then {private _msg = (_loon splitString "\'""`<>") joinString "";
    _msg = (_msg splitString toString [10, 13]) joinString " ";
    if ((count _msg) > 180) then { _msg = _msg select [0, 180]; };
    if (_msg isNotEqualTo "") then {private _likes = 300 + floor (random 1500);
        [format ["INSERT INTO looner_posts (uid, name, message, likes, verified, reply_to) VALUES ('BENBONES', 'Ben Bones', '%1', %2, 1, 0)", _msg, _likes]] call DB_fnc_asyncQuery;
        private _rows = ["SELECT id, name, message, to_char(ts, 'Mon FMDD HH24:MI') AS posted, likes, verified, reply_to FROM looner_posts ORDER BY id DESC LIMIT 50", 2, true] call DB_fnc_asyncQuery;
        if (!isNil "_rows" && {_rows isEqualType []}) then { reverse _rows; [[_rows], "AP_fnc_loonerReceive", -2] spawn AP_fnc_MP; };};
};
