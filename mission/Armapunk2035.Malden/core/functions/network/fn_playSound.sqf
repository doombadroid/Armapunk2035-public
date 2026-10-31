params[["_source", objNull, [objNull]], ["_sound", "", [""]], "_isPlaySound", ["_range", 0, [0]]];
// owner 2026-06-25: slot-3 was typed [false] -> a caller passing a NUMBER there (range meant for slot 4) threw
// "Params: Type Number, expected Bool" ~320x/day across many civs. Drop the rigid type-spec + coerce: a number in
// slot 3 is treated as the say3D range; any other non-bool falls back to false. Sound still plays either way.
if (isNil "_isPlaySound") then { _isPlaySound = false };
if (_isPlaySound isEqualType 0) then { if (_range <= 0) then { _range = _isPlaySound }; _isPlaySound = false; };
if !(_isPlaySound isEqualType true) then { _isPlaySound = false };
if (isNull _source && !(_isPlaySound)) exitWith {};
if (_isPlaySound) then {playSound _sound;} else {
    if (_range > 0) then {   // optional explicit say3D max distance (e.g. drone siren matches the van's 650 m)
        _source say3D [_sound, _range];} else {_source say3D _sound;};};
