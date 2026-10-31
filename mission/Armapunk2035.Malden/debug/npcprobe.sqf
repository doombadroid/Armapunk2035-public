/*
    npcprobe.sqf -- mark where a shop NPC should stand.

    Walk to the spot, FACE THE WAY THE NPC SHOULD FACE, and run one line per NPC:

        ["gun"] call AP_npcMark;

    The tag is the shop / variant id from the catalogue (tools/npc_place.py --list).
    Then run tools/npc_place.py and the rows are written into fn_mapData.sqf.

    WHY IN-GAME AND NOT EDEN. A shop NPC has to be a client-local mapData row -- the trailing
    `false` -- so each player instantiates their own copy and a scroll-wheel addAction works. An
    Eden-placed unit is a server-owned AI and would buy nothing. mapData rows are also APPEND-only,
    which is the operation that has proven safe on this file; deleting from the middle of the .sqm
    breaks the Item numbering and the mission stops loading.

    Position is getPosATL because that is the frame fn_createVehicleLocal applies with setPosATL.
    Heading is getDir, converted to a vector by the generator -- NOT here, so the conversion lives
    in one place.
*/

AP_npcMark = {
    params [["_tag", "", [""]]];
    if (_tag isEqualTo "") exitWith { hint "npcprobe: give a tag, e.g. [""gun""] call AP_npcMark;"; };
    private _p = getPosATL player;
    private _d = getDir player;
    diag_log format ["-NPCPLACE- %1|%2|%3|%4|%5",
        _tag, (_p select 0) toFixed 3, (_p select 1) toFixed 3, (_p select 2) toFixed 3, _d toFixed 4];
    if (isNil "AP_npcMarked") then { AP_npcMarked = []; };
    AP_npcMarked pushBack _tag;
    hint format ["-NPCPLACE- %1\npos %2\nheading %3\n\nmarked so far: %4",
        _tag, (_p apply { round _x }), round _d, AP_npcMarked];
};

hint "npcprobe loaded.\n\nStand where the NPC goes, face the way it should face, then:\n\n    [""gun""] call AP_npcMark;";

/*
    AP_npcFace -- point an NPC at you.

    mapData rows are placed with heading 0 (due north) because a comment carries a position and no
    facing. Walk up to the NPC, stand where a player would approach from, aim at it, and run:

        [] call AP_npcFace;

    It logs the heading that makes that NPC face you. Hand the -NPCFACE- lines back and the rows are
    updated. vectorDir is [sin(h), cos(h), 0] clockwise from north -- the conversion stays in
    tools/npc_place.py so there is exactly one copy of it.
*/
AP_npcFace = {
    private _npc = cursorObject;
    if (isNull _npc) exitWith { hint "aim at the NPC first"; };
    private _p = getPosATL _npc;
    private _h = ((getPosATL player) select 0 - (_p select 0)) atan2 ((getPosATL player) select 1 - (_p select 1));
    if (_h < 0) then { _h = _h + 360; };
    diag_log format ["-NPCFACE- %1|%2|%3|%4", typeOf _npc, (_p select 0) toFixed 3, (_p select 1) toFixed 3, _h toFixed 4];
    hint format ["%1\nat %2\nshould face %3 deg", typeOf _npc, (_p apply { round _x }), round _h];
};
