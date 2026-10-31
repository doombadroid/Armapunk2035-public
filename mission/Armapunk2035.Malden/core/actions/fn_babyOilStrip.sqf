#include "..\..\macro.h"
/*
    AP_fnc_babyOilStrip  (LooneyBin, owner 2026-06-25) -- runs on the RESTRAINED target's OWN client (forwarded
    by APS_fnc_victimSRV "babyoil" for AP_fnc_babyOil). Strips them to their underwear (weapons + worn
    clothing/containers + linked items all removed -> the gear is GONE, not dropped) and tells them they got oiled.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server hop only: APS_fnc_victimSRV checks actor/range/state
if (isNull player) exitWith {};
removeAllWeapons player;
removeGoggles player;
removeHeadgear player;
{ player unlinkItem _x } forEach (assignedItems player);   // map/compass/GPS/watch/NVG/binos etc.
removeVest player;
removeBackpackGlobal player;
removeUniform player;                                      // -> down to underwear
["You're covered in baby oil", "basic"] spawn AP_fnc_handleMessage;
