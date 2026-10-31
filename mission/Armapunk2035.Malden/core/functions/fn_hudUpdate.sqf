if (!hasInterface) exitWith {};   // LooneyBin: client-only fn -- legacy server senders use target `true` (= server too) -> undefined AP_* vars spammed the RPT (wanted_remove/wantedPardon/playerDisconnected)
disableSerialization;
if (AP_isDead) exitWith {};

// ---- PR14: THE NATIVE HUD IS RETIRED, NOT DELETED -------------------------------------------
// The owner's call after the STATUS HUD (core\web\fn_hudWebInit.sqf) was confirmed drawing in
// game: "remove the old HUD". Every NATIVE DRAWING statement this function ever ran is now
// inside the one `if (_nativeHud)` block below, and nothing inside it changed -- not a
// character, not the indentation, so `git diff -w` shows this file gaining a condition and
// losing nothing. What is NOT in that block is everything this function did that was never
// about pixels, because those consumers do not care which HUD is on screen:
//
//   * the bounty_apb / bounty_dot_apb marker cleanup, hoisted immediately below. It is the only
//     place that clears a cop's APB tracking markers when the APB itself expires -- the other
//     two deleters (fn_removeBounty, fn_trackAPB) fire on their own events, not on expiry -- so
//     leaving it inside the drawing block would have left dead markers on a cop's M map for as
//     long as the web HUD was on.
//   * the AP_fnc_hudWebPush tail, which is the web HUD's fastest refresh path.
//   * the four profileNamespace writes (AP_thirst / AP_hunger / AP_playerDamage / AP_playerDir),
//     which are read back on the next session and by the deck.
//
// THE ESCAPE HATCH IS THE SAME ONE FLAG THE WEB HUD ALREADY HAD: AP_webHudEnabled = false and
// the native HUD is the HUD again, whole, from the debug console, with no relog and no server
// change. Two other files were gated on the same flag so that "retired" means the layer is not
// even cut: AP_fnc_hudSetup no longer cuts AP_playerHUD at init, and the web keeper cuts layer 2
// down if anything else does (evh\fn_onPlayerKilled.sqf re-cuts it on every death). That
// matters because AP_playerHUD's class defaults are VISIBLE -- ui.hpp places every bar track,
// fill, icon and overlay at 0.8/0.85 and only this function ever moves them -- so a layer that
// is cut and never drawn into is a stack of placeholder bars in the middle of the screen.
//
// ONE SEMANTIC NOTE on the block below: its `if (isNull _ui) exitWith {...}` self-heal used to
// exit this FUNCTION and now exits the `then` block, so on the escape-hatch path, on the one
// tick where the layer is missing, the recursion's tail runs and then the tail below runs again.
// Both halves of that tail are idempotent (a change-gated push, four absolute setVariables), so
// the cost is one wasted pass and the behaviour is unchanged. Left verbatim rather than
// "improved": this block's whole value is being the old HUD, exactly.
private _nativeHud = !(missionNamespace getVariable ["AP_webHudEnabled", true]);

// NON-VISUAL, RUNS ON BOTH PATHS -- see above. Hoisted out of the centre-strip text builder.
if (AP_effSide isEqualTo west && (AP_allPointsBulletin isEqualTo[])) then {deleteMarkerLocal "bounty_apb";
    deleteMarkerLocal "bounty_dot_apb";};

if (_nativeHud) then {
private _ui = uiNameSpace getVariable["AP_playerHUD", displayNull];
private _control = _ui displayCtrl 23515;
private _header = _ui displayCtrl 23525;
private _leftHeader = _ui displayCtrl 23526;
if (isNull _ui) exitWith {2 cutRsc["AP_playerHUD", "PLAIN"];
    call AP_fnc_hudUpdate;};
_control ctrlSetPosition[safeZoneX, safeZoneY + safeZoneH - 0.04, safeZoneW, 0.04];
_header ctrlSetPosition[safeZoneX, safeZoneY, safeZoneW, 0.04];
private _hp = ceil(round((1 - (damage player)) * 100));
private _healthColor =
switch (true) do {case (_hp < 10): {"FF0000"};
    case (_hp < 20): {"FF4000"};
    case (_hp < 30): {"FF8000"};
    case (_hp < 40): {"FFB000"};
    case (_hp < 50): {"FFF000"};
    case (_hp < 60): {"D0FF00"};
    case (_hp < 70): {"90FF00"};
    case (_hp < 80): {"50FF00"};
    case (_hp < 90): {"25FF00"};
    default {"00FF00"};}; private _text = "<t align='center'>";
private _footText = "";
private _leftText = "";
// health / water / food now render as NIGHT CITY segmented bars, bottom-right (updated at the end of this fn).
// The centre strip keeps only wanted / bounty / APB / drone / passive status.
if (!isNil "AP_droneRechargeAt" && {AP_droneRechargeAt > time}) then {   // revive-drone battery recharge countdown
    _text = _text + format["<img size='1' image='icons\hud_norevive.paa' /><t color='#ff8c00'> Drone %1m</t>    ", (ceil ((AP_droneRechargeAt - time) / 60)) max 1];
};
private _apbText =
if (AP_allPointsBulletin param[1, ""] isEqualTo(getPlayerUID player)) then {" (APB)"} else {
    ""};   // wanted $ now shown as the NIGHT CITY WANTED bar (bottom-right), not in the centre strip
if !(AP_bounty_list isEqualTo[]) then {{_x params["_bountyPID", "_bountyName"];
        private _bounty = allPlayers param[allPlayers findIf {_bountyPID isEqualTo(getPlayerUID _x)}, objNull];
        if !(isNull _bounty) then {
            _text = _text + format["<img size='0.5' image='icons\hud_target.paa' /> <t size='1'>%1</t>    ", [_bountyName] call AP_fnc_cleanName];
        };}
    forEach AP_bounty_list;};
if (AP_effSide isEqualTo west && !(AP_allPointsBulletin isEqualTo[])) then {
    _footText = format["<t align='center'>APB: <t color='#ff0000'>%1</t> wanted for $%2</t>", AP_allPointsBulletin select 0, [AP_allPointsBulletin select 2] call AP_fnc_numberText];
};
if ((player getVariable["AP_can_revive", -1000]) > time) then {
    _text = _text + format["<img size='1' image='icons\hud_norevive.paa' /> %1    ", round((player getVariable["AP_can_revive", -1000]) - time)];
};
if (AP_passiveMode) then {private _passiveTime = 120 - A_stats_civTime;
    if (_passiveTime < 0) then {_passiveTime = 0;};
    private _passiveMinutes =
    if (_passiveTime isEqualTo 1) then {"minute"} else {"minutes"};
    _text = _text + format["<img size='1' image='icons\hud_passivemode.paa' /> Passive Mode (%1 %2)    ", _passiveTime, _passiveMinutes];};
_text = _text + "</t>";
_control ctrlSetStructuredText parseText _text;
_control ctrlCommit 0;
_header ctrlSetStructuredText parseText _footText;
_header ctrlCommit 0;
_leftHeader ctrlSetStructuredText parseText _leftText;
_leftHeader ctrlCommit 0;

// ── NIGHT CITY segmented survival bars, TRUE bottom-right via safeZone (position + fill + colour + value each tick) ──
private _rE = safeZoneX + safeZoneW;
private _bE = safeZoneY + safeZoneH;
private _iconW = 0.030; private _iconH = 0.038;
private _barW = 0.165;  private _barH = 0.023;
private _valW = 0.100;  private _gap = 0.010; private _rowH = 0.048;
private _left = _rE - (_iconW + _gap + _barW + _gap + _valW) - 0.022;
// vertical stack from the bottom: WANTED (bar + number) lowest, then FOOD / H2O / HP upward
private _marginB = 0.022;
private _wValY  = _bE - _marginB - 0.050;
private _wBarH  = 0.026;
private _wBarY  = _wValY - 0.005 - _wBarH;
private _foodTop = _wBarY - 0.014 - _rowH;
private _h2oTop  = _foodTop - _rowH;
private _hpTop   = _h2oTop - _rowH;

private _setBar = {params ["_iconIdc", "_trackIdc", "_fillIdc", "_overIdc", "_valIdc", "_val", "_isHP", "_rowTop"];
    private _barX = _left + _iconW + _gap;
    private _valX = _barX + _barW + _gap;
    private _barY = _rowTop + (_rowH - _barH) / 2;
    private _frac = ((0 max _val) min 100) / 100;
    private _col =
        if (_isHP) then {switch (true) do {case (_val < 50):  { [0.937, 0.192, 0.224, 1] };   // red    -- below half
                case (_val < 100): { [0.957, 0.686, 0.176, 1] };   // amber  -- not full
                default            { [0.325, 0.890, 0.612, 1] };    // mint   -- full
            };} else {switch (true) do {case (_val < 20): { [0.937, 0.192, 0.224, 1] };    // red
                case (_val < 40): { [0.957, 0.686, 0.176, 1] };    // amber
                default           { [0.216, 0.910, 0.941, 1] };    // cyan
            };};
    (_ui displayCtrl _iconIdc) ctrlSetPosition [_left, _rowTop + 0.002, _iconW, _iconH];
    (_ui displayCtrl _iconIdc) ctrlCommit 0;
    (_ui displayCtrl _trackIdc) ctrlSetPosition [_barX, _barY, _barW, _barH];
    (_ui displayCtrl _trackIdc) ctrlCommit 0;
    private _f = _ui displayCtrl _fillIdc;
    _f ctrlSetPosition [_barX, _barY, _frac * _barW, _barH];
    _f ctrlSetBackgroundColor _col;
    _f ctrlCommit 0;
    (_ui displayCtrl _overIdc) ctrlSetPosition [_barX, _barY, _barW, _barH];
    (_ui displayCtrl _overIdc) ctrlCommit 0;
    private _v = _ui displayCtrl _valIdc;
    _v ctrlSetPosition [_valX, _rowTop + 0.002, _valW, 0.044];
    _v ctrlSetStructuredText parseText str (round _val);
    _v ctrlCommit 0;};
[23535, 23530, 23531, 23532, 23534, _hp,         true,  _hpTop]   call _setBar;  // HP  (top)
[23545, 23540, 23541, 23542, 23544, APV_thirst, false, _h2oTop]  call _setBar;  // H2O (mid)
[23555, 23550, 23551, 23552, 23554, APV_hunger, false, _foodTop] call _setBar;  // FOOD (bottom)

// ── WANTED bar (civ only): neon-yellow 0-5000 bounty; full + red at 5000 = probable cause; $ climbs underneath ──
private _wanted = if (AP_effSide isEqualTo civilian) then { (A_stats_crimes param [0, 0]) max 0 } else { 0 };
private _wCtrls = [_ui displayCtrl 23560, _ui displayCtrl 23561, _ui displayCtrl 23562, _ui displayCtrl 23563, _ui displayCtrl 23564];
if (_wanted > 0) then {_wCtrls params ["_wIcon", "_wTrack", "_wFill", "_wOver", "_wVal"];
    private _wBarX = _left + _iconW + _gap;
    private _wBarW = _barW + _gap + _valW;               // wide bar (spans bar + value columns)
    private _wFrac = (_wanted min 5000) / 5000;
    private _wPC = _wanted >= 5000;                       // probable cause
    private _wCol = if (_wPC) then { [0.937, 0.192, 0.224, 1] } else { [0.957, 0.686, 0.176, 1] };  // red at PC, else neon-yellow
    { _x ctrlSetFade 0; } forEach _wCtrls;
    _wIcon ctrlSetPosition [_left, _wBarY - 0.005, _iconW, _iconH]; _wIcon ctrlCommit 0;
    _wTrack ctrlSetPosition [_wBarX, _wBarY, _wBarW, _wBarH]; _wTrack ctrlCommit 0;
    _wFill ctrlSetPosition [_wBarX, _wBarY, _wFrac * _wBarW, _wBarH]; _wFill ctrlSetBackgroundColor _wCol; _wFill ctrlCommit 0;
    _wOver ctrlSetPosition [_wBarX, _wBarY, _wBarW, _wBarH]; _wOver ctrlCommit 0;
    _wVal ctrlSetPosition [_wBarX, _wValY, _wBarW, 0.050];
    _wVal ctrlSetStructuredText parseText format ["<t align='center' color='%1'>WANTED  $%2</t>", (if (_wPC) then { "#ef3139" } else { "#f4af2d" }), [_wanted] call AP_fnc_numberText];
    _wVal ctrlCommit 0;} else {{ _x ctrlSetFade 1; _x ctrlCommit 0; } forEach _wCtrls;};
};   // ---- end of the native-drawing block (PR14) ----------------------------------------------

// PR13 STATUS HUD (web): the same numbers, into the transparent title-layer page one screen
// layer up (core\web\fn_hudWebPush.sqf, dialog\hudWeb.hpp). PR14 made this the ONLY HUD by
// default, so this call is now the normal path and the block above is the fallback -- but it is
// still a no-op costing one string compare when the layer is down (dead, or the cut has not
// landed yet). Still deliberately at the TAIL: on the escape-hatch path the WANTED branch above
// un-fades its own controls every tick, so anything that must run after a full native pass has
// to sit below it.
[] call AP_fnc_hudWebPush;

profileNamespace setVariable["AP_thirst", APV_thirst];
profileNamespace setVariable["AP_hunger", APV_hunger];
profileNamespace setVariable["AP_playerDamage", damage player];
profileNamespace setVariable["AP_playerDir", getDir vehicle player];