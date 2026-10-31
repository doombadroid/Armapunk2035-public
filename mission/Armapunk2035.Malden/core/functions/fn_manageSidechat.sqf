
// sidechat needs to be setup correctly I went into description.ext and disabled the default sidechat 
// and let the server setup generate the sidechat previous methods like north trying to set the groupID in join group may have worked but didnt include gang groups
// as well as I can see a couple ways how we could get errors from changing the groupID
// I dont see as to why not create a sidechat channel it appears the Ai had also previously mentioned script fails due to the sidechat not being setup

params[["_enable", true, [true]], ["_unit", player, [objNull]]];

if (AP_effSide isEqualTo west || AP_effSide isEqualTo independent || isNull _unit) exitWith {};   // owner 2026-06-26 reconcile: exit cops/null FIRST -- was AFTER the nil-check, so every cop call hit the "error" toast. owner 2026-06-27 (#5): also exit TT/independent -- they have no civ radio channel (else->nil) so they hit the same error toast on every login/spawn/ClupdatePartial; the civ-only radio system stays untouched by design
private _radio = if (AP_effSide isEqualTo civilian) then {AP_radio_civ} else {nil};   // owner 2026-06-26: was lifeState_radio_civ (undefined). init.sqf creates AP_radio_civ.

if (isNil "_radio" || {_radio isEqualType ""}) exitWith {["An error occured. Please try again", "basic"] spawn AP_fnc_handleMessage};

private _radioInfo = radioChannelInfo _radio;
private _radioUnits = _radioInfo select 3;

if (_enable) then {if !(_unit in _radioUnits) then {_radio radioChannelAdd [_unit];};} else {_radio radioChannelRemove [_unit];};

// owner 2026-06-19 (#326): the side-chat toggle was a NO-OP. It drove custom radioChannelCreate channels
// (AP_radio_civ/med) that the server never creates, so _radio stayed a String "" and the fn exited at the
// isEqualType-0 guard every call. Drive the ENGINE Side channel (1) instead -- enable/disable side text+voice
// for the local player. (Cops/west keep their own dispatch channels untouched.) Re-applied on respawn/revive/
// ClupdatePartial like before, so the setting survives those resets.
// owner 2026-06-19: side VOICE (VON) is now ALWAYS OFF -- the toggle controls side TEXT only. Previously
// `[_enable,_enable]` re-enabled side voice for the local player (default on), overriding the global
// disableChannels {1,false,true} voice-off, letting people talk in side via the Voice-Over-Net button.
1 enableChannel [_enable, false];
6 enableChannel [_enable, false];
