params[["_house", objNull, [objNull]], ["_enable", false, [true]], "_rgb"];
if (isNull _house) exitWith {};
if !(_house isKindOf "House_F") exitWith {};
if (_enable) then {private _offset =
    switch (true) do {case ((typeOf _house) in ["Land_i_House_Big_01_V1_F", "Land_i_House_Big_01_V2_F", "Land_i_House_Big_01_V3_F"]): {
                [0, -2, 3.8]};
        case ((typeOf _house) in ["Land_i_House_Big_02_V1_F", "Land_i_House_Big_02_V2_F", "Land_i_House_Big_02_V3_F"]): {[2, 0, 3.5]};
        case ((typeOf _house) in ["Land_i_House_Small_01_V1_F", "Land_i_House_Small_01_V2_F", "Land_i_House_Small_01_V3_F"]): {[-1.5, 0, 2]
            };
        case ((typeOf _house) in ["Land_i_House_Small_02_V1_F", "Land_i_House_Small_02_V2_F", "Land_i_House_Small_02_V3_F"]): {[2, 0, 2.4]
            };
        case ((typeOf _house) in ["Land_i_House_Small_03_V1_F", "Land_i_House_Small_03_V3_F", "Land_i_House_Small_03_V3_F"]): {
                [-3.3, 1, 2.5]};
        case ((typeOf _house) in ["Land_i_Stone_HouseSmall_V1_F", "Land_i_Stone_HouseSmall_V2_F", "Land_i_Stone_HouseSmall_V3_F"]): {
                [0.90, 2.3, 4]};
        case ((typeOf _house) in ["Land_i_Stone_Shed_V1_F", "Land_i_Stone_Shed_V2_F", "Land_i_Stone_Shed_V3_F"]): {[0, 1.9, 3.5]};
        case ((typeOf _house) in ["Land_i_Shed_Ind_F"]): {[0, 3.4, 4]};
        default {[0, 0, 0]};}; if (_offset isEqualTo[0, 0, 0]) exitWith {};
    if (_rgb isEqualTo[]) then {_rgb = [250, 150, 50]};
    private _lightSource = "#lightpoint"
    createVehicleLocal[0, 0, 0];
    _lightSource lightAttachObject[_house, _offset];
    _lightSource setLightColor _rgb;
    _lightSource setLightAttenuation[1, 0, 0, 0];
    _lightSource setLightIntensity 10;
    _lightSource setLightUseFlare true;
    _lightSource setLightFlareSize 0.2;
    _lightSource setLightFlareMaxDistance 50;
    _house setVariable["AP_lightSource", _lightSource];} else {if (isNull(_house getVariable["AP_lightSource", objNull])) exitWith {};
    deleteVehicle(_house getVariable["AP_lightSource", objNull]);};