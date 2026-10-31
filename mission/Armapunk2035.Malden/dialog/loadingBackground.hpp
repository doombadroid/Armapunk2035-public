class AP_loadingScreen {idd = 388000;
    name = "AP_loadingScreen";
    duration = 1e+007;
    movingEnable = 0;
    fadein = 0;
    fadeout = 0;
    onLoad = "uiNamespace setVariable ['AP_loadingScreen', _this select 0]";
    onUnload = "uiNamespace setVariable ['AP_loadingScreen', nil]";
    class controls {
        // black backing so the letterbox gaps never show the world behind (aspect mismatch on 16:9 clients)
        class loadingBlack: AP_RscText {idc = -1;
            text = "";
            x = safeZoneX;
            y = SafeZoneY;
            w = safeZoneW;
            h = safeZoneH;
            colorBackground[] = {0.016, 0.02, 0.031, 1};};
        class loadingPicture: AP_RscPictureKeepAspect {idc = 388001;
            onLoad = "(_this select 0 ) ctrlSetText 'images\splash_join.jpg';";
            x = safeZoneX;
            y = SafeZoneY;
            w = safeZoneW;
            h = safeZoneH;
            colorBackground[] = {0, 0, 0, 0};};};};