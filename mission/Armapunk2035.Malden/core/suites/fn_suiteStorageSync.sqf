/*
    File: fn_suiteStorageSync.sqf  (AP_fnc_suiteStorageSync)
    Persist the open suite crate NOW. Every trunk-screen action that changes what is in
    it (take / store / swap / drop) calls this next to its gear save, ordered so the side
    that LOSES the item goes out first: take/swap/drop sync first, store saves gear first.
    Sent with call, not spawn, so it leaves in the same frame as that gear save; a crash
    between the two can then only lose an item, never duplicate it.

        [] call AP_fnc_suiteStorageSync   -> true when AP_trunk_vehicle is the suite crate

    The crate is local to this machine (fn_suiteStorage), so the server cannot see a
    change until it is sent, and the disconnect handler's house force-persist never
    reaches it. Before this the suite row was written only on close: take an item,
    alt-F4, and it was in both the suite row and the gear row the take had just saved.
    AP_suiteStoreSeq orders the writes (shared with the close in fn_suiteStorage): the
    server refuses one older than a write it has already taken, so it is never reset while
    this client lives -- a late write from the previous open must number below every write
    of this one. localNamespace (it and the crate ref), so no other client can publicVariable them.
*/
private _c = AP_trunk_vehicle;
if (isNull _c || {!(_c isEqualTo (localNamespace getVariable ["AP_suiteCrate", objNull]))}) exitWith { false };
private _seq = (localNamespace getVariable ["AP_suiteStoreSeq", 0]) + 1;
localNamespace setVariable ["AP_suiteStoreSeq", _seq];
// Copies: the trunk code edits these arrays in place; the snapshot must not share them.
[["sync", _c getVariable ["AP_suiteOid", ""], [+(_c getVariable ["AP_vinv", [[], 0]]), +(_c getVariable ["AP_pinv", [[], 0]]), _seq]],
    "APS_fnc_suiteStorageSRV", 2] call AP_fnc_MP;
true
