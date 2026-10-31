/*
    File: fn_mapRowText.sqf  (AP_fnc_mapRowText)
    One wire row -> its SQF literal, parseable by parseSimpleArray. The ONLY row serialiser.

    Numbers go through toFixed: str and format print SIX significant figures, so a world
    coordinate like 7216.602 would come out as "7216.6" (BIKI toFixed; the six-digit money
    footgun of 2026-09-03 is the same conversion). Strings, booleans and the loadout array go
    through str, which doubles every " -- exactly what parseSimpleArray reverses.

    Row: [class, [x,y,z], [[vdir],[vup]], init, isServer, loadout, id,
          model, scale, lod, streamR (-1 = default), onServer]
*/
params [["_r", [], [[]]]];
_r params ["_cls", "_p", "_du", "_init", "_srv", "_lo", "_id",
           ["_model", "", [""]], ["_scale", 1, [0]], ["_lod", 1, [0]], ["_sr", -1, [0]], ["_os", false, [false]]];
_du params [["_d", [0,1,0], [[]]], ["_u", [0,0,1], [[]]]];
"[" + (str _cls)
    + ",[" + ((_p select 0) toFixed 3) + "," + ((_p select 1) toFixed 3) + "," + ((_p select 2) toFixed 3)
    + "],[[" + ((_d select 0) toFixed 4) + "," + ((_d select 1) toFixed 4) + "," + ((_d select 2) toFixed 4)
    + "],[" + ((_u select 0) toFixed 4) + "," + ((_u select 1) toFixed 4) + "," + ((_u select 2) toFixed 4)
    + "]]," + (str _init) + "," + (str _srv) + "," + (str _lo) + "," + (_id toFixed 0)
    + "," + (str _model) + "," + (_scale toFixed 3) + "," + (_lod toFixed 0) + "," + (_sr toFixed 1) + "," + (str _os)
    + "]"
