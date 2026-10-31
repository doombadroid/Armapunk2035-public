params[["_welcomeUI", false, [false]]];
disableSerialization;
"loadingScreen"
cutRsc["AP_loadingScreen", "PLAIN", -1, true];
private _plb_display = uiNamespace getVariable "AP_loadingScreen";
if (isNull _plb_display) exitWith {};
_plb_display displaySetEventHandler["keyDown", "_this call AP_fnc_displayHandler"];
private _loadingScreenText = _plb_display ctrlCreate["AP_RscStructuredText", -1];
_loadingScreenText ctrlSetPosition[0.178279 * safezoneW + safezoneX, 0.368 * safezoneH + safezoneY, 0.657876 * safezoneW, 0.055 * safezoneH];
_loadingScreenText ctrlSetBackgroundColor[-1, -1, -1, -1];
_loadingScreenText ctrlCommit 0;
if (!_welcomeUI) then {private _loadingScreenIcon = _plb_display ctrlCreate["AP_RscPictureKeepAspect", -1];
    _loadingScreenIcon ctrlSetPosition[0.386562 * safezoneW + safezoneX, 0.434 * safezoneH + safezoneY, 0.216563 * safezoneW, 0.286 * safezoneH];
    _loadingScreenIcon ctrlSetBackgroundColor[-1, -1, -1, -1];
    _loadingScreenIcon ctrlSetText "A3\Missions_F_Exp\data\Img\lobby\ui_campaign_lobby_background_tablet_radial_left_ca.paa";
    _loadingScreenIcon ctrlCommit 0;
    private _angle = 0;
    while {AP_loadingScreenStatus isNotEqualTo "LoonyBin Client Loaded"}
    do {if (_angle > 359) then {_angle = 0};
        _loadingScreenIcon ctrlSetAngle[_angle, 0.5, 0.5];
        _angle = _angle + 1;
        _loadingScreenText ctrlSetStructuredText parseText(format["<t size='1.5' align='center'>%1</t>", AP_loadingScreenStatus]);
        _loadingScreenText ctrlCommit 0.00055;
        uiSleep 0.00055;}; waitUntil {(AP_loadingScreenStatus isEqualTo "LoonyBin Client Loaded")};
    _loadingScreenText ctrlSetStructuredText parseText(format["<t size='1.5' align='center'>%1</t>", AP_loadingScreenStatus]);
    _loadingScreenIcon ctrlSetAngle[0, 0, 0];
    _loadingScreenIcon ctrlSetText(format["mpmissions\__cur_mp.%1\icons\checkmark.paa", toLower AP_worldName]);};