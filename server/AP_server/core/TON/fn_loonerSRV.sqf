/*
    APS_fnc_loonerSRV  (LooneyBin -- "Looner" microblog server, v2)
    Client args:
      ["feed"]          send the current feed to the REQUESTING client (chronological)
      ["feed","top"]    send the TRENDING feed (most-liked, recent window)
      ["post", msg]     post as the calling player (identity resolved server-side, never trusted)
      ["like", postId]  like a post (one like per uid per post)

    Row shape sent to clients: [id, name, message, minutesAgo, likes, verified, replyTo].

    SECURITY: identity from remoteExecutedOwner (never client args); sanitize markup/SQL metachars;
    QUOTE() every varchar read; 20s/uid post rate limit; 2s/uid like rate limit.
    v2 adds: verified badges (owner + governor + the Ben Bones bot), like counts, a Ben Bones auto-dunk bot,
    and a trending sort. Requires the looner_posts likes/reply_to/verified columns + looner_likes table.
*/
if (!isServer) exitWith {};
params [["_mode", "", [""]], ["_arg", "", ["", 0]]];

#define LOONER_OWNER_UID "76561190000000001"

// verified = owner, current governor, or the Ben Bones bot. Computed at POST time and stored.
private _fnVerified = {params ["_uid"];
    if (_uid isEqualTo LOONER_OWNER_UID) exitWith { 1 };
    private _gov = localNamespace getVariable ["SRV_governorData", []];   // server copy: the published global is client-writable
    if ((_gov param [0, ""]) isEqualTo _uid) exitWith { 1 };   // governor uid in slot 0 (best-effort)
    0};

private _fnFeed = {params [["_sort", "new"]];
    private _order = if (_sort isEqualTo "top") then { "likes DESC, id DESC" } else { "id DESC" };
    // owner 2026-07-15: DATE_FORMAT's %b/%e/%H/%i went through SQF format, which ATE the % tokens -> every
    // post was stamped the literal string "b e H:i". Send minutes-ago (a number) and let the client render
    // relative time; build the query by concatenation so no % survives to format.
    private _q = "SELECT id, name, message, trunc(extract(epoch from (NOW() - ts)) / 60)::bigint AS age_min, likes, verified, reply_to FROM looner_posts ORDER BY " + _order + " LIMIT 50";
    private _rows = [_q, 2, true] call DB_fnc_asyncQuery;
    if (isNil "_rows" || {!(_rows isEqualType [])}) then { _rows = []; };
    if (_sort isEqualTo "new") then { reverse _rows; };   // chronological; trending stays most-liked-first
    _rows};

// Ben Bones auto-dunk bot -- fires ~40% of the time a real player posts. Standalone dunk (reply_to left 0),
// the @name in the copy carries the context. Gets a fat like count = the classic "ratio".
private _fnBonesDunk = {params ["_targetName"];
    private _lines = ["@%1 that's exactly what a lizard would post",
        "WAKE UP @%1 -- you're being farmed for adrenochrome and you're LOONING about it",
        "not saying @%1 is a globalist asset. just saying I've never seen them drink Super Male Vitality.",
        "@%1 big if true. it's not true. but it's big.","1.9 MILLION loons watching @%1 and the MSM says NOTHING",
        "the FROGS put @%1 up to this. look it up. (you can't, they deleted it.)","@%1 this post is a chemtrail. i can smell it."];
    private _msg = format [selectRandom _lines, _targetName];
    private _likes = 200 + floor (random 1600);   // the ratio
    [format ["INSERT INTO looner_posts (uid, name, message, likes, verified, reply_to) VALUES ('BENBONES', 'Ben Bones', '%1', %2, 1, 0)", _msg, _likes]] call DB_fnc_asyncQuery;
};

private _src = remoteExecutedOwner;

switch (toLower _mode) do {case "feed": {if (_src <= 2) exitWith {};
        private _unit = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
        if (isNull _unit) exitWith {};
        private _sort = if ((toLower (format ["%1", _arg])) isEqualTo "top") then { "top" } else { "new" };
        [[[_sort] call _fnFeed], "AP_fnc_loonerReceive", _unit] spawn AP_fnc_MP;};

    case "like": {private _unit = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
        if (isNull _unit) exitWith {};
        private _uid = getPlayerUID _unit;
        if (_uid isEqualTo "") exitWith {};
        private _pid = parseNumber (format ["%1", _arg]);
        if (_pid <= 0) exitWith {};
        if (isNil "AP_loonerLikeLast") then { AP_loonerLikeLast = createHashMap; };
        if ((serverTime - (AP_loonerLikeLast getOrDefault [_uid, -100])) < 2) exitWith {};
        AP_loonerLikeLast set [_uid, serverTime];
        // one like per uid per post
        private _seen = [format ["SELECT COUNT(*) AS c0 FROM looner_likes WHERE uid='%1' AND post_id=%2", _uid, _pid], 2, true] call DB_fnc_asyncQuery;
        if (parseNumber (format ["%1", (_seen param [0, [0]]) param [0, 0]]) > 0) exitWith {
            [["Looner: you already liked that loon."], "AP_fnc_handleMessage", _unit] spawn AP_fnc_MP;};
        [format ["INSERT INTO looner_likes (uid, post_id) VALUES ('%1', %2)", _uid, _pid]] call DB_fnc_asyncQuery;
        [format ["UPDATE looner_posts SET likes = likes + 1 WHERE id = %1", _pid]] call DB_fnc_asyncQuery;
        [[["new"] call _fnFeed], "AP_fnc_loonerReceive", -2] spawn AP_fnc_MP;};

    case "post": {private _unit = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
        if (isNull _unit) exitWith {};
        private _uid = getPlayerUID _unit;
        if (_uid isEqualTo "") exitWith {};

        if (isNil "AP_loonerLast") then { AP_loonerLast = createHashMap; };
        if ((serverTime - (AP_loonerLast getOrDefault [_uid, -100])) < 20) exitWith {
            [["Looner: slow down -- one post every 20 seconds."], "AP_fnc_handleMessage", _unit] spawn AP_fnc_MP;};

        private _clean = (_arg splitString "\'""`<>") joinString "";
        _clean = (_clean splitString toString [10, 13]) joinString " ";
        _clean = trim _clean;
        if (_clean isEqualTo "") exitWith {};
        if ((count _clean) > 180) then { _clean = _clean select [0, 180]; };

        private _nm = ((name _unit) splitString "\'""`<>") joinString "";
        if ((count _nm) > 28) then { _nm = _nm select [0, 28]; };
        if (_nm isEqualTo "") then { _nm = "Anonymous Loon"; };

        private _ver = [_uid] call _fnVerified;
        AP_loonerLast set [_uid, serverTime];
        [format ["INSERT INTO looner_posts (uid, name, message, verified) VALUES ('%1', '%2', '%3', %4)", _uid, _nm, _clean, _ver]] call DB_fnc_asyncQuery;
        ["-LOONER-", _unit, (name _unit), format ["posted: %1", _clean]] call APS_fnc_logIt;

        // Ben Bones auto-dunk (~40%) -- ratio the poster
        if (random 1 < 0.40) then { [_nm] call _fnBonesDunk; };

        [[["new"] call _fnFeed], "AP_fnc_loonerReceive", -2] spawn AP_fnc_MP;};};
