AP_loginBonusData params["_playerUID", "_consecutiveDays", "_needsGift", "_wipeProgress"];
if (_consecutiveDays >= 101) exitWith {};
if !(_needsGift) exitWith {
    [format["You have no login bonus loot at the moment! You have been playing everyday for the past %1 day(s)", AP_loginBonusData param[1, 0]], "basic"] spawn AP_fnc_handleMessage;
};
if (AP_effSide isNotEqualTo civilian) exitWith {
    ["You must be on civilian to open a login bonus crate!", "basic"] spawn AP_fnc_handleMessage;};
if !(isNull objectParent player) exitWith {
    ["You must be outside a vehicle to check your login bonus!", "basic"] spawn AP_fnc_handleMessage;};
if ((AP_is_arrested param [0,0]) isEqualTo 1) exitWith {
    ["You cannot redeem your login bonus while you are in prison!", "basic"] spawn AP_fnc_handleMessage;};
private _dialogQuestion = ["Do you want to open your login bonus crate?", "LoonyBin Login Bonus", "Yes", "No"] call BIS_fnc_guiMessage;
if !(_dialogQuestion) exitWith {["You chose not open your LoonyBin Login Bonus Crate!", "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0;};
private _tierTable = ["getCfg"] call AP_fnc_loginBonusCfg;
private _rewardIDX = _tierTable findIf {(_x param[0, 0]) isEqualTo _consecutiveDays};
private _getPicture = {params["_isPhysical", "_itemClassname"];
    if (_isPhysical) then {([_itemClassname] call AP_fnc_fetchCfgDetails) param[2, ""]} else {
        ["getIcon", _itemClassname] call AP_fnc_virtItemCfg};};
if (_rewardIDX isNotEqualTo - 1) then {
    (["get3Tiers", _rewardIDX] call AP_fnc_loginBonusCfg) params["_previousTier", "_currentTier", "_nextTier"];
    disableUserInput true;
    switch (_rewardIDX) do {case (0): {_nextTier = _currentTier;
                _currentTier = _previousTier;
                _previousTier = [];};
        case (50): {_nextTier = [];};};
    ["loginbonus_menu"] call AP_fnc_createDialog;
    disableSerialization;
    waitUntil {!isNull(findDisplay 635000)};
    private _display = findDisplay 635000;
    private _tickBox1 = _display displayCtrl 635001;
    private _tickBox2 = _display displayCtrl 635002;
    private _tickBox3 = _display displayCtrl 635003;
    private _rewardFrame = _display displayCtrl 635005;
    private _closeButton = _display displayCtrl 635004;
    _closeButton ctrlEnable false;
    private _tickBox1Picture =
    if (_previousTier isNotEqualTo[]) then {
        [!(_previousTier param[2, false]), ((_previousTier param[1, []]) param[0, ""])] call _getPicture} else {""};
    private _tickBox2Picture =
    if (_currentTier isNotEqualTo[]) then {[!(_currentTier param[2, false]), ((_currentTier param[1, []]) param[0, ""])] call _getPicture
    } else {""};
    private _tickBox3Picture =
    if (_nextTier isNotEqualTo[]) then {[!(_nextTier param[2, false]), ((_nextTier param[1, []]) param[0, ""])] call _getPicture} else {
        ""};
    private _randomPicture = "";
    _tickBox1 ctrlSetFade 0.65;
    _tickBox1 ctrlCommit 0;
    _tickBox3 ctrlSetFade 0.65;
    _tickBox3 ctrlCommit 0;
    // LooneyBin 2026-06-11 (owner): drop the fake "random" slot-machine spin -- reveal + grant instantly.
    _rewardFrame ctrlShow true;
    playSound(selectRandom["lootreward1", "lootreward2", "lootreward3"]);
    _tickBox1 ctrlSetText format["%1", _tickBox1Picture];
    _tickBox2 ctrlSetText format["%1", _tickBox2Picture];
    _tickBox3 ctrlSetText format["%1", _tickBox3Picture];
    disableUserInput false;
    [_rewardIDX] spawn AP_fnc_loginBonusGive;
    _closeButton ctrlEnable true;};