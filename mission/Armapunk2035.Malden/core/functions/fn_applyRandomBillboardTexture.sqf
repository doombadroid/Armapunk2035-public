/*
    AP_fnc_applyRandomBillboardTexture  (LooneyBin)
    Restored billboard rotation -- deobf had gutted this to a single static placeholder image (no list/timer).
    Each rotating billboard registers itself + immediately gets a random ad; a SINGLE 5-minute loop (started
    once) re-rolls every registered billboard. Per-client (setObjectTexture is a local visual). Owner can add
    ads to AP_billboardAds or change AP_billboardInterval.
*/
params ["_obj_main", "_selectionNumber"];
AP_billboardAds = ["images\billboard1.jpg", "images\billboard2.jpg"];
AP_billboardInterval = 300;   // owner 2026-06-11: rotate every 5 minutes

if (isNil "AP_billboardObjs") then { AP_billboardObjs = []; };
AP_billboardObjs pushBackUnique [_obj_main, _selectionNumber];
_obj_main setObjectTexture [_selectionNumber, selectRandom AP_billboardAds];

if (isNil "AP_billboardRotationStarted") then {AP_billboardRotationStarted = true; [{{if !(isNull (_x select 0)) then {
                (_x select 0) setObjectTexture [(_x select 1), selectRandom AP_billboardAds];};} forEach AP_billboardObjs;
    }, createHashMap, AP_billboardInterval] call AP_fnc_addPerFrameHandler;};
