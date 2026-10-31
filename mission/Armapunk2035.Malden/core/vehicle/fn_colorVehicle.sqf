params[["_object", objNull, [objNull]], ["_skinID", -1, [0]]];
if (isNull _object || _skinID isEqualTo - 1) exitWith {};
if (local _object) then {_object setVariable["AP_vehicleColor", _skinID, true];};
private _classname = (typeOf _object);
// MAXSEC HATCHBACK (owner 2026-09-06): a cop-owned Hatchback Sport wears the server-served HTML livery
// hatch_utu (glow 12) instead of a .paa row, and carries the siren-swap pair fn_sirenLights reads.
// Applied by the machine the vehicle is LOCAL to (the buyer / puller, or the server on a restart
// restore) -- that one broadcast reaches everyone JIP-safe; the other machines must NOT paint their
// local .paa over it, so every machine leaves here for this class+side.
private _side = _object getVariable ["AP_side", civilian];
if ((_classname isEqualTo "C_Hatchback_01_sport_F") && { (_side isEqualTo west) || {_side isEqualType "" && {(toLower _side) in ["cop", "west"]}} }) exitWith {
    if (local _object) then {
        // [base, alert, glow with lights OFF, glow with lights ON] (owner 2026-09-07: the circuitry glows only
        // while the lights run -- off = plain paint, on = emissive 25, the strongest that still reads as paint)
        _object setVariable ["AP_htmlSkinAlert", ["hatch_utu", "hatch_utu_alert", 0, 25], true];
        _object setVariable ["AP_copProps", true, true];   // pushbar + lightbar: every client attaches its own (initPlayerLocal), JIP-safe
        [_object, "hatch_utu", false, 0, 0] call AP_fnc_htmlSkin;
    };
};
private _chrome = false;
private _idxCount = 0;
if ((_classname == "C_Offroad_01_F") && (_skinID isEqualTo 16)) then {_chrome = true;
    _idxCount = 0;};
if ((_classname == "C_Heli_Light_01_civil_F") && (_skinID isEqualTo 15)) then {_chrome = true;
    _idxCount = 0;};
if ((_classname == "B_Heli_Light_01_F") && (_skinID isEqualTo 15)) then {_chrome = true;
    _idxCount = 0;};
if ((_classname == "I_Heli_Transport_02_F") && (_skinID isEqualTo 2)) then {_chrome = true;
    _idxCount = 2;};
if ((_classname == "B_Heli_Transport_03_unarmed_F") && (_skinID isEqualTo 1)) then {_chrome = true;
    _idxCount = 1;};
if ((_classname == "B_Heli_Transport_01_F") && (_skinID isEqualTo 1)) then {_chrome = true;
    _idxCount = 1;};
if ((_classname == "C_Tractor_01_F") && (_skinID isEqualTo 4)) then {_chrome = true;
    _idxCount = 0;};
if ((_classname == "C_Offroad_01_comms_F") && (_skinID isEqualTo 19)) then {_chrome = true;
    _idxCount = 2;};
if ((_classname == "C_Offroad_01_covered_F") && (_skinID isEqualTo 19)) then {_chrome = true;
    _idxCount = 2;};
if ((_classname == "C_Plane_Civil_01_F") && (_skinID isEqualTo 1)) then {_chrome = true;
    _idxCount = 2;};
waitUntil {!isNil {_object getVariable "AP_vehicleColor"}};
if (_chrome) then {for "_i"
    from 0 to _idxCount do {_object setObjectMaterial[_i, "\A3\data_f\chrome_enviro.rvmat"];
        _object setObjectTexture[_i, '#(argb,8,8,3)color(0,0.7,0.7,0.01)'];};} else {
    private["_texture1", "_texture2", "_texture3", "_texture4"];
    private _textureRow = ["specific", _classname, _skinID] call AP_fnc_vehicleTextures;
    if (_textureRow isEqualTo[]) exitWith {diag_log "Skin texturing error occured!"};
    _texture1 = _textureRow select 11;
    if (count _textureRow > 12) then {_texture2 = _textureRow select 12};
    if (count _textureRow > 13) then {_texture3 = _textureRow select 13};
    if (count _textureRow > 14) then {_texture4 = _textureRow select 14};
    [_object, 0, _texture1] call AP_fnc_setTexture;
    if !(isNil "_texture2") then {[_object, 1, _texture2] call AP_fnc_setTexture;};
    if !(isNil "_texture3") then {[_object, 2, _texture3] call AP_fnc_setTexture;};
    if !(isNil "_texture4") then {[_object, 3, _texture4] call AP_fnc_setTexture;};
    if ((_classname == "O_MRAP_02_F") && (_skinID isEqualTo 28)) then {_object setObjectMaterial[1, "images\rvmat\Red_Pearlecent.rvmat"];};
};