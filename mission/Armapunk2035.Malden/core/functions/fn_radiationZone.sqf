if (!canSuspend) exitWith {_this spawn AP_fnc_radiationZone;};
params["_thisList", "_thisTrigger"];
if !(player in _thisList || (vehicle player) in _thisList) exitWith {};
private _plb_obj = player;
private _zoneRadius = (triggerArea _thisTrigger) select 0;
private _hazmatUniforms = ["U_I_E_CBRN_Suit_01_EAF_F", "U_I_CBRN_Suit_01_AAF_F", "U_C_CBRN_Suit_01_Blue_F", "U_C_CBRN_Suit_01_White_F", "U_B_CBRN_Suit_01_Wdl_F", "U_B_CBRN_Suit_01_Tropic_F", "U_B_CBRN_Suit_01_MTP_F", "U_B_Wetsuit", "U_O_Wetsuit", "U_I_Wetsuit"];
private _hazmatMasks = ["G_RegulatorMask_F", "G_AirPurifyingRespirator_01_F", "G_AirPurifyingRespirator_02_black_F", "G_AirPurifyingRespirator_02_olive_F", "G_AirPurifyingRespirator_02_sand_F", "G_Diving"];
private _effectMagnitude =
if ((goggles player) in _hazmatMasks) then {[0.033, 0.02, 0.075]} else {[0.15, 0.03, 0.29]};
private _PP_wetD = ppEffectCreate["WetDistortion", 300];
_PP_wetD ppEffectEnable true;
_PP_wetD ppEffectAdjust[1, (_effectMagnitude select 0), 0.15, 1, 1, 1, 1, 0.05, 0.01, 0.05, 0.01, 0.1, 0.1, 0.2, 0.2];
_PP_wetD ppEffectCommit 0;
private _PP_colorC = ppEffectCreate["ColorCorrections", 1500];
_PP_colorC ppEffectEnable true;
_PP_colorC ppEffectAdjust[1, 1, 0, [2, 2, -2, (_effectMagnitude select 1)], [1, 1, 1, 1], [0.33, 0.33, 0.33, 0], [0, 0, 0, 0, 0, 0, 4]];
_PP_colorC ppEffectCommit 10;
private _PP_film = ppEffectCreate["FilmGrain", 2000];
_PP_film ppEffectEnable true;
_PP_film ppEffectAdjust[(_effectMagnitude select 2), 1, 1, 0.5, 0.5, true];
_PP_film ppEffectCommit 5;
if !((uniform player) in _hazmatUniforms) then {
    titleText["<img size='3' image='icons\warningico.paa' /><t color='#ff0000' size='5'>CAUTION!</t><img size='3' image='icons\warningico.paa' /><br/> <t size='1.5'>You have entered a radiation zone!<br/> You will get Critical Radiation Poisoning from not wearing protective gear!</t>", "PLAIN", -1, true, true];
    uiSleep 3;
    [999999] call BIS_fnc_bloodEffect;
    while {((player distance _thisTrigger) < _zoneRadius)}
    do {private _centerDistance = player distance _thisTrigger;
        uiSleep 0.5;
        if ((_centerDistance < _zoneRadius) && ((damage _plb_obj) < 0.5)) then {
            private _effectPercent = (1 - (_centerDistance / _zoneRadius)) max 0;
            private _radDamage = (0.5 * _effectPercent) / 6.66;
            if ((damage _plb_obj) < 0.5) then {_plb_obj setDamage(((damage _plb_obj) + _radDamage) min 0.5)};};};} else {
    titleText["<img size='3' image='icons\warningico.paa' /><t color='#ff0000' size='5'>CAUTION!</t><img size='3' image='icons\warningico.paa' /><br/> <t size='1.5'>You have entered a radiation zone!</t>", "PLAIN", -1, true, true];
};
waitUntil {uiSleep 1;
    ((player distance2D _thisTrigger) > _zoneRadius)};
ppEffectDestroy[_PP_wetD, _PP_colorC, _PP_film];