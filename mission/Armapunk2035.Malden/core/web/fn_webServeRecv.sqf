/*
    File: fn_webServeRecv.sqf  (AP_fnc_webServeRecv)

    Server -> client half of the UI serving path. APS_fnc_webPageSRV answers a
    page request here with one of:

        [_pageId, "",      _version]   unchanged -- the client already has it
        [_pageId, _packed, _version]   deflated markup to apply, and its tag

    Either way the answer is handed to whichever webui_fnc_serve request is
    waiting on that page id. An "unchanged" answer is delivered as an empty page,
    which is fn_serve's documented "nothing to apply": it consumes the ticket
    quietly instead of leaving it to expire on the 5 s timer. The version tag
    rides into fn_serve's cache with the markup and comes back to the server as
    `_have` on the next open, which is what lets the server answer "unchanged"
    without reading the page at all.

    CALLER GUARD. remoteExec whitelisting limits the TARGET of a call, never its
    ORIGIN, so a whitelist entry alone does not stop another CLIENT calling this
    with markup of their choosing -- and markup is executable content that would
    be written into a document holding the A3API binding. That is arbitrary
    script execution in a privileged page, so the origin is checked here rather
    than assumed:

        remoteExecutedOwner == 2   the server
        remoteExecutedOwner == 0   a local call, not over the network

    Anything else is dropped and logged. This is the same guard fn_handleInv
    carries, for the same reason.

    Nothing here compiles or evaluates the payload. It is inflated and handed to
    the browser as bytes.
*/

params [["_pageId", "", [""]], ["_packed", "", [""]], ["_version", "", [""]]];

if (!(remoteExecutedOwner in [0, 2])) exitWith {
    diag_log format ["[AP][webserve] DROPPED page markup from client %1 (id: %2)", remoteExecutedOwner, _pageId];
};
if (_pageId isEqualTo "") exitWith {};

// The request this answers. Taken out FIRST, on every path: a ticket that is
// never answered lingers until fn_serve's expiry timer logs it as a no-reply.
private _waiting = uiNamespace getVariable ["AP_webServeWaiting", createHashMap];
private _cb = _waiting getOrDefault [_pageId, {}];
_waiting deleteAt _pageId;
uiNamespace setVariable ["AP_webServeWaiting", _waiting];

// "Unchanged": nothing to apply, and the PBO page (or the cached override fn_serve
// already applied) stands. The empty answer is what consumes the ticket.
if (_packed isEqualTo "") exitWith {
    if (_cb isNotEqualTo {}) then { [""] call _cb; };
};

// "Inflate" is the engine's own zlib, matching the server's "Deflate", and
// works on controlNull. Output is capped at 1 MB by the engine; a page over
// that returns empty rather than truncating, so an empty result is treated as
// "no override" and the page already on screen stands.
private _markup = controlNull ctrlWebBrowserAction ["Inflate", _packed];
if (_markup isEqualTo "") exitWith {
    diag_log format ["[AP][webserve] inflate failed for %1 (%2 packed chars) -- keeping the PBO page", _pageId, count _packed];
    if (_cb isNotEqualTo {}) then { [""] call _cb; };
};

if (_cb isEqualTo {}) exitWith {
    // Arrived after the dialog closed, or nobody is waiting. Still worth
    // caching: the next open of that page applies it with no round trip, and
    // sends the tag back so the server can answer "unchanged".
    // localNamespace, matching where fn_serve keeps and reads its cache.
    private _cache = localNamespace getVariable ["webui_serveCache", createHashMap];
    _cache set [_pageId, [_markup, _version]];
    localNamespace setVariable ["webui_serveCache", _cache];
};

[_markup, _version] call _cb;
