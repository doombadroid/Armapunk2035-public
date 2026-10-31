/*
    File: fn_webPageSRV.sqf  (APS_fnc_webPageSRV)

        [_pageId, _have] remoteExec ["APS_fnc_webPageSRV", 2];

    Serves a UI page's markup to the client that asked for it, so UI can ship
    WITHOUT a client repack. See arma-webui's functions/fn_serve.sqf for the
    whole design; the short version:

      - every page still ships in the mission PBO and still renders from there;
      - that copy is a BASELINE and never has to be updated again;
      - the current version lives on the SERVER's disk, which clients never see;
      - a UI change therefore costs a file edit, not a 230 MB mission PBO
        re-download for every connected player.

    If this function is missing, the file is absent, or the server never
    answers, the client keeps the page it already rendered.

    THE HANDSHAKE, AND WHY THERE IS ONE. The first version of this shipped the
    file on every open, unconditionally. Measured 2026-09-02 on the dev server:
    deck.html is 364 KB raw, 121 KB deflated, and took ~3 s to cross the
    network ON LOOPBACK (Arma paces guaranteed messages), after which the page
    rewrote itself and re-ran its whole boot -- the handset visibly unrolled
    twice on every open, for bytes identical to the PBO copy. So:

      - the client sends `_have`, the version tag it got with its last reply for
        this page ("" if none). webpages.serve answers "unchanged" when the tag
        still matches, and nothing is read into the game at all;
      - with no tag, the daemon compares the file byte-for-byte against the
        mission tree this repo packs (the PBO baseline). Identical means the
        client already has it, and that is the state every deploy leaves behind;
      - only a page that actually differs is deflated and sent, with its tag.

    "Unchanged" is ANSWERED, not left silent: the client parks a ticket per
    request, and a silent server leaves it to expire on a timer with a log line.
    An empty page is the documented "nothing to apply" answer and clears it.

    WHERE THE MARKUP LIVES, AND WHY NOT loadFile. On disk, under the path
    tools/pysqf_modules/webpages.py calls ROOT, read through PySQF. `loadFile`
    is a disabled command on this server -- `Trying to execute a disabled
    command 'loadfile'` -- and the first version of this file used it and
    shipped inert (b0638, 2026-08-18). Reading off disk is the better answer
    regardless: no repack and no restart to ship a UI change.

    COMPRESSION IS ENGINE-NATIVE. ctrlWebBrowserAction "Deflate" returns
    base64'd zlib and works with controlNull, so the SERVER can compress with no
    display and no browser control. The client's "Inflate" caps its OUTPUT at
    1 MB; the largest page here is map.html at 403 KB, and the size is logged.

    SECURITY. This sends executable content to a client, so the direction is
    load-bearing: the reply goes out through AP_fnc_MP to the REQUESTING CLIENT
    only, and AP_fnc_webServeRecv is whitelisted with allowedTargets = 1 so a
    client cannot use it to push markup at another client. Nothing here compiles
    or evaluates the file -- it is read as opaque bytes and forwarded.
*/

params [["_pageId", "", [""]], ["_have", "", [""]]];
if (!isServer) exitWith {};

private _client = remoteExecutedOwner;
// Never trust a path from a client. Anything that could climb out of the web
// root, or is not a page, is refused rather than normalised -- normalising an
// attacker-supplied path is how directory traversal gets shipped.
if (_pageId isEqualTo "") exitWith {};
if (count _pageId > 200) exitWith {};
if (".." in _pageId) exitWith {
    diag_log format ["[AP][webserve] refused traversal attempt from %1: %2", _client, _pageId];
};
if !(_pageId regexMatch "[A-Za-z0-9_\-\\/\.]+\.(html|js|css)") exitWith {
    diag_log format ["[AP][webserve] refused non-page id from %1: %2", _client, _pageId];
};
// The tag is only ever compared, never used as a path, but a client can send
// anything here: bound it so it cannot be used to carry a large payload.
if (count _have > 64) then { _have = ""; };

// PySQF, not loadFile -- see the header. If the daemon is down, or was started
// without the `webpages` module, this comes back not-ok and the client keeps the
// page it already rendered. That is the designed fallback, so it is not an error
// and is not logged per open.
private _reply = ["webpages.serve", [_pageId, _have]] call APS_fnc_pysqfCall;
if !(_reply isEqualType []) exitWith {};
_reply params [["_ok", false, [false]], ["_res", [], [[]]]];
if (!_ok) exitWith {};
_res params [["_status", "", [""]], ["_markup", "", [""]], ["_version", "", [""]]];

if (_status isEqualTo "unchanged") exitWith {
    diag_log format ["[AP][webserve] %1 -> %2: unchanged (%3)", _pageId, _client, _version select [0, 8]];
    [[_pageId, "", _version], "AP_fnc_webServeRecv", _client, false] call AP_fnc_MP;
};
// Nothing on disk for this page (the landing screen, the casino tables, anything
// not in the serve root). Answer that too: measured on b0829, a silent server
// left the client's ticket to expire on its 5 s timer with a "no reply" log line
// on every open of every such screen. The empty answer clears it at once.
if (_status isNotEqualTo "page" || { _markup isEqualTo "" }) exitWith {
    [[_pageId, "", ""], "AP_fnc_webServeRecv", _client, false] call AP_fnc_MP;
};

private _packed = controlNull ctrlWebBrowserAction ["Deflate", _markup];
if (_packed isEqualTo "") exitWith {
    diag_log format ["[AP][webserve] Deflate returned empty for %1 (%2 chars raw)", _pageId, count _markup];
};

diag_log format ["[AP][webserve] %1 -> %2: %3 chars raw, %4 deflated (%5)", _pageId, _client, count _markup, count _packed, _version select [0, 8]];
[[_pageId, _packed, _version], "AP_fnc_webServeRecv", _client, false] call AP_fnc_MP;
