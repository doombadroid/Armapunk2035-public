/*
    File: fn_webServeInit.sqf  (AP_fnc_webServeInit)

    Registers this mission's transport for arma-webui's page serving, once, at
    postInit. The library does not know about remoteExec or AP_fnc_MP -- it asks
    a host-supplied fetcher for a page and applies whatever comes back -- so this
    is the whole integration.

    Setting webui_serveFetcher is what TURNS THE FEATURE ON. Without it,
    webui_fnc_serve exits immediately and every page renders from the mission
    PBO exactly as before. That is also the kill switch: set

        webui_serveEnabled = false;

    and the next page open ignores the server entirely. Worth knowing before a
    deploy, because it means this feature can be switched off from the debug
    console without a repack.

    HISTORY. Disabled 2026-08-21: the path had never actually run (the PySQF
    daemon had never come up as a service), and its first real run surfaced two
    latent bugs in the bridge plus a deck that never received its phone channel.
    The bridge's 2026-08-29 audit sweep fixed the document-rewrite path (the
    channel cache is kept across the rewrite, and the incoming document's
    readiness promise is re-resolved). Re-verified 2026-09-02, first offline
    against the real deck page in headless Chrome (all four push/serve
    orderings), then in game: the served document booted and received the
    phone channel. What that run ALSO showed was the cost of serving
    unconditionally -- ~3 s of network transit for 121 KB on loopback, then a
    full re-boot of a page identical to the PBO copy -- which is why the
    fetcher now sends `_have` and the server answers "unchanged" (see
    APS_fnc_webPageSRV).
*/

if (!hasInterface) exitWith {};

webui_serveFetcher = compileFinal {
    params [["_pageId", "", [""]], ["_have", "", [""]], ["_cb", {}, [{}]]];
    if (_pageId isEqualTo "") exitWith {};

    // One outstanding request per page. A second open while the first is still
    // in flight replaces the callback rather than queueing another remoteExec:
    // the server's reply is keyed by page id, not by request, so two in flight
    // would race to the same slot and one would be dropped anyway.
    private _waiting = uiNamespace getVariable ["AP_webServeWaiting", createHashMap];
    private _already = _waiting getOrDefault [_pageId, {}];
    _waiting set [_pageId, _cb];
    uiNamespace setVariable ["AP_webServeWaiting", _waiting];
    if (_already isNotEqualTo {}) exitWith {};

    // _have is the version tag fn_serve cached with this page's last override
    // ("" if it has none). The server answers "unchanged" when it still matches,
    // or when the client has no tag and the file is identical to the PBO copy.
    [[_pageId, _have], "APS_fnc_webPageSRV", false, false] call AP_fnc_MP;
};

diag_log "[AP][webserve] fetcher registered -- server may override page markup";
