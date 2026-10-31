/*
    fn_deckNetlink.sqf  (AP_fnc_deckNetlink) -- NETLINK, the deck's mesh browser.

    NETLINK is a VIEW INSIDE THE DECK (CTX_APPS "net" in ui\html\deck.html), not a
    dialog of its own. It briefly was one: the designer's page ships its own copy of
    the SPOOL MK-II chassis, which read as "standalone page" and became dialog 938600
    on 2026-09-04. That was wrong -- the chassis in the page is the SAME chassis
    deck.html paints, and a separate dialog meant two of them stacked. The handoff
    said so in its first line ("open from the deck app grid as deckGo('browser')")
    and this file is the correction.

    Verbs (page -> here, through the deck's own "netlink" registration in
    fn_deckOpen.sqf):
        ["data"]          -> the payload below (also what "refresh" pushes)
        ["post", text]    -> post to Looner as the calling player
        ["like", postId]  -> like a post

    NOTHING NEW DECIDES ANYTHING. post/like forward to APS_fnc_loonerSRV, which has
    owned Looner since 2026-07-15 and is untouched: identity from remoteExecutedOwner
    (never from the page), sanitising, rate limits (20 s per post, 2 s per like) and
    one-like-per-uid in looner_likes. No new CfgRE entry and no new write path --
    APS_fnc_loonerSRV was already whitelisted because the native browser called
    exactly these two verbs.

    THE PAGE IS NEVER PATCHED LOCALLY ON A MUTATION. A post or a like fires the verb
    and stops; the render happens when the server's rebroadcast lands in
    AP_fnc_loonerReceive and is pushed back on the "netlink" channel. That is what
    makes a refused like correct for free -- the count simply never moves, and the
    server's own toast explains why.

    ROW SHAPE. APS_fnc_loonerSRV sends [id, name, message, minutesAgo, likes,
    verified, replyTo] oldest-first, and sends minutes-ago as a NUMBER on purpose:
    the server's DATE_FORMAT tokens did not survive SQF format[] and every post came
    back stamped "b e H:i" (fn_loonerSRV's own note). The page renders the relative
    time from it. replyTo has no place in the design yet and is dropped here rather
    than pushed as a field nothing reads.

    EXCHANGE is not wired. exchange.mld runs on the page's own sample rows: the deck
    already ships a real EXCHANGE app against the same listings, and a second live
    client for one dataset is a synchronisation problem bought for nothing.
*/
params [["_mode", "data", [""]], ["_arg", "", ["", 0]]];

switch (toLower _mode) do {

    case "data": {
        private _rows = missionNamespace getVariable ["AP_loonerFeed", []];
        private _feed = [];
        {
            _x params [["_id", 0], ["_nm", "Loon"], ["_msg", ""], ["_mins", 0], ["_likes", 0], ["_ver", 0]];
            // extDB3 hands numbers back as strings often enough that the native page
            // guarded this too -- same coercion, same reason.
            if (_mins  isEqualType "") then { _mins  = parseNumber _mins; };
            if (_likes isEqualType "") then { _likes = parseNumber _likes; };
            if (_ver   isEqualType "") then { _ver   = parseNumber _ver; };
            _feed pushBack (createHashMapFromArray [
                ["id", _id], ["n", _nm], ["x", _msg],
                ["m", _mins], ["l", _likes], ["v", _ver > 0]
            ]);
        } forEach _rows;

        // ask the server for a fresher one; this returns the cached copy immediately
        // so the first paint is never a blank stream waiting on a round trip
        [["feed"], "APS_fnc_loonerSRV", 2, false, false] spawn AP_fnc_MP;

        createHashMapFromArray [
            ["me",    createHashMapFromArray [["n", name player]]],
            ["feed",  _feed],
            // the registry the page's 404 copy reads. Two hosts; the field exists so
            // a third is a data change rather than a page edit.
            ["sites", [
                createHashMapFromArray [["host", "twatter.mld"],  ["title", "TWATTER"]],
                createHashMapFromArray [["host", "exchange.mld"], ["title", "MDN·EXCHANGE"]]
            ]]
        ]
    };

    case "post": {
        private _text = trim (format ["%1", _arg]);
        if (_text isEqualTo "") exitWith { createHashMapFromArray [["ok", false], ["msg", "empty"]] };
        // 180 is the server's own cap; trimming here saves a round trip, it does not enforce
        if ((count _text) > 180) then { _text = _text select [0, 180]; };
        [["post", _text], "APS_fnc_loonerSRV", 2, false, false] spawn AP_fnc_MP;
        createHashMapFromArray [["ok", true], ["msg", ""]]
    };

    case "like": {
        private _id = if (_arg isEqualType 0) then { _arg } else { parseNumber (format ["%1", _arg]) };
        if (_id <= 0) exitWith { createHashMapFromArray [["ok", false], ["msg", "bad id"]] };
        [["like", _id], "APS_fnc_loonerSRV", 2, false, false] spawn AP_fnc_MP;
        createHashMapFromArray [["ok", true], ["msg", ""]]
    };

    default { createHashMapFromArray [["ok", false], ["msg", format ["netlink: unknown verb %1", _mode]]] };
};
