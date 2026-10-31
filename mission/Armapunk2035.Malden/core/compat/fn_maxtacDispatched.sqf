// AP_fnc_maxtacDispatched -- LooneyBin: MaxTac summons receiver (restored 2026-06-11).
// Server AP_fnc_maxtacDispatch remoteExecs [ _locations, _center ] to each eligible officer when the
// Federal Reserve alarm trips. Notifies + offers a "Join MaxTac" scroll action. Accepting applies MaxTac
// kit and calls APS_fnc_registerMaxTac, which adds the officer to AP_maxtac_active server-side; the
// (intact) server flow then assigns roles, spawns the MaxTac MRAP/boat and deploys the squad.
params [["_locations", [], [[]]], ["_center", [0,0,0], [[]]]];
if (side player != west) exitWith {};

AP_MAXTACActionAvail = true; [
    "<t color='#316dff'><t size='1.6'><t align='center'>MaxTac Activated</t></t></t><br/><br/><t align='left'><t size='0.85'><t color='#ffffff'>A major crime is in progress and MaxTac has been called up.<br/><br/><t color='#33CC33'>Use your scroll wheel -> <t color='#ffffff'>Join MaxTac Deployment<t color='#33CC33'> to gear up and deploy with the squad.",
    "copmsg"] spawn AP_fnc_handleMessage;
if (!(_center isEqualTo [0,0,0]) && {(_center select 0) > 0}) then {
    ["MaxTac", _center, " MaxTac Staging -", "colorBLUFOR", "mil_warning", 240] spawn AP_fnc_createLMarker;};

// Add the join action exactly once per session; visibility is gated by the condition string.
if (isNil { player getVariable "AP_maxtacJoinAct" }) then {private _act = player addAction ["<t color='#3399FF'>Join MaxTac Deployment</t>", {
            if (AP_activeMAXTAC) exitWith {};
            AP_maxtacLoadout = getUnitLoadout player;
            player setUnitLoadout [["srifle_DMR_03_F", "", "acc_pointer_IR", "optic_Arco_blk_F", ["20Rnd_762x51_Mag", 20],
                [], ""], [], [], ["U_B_CombatUniform_mcam_worn", [["FirstAidKit", 2], ["SmokeShellBlue", 2, 1], ["SmokeShell", 2, 1],
                ["SmokeShellGreen", 2, 1]]], ["V_PlateCarrier1_blk", [["20Rnd_762x51_Mag", 10, 20]]], ["B_AssaultPack_blk", [
                ["20Rnd_762x51_Mag", 10, 20]]], "H_CrewHelmetHeli_B", "G_Balaclava_blk", ["Rangefinder", "", "", "", [],
                [], ""], ["ItemMap", "ItemGPS", "", "ItemCompass", "", "Integrated_NVG_F"]];
            // 2026-08-13: dropped `[uniform player, "setIdx", 10]` here -- id 10 was the MaxTac uniform
            // retexture (c_combat_police_co.jpg), deleted with the rest of the custom police skin art.
            // setIdx no-ops on a missing row, so the call was silently doing nothing. The deployment
            // loadout above still issues the stock U_B_CombatUniform_mcam_worn.
            [] spawn {uiSleep 0.5;
                [] call AP_fnc_giveMedkits;};
            AP_activeMAXTAC = true;
            AP_isMaxTac = true;
            [[player], "APS_fnc_registerMaxTac", 2] spawn AP_fnc_MP;
            ["You joined MaxTac. Stand by -- the squad MRAP is being staged for deployment.", "basic"] spawn AP_fnc_handleMessage;},
        nil, 1.5, false, true, "","AP_MAXTACActionAvail && !AP_activeMAXTAC"];
    player setVariable ["AP_maxtacJoinAct", _act];};
