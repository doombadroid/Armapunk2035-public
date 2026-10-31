// SPDX-License-Identifier: MIT
/*
    fn_openOffers.sqf -- ask the server what this giver is offering, and show
    it.

    WHY THIS EXISTS
      The offers a giver holds are not a client-side question. On a shared
      board they are competed for by everyone on the server, they expire on
      their own, and which of them a given player may take depends on
      prerequisites the client must not be trusted to evaluate. A client that
      built its own offer list would show quests the player cannot have and,
      worse, would show a job that another player took thirty seconds ago.

      So the client asks and waits. The screen opens immediately in a pending
      state -- a giver that appears to do nothing for half a second is
      indistinguishable from a broken giver -- and fills in when the server
      answers.

    WHAT IT DOES
      - Validates the giver id against the index built at preInit.
      - Throttles repeat opens, so holding the action key does not become a
        request per frame.
      - Opens the journal on the offers view for that giver, pending.
      - Requests the offers from the server.

      Server reply contract: the server answers by running, on this client,
          ["board", [_giverId, _rows]] remoteExec ["aq_fnc_sync", _own]
      which aq_fnc_sync turns into ["offers", [_giverId, _records]] for the
      journal. An empty list is a valid answer and renders as "no work
      available", which is different from, and must not look like, a request
      that never came back.

    Usage:  ["market_trader"] call aq_fnc_openOffers;
*/

params [["_giverId", "", [""]]];

if (_giverId isEqualTo "") exitWith {
    diag_log "[AQ] openOffers: refused, empty giver id";
    false
};
if (!hasInterface) exitWith {
    diag_log "[AQ] openOffers: called with no interface -- this is a client-side entry point";
    false
};
if (isNil "aq_ready" || {!aq_ready}) exitWith {
    diag_log format ["[AQ] openOffers: refused '%1', system not armed (validation failed or preInit did not run)", _giverId];
    false
};

if (isNil { aq_idxGiver get _giverId }) exitWith {
    diag_log format ["[AQ] openOffers: no giver '%1' in AQ_Givers. Known givers: %2", _giverId, keys aq_idxGiver];
    false
};

// ---------------------------------------------------------------- throttle
if (isNil "aq_lastOfferReq") then { aq_lastOfferReq = createHashMap; };
private _now = diag_tickTime;
if (_now - (aq_lastOfferReq getOrDefault [_giverId, -1e6]) < 0.75) exitWith { false };
aq_lastOfferReq set [_giverId, _now];

// ------------------------------------------------------------------- show
aq_pendingGiver = _giverId;
["open", ["offers", _giverId]] call aq_fnc_journal;

// ---------------------------------------------------------------- request
["offers", _giverId, player] remoteExec ["aq_fnc_srvBoard", 2];
true
