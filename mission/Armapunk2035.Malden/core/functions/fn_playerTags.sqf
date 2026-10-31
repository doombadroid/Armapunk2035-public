disableSerialization;
if (visibleMap || {!alive player} || {dialog}) exitWith {500 cutText["", "PLAIN"];};
private _ui = uiNamespace getVariable["AP_hud_nametags", displayNull];
if (isNull _ui) then {500 cutRsc["AP_hud_nametags", "PLAIN"];
    _ui = uiNamespace getVariable["AP_hud_nametags", displayNull];
    uiNamespace setVariable["AP_tagTextCache", createHashMap];   // perf 2026-07-05: fresh controls -> drop stale per-tag text cache
};
// perf 2026-07-05: skip parseText+ctrlSetStructuredText (XML parse + text-layout, the dominant per-frame
// cost) when a tag's string is unchanged vs the last one set on that control. Position still updates every
// frame. Keyed by control idc; the cache is reset above whenever the display is (re)built.
private _tagTextCache = uiNamespace getVariable["AP_tagTextCache", createHashMap];
if (AP_targetTag) then {if !(isNull cursorTarget) then {if !(cursorTarget in AP_tag_units) then {
            if ((cursorTarget isKindOf "CAManBase" && isPlayer cursorTarget) || cursorTarget isKindOf "Car" || cursorTarget isKindOf "Air" || cursorTarget isKindOf "Ship") then {
                AP_tag_units pushBack cursorTarget;};};};};
private _eyePosVehicle =
if (isNull objectParent player) then {player} else {objectParent player}; {private _idc = _ui displayCtrl(78000 + _forEachIndex);
    private _targetEyePosVehicle =
    if (isNull objectParent _x) then {_x} else {objectParent _x};
    if (alive _x && {!(lineIntersects[eyePos _eyePosVehicle, eyePos _targetEyePosVehicle, _eyePosVehicle, _targetEyePosVehicle])}) then {
        private _pos = [visiblePosition _x select 0, visiblePosition _x select 1, ((_x modelToWorld(_x selectionPosition "head")) select 2) + 0.5];
        private _sPos = worldToScreen _pos;
        private _distance = _pos distance player;
        private _maxDistance =
        if (goggles _x in AP_masks) then {5} else {20};
        private _hidden = ((goggles _x in AP_masks) && (_distance > _maxDistance) && !(side _x isEqualTo independent));
        if (count _sPos > 1 && !(_x getVariable["AP_invisOn", false]) && {(_distance <= _maxDistance) || {
                AP_targetTag && _x isEqualTo cursorTarget}}) then {
            if (_x isKindOf "CAManBase" || (((crew _x) select { (AP_effSide isEqualTo west) || !(side _x isEqualTo west) }) isNotEqualTo [])) then {
                private _icon = call {if !(_x isKindOf "CAManBase") exitWith {
                        if (_x getVariable["AP_vehicleIconCache", ""] isEqualTo "") then {
                            _x setVariable["AP_vehicleIconCache", getText(configFile >> "CfgVehicles" >> typeOf _x >> "picture")];};
                        format["<img image='%1' size='1'></img>  ", _x getVariable["AP_vehicleIconCache", ""]];};
                    if (side _x isEqualTo independent) exitWith {
                        // TT rank icons. select 99 (EMT Volunteer) / out-of-range = SCRIPT ERROR, so clamp the index;
                        // 99 (volunteer) -> bottom-tier icon. 2026-08-13: renamed the ng_*.paa rank icons to tt_*.paa
                        // alongside the files themselves, and gave the rank-7 entry the .paa extension every sibling
                        // already had -- without it the path did not resolve and a TT Marshal drew a blank icon. The
                        // old claim that this art was never added is dropped: all seven files are present and tracked.
                        private _ttLvl = _x getVariable["AP_medLevel", 0];
                        if (_ttLvl isEqualTo 99) then { _ttLvl = 1 };
                        private _iconPath = ["", "icons\tt_private.paa", "icons\tt_corporal.paa", "icons\tt_sergeant.paa", "icons\tt_wo.paa", "icons\tt_lieutenant.paa", "icons\tt_commander.paa", "icons\tt_marshal.paa"] select ((_ttLvl min 7) max 0);
                        format["<img image='%1' size='1'></img>  ", MISSION_ROOT + _iconPath];};
                    if ((side _x isEqualTo west) && {_x getVariable["AP_showrank", true]}) exitWith {
                        private _iconPath = ["", "\A3\Ui_f\data\GUI\Cfg\Ranks\private_gs.paa", MISSION_ROOT + "icons\pfc_gs.paa", "\A3\Ui_f\data\GUI\Cfg\Ranks\corporal_gs.paa", "\A3\Ui_f\data\GUI\Cfg\Ranks\sergeant_gs.paa", "\A3\Ui_f\data\GUI\Cfg\Ranks\lieutenant_gs.paa", "\A3\Ui_f\data\GUI\Cfg\Ranks\captain_gs.paa", "\A3\Ui_f\data\GUI\Cfg\Ranks\colonel_gs.paa"] select(_x getVariable["AP_unitCopLevel", 0]);
                        format["<img image='%1' size='1'></img>  ", _iconPath];};
                    if ((_x getVariable["AP_aggressive", -300]) > (time - 300)) exitWith {
                        format["<img image='%1icons\rook.paa' size='1' shadow='0'></img>  ", MISSION_ROOT]};
                    if ((_x getVariable["gang_data", [-1]] select 0) in AP_gang_wars) exitWith {
                        format["<img image='%1icons\gangwar.paa' size='1' shadow='0'></img>  ", MISSION_ROOT]};
                    // Fixer war: same icon as a gang war, deliberately. To the player
                    // holding the rifle the two mean the identical thing -- this one is
                    // shootable and the admins will not take a report -- and inventing a
                    // second glyph for the same permission would be a thing to learn for
                    // no gain. AP_warHere is false for almost everyone almost everywhere,
                    // so this costs one boolean read per tag off the hot path.
                    if ([_x] call AP_fnc_factionHostile) exitWith {
                        format["<img image='%1icons\gangwar.paa' size='1' shadow='0'></img>  ", MISSION_ROOT]};
                    if (_x getVariable["AP_activeBounty", false]) exitWith {
                        format["<img image='%1icons\police.paa' size='1'></img>  ", MISSION_ROOT]};
                    if ((getPlayerUID _x) isEqualTo(SRV_governorData param[0, "Nah"])) exitWith {
                        format["<img image='%1icons\govern.paa' color='#FF0000' size='1'></img>  ", MISSION_ROOT]};""};
                private _text = call {if !(_x isKindOf "CAManBase") exitWith {private _text = []; {private _extra =
                            if (_forEachIndex > 0) then {", "} else {
                                ""}; if ((goggles _x in AP_masks) && {(_distance > _maxDistance)}) then {
                                if ((currentWeapon player in ["Binocular", "Rangefinder"] && {cameraView == "Gunner"
                                }) || (_x in (units group player))) then {
                                    _text pushBack(format["%1%3%2", _extra, (_x getVariable["AP_name", [name _x] call AP_fnc_cleanName]), ((group _x) getVariable["AP_grpTag", ""])])
                                } else {_text pushBack(format["%1Unknown", _extra]);};} else {
                                _text pushBack(format["%1%3%2", _extra, (_x getVariable["AP_name", [name _x] call AP_fnc_cleanName]), ((group _x) getVariable["AP_grpTag", ""])])
                            };}
                        // owner 2026-06-13: hide COP (west) occupants from non-cop viewers -- looking at a cop
                        // vehicle (esp. a chopper) was revealing the MaxSec officers inside to anyone. Cops still see cops.
                        forEach((crew _x) select { (AP_effSide isEqualTo west) || !(side _x isEqualTo west) });
                        _text};
                    if (_hidden) exitWith {if ((_x in (units group player)) || (currentWeapon player in ["Binocular", "Rangefinder"] && {
                            cameraView == "Gunner"})) then {_x getVariable["AP_name", [name _x] call AP_fnc_cleanName]} else {
                            "Unknown"};}; if ((side _x isEqualTo west) && {_x getVariable["AP_showrank", true]}) exitWith {
                        private _nameCache = _x getVariable["AP_nameCache", ""];
                        if (_nameCache isEqualTo "") then {private _prefix = call {private _text = "";
                                if (_x getVariable["AP_unitCopRetiredLevel", 0] != 0) then {_text =
                                    switch (_x getVariable["AP_unitCopRetiredLevel", 0]) do {case 4: {"Retired MaxSec Sergeant "};
                                        case 5: {"Retired MaxSec Lieutenant "};
                                        case 6: {"Retired MaxSec Captain "};
                                        default {""};};} else {_text =
                                    switch (_x getVariable["AP_unitCopLevel", 0]) do {case 1: {"MaxSec Cadet "};
                                        case 2: {"MaxSec Patrol Officer "};
                                        case 3: {"MaxSec Corporal "};
                                        case 4: {"MaxSec Sergeant "};
                                        case 5: {"MaxSec Lieutenant "};
                                        case 6: {"MaxSec Captain "};
                                        case 7: {"MaxSec Chief of Police "};
                                        default {""};};};
                                _text};
                            // owner 2026-06-13: the cop tag must ALWAYS show the NAME, not just the rank.
                            // AP_name can be "" for a cop whose data hasn't replicated yet (JIP/spawn race);
                            // getVariable then returns the literal "" (not the default), so the old code cached
                            // "MaxSec <rank> " with a blank name and FROZE it -> "rank only" forever. Fall back to
                            // name _x, and only persist the cache once we actually have a name (self-heals).
                            private _rawName = _x getVariable["AP_name", ""];
                            if (_rawName isEqualTo "") then { _rawName = name _x; };
                            private _name = [_rawName] call AP_fnc_cleanName;
                            _nameCache = format["%1 %2", _prefix, _name];
                            if (_name isNotEqualTo "") then { _x setVariable["AP_nameCache", _nameCache]; };};
                        _nameCache;};
                   if ((side _x isEqualTo independent) && {_x getVariable["AP_showrank", true]}) exitWith {
                        private _nameCache = _x getVariable["AP_nameCache", ""];
                        if (_nameCache isEqualTo "") then {private _ttLevel = _x getVariable["AP_medLevel", 0];
                            private _prefix = "";
                            if (_ttLevel isEqualTo 99) then {_prefix = "TT EMT Volunteer";} else {
                                _prefix = ["", "TT Private", "TT Corporal", "TT Sergeant", "TT Warrant Officer", "TT Lieutenant", "TT Commander", "TT Marshal"] select ((_ttLevel min 7) max 0);
                            };
                            // owner 2026-06-13: same name-always fix as the cop tag -- don't freeze a blank name
                            private _rawName = _x getVariable["AP_name", ""];
                            if (_rawName isEqualTo "") then { _rawName = name _x; };
                            private _name = [_rawName] call AP_fnc_cleanName;
                            _nameCache = format["%1 %2", _prefix, _name];
                            if (_name isNotEqualTo "") then { _x setVariable["AP_nameCache", _nameCache]; };};
                        _nameCache;};
                    if ((side _x isEqualTo civilian) && {_x getVariable["AP_newBlood", false]}) exitWith {
                        // owner 2026-07-11 (onboarding): NEW BLOOD tag -- fresh accounts are visibly marked so
                        // veterans know the rules protect them (RDM on a New Blood = harsher punishment; -NEWBLOOD-
                        // kill log backs enforcement). Cleared naturally once playtime passes the threshold.
                        private _rawName = _x getVariable["AP_name", ""];
                        if (_rawName isEqualTo "") then { _rawName = name _x; };
                        format ["[NEW BLOOD] %1", [_rawName] call AP_fnc_cleanName]};
                    if ((side _x isEqualTo civilian) && {_x getVariable["AP_unitPassiveMode", false]}) exitWith {
                        private _nameCache = _x getVariable["AP_nameCache", ""];
                        if (_nameCache isEqualTo "") then {private _prefix = "[PASSIVE MODE]";
                            // owner 2026-06-13: same name-always fix -- don't freeze a blank name
                            private _rawName = _x getVariable["AP_name", ""];
                            if (_rawName isEqualTo "") then { _rawName = name _x; };
                            private _name = [_rawName] call AP_fnc_cleanName;
                            _nameCache = format["%1 %2", _prefix, _name];
                            if (_name isNotEqualTo "") then { _x setVariable["AP_nameCache", _nameCache]; };};
                        _nameCache;};
                    if (local _x) then {_x getVariable["AP_name", ""];} else {
                        _x getVariable["AP_name", [name _x] call AP_fnc_cleanName];};};
                // Streamer Mode: censor profanity in the displayed name before it is decorated. _text is a String
                // for a person (incl. any rank/passive prefix) or an Array of crew names for a vehicle.
                if (!isNil "AP_streamerMode" && {AP_streamerMode}) then {if (_text isEqualType "") then {
                        _text = [_text] call AP_fnc_profanityFilter;} else {
                        if (_text isEqualType []) then { _text = _text apply { [_x] call AP_fnc_profanityFilter }; };};};
                if ((_x in allPlayers) && {!(_hidden)}) then {if (_x getVariable["AP_prefix", ""] isNotEqualTo "") then {
                        _text = format[_x getVariable["AP_prefix", ""], _text];};
                    private _title = ["", _x getVariable["AP_title", ["", "#B6B6B6"]]] select AP_showTitle;
                    if (((_x distance player) < 25) || ((currentWeapon player in ["Binocular", "Rangefinder"]) && {cameraView == "Gunner"
                    })) then {if !(((group _x) getVariable["gang_name", ""]) isEqualTo "") then {
                            private _groupName = ((group _x) getVariable["gang_name", ""]);
                            _text = format["%1<br/><t size='0.8' align='center' color='#B6B6B6'>%2</t>", _text, _groupName];} else {
                            private _index = [group _x, randomized_life_group_list] call AP_fnc_index;
                            private _groupName = (randomized_life_group_list param[_index, ""]) param[0, ""];
                            if !(_groupName isEqualTo "") exitWith {
                                _text = format["%1<br/><t size='0.8' align='center' color='#B6B6B6'>%2</t>", _text, _groupName];};};
                        _text = _text + format["<br/><t align='center' color='%2' size='0.7'>%1</t>", _title param[0, ""], _title param[1, "#B6B6B6"]];
                    };};
                private _color = call {if !(_x isKindOf "CAManBase") exitWith {
                        ((crew _x) select { (AP_effSide isEqualTo west) || !(side _x isEqualTo west) }) apply {call {
                                if (_x in (units group player) && {AP_effSide isEqualTo civilian}) exitWith {"00FF00"};
                                if ((_x getVariable["AP_aggressive", -300]) > (time - 300)) exitWith {"FF0000"};
                                if ((_x getVariable["gang_data", [-1]] select 0) in AP_gang_wars) exitWith {"FF0000"};
                                if ([_x] call AP_fnc_factionHostile) exitWith {"FF0000"};"FFFFFF"};};};
                    if (_x getVariable["AP_unitPassiveMode", false]) exitWith {"353635"};
                    if (_x in (units group player) && {AP_effSide isEqualTo civilian}) exitWith {"00FF00"};
                    if (!isPlayer _x && {_x isKindOf "CAManBase"}) exitWith {"CCCCCC"};
                    if ((_x getVariable["AP_aggressive", -300]) > (time - 300)) exitWith {"FF0000"};
                    if ((_x isKindOf "CAManBase") && {(_x getVariable["gang_data", [-1]] select 0) in AP_gang_wars}) exitWith {"FF0000"};
                    // Fixer war, inside a belligerent's territory. Sits with the other
                    // reds and ABOVE the New Blood green below it: a new player who has
                    // joined an aligned gang and walked into a war zone is engageable,
                    // and a green tag there would be a lie that gets somebody banned.
                    if ((_x isKindOf "CAManBase") && {[_x] call AP_fnc_factionHostile}) exitWith {"FF0000"};
                    // owner 2026-07-11: GREEN, deliberately -- green reads "friendly/protected" here (group/TT
                    // color). A hot color would read as an engageable target; New Bloods are the opposite:
                    // killable only WITH initiation, and RDM on them is punished harder.
                    if ((side _x isEqualTo civilian) && {_x getVariable["AP_newBlood", false]}) exitWith {"00FF00"};
                    if ((side _x isEqualTo west) && {_x getVariable["AP_showrank", true]}) exitWith {"1bc6fa"};
                    if (side _x isEqualTo independent) exitWith {"00FF00"};
                    [_x getVariable["AP_prefix", ""]] call AP_fnc_getTitleColor;};
                private _nameTag = call {if !(_x isKindOf "CAManBase") exitWith {
                        private _xNameTag = format["<t align='center'>%1", _icon]; {
                            _xNameTag = _xNameTag + format["<t color='#%2'>%1</t>", _x, _color select _forEachIndex];}
                        forEach _text;
                        format["%1</t>", _xNameTag];};
                    format["<t align='center'>%3<t color='#%2'>%1</t></t>", _text, _color, _icon]};
                private _tagKey = 78000 + _forEachIndex;
                if !((_tagTextCache getOrDefault [_tagKey, ""]) isEqualTo _nameTag) then {_idc ctrlSetStructuredText parseText _nameTag;
                    _tagTextCache set [_tagKey, _nameTag];};
                // owner 2026-06-13: center the tag on the head. The LIVE control is AP_hud_nametags
                // (chat_hud.hpp), width 0.30 -- NOT the legacy ga_hud_nametags 0.6 the old comment cited.
                // align='center' centers the text on the control's center (x + w/2), so the LEFT edge must sit
                // at headScreenX - 0.15 to land on the head. Size is set by the control font (~30% smaller);
                // scale stays 1 so there's no ctrlSetScale pivot ambiguity to skew the horizontal centering.
                _idc ctrlSetPosition[(_sPos select 0) - 0.15, _sPos select 1];
                _idc ctrlSetScale 1;
                _idc ctrlSetFade 0;
                _idc ctrlCommit 0;
                _idc ctrlShow true;} else {_idc ctrlShow false;};} else {_idc ctrlShow false;};} else {_idc ctrlShow false;};}
forEach AP_tag_units;
if (count AP_tag_cache > count AP_tag_units) then {for "_i"
    from(count AP_tag_units) to(count AP_tag_cache) - 1 do {private _idc = _ui displayCtrl(78000 + _i);
        _idc ctrlShow false;};};
