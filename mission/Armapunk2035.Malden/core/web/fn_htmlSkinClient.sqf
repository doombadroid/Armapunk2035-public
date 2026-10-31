/*
    fn_htmlSkinClient.sqf  (AP_fnc_htmlSkinClient) -- the per-viewer half of a server-streamed HTML
    skin. remoteExec'd by fn_htmlSkin to every client (JIP-queued) with the skin id.

    It cannot serve the page at once: the display "apskin_<id>" only exists after this client's
    engine has DRAWN the texture, which means the car has been on screen. So the id goes into a
    wanted-list and a 1 Hz loop serves each display the moment it appears. Idempotent per id.
*/
params [["_id", "", [""]], ["_live", false, [false]], ["_obj", objNull, [objNull]], ["_prev", "", [""]]];
if (!hasInterface || {_id isEqualTo ""}) exitWith {};
if (isNil "AP_htmlSkinWanted") then { AP_htmlSkinWanted = createHashMap; };
if (isNil "AP_htmlSkinLive") then { AP_htmlSkinLive = createHashMap; };
// LIVE: an animated page -- register the object with the cap manager so this viewer keeps pumping the
// shared display (nearest 20), instead of freezing it after the first paint. Several objects can wear
// one live skin; the manager pumps the display once per frame whichever object is nearest.
if (_prev isNotEqualTo "" && {_prev isNotEqualTo _id} && {!isNull _obj}) then { [_obj, "apskin_" + _prev, false] call AP_fnc_uiTexManager; };   // skin swap: stop pumping the old one for this object
if (_live && {!isNull _obj}) then { AP_htmlSkinLive set [_id, true]; [_obj, "apskin_" + _id] call AP_fnc_uiTexManager; };
// A RE-APPLY OF A KNOWN ID IS A REFRESH (owner 2026-09-06: "nothing changed" after a page edit -- this
// line was a bare exitWith, so a skin id seen once this session could never pick up a new version of
// its page; toggling off would not have helped either, "off" only resets the texture). Skins are
// edited live on the server, so revalidate what we hold against the server's tag and reload the
// document in place if it moved. A frozen static skin is resumed for the reload and freezes again.
if (_id in AP_htmlSkinWanted) exitWith {
    private _d = findDisplay ("apskin_" + _id);
    private _c = if (isNull _d) then { controlNull } else { _d displayCtrl 941931 };
    if (isNull _c) exitWith { AP_htmlSkinWanted set [_id, "wanted"]; };   // display gone: serve fresh when it returns
    private _have = ((uiNamespace getVariable ["AP_htmlSkinMarkup", createHashMap]) getOrDefault [_id, ["", ""]]) select 1;
    uiNamespace setVariable ["AP_htmlSkinFetchCtrl", _c];
    uiNamespace setVariable ["AP_htmlSkinFetchId", _id];
    [format ["ui\html\skins\%1.html", _id], _have, {
        params [["_markup", "", [""]], ["_version", "", [""]]];
        private _c = uiNamespace getVariable ["AP_htmlSkinFetchCtrl", controlNull];
        private _id = uiNamespace getVariable ["AP_htmlSkinFetchId", ""];
        if (_markup isEqualTo "") exitWith { diag_log format ["[AP-HSKIN] client: %1 re-applied; server says unchanged", _id]; };
        (uiNamespace getVariable ["AP_htmlSkinMarkup", createHashMap]) set [_id, [_markup, _version]];
        if (isNull _c) exitWith {};
        if (_c getVariable ["AP_hskinFrozen", false]) then { _c ctrlWebBrowserAction ["ResumeBrowser"]; _c setVariable ["AP_hskinFrozen", false]; };
        _c setVariable ["AP_hskinFirstAt", -1]; _c setVariable ["AP_hskinDraws", 0]; _c setVariable ["AP_hskinLoaded", true];
        _c ctrlWebBrowserAction ["OpenDataAsURL", _markup];
        diag_log format ["[AP-HSKIN] client: %1 reloaded in place (OpenDataAsURL, %2 chars, %3)", _id, count _markup, _version];
    }] call (missionNamespace getVariable ["webui_serveFetcher", {}]);
    diag_log format ["[AP-HSKIN] client: %1 re-applied; revalidating against %2", _id, _have];
};
AP_htmlSkinWanted set [_id, "wanted"];
diag_log format ["[AP-HSKIN] client: skin %1 wanted; waiting for display apskin_%1", _id];

if (isNil "AP_htmlSkinLoop") then {
    AP_htmlSkinLoop = true;
    if (isNil "AP_uiTexSkinPreloaded") then {   // the ui2texture mipmap workaround, once per session
        private _tmp = (findDisplay 46) createDisplay "AP_uiTexSkin";
        _tmp closeDisplay 1;
        AP_uiTexSkinPreloaded = true;
    };
    [] spawn {
        private _tick = 0;
        while { true } do {
            uiSleep 1; _tick = _tick + 1;
            {
                private _id = _x; private _state = _y;
                private _d = findDisplay ("apskin_" + _id);
                // a served skin whose display has GONE (the object was reset, or streamed out and the
                // engine dropped the display) must be served again when it comes back -- otherwise the
                // next apply of the same id shows the black placeholder for the rest of the session
                if (_state isEqualTo "served" && { isNull _d }) then { AP_htmlSkinWanted set [_id, "wanted"]; _state = "wanted"; };
                if (_state isEqualTo "wanted" && { !isNull _d }) then {
                    private _c = _d displayCtrl 941931;
                    if (!isNull _c) then {
                        if ([_c] call webui_fnc_init) then {
                            // THE ENGINE LOADS THE PAGE, NOT JAVASCRIPT. Measured on dev b0969: ExecJS does
                            // not execute in a browser that lives inside a ui2texture display -- the
                            // webui_fnc_serve swap (WEBUI._serve over ExecJS) never ran, while the identical
                            // swap works in a plain Chrome and page -> SQF calls work in-texture. So the
                            // markup is fetched through the mission's serve fetcher (server-authoritative,
                            // sha-tagged) and handed to the control with ctrlWebBrowserAction
                            // "OpenDataAsURL", which is an engine action with no script in the path. The
                            // loaded document still has A3API (its RequestTexture answered 1024x1024 on
                            // the same run) and its own webui.js boot, so page -> SQF logging works after.
                            [_c, "log", {
                                params [["_msg", "", [""]]];
                                diag_log format ["[WEBUI-PAGE] %1", _msg];
                                true
                            }] call webui_fnc_on;
                            AP_htmlSkinWanted set [_id, "served"];
                            private _cache = uiNamespace getVariable ["AP_htmlSkinMarkup", createHashMap];
                            uiNamespace setVariable ["AP_htmlSkinMarkup", _cache];
                            private _have = (_cache getOrDefault [_id, ["", ""]]) select 1;
                            private _pageId = format ["ui\html\skins\%1.html", _id];
                            // apply what we already hold at once (a re-appearing display), then revalidate
                            if (((_cache getOrDefault [_id, ["", ""]]) select 0) isNotEqualTo "") then {
                                _c ctrlWebBrowserAction ["OpenDataAsURL", (_cache get _id) select 0];
                            };
                            [_pageId, _have, {
                                // fn_webServeRecv answers [_markup, _version] call _cb, or [""] for "unchanged"
                                // (the first cut read _this as a wrapped reply and dropped every answer)
                                params [["_markup", "", [""]], ["_version", "", [""]]];
                                if (_markup isEqualTo "") exitWith {};   // unchanged: what we applied stands
                                private _c = uiNamespace getVariable ["AP_htmlSkinFetchCtrl", controlNull];
                                private _id = uiNamespace getVariable ["AP_htmlSkinFetchId", ""];
                                (uiNamespace getVariable ["AP_htmlSkinMarkup", createHashMap]) set [_id, [_markup, _version]];
                                if (!isNull _c) then {
                                    // THE FREEZE CLOCK STARTS HERE, NOT AT THE PLACEHOLDER'S PAINT (owner 2026-09-06,
                                    // hatch_maxsec "just all black": a 420 KB page took 7 s to arrive, the black
                                    // placeholder's first paint had started the 3 s clock, StopBrowser fired at +5 s and
                                    // the real page loaded into a stopped browser). Loaded = true gates the freeze;
                                    // a browser the race already stopped is resumed for the load.
                                    if (_c getVariable ["AP_hskinFrozen", false]) then { _c ctrlWebBrowserAction ["ResumeBrowser"]; _c setVariable ["AP_hskinFrozen", false]; };
                                    _c setVariable ["AP_hskinFirstAt", -1]; _c setVariable ["AP_hskinDraws", 0]; _c setVariable ["AP_hskinLoaded", true];
                                    _c ctrlWebBrowserAction ["OpenDataAsURL", _markup];
                                    diag_log format ["[AP-HSKIN] client: %1 loaded through the engine (OpenDataAsURL, %2 chars, %3)", _id, count _markup, _version];
                                };
                            }] call (missionNamespace getVariable ["webui_serveFetcher", {}]);
                            uiNamespace setVariable ["AP_htmlSkinFetchCtrl", _c];
                            uiNamespace setVariable ["AP_htmlSkinFetchId", _id];
                            // paints: the first one stamps the clock the static-skin freeze runs on
                            _c setVariable ["AP_hskinDraws", 0];
                            _c ctrlAddEventHandler ["Draw", {
                                params ["_c"];
                                private _k = (_c getVariable ["AP_hskinDraws", 0]) + 1;
                                _c setVariable ["AP_hskinDraws", _k];
                                if (_k isEqualTo 1) then { _c setVariable ["AP_hskinFirstAt", diag_tickTime]; diag_log format ["[AP-HSKIN] client: %1 first paint at frame %2", ctrlParent _c, diag_frameNo]; };
                            }];
                            diag_log format ["[AP-HSKIN] client: display for %1 appeared; page requested from the server", _id];
                        };
                    };
                };
                // a served skin gets pumped until 3 s after its FIRST paint (the document rewrite is a few
                // frames; a static page then paints once or twice and never again -- a paint COUNT never
                // reaches a threshold, which is why the first live run pumped forever), then left frozen
                if (_state isEqualTo "served") then {
                    [_d, _id] call { params ["_d", "_id"];
                        private _c = _d displayCtrl 941931;
                        private _k = _c getVariable ["AP_hskinDraws", 0];
                        private _t0 = _c getVariable ["AP_hskinFirstAt", -1];
                        if (_id in AP_htmlSkinLive) exitWith {};   // live: the cap manager pumps it every frame; never freeze
                        if !(_c getVariable ["AP_hskinLoaded", false]) exitWith { displayUpdate _d; };   // still the placeholder: keep pumping, never freeze
                        if (_t0 < 0 || { diag_tickTime - _t0 < 3 }) then { displayUpdate _d; } else {
                            if !(_c getVariable ["AP_hskinFrozen", false]) then {
                                _c setVariable ["AP_hskinFrozen", true];
                                _c ctrlWebBrowserAction ["StopBrowser"];
                                diag_log format ["[AP-HSKIN] client: %1 frozen after %2 paints -- browser stopped, no further updates", _id, _k];
                            };
                        };
                    };
                };
            } forEach AP_htmlSkinWanted;
            // the eviction probe: once a minute, is every served display still there?
            if ((_tick mod 60) isEqualTo 0) then {
                { if (_y isEqualTo "served") then {
                    diag_log format ["[AP-HSKIN] t+%1 min: display apskin_%2 %3", _tick / 60, _x, ["GONE", "alive"] select (!isNull (findDisplay ("apskin_" + _x)))];
                }; } forEach AP_htmlSkinWanted;
            };
        };
    };
};
