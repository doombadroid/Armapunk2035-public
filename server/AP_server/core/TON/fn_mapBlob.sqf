/*
    File: fn_mapBlob.sqf  (APS_fnc_mapBlob)
    One cell as an engine-deflated SQF literal, cached per rev (mapdb.md D4).
    params: 0 = cell key ("far" or "<cx>_<cy>")
    returns: [rev, packed, rowCount]; packed "" = empty cell or refused (logged)

    Permanent self-check: what a client will parse is exactly what this server holds. The
    engine's Inflate caps its OUTPUT at 1 MB; the largest cell measured 191 KB raw.
*/
params [["_k", "", [""]]];
private _mapBlobs = localNamespace getVariable "APS_mapBlobs";   // the stores: localNamespace (APS_fnc_mapLoad)
private _have = _mapBlobs get _k;
if (!isNil "_have") exitWith { _have };
private _ids = (localNamespace getVariable "APS_mapCells") getOrDefault [_k, []];
private _e = [localNamespace getVariable "APS_mapRev", "", count _ids];
if (_ids isNotEqualTo []) then {
    private _mapText = localNamespace getVariable "APS_mapText";
    private _txt = "[" + ((_ids apply { _mapText get _x }) joinString ",") + "]";
    if (count _txt > 600000) then { diag_log format ["[AP-MAP] WARNING cell %1 is %2 chars raw", _k, count _txt]; };
    if (count _txt > 900000) then {
        diag_log format ["[AP-MAP] REFUSED cell %1: %2 chars raw (engine Inflate cap 1 MB)", _k, count _txt];
    } else {
        private _packed = controlNull ctrlWebBrowserAction ["Deflate", _txt];
        private _back = parseSimpleArray (controlNull ctrlWebBrowserAction ["Inflate", _packed]);
        private _mapRows = localNamespace getVariable "APS_mapRows";
        if (_back isEqualTo (_ids apply { _mapRows get _x })) then {
            _e set [1, _packed];
        } else {
            diag_log format ["[AP-MAP] ROUNDTRIP FAIL cell %1 (%2 rows, %3 chars) -- blob refused", _k, count _ids, count _txt];
        };
    };
};
_mapBlobs set [_k, _e];
_e
