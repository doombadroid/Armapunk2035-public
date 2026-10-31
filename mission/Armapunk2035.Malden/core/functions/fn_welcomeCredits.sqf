if (isDedicated) exitWith {};
private _sizeTitle = 0.7;
private _sizeSubText = 0.55;
private _colorTitle = "#CC1111";
private _colorSubText = "#c0be94";
private _alignTitle = "right";
private _alignSubText = "right";
private _fontTitle = "PuristaSemibold";
private _fontSubText = "PuristaLight";
private _delay = 5;
private _fadeIn = 3;
private _wealthyList = "";
private _donorList = "";
// LooneyBin (owner, 2026-06-11): on-spawn credits roll de-monetized -- "Donators" + "Teamspeak"
// entries removed. Just Welcome / Most Wealthy / Roleplaying remain.
private _titles = ["Welcome to The LoonyBin", "Most Wealthy", "Roleplaying"];
private _shortTexts = ["The shortest standing Arma 3 Life RPG community", "", "LoonyBin is an RP community. Follow RDM and VDM rules!"];
private _posTexts = [[0.65, 0.5, 0.4], [0.65, 0.35, 0.25], [0.65, 0.5, 0.25]]; {
    _wealthyList = format["%1%2. %3<br/>", _wealthyList, _forEachIndex + 1, _x select 0];}
forEach AP_topWealth apply {_x select 0}; {_donorList = format["%1%2<br/>", _donorList, _x select 0];}
forEach AP_topDonor apply {_x select 0};
_shortTexts set[1, _wealthyList];
// (index 2 is now "Roleplaying" text -- donor list no longer injected)
uiSleep _delay; {private _title = _x;
    private _shortText = _shortTexts select _forEachIndex;
    private _posText = _posTexts select _forEachIndex;
    private _time = round(count toArray(_title + _shortText) / 6 / 2) + 3;
    private _message = format["<t size='%1' color='%2' align='%3' font='%4'>%5<br /></t>", _sizeTitle, _colorTitle, _alignTitle, _fontTitle, _title];
    _message = _message + format["<t size='%1' color='%2' align='%3' font='%4'>%5<br /></t>", _sizeSubText, _colorSubText, _alignSubText, _fontSubText, _shortText];
    [_message, [(_posText select 0) * safeZoneW + safeZoneX, _posText select 2],
        [(_posText select 1) * safezoneH + safezoneY, 1 * safezoneH + safezoneY], _time, _fadeIn] spawn BIS_fnc_dynamicText;
    uiSleep(_time + _fadeIn + 4);}
forEach _titles;