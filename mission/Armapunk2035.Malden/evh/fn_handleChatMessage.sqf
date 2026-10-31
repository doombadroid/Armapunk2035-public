params["_channel", "_owner", "_from", "_text", "_person", "_name", "_strID", "_forcedDisplay", "_isPlayerMessage", "_sentenceType", "_chatMessageType", "_unknownParam"];
if (!isNil "AP_streamerMode" && {AP_streamerMode}) then { _text = [_text] call AP_fnc_profanityFilter; };
private _hideMsg = false;
if (true) then {
    // LoonyBin (owner): chat word-filter removed -- side/global/direct chat is uncensored.
    if (_channel isEqualTo 3 && (("Regroup" in _text) || ("Grid:" in _text) || ("Contact -" in _text))) exitWith {_hideMsg = true;};
    if (_channel isEqualTo 17) exitWith {if ("- " in _text) then {if (A_stats_civTime < 300) then {
                [_text, "fromadmin"] spawn AP_fnc_handleMessage;};} else {if !("VIP" in _text) then {
                [_text, "fromadmin"] spawn AP_fnc_handleMessage;};};};};

// ideally we use regexMatch for this to prevent false positives but regex hurts my brain and its 3am 
// or alternatively we could go into the server profile config and set deathmessages = 0 
// do ^ if this becomes problamatic 
private _lowerText = toLower _text;
if ("was killed by" in _lowerText || "has died" in _lowerText) then {
    //_hideMsg = true;
};

// LooneyBin (owner, 2026-06-11): persistent chat history. Feed displayed social-channel messages
// (0 global / 1 side / 5 direct) into a bottom-left HUD that keeps the last 12 lines so you can read
// recent chat instead of it fading. Skips hidden (filtered) messages.
if (hasInterface && !_hideMsg && {_isPlayerMessage} && {_channel in [0, 1, 5]} && {!(_text isEqualTo "")}) then {
    if (isNil "AP_chatLog") then { AP_chatLog = []; };
    private _who = if (_from isEqualTo "") then { _name } else { _from };
    private _col = ["#7fb8ff", "#7dff9e", "#ffffff", "#ffffff", "#ffffff", "#dddddd"] param [_channel, "#ffffff"];
    AP_chatLog pushBack format ["<t color='%1' size='0.9'>%2:</t> %3", _col, _who, _text];
    while { count AP_chatLog > 12 } do { AP_chatLog deleteAt 0; };
    if (isNull (uiNamespace getVariable ["AP_chat_hud", displayNull])) then { 131 cutRsc ["AP_chat_hud", "PLAIN", -1, true]; };
    private _d = uiNamespace getVariable ["AP_chat_hud", displayNull];
    if (!isNull _d) then { (_d displayCtrl 246001) ctrlSetStructuredText parseText (AP_chatLog joinString "<br/>"); };};
// Streamer Mode: return the profanity-filtered text as a String override so the NATIVE chat line renders the
// censored version. HandleChatMessage returns: true = hide the line, String = replace the displayed text (sender
// name kept). Editing _text alone does nothing -- only the return value reaches the engine. Covers own + others'
// messages on social channels (0 global / 1 side / 3 group / 4 vehicle / 5 direct).
if (_hideMsg) exitWith { true };
if (!isNil "AP_streamerMode" && {AP_streamerMode}) exitWith {
    // Censor names + text everywhere the engine renders this line. For a player social message return [from, text]
    // to replace the sender NAME and the text; for anything else (kill feed / system notices that embed player
    // names) return the already-filtered text. Non-streamers fall through to normal display (false).
    if (_isPlayerMessage && {_channel in [0, 1, 3, 4, 5]} && {!(_from isEqualTo "")}) then {[[_from] call AP_fnc_profanityFilter, _text]
    } else {_text}};
false