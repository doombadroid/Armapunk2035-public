// LooneyBin :: probe 3DEN coordinate conventions so the importer can be made correct.
// Run in the 3DEN Debug Console:  call compile preprocessFileLineNumbers "edenProbe.sqf"
// Then relay the "PROBE ..." line (systemChat / clipboard / RPT).

if (!is3DEN) exitWith { systemChat "probe: run inside the 3DEN editor."; };

private _x = 13807; private _y = 18965;
private _g = getTerrainHeightASL [_x,_y];                 // terrain ASL at the cop shop
private _e = create3DENEntity ["Object","Land_PaperBox_closed_F",[_x,_y,0],false];
_e set3DENAttribute ["position",[_x,_y,_g + 5]];         // I set the attribute to (ground+5) AS-IF ASL

private _f = { (round (_this * 100)) / 100 };

private _r = format [
  "PROBE ground=%1 | setAttrPosASL=%2 | objATL_z=%3 objASL_z=%4 | attrReadback=%5 | ATLtoASL[x,y,0]=%6",
  _g call _f,
  (_g + 5) call _f,
  ((getPosATL _e) select 2) call _f,
  ((getPosASL _e) select 2) call _f,
  _e get3DENAttribute "position",
  ATLToASL [_x,_y,0]
];
systemChat _r;
diag_log _r;
copyToClipboard _r;
