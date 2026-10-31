/*
    fn_htmlSkin.sqf  (AP_fnc_htmlSkin) -- SPIKE, owner 2026-09-06: a vehicle skin that lives on the
    SERVER as an HTML page and is streamed to whoever looks at the car. No PBO, no mod, no client file.

        [_veh, "hatch_a"] call AP_fnc_htmlSkin;          // STATIC: ids = server/AP_server/web/ui/html/skins/<id>.html
        [_veh, "neon_edge", true] call AP_fnc_htmlSkin;  // LIVE: animated page, every viewer keeps pumping it (capped)
        [player, "circuit", true] call AP_fnc_htmlSkin;  // a UNIT works too: uniform selection 0, and the backpack if worn
        [_veh, "off"] call AP_fnc_htmlSkin;              // #reset texture AND material, tell everyone to forget it
        [player, "gen_ticker", true, 0, 100] call AP_fnc_htmlSkin; // 5th arg: emissive (nearest of a ladder, see below)

    THE CHAIN. The car's hidden selections get, via setObjectTextureGlobal, the string
        #(rgb,512,512,1)uiEx(display:AP_uiTexSkin,uniqueName:apskin_<id>)
    which replicates to every client (JIP-safe: the engine keeps object textures). On each client the
    engine creates display "apskin_<id>" the first time it draws that texture; AP_fnc_htmlSkinClient
    (remoteExec'd here to everyone, JIP-queued) watches for it, initialises the webui bridge on the
    browser inside it, and asks the server for ui\html\skins\<id>.html through the ordinary
    webui_fnc_serve path -- sha1-tagged, cached per session, "unchanged" when already held. The page
    is a JPEG data URI stretched over the document. After the browser's first Draw the display is
    never pumped again (a static skin is one paint) and the browser is stopped: per-frame cost zero.

    ONE DISPLAY PER SKIN, NOT PER CAR. The unique name is the skin id, so ten cars in hatch_red share
    one display and one browser on every viewer. Distinct skins in view, not cars, is the count the
    uiTex cap applies to.

    WHAT THE SPIKE IS FOR: does a frozen ui2texture survive ten idle minutes, alt-tab, VRAM pressure --
    or come back black? fn_htmlSkinClient logs every 60 s whether each served display still exists.
    The paint itself is the owner's eyeball.
*/
params [["_veh", objNull, [objNull]], ["_id", "", [""]], ["_live", false, [false]], ["_size", 0, [0]], ["_glow", 0, [0]]];
// RESOLUTION (owner: "they look low res compared to the originals" -- they were 512). The string's size
// is the texture the display renders into. Stock sheets are 2048, so a STATIC skin gets 2048: painted
// once, it costs memory and nothing per frame. A LIVE one is copied every frame, and 2048 is sixteen
// times the readback of 512, so it defaults to 1024; pass a 4th argument to override either.
if (_size isEqualTo 0) then { _size = if (_live) then { 1024 } else { 2048 }; };
// SERVER TOO (owner 2026-09-06, default cop livery): fn_restoreVehicles paints restored cars from the
// dedicated server, so the broadcast half must run there; only the message needs a screen.
if (isNull _veh) exitWith { false };
private _n = count (_veh getObjectTextures []);
// a unit's backpack is its own object with its own selection 0 -- it gets the same string so the
// page paints both from ONE display (the skin id is the display name, shared)
private _bp = if (_veh isKindOf "CAManBase") then { unitBackpack _veh } else { objNull };
if (_n isEqualTo 0) exitWith { if (hasInterface) then { ["That class has no hidden selections.", "basic"] spawn AP_fnc_handleMessage; }; false };

if (_id in ["", "off"]) exitWith {
    for "_i" from 0 to (_n - 1) do { _veh setObjectTextureGlobal [_i, "#reset"]; _veh setObjectMaterialGlobal [_i, "#reset"]; };
    if (!isNull _bp) then { _bp setObjectTextureGlobal [0, "#reset"]; _bp setObjectMaterialGlobal [0, "#reset"]; };
    _veh setVariable ["AP_htmlSkin", nil, true];
    diag_log format ["[AP-HSKIN] %1 reset", typeOf _veh];
    true
};
private _safe = toLower (_id regexReplace ["[^0-9A-Za-z_]", "_"]);
private _prev = _veh getVariable ["AP_htmlSkin", ""];   // the id this object wore before: viewers drop its live registration
private _name = "apskin_" + _safe;
// TEXTURE TYPE (owner, 2048 pass: "darker and less reflective" than the stock paint). uiEx's texType
// defaults to "ca" -- an alpha texture -- which puts the body through the alpha-blended path instead
// of the opaque diffuse one the car's own rvmat expects. "co" is what a livery is. Live-tunable:
//     AP_htmlSkinTexType = "ca"; then re-apply, to compare.
private _tt = missionNamespace getVariable ["AP_htmlSkinTexType", "co"];
private _tex = format ["#(rgb,%2,%2,1)uiEx(display:AP_uiTexSkin,uniqueName:%1,bgColor:#000000ff,texType:%3)", _name, _size, _tt];
for "_i" from 0 to (_n - 1) do { _veh setObjectTextureGlobal [_i, _tex]; };
if (!isNull _bp && { count (_bp getObjectTextures []) > 0 }) then { _bp setObjectTextureGlobal [0, _tex]; };
// GLOW (owner 2026-09-06, "emissive rvmat ... can that still be served purely over html"): no -- an rvmat
// is an engine material file and must exist in the PBO -- but a generic ladder covers every skin, so
// the art stays served HTML. The 5th arg is the EMISSIVE you want (0 = the garment's own material);
// the nearest of ap_glowskin_{4,12,25,50,100,200,400}.rvmat is applied. Scale: ap_printer_screen 9
// (10 cm LCD), ap_vendsign 45 (shopfront), the neon signage 1e5. The whole selection is emissive;
// the page's dark ground stays dark, its lights light. Not every class exposes materials
// (getObjectMaterials empty = the engine ignores the call); logged.
private _ladder = [4, 12, 25, 50, 100, 200, 400];
private _mat = "#reset";
if (_glow > 0) then {
    private _near = _ladder select 0;
    { if (abs (_x - _glow) < abs (_near - _glow)) then { _near = _x; }; } forEach _ladder;
    _mat = format ["mpmissions\__cur_mp.Malden\ap_glowskin_%1.rvmat", _near];
};
for "_i" from 0 to (_n - 1) do { _veh setObjectMaterialGlobal [_i, _mat]; };
if (!isNull _bp && { count (_bp getObjectMaterials []) > 0 }) then { _bp setObjectMaterialGlobal [0, _mat]; };
diag_log format ["[AP-HSKIN] glow=%1 material %2 on %3 (class materials: %4)", _glow, _mat, typeOf _veh, _veh getObjectMaterials []];
_veh setVariable ["AP_htmlSkin", _safe, true];
// everyone, JIP-queued under one key per object so a late joiner gets the latest skin only once.
// LIVE skins carry the object too: the viewer registers it with the cap manager, which sorts by distance.
[[_safe, _live, _veh, _prev], "AP_fnc_htmlSkinClient", true, format ["apskin_%1", netId _veh]] call AP_fnc_MP;
diag_log format ["[AP-HSKIN] %1 -> %2 on %3 selection(s); string broadcast, client service told", typeOf _veh, _safe, _n];
true
