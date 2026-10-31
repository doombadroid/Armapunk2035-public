#include"..\macro.h"
private _plb_obj=player;

AP_actions= [];

// LUXE SUITES kiosk (suites.md) -- the lobby directory for leasing a lux-tower
// floor. Player-side action gated on a tagged cursorObject, the same convention
// every other world-object action in this file uses.
// LUXE SUITES door -- the tenant's lock toggle, shown only at the front door of a
// suite they hold. b0350: this is the other half of the lock the lease sets; it
// did not exist, so leasing shut the tenant out of their own floor for good.
AP_actions pushBack(_plb_obj addAction ["<t color='#0db8ff'>Lock / Unlock Suite</t>", {
        private _i = AP_LUXDOOR_NEAR;
        if (_i < 0) exitWith {};
        private _lf = (AP_LUXDOOR_LEAVES select _i) select 0;
        private _oid = _lf getVariable ["AP_suiteOid", ""];
        if (_oid isEqualTo "") exitWith {};
        private _now = _lf getVariable ["ap_doorLocked", false];
        [["lock", _oid, ([1, 0] select _now)], "APS_fnc_suiteSRV", 2] spawn AP_fnc_MP;
        [format ["Suite %1.", ["locked", "unlocked"] select _now], "basic"] spawn AP_fnc_handleMessage;
    },nil,59,false,false,"",'!isNil "AP_LUXDOOR_NEAR" && {AP_LUXDOOR_NEAR >= 0} && {!isNil "AP_LUXDOOR_LEAVES"} && {(((AP_LUXDOOR_LEAVES select AP_LUXDOOR_NEAR) select 0) getVariable ["ap_suiteOwner", ""]) isEqualTo (getPlayerUID player)}',4]);

AP_actions pushBack(_plb_obj addAction ["<t color='#0db8ff'>Luxe Suites Directory</t>", {
        [cursorObject] spawn AP_fnc_suiteKiosk},nil,60,false,false,"",'!isNull cursorObject && {(typeOf cursorObject) isEqualTo "GalleryDioramaUnit_01_F"} && {player distance cursorObject < 4} && {AP_effSide isEqualTo civilian} && {isNull objectParent player}',4]);

// FACTION REWORK -- the two HQ duty terminals. Both conditions open with AP_dutyEnabled read through a
// getVariable default, so with the flag false (the kill-switch/rollback state) neither entry can ever render, and a
// client that has not yet received the publish reads false instead of raising. The same action clocks OFF
// when you are already on that faction's shift -- AP_fnc_dutyTerminal turns the request around itself.
// cop_spawn_2 is "Emergency Response HQ" (dialog\function\fn_spawnPointCfg.sqf:8), the MaxSec main station.
// med_spawn_1 IS in mission.sqm as of PR6 -- [7200, 7850], the main hospital -- so this action now resolves
// to a real place instead of [0,0,0]. Both radii stay at 5 m, and deliberately the SAME 5 m: the two
// terminals are one mechanism with one faction switch, so a player who has learned where to stand at one
// station should not find the other has a different reach. Widening it for the hospital forecourt was
// considered and dropped for that reason -- if 5 m turns out to be tight in-world, both move together.
//
// RESOLVED -- OWNER DECISION ANSWERED. Both terminals used to share respawn_west with the La Trinite
// spawn-select holding pen (all four respawn_* anchors shipped stacked at civ_spawn_1, mission.sqm
// Item4303-4306), so AP_fnc_dutyFlushBlock's old 1000 m no-gear-save ring -- built for fn_saveGear.sqf:25,
// fn_ClupdatePartial.sqf's case 3 and fn_ClupdateRequest.sqf:35, which all still silently drop a gear save
// inside it -- blocked whichever terminal happened to land closest to the anchor. respawn_west now sits AT
// cop_spawn_2 (MaxSec HQ) instead: the Trauma terminal at med_spawn_1 is ~5.04 km clear, and the MaxSec
// terminal is dead centre of its own ring, ~0 m by construction -- so it refused every MaxSec sign-on and
// clock-off in turn, exactly the same failure this paragraph used to describe for Trauma.
// FIXED, as of this commit: the MaxSec terminal's duty-swap flush is exempted from that ring.
// AP_dutyFlushBypass (fn_dutyClient.sqf, set only around its own flush calls) lets the sign-on/clock-off
// gear+position flush cross fn_saveGear.sqf and fn_ClupdatePartial.sqf's case 3 for real; any ORGANIC gear
// save near the base -- periodic PFH, spawn-in, fn_ClupdateRequest.sqf's own tick -- reads the flag's false
// default and stays ring-blocked exactly as before. Full trace in fn_dutyFlushBlock.sqf's header. The wider
// La Trinite defect -- civilian gear still not persisting near town, because respawn_civilian/guerrila/east
// are still stacked at civ_spawn_1 -- is untouched by this fix and remains a separate owner call.
// The terminals are the owner's tablet props (map layer, 2026-08-20). Object-attached actions never
// rendered in the owner's playtest (mapData plain rows spawn as createSimpleObject -- no action
// support), so the action is PLAYER-attached, shown while any tablet of the class is within 5m.
// The HQ pick (which faction's terminal) keys on which HQ the player is standing at.
{
    _x params ["_faction", "_label", "_colour", "_tabs", "_open", ["_whenOnDuty", false]];
    AP_actions pushBack (player addAction [format ["<t color='%1'>%2</t>", _colour, _label], _open,
        _faction, 5, false, true, "",
        format ['(missionNamespace getVariable ["AP_dutyEnabled", false]) && {!dialog} && {isNull objectParent player} && {(missionNamespace getVariable ["AP_onDuty", false]) isEqualTo %2} && {%1 findIf {(player distance2D _x) < 5} > -1}', _tabs, _whenOnDuty], 6]);
} forEach [
    ["maxsec", "MaxSec Duty Terminal", "#1E90FF", [[10507.2,4024.1],[10486.9,4059.8]], {[(_this select 3)] spawn AP_fnc_dutyTermOpen}],
    ["trauma", "Trauma Team Duty Terminal", "#26ff7a", [[7418.0,8090.2],[7400.2,8127.2]], {[(_this select 3)] spawn AP_fnc_dutyTerminal}],
    // Clock-off: owner 2026-08-20 -- no UI, no confirmation, one scroll entry at ANY tablet while on
    // duty. AP_fnc_dutyTerminal's on-duty turnaround already releases without a dialog; the faction
    // arg is the shift being ended.
    ["off", "Clock Off Duty", "#ff5f5f", [[10507.2,4024.1],[10486.9,4059.8],[7418.0,8090.2],[7400.2,8127.2]], {[AP_dutyFaction] spawn AP_fnc_dutyTerminal}, true]
];

// BOUNTY BUYOUT at the MaxSec tablets. Owner ruling 2026-08-20: an officer with an outstanding bounty
// still cannot clock on, but they settle it themselves rather than going to find a second cop willing to
// pardon them. AP_fnc_dutyPayoff owns the confirm and the spend; the server prices it and moves the money.
//
// WHY IT IS A SCROLL ENTRY AND NOT A BUTTON ON THE WEB TERMINAL. ui\html\duty_maxsec.html is the
// designer's page and its refusal surface is one line of code -- `toast((res&&res.err)||'DUTY START
// FAILED')` (:260) -- a fire-and-forget string with no action, no second verb and no confirm. There is no
// way to put a "PAY IT OFF" button on it without editing the designer's markup and its state machine,
// which is a design change and not this task's to make. So the page keeps its toast, gains a pointer at
// the end of the refusal text (AP_fnc_dutyTermBridge), and the action it is pointing at is this one --
// which is also the route for the Trauma tablets' fallback picker and for anyone whose page failed to
// bind. It sits OUTSIDE the terminal table above because that table's condition is templated per faction
// and this needs two clauses none of those rows have.
//
// THE CONDITION IS AN OFFER FILTER AND NOTHING MORE, exactly like fn_dutyCfg's role gateCodes: every one
// of these is re-derived server-side from the server's own DB read before a cent moves (APS_fnc_dutySRV's
// "payoff" re-runs alive / civilian / restrained / rostered / cooldown / whitelist / arrested / wanted),
// so a client that forces the action visible has bought itself nothing.
// AP_wantedAmt is the OFFENDER'S OWN published figure -- their client sets it from A_stats_crimes and
// publishes it (fn_wantedListAdd.sqf:5), which is the same variable every cop tool reads -- so it is the
// "does this player have a bounty" test that needs no server round trip. It is NOT the price: the price
// is AP_dutyBuyout, published by the server, and with no quote in hand the prompt says so.
// The two levels are read through getVariable defaults rather than called bare, the same guard
// fn_dutyTermData and fn_landingData use: a THROW inside an addAction condition is evaluated every frame.
AP_actions pushBack (player addAction ["<t color='#1E90FF'>Pay Off Bounty (MaxSec)</t>",
    {["maxsec", "DUTYTABLET"] spawn AP_fnc_dutyPayoff}, nil, 5.1, false, true, "",
    '(missionNamespace getVariable ["AP_dutyEnabled", false]) && {!dialog} && {isNull objectParent player}'
    + ' && {!(missionNamespace getVariable ["AP_onDuty", false])}'
    + ' && {(player getVariable ["AP_wantedAmt", 0]) > 0}'
    + ' && {((call (missionNamespace getVariable ["AP_copLevel", {0}])) >= 1) || ((call (missionNamespace getVariable ["AP_adminLevel", {0}])) >= 1)}'
    + ' && {[[10507.2,4024.1],[10486.9,4059.8]] findIf {(player distance2D _x) < 5} > -1}', 6]);

// LooneyBin owner 2026-07-04: Wreckage Recovery Kit -- universal (all sides) scroll-wheel action shown on any
// WRECK when the player is holding a kit in their Y-inventory. Returns the wreck to its owner's garage.
AP_actions pushBack(_plb_obj addAction ["<t color='#90EE90'>Recover Wreckage</t>", {[cursorObject]
        spawn AP_fnc_recoverWreck},nil,200,false,false,"",'!isNil "AP_inv_wreckkit" && {AP_inv_wreckkit > 0} && !(alive cursorObject) && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship") && (cursorObject distance player < (12 + 0.5 * (sizeOf (typeOf cursorObject)))) && (count (cursorObject getVariable ["AP_dbInfo", []]) >= 2 || count (cursorObject getVariable ["dbInfo", []]) >= 2)',12]);

AP_actions pushBack(_plb_obj addAction ["<t color='#f2c14e'>Grab Component</t>", { [cursorObject] spawn AP_fnc_grabComponent },nil,201,false,false,"",'!isNull cursorObject && {(cursorObject getVariable ["AP_componentCrate", ""]) isNotEqualTo ""} && {!(cursorObject getVariable ["AP_grabbed", false])} && {player distance cursorObject < 5}',5]);

AP_actions pushBack(_plb_obj addAction ["<t color='#f2c14e'>Assemble Mining Rig</t>", { [] spawn AP_fnc_miningAssemble },nil,202,false,false,"",'(missionNamespace getVariable ["AP_inv_cryptoCPU",0] > 0) && {missionNamespace getVariable ["AP_inv_cryptoGPU",0] > 0} && {missionNamespace getVariable ["AP_inv_cryptoPSU",0] > 0} && {missionNamespace getVariable ["AP_inv_cryptoStorage",0] > 0} && {missionNamespace getVariable ["AP_inv_cryptoMotherboard",0] > 0} && {missionNamespace getVariable ["AP_inv_cryptoRam",0] > 0} && {missionNamespace getVariable ["AP_inv_cryptoCooler",0] > 0} && {missionNamespace getVariable ["AP_inv_cryptoCase",0] > 0}',5]);

// LooneyBin 2026-07-18: the mining rig is now a PLACED PHYSICAL object (installed via Use item -> placement).
// These scroll on the placed rig (any composition piece is tagged AP_cryptoRig + AP_rigOwner).
// ── RESOURCE RIG (traded system 2026-08-27): ONE action -- the deck RIG
// CONSOLE is the control surface (owner call). The app carries deploy/pack/
// start/stop and the mine-target picker; APS_fnc_rigSRV re-validates all of it.
AP_actions pushBack (_plb_obj addAction ["<t color='#f2c14e'>Rig Console</t>",
    { ["Rig", cursorObject] call AP_fnc_deckOpenApp },
    nil, 202, false, false, "",
    '!isNull cursorObject && {(cursorObject getVariable ["AP_rigKind", ""]) isNotEqualTo ""} && {player distance cursorObject < 12} && {isNull objectParent player}', 12]);
AP_actions pushBack(_plb_obj addAction ["<t color='#f2c14e'>Collect New Drachma</t>", { ["collect", cursorObject] spawn AP_fnc_miningRig },nil,201,false,false,"",'!isNull cursorObject && {(cursorObject getVariable ["AP_cryptoRig", false])} && {(cursorObject getVariable ["AP_rigOwner", ""]) isEqualTo (getPlayerUID player)} && {player distance cursorObject < 6}',5]);

AP_actions pushBack(_plb_obj addAction ["<t color='#fdd835'>Move Mining Rig</t>", { ["move", cursorObject] spawn AP_fnc_miningRig }
    // multi-rig 2026-07-22: Move/Delete key on the HOUSE owner (AP_rigHomeOwner), matching the server
    // delete-gate -- a hijack flips AP_rigOwner, and the victim must still be able to reclaim hardware.
    ,nil,201,false,false,"",'!isNull cursorObject && {(cursorObject getVariable ["AP_cryptoRig", false])} && {(cursorObject getVariable ["AP_rigHomeOwner", ""]) isEqualTo (getPlayerUID player)} && {player distance cursorObject < 6} && {isNull objectParent player} && {isNull AP_placing}',5]);

AP_actions pushBack(_plb_obj addAction ["<t color='#ff5252'>Delete Mining Rig</t>", { ["delete", cursorObject] spawn AP_fnc_miningRig },nil,201,false,false,"",'!isNull cursorObject && {(cursorObject getVariable ["AP_cryptoRig", false])} && {(cursorObject getVariable ["AP_rigHomeOwner", ""]) isEqualTo (getPlayerUID player)} && {player distance cursorObject < 6} && {isNull objectParent player}',5]);

// 3D printer (2026-08-22). PROXIMITY, not cursorObject -- unlike the mining rig these props ship
// with NO collision by owner call, so a raycast passes straight through them and cursorObject can
// never return one. AP_fnc_fabNear does a 3 m nearestObjects; the cheap `alive` / `objectParent`
// tests are in front of it so the per-frame cost of the condition is a boolean in the common case.
// The label follows the machine (owner 2026-09-03: a bench is not a fabricator): the tier row's
// display name is stamped into the action text with setUserActionText, but only when it differs
// from the last one stamped, so the per-frame cost on top of fabNear is one string compare.
AP_fabActLabel = ["", ""];
AP_actions pushBack(_plb_obj addAction ["<t color='#56d6e2'>Use Fabricator</t>", { [call AP_fnc_fabNear] spawn AP_fnc_fabMenu },nil,200,false,false,"",'alive player && {isNull objectParent player} && {AP_effSide isEqualTo civilian} && {private _f = call AP_fnc_fabNear; if (isNull _f) exitWith {false}; private _n = (["tier", _f getVariable ["AP_fabTier", 1]] call AP_fnc_fabCfg) select 5; if (_n isNotEqualTo (AP_fabActLabel select 0)) then {AP_fabActLabel set [0, _n]; _target setUserActionText [_actionId, format ["<t color=''#56d6e2''>Use %1</t>", _n]]}; true}',4]);

AP_actions pushBack(_plb_obj addAction ["<t color='#ff5252'>Pack Up Fabricator</t>", { [["pickup", [player, (call AP_fnc_fabNear) getVariable ["AP_fabId", -1]]], "APS_fnc_fabSRV", 2] spawn AP_fnc_MP }
    // Keyed on the HOUSE owner as well as the installer, mirroring the server gate and the mining
    // rig's: whoever owns the property must always be able to reclaim hardware left inside it.
    ,nil,199,false,false,"",'alive player && {isNull objectParent player} && {isNull AP_placing} && {private _f = call AP_fnc_fabNear; if (isNull _f) exitWith {false}; if !(((_f getVariable ["AP_fabOwner",""]) isEqualTo (getPlayerUID player)) || {(_f getVariable ["AP_fabHomeOwner",""]) isEqualTo (getPlayerUID player)}) exitWith {false}; private _n = (["tier", _f getVariable ["AP_fabTier", 1]] call AP_fnc_fabCfg) select 5; if (_n isNotEqualTo (AP_fabActLabel select 1)) then {AP_fabActLabel set [1, _n]; _target setUserActionText [_actionId, format ["<t color=''#ff5252''>Pack Up %1</t>", _n]]}; true}',4]);

// VENDING MACHINES (2026-09-07). The cabinet is a Syntax-1 simple object and its action carrier a
// UserTexture quad with no geometry LOD, so neither can be cursor-targeted; npcs\fn_vendShop.sqf
// prepares one spec per shop action on the cabinet (AP_vendSpec) and this adds them for the cabinet
// within 2.5 m, the fabricator's proximity pattern. Each runs the carrier's own script with the
// carrier as _target through AP_fnc_vendFire -- also the token initPlayerLocal's scroll-menu audit
// whitelists, because the shop titles carry "--" and would otherwise be stripped and reported.
if (!isNil "AP_vendSigns") then {
    private _vcab = objNull; private _vbd = 2.5;
    {
        _x params ["_vc"];
        if (!isNull _vc) then { private _vd = player distance _vc; if (_vd < _vbd) then { _vbd = _vd; _vcab = _vc; }; };
    } forEach AP_vendSigns;
    if (!isNull _vcab && {!isNull (_vcab getVariable ["AP_vendAct", objNull])}) then {
        {
            _x params ["_vt", "_va", "_vp", "_vs", "_vh", "_vk", "_vcond"];
            AP_actions pushBack (_plb_obj addAction [_vt, { _this call AP_fnc_vendFire }, _va, _vp, _vs, _vh, _vk, _vcond, 5]);
        } forEach (_vcab getVariable ["AP_vendSpec", []]);
    };
};

// LooneyBin 2026-07-18: NON-owner -> hack the rig (Terminal Breach -> full takeover + Cyber Crime charge)
AP_actions pushBack(_plb_obj addAction ["<t color='#00e5ff'>Hack Mining Rig</t>", { [cursorObject] spawn AP_fnc_cyberdeck },nil,201,false,false,"",'!isNull cursorObject && {(cursorObject getVariable ["AP_cryptoRig", false])} && {(cursorObject getVariable ["AP_rigOwner", ""]) isNotEqualTo (getPlayerUID player)} && {AP_effSide isEqualTo civilian} && {(call AP_fnc_hasDeck)} && {player distance cursorObject < 6} && {!(((nearestObjects [cursorObject, ["House"], 20]) param [0, objNull]) getVariable ["AP_buildingLocked", true])}',5]);

if((getPlayerUID player) in []) then {AP_actions pushBack(_plb_obj addAction ["<t color='#00FF00'>Deactivate Spangle</t>", {player setVariable ["AP_supertaze",false,true];},"",1.5,false,false,"",'(player getVariable [ "AP_supertaze",false ] )',6]);

    AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Activate Spangle</t>", {player setVariable ["AP_supertaze",true,true];},"",1.5,false,false,"",'!(player getVariable [ "AP_supertaze",false ] )',6]);};

if!(AP_scrollDisabled) then {if((call AP_adminLevel)>=2) then {AP_actions pushBack(_plb_obj addAction ["<t color='#00FF00'>House Registration</t>", {if(cursorObject getVariable ["AP_homeOwner",""]
                isEqualTo"") exitWith {[format ["<t color='#FF0000' align='center'><t size='1.5' align='center'>House ID:"+"</t></t><br/>%1",cursorObject getVariable ["AP_houseID",-1]],"basic"]
                    spawn AP_fnc_handleMessage;};
 [format ["<t color='#FF0000' align='center'><t size='1.5' align='center'>House Owner/ID:"+"</t></t><br/>%1 / %2",cursorObject getVariable ["AP_homeOwner","Not found"],cursorObject getVariable ["AP_houseID",-1]],"basic"]
                spawn AP_fnc_handleMessage;},cursorObject,-1,false,false,"",'!(cursorObject getVariable [ "AP_restricted_house", false ] ) && !isNull cursorObject && (player distance cursorObject) < 20 && typeOf cursorObject in AP_houseTypes',6]);

        AP_actions pushBack(_plb_obj addAction ["Check Registration", {[cursorObject]
                call AP_fnc_searchVehAction},"",0,false,false,"",' !isNull cursorObject && (player distance cursorObject) < 5 && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship")',6]);

        AP_actions pushBack(_plb_obj addAction ["<t color='#00FF00'>Rebel Loadouts</t>", {[player,player,-1,"rebel"]
                spawn AP_fnc_loadoutMenu},"",1.5,false,false,"",'(call AP_adminLevel) >= 3 && !isNull cursorObject && (typeOf cursorObject in AP_houseTypes) && (player distance cursorObject < 15) && ((cursorObject getVariable [ "AP_homeOwner", "" ] ) isNotEqualTo "")',6]);};

    if(isNull AP_sittingChair) then {AP_actions pushBack(_plb_obj addAction ["<t color='#2eeece'>Sit Down</t>", {[cursorObject]
                spawn AP_fnc_handleChair},nil,1.5,true,true,"""",'player distance cursorObject < 3 && { ( [ str cursorObject, "bench" ] call KRON_StrInStr || [ str cursorObject, "chair" ] call KRON_StrInStr) }',-1]);};

    AP_actions pushBack(_plb_obj addAction ["<t color='#ADFF2F'>ATM</t>", {[]
            call AP_fnc_atmMenu},nil,1.5,true,true,"""",'((player distance cursorObject < 3 && { typeOf cursorObject in [ "Land_Mattaust_ATM","Land_atm" ] || [ str cursorObject,"atm_0" ] call KRON_StrInStr } ))',6]);

    AP_actions pushBack(_plb_obj addAction ["<t color='#FFFF2F'>Gang Account</t>", {[]
            call AP_fnc_gangAtmMenu},nil,1.5,true,true,"""",'(count AP_gang_data > 0) && AP_effSide isEqualTo civilian && (player distance cursorObject < 3 && { typeOf cursorObject in [ "Land_Mattaust_ATM","Land_atm" ] || [ str cursorObject,"atm_0" ] call KRON_StrInStr } )',6]);

    AP_actions pushBack(_plb_obj addAction ["<t color='#FF7400'>Check Mailbox</t>", {[]
            call AP_fnc_checkMailbox},nil,1.5,true,true,"""",'player distance cursorObject < 3 && ( { typeOf cursorObject in [ "Land_Mattaust_ATM","Land_atm" ] || [ str cursorObject,"atm_0" ] call KRON_StrInStr } )',6]);

    // ATM SKIMMER (LooneyBin 2026-07-16): civ plants a $50k rebel skimmer on the physical ATM; cop pulls it for $200k.
    AP_actions pushBack(_plb_obj addAction ["<t color='#e88b2d'>Plant ATM Skimmer</t>", { [] spawn AP_fnc_applyAtmSkimmer; },nil,1.4,true,true,"",'AP_effSide isEqualTo civilian && {AP_inv_atmskimmer > 0} && {player distance cursorObject < 3} && {((typeOf cursorObject) in ["Land_Atm_01_F","Land_Atm_02_F","Land_Mattaust_ATM","Land_atm"]) || {[str cursorObject, "atm_0"] call KRON_StrInStr}}',6]);
    AP_actions pushBack(_plb_obj addAction ["<t color='#3aa0ff'>Remove ATM Skimmer ($200,000)</t>", { [["remove", getPosATL cursorObject, 0, player], "APS_fnc_atmSkimSRV", 2] spawn AP_fnc_MP; },nil,1.4,true,true,"",'AP_effSide isEqualTo west && {(cursorObject call AP_fnc_atmSkimOwner) isNotEqualTo ""} && {player distance cursorObject < 3} && {((typeOf cursorObject) in ["Land_Atm_01_F","Land_Atm_02_F","Land_Mattaust_ATM","Land_atm"]) || {[str cursorObject, "atm_0"] call KRON_StrInStr}}',6]);

    if(vehicle player isKindOf"Air"&&driver vehicle player isEqualTo player) then {AP_actions pushBack(_plb_obj addAction ["Eject", {_veh=vehicle player;

                if(_veh!=player) then {_engineOn=isEngineOn _veh;

                    player action ["GetOut",_veh];

                    uiSleep 1;};},"",6,false,false,"",'vehicle player isKindOf "Air" && driver vehicle player == player ;',6]);};

    if(((vehicle player) getVariable ["AP_nitro",0])>0) then {AP_actions pushBack(_plb_obj addAction ["<t color='#00FF00'>Activate Nitro</t>", {[vehicle player]
                call AP_fnc_activateNitro},nil,2,false,false,"",'(vehicle player != player) && (driver vehicle player == player) && (((vehicle player) getVariable [ "AP_nitro", 0 ] ) > 0)',-1]);};

    AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Repair Vehicle</t>", {[cursorObject]
            call AP_fnc_repairTruck},nil,0,false,false,"",' (isNull objectParent player) && !isNull cursorObject && alive cursorObject && ((cursorObject isKindOf "Car") || (cursorObject isKindOf "Air") || (cursorObject isKindOf "Ship")) && (player distance cursorObject < 5) ',6]);

    AP_actions pushBack(_plb_obj addAction ["Unflip Vehicle", {[cursorObject]
            call AP_fnc_flip},"",-1,false,false,"",'!(cursorObject getVariable [ "AP_mobileHeadQuartersTruckLocked", false ] ) && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air") && (vehicle player == player) && (player distance cursorObject < 8) && (local cursorObject || cursorObject in AP_vehicles || vectorUp cursorObject select 2 < 0.6 || vectorUp cursorObject select 1 > 0.2 || vectorUp cursorObject select 1 < -0.2) && (speed cursorObject < 1)',6]);

    AP_actions pushBack(_plb_obj addAction ["Push Vehicle", {[]
            call AP_fnc_pushVehicle},nil,0.6,false,true,"",'!isNull cursorObject && (cursorObject isKindOf "Air" || cursorObject isKindOf "Ship") && (cursorObject in AP_vehicles) && (player distance cursorObject) < 5 && (speed cursorObject) < 5 && (isNull objectParent player) && !AP_action_in_use',6]);

    AP_actions pushBack(_plb_obj addAction ["Pick Up Item(s)", {[cursorObject]
            call AP_fnc_menuPickupItems},nil,1.5,false,false,"",'!isNull cursorObject && count (cursorObject getVariable [ "AP_droppedItems", [ ] ] ) > 0 && player distance cursorObject < 5',6]);

    AP_actions pushBack(_plb_obj addAction ["<t color='#00FF00'>Fix Firing Pin</t>", {[]
            call AP_fnc_fixFiringPin},nil,1.5,false,false,"",'(player getVariable [ "AP_gunBroken",false ] ) && !(player getVariable [ "AP_restrained",false ] ) && (isNull objectParent player)',6]);

    AP_actions pushBack(_plb_obj addAction ["<t color='#1E90FF'>Deploy MaxSec UAV</t>", {[]
            spawn AP_fnc_copUAV},nil,1.5,false,false,"",'(AP_effSide isEqualTo west) && (call AP_copLevel) >= 6 && AP_inv_uav05 > 0 && (isNull objectParent player)',6]);

    if (isNil "AP_droneMonitor") then {["init"]
        spawn AP_fnc_reviveDrone};

    AP_actions pushBack(_plb_obj addAction ["<t color='#26ff7a'>Healing Bullets</t>", {player setVariable ["AP_medicGunMode","heal",true]; ["Medic gun set to HEALING BULLETS - each shot heals the target +10 hp.","info"]
            spawn AP_fnc_handleMessage;},nil,1.5,false,false,"",'17 in AP_medic_talents && (currentWeapon player isEqualTo "hgun_P07_khk_F") && ((player getVariable [ "AP_medicGunMode","taser" ] ) isEqualTo "taser")',6]);

    AP_actions pushBack(_plb_obj addAction ["<t color='#ff4040'>Taser Mode</t>", {player setVariable ["AP_medicGunMode","taser",true]; ["Medic gun set to TASER - each shot downs the target.","info"]
            spawn AP_fnc_handleMessage;},nil,1.5,false,false,"",'17 in AP_medic_talents && (currentWeapon player isEqualTo "hgun_P07_khk_F") && ((player getVariable [ "AP_medicGunMode","taser" ] ) isEqualTo "heal")',6]);

    AP_actions pushBack(_plb_obj addAction ["<t color='#26ff7a'>Treat via Drone</t>", {["treat"]
            spawn AP_fnc_reviveDrone},nil,2,false,false,"",'(AP_effSide isEqualTo independent) && (call AP_medicLevel) >= 3 && ((typeOf (getConnectedUAV player)) in [ "C_IDAP_UAV_06_medical_F","I_UAV_06_medical_F" ] ) && { (allPlayers findIf { (_x distance (getConnectedUAV player)) < 7 && ((_x getVariable [ "AP_revivable",false ] ) || (alive _x && damage _x > 0.3)) } ) > -1 }',6]);

    AP_actions pushBack(_plb_obj addAction ["<t color='#7ad1ff'>Medical Supplies (Drone)</t>", {[cursorObject,"","","hospital"]
            call AP_fnc_virtualShopMenu},nil,1.5,false,false,"",'!isNull cursorObject && ((typeOf cursorObject) in [ "I_UAV_06_medical_F","C_IDAP_UAV_06_medical_F" ] ) && (cursorObject getVariable [ "AP_medSupply", false ] ) && (player distance cursorObject < 8)',6]);

    AP_actions pushBack(_plb_obj addAction ["Push Back",AP_fnc_pushObject,"",0,false,false,"",'!isNull cursorTarget && player distance cursorTarget < 6 && (cursorTarget isKindOf "Ship" || cursorTarget isKindOf "Plane")',6]);

    AP_actions pushBack(_plb_obj addAction ["Pick Up Object",AP_fnc_pickupObject,cursorObject,0,false,false,"",'!isNull cursorObject && (typeOf cursorObject isNotEqualTo "Land_BatteryPack_01_closed_black_F") && cursorObject getVariable [ "AP_placedItem", false ] && ((player isEqualTo ((cursorObject getVariable [ "AP_owner", objNull ] ))) || ((getPlayerUID player) isEqualTo (cursorObject getVariable [ "AP_ownerID", "" ] ))) && ((player distance cursorObject) < 5)',6]);

    AP_actions pushBack(_plb_obj addAction ["<t color='#a8d8ff'>Lay Down</t>", {["lay",cursorObject]
            call AP_fnc_furnitureAction},nil,1.5,false,true,"",'!isNull cursorObject && (typeOf cursorObject isEqualTo "Land_WoodenBed_01_F") && (cursorObject getVariable [ "AP_placedItem",false ] ) && !(player getVariable [ "AP_layingBed",false ] ) && (player distance cursorObject < 3) && (isNull objectParent player)',6]);

    AP_actions pushBack(_plb_obj addAction ["<t color='#a8d8ff'>Get Up</t>", {["getup",objNull]
            call AP_fnc_furnitureAction},nil,1.5,false,true,"",'player getVariable [ "AP_layingBed",false ]',6]);

    AP_actions pushBack(_plb_obj addAction ["<t color='#fdd835'>Move Furniture</t>", {["move",cursorObject]
            call AP_fnc_furnitureAction},nil,1.5,false,false,"",'!isNull cursorObject && (cursorObject getVariable [ "AP_placedItem",false ] ) && (typeOf cursorObject in AP_furnitureClasses) && ((getPlayerUID player) isEqualTo (cursorObject getVariable [ "AP_ownerID","" ] )) && (player distance cursorObject < 4) && (isNull objectParent player)',6]);

    AP_actions pushBack(_plb_obj addAction ["<t color='#ff5252'>Delete Furniture</t>", {["delete",cursorObject]
            spawn AP_fnc_furnitureAction},nil,1.5,false,false,"",'!isNull cursorObject && (cursorObject getVariable [ "AP_placedItem",false ] ) && (typeOf cursorObject in AP_furnitureClasses) && ((getPlayerUID player) isEqualTo (cursorObject getVariable [ "AP_ownerID","" ] )) && (player distance cursorObject < 4) && (isNull objectParent player)',6]);

    AP_actions pushBack(_plb_obj addAction ["Eject All Physical Items", {private _confirm= ["Do you want to drop all the physical items from your loot chest? This will allow other players to see/take them off the ground.","Seasonal Chest Loot","Yes","No"]
            call BIS_fnc_guiMessage;

            if!(_confirm) exitWith {};
 ["ejectItems",0,cursorObject]
            call AP_fnc_dropPhysicalItem},"",0,false,false,"",'!isNull cursorObject && (typeOf cursorObject isEqualTo "Box_Syndicate_WpsLaunch_F") && cursorObject getVariable [ "AP_questloot", false ] && ((player distance cursorObject) < 5)',6]);

    if!(isNull AP_placing) then {AP_actions pushBack(_plb_obj addAction ["Place Object",AP_fnc_placeObject,nil,0,false,false,"",'!isNull AP_placing',6]);

        AP_actions pushBack(_plb_obj addAction ["<t color='#a8d8ff'>Raise Object (+Z)</t>", {AP_placeZ=AP_placeZ+0.1;

                if(!isNull AP_placing)then {AP_placing attachTo [player, [0,AP_placeFwd,AP_placeZ]];

                    AP_placing setDir AP_placeDir;};},nil,1.5,false,false,"",'!isNull AP_placing',6]);

        AP_actions pushBack(_plb_obj addAction ["<t color='#a8d8ff'>Lower Object (-Z)</t>", {AP_placeZ=AP_placeZ-0.1;

                if(!isNull AP_placing)then {AP_placing attachTo [player, [0,AP_placeFwd,AP_placeZ]];

                    AP_placing setDir AP_placeDir;};},nil,1.5,false,false,"",'!isNull AP_placing',6]);

        // owner 2026-07-10: FAST vertical steps (the 0.1m ones need 30 clicks for a platform height).
        AP_actions pushBack(_plb_obj addAction ["<t color='#a8d8ff'>Raise Object (+1m)</t>", {AP_placeZ = AP_placeZ + 1;
                if (!isNull AP_placing) then {AP_placing attachTo [player, [0, AP_placeFwd, AP_placeZ]];
                    AP_placing setDir AP_placeDir;};},nil,1.5,false,false,"",'!isNull AP_placing',6]);

        AP_actions pushBack(_plb_obj addAction ["<t color='#a8d8ff'>Lower Object (-1m)</t>", {AP_placeZ = AP_placeZ - 1;
                if (!isNull AP_placing) then {AP_placing attachTo [player, [0, AP_placeFwd, AP_placeZ]];
                    AP_placing setDir AP_placeDir;};},nil,1.5,false,false,"",'!isNull AP_placing',6]);

        AP_actions pushBack(_plb_obj addAction ["<t color='#a8d8ff'>Rotate Object (10 deg)</t>", {AP_placeDir=(AP_placeDir+10) mod 360;

                if(!isNull AP_placing)then {AP_placing setDir AP_placeDir;};},nil,1.5,false,false,"",'!isNull AP_placing',6]);

        AP_actions pushBack(_plb_obj addAction ["Stop Placing Object", {deleteVehicle AP_placing;

                AP_placing=objNull;},nil,0,false,false,"",'!isNull AP_placing',6]);};

    AP_actions pushBack(_plb_obj addAction ["<t color='#fb9924'>Place Boom Box</t>", {["boombox"]
            spawn AP_fnc_holdObject},nil,2,false,false,"",'(isNull objectParent player) && (AP_inv_boombox > 0) && (isNull AP_boomBox) && (isNull AP_placing) && (player nearObjects [ "Land_BatteryPack_01_closed_black_F", 20 ] isEqualTo [ ] )',-1]);

    AP_actions pushBack(_plb_obj addAction ["<t color='#e760ff'>Start Dancing</t>", {["startDance", []]
            spawn AP_fnc_boomBox},nil,2,false,false,"",'(isNull objectParent player) && !(AP_isDancing) && (player nearObjects [ "Land_BatteryPack_01_closed_black_F", 13 ] isNotEqualTo [ ] )',-1]);

    AP_actions pushBack(_plb_obj addAction ["<t color='#e760ff'>Stop Dancing</t>", {["stopDance", []]
            spawn AP_fnc_boomBox},nil,2,false,false,"",'(isNull objectParent player) && (AP_isDancing)',-1]);

    if((cursorObject isEqualTo AP_boomBox)&&(((cursorObject getVariable ["AP_boomBoxData", []]) param [1,""]) isEqualTo(getPlayerUID player))) then {AP_actions pushBack(_plb_obj addAction ["<t color='#f01f07'>Stop Music</t>", {["stopMusic", [cursorObject]]
                spawn AP_fnc_boomBox},nil,2,false,false,"",'(isNull objectParent player) && !(isNull cursorObject) && (alive cursorObject) && (((cursorObject getVariable [ "AP_boomBoxData", [ ] ] ) param [ 3, "" ] ) isNotEqualTo "")',-1]);

        AP_actions pushBack(_plb_obj addAction ["<t color='#fb9924'>Start Music</t>", {["startMusic", [cursorObject]]
                spawn AP_fnc_boomBox},nil,2,false,false,"",'(isNull objectParent player) && !(isNull cursorObject) && (alive cursorObject) && (((cursorObject getVariable [ "AP_boomBoxData", [ ] ] ) param [ 3, "" ] ) isEqualTo "")',-1]);

        AP_actions pushBack(_plb_obj addAction ["<t color='#f01f07'>Delete Boom Box</t>", {["deleteBoomBox", [cursorObject]]
                spawn AP_fnc_boomBox},nil,2,false,false,"",' (isNull objectParent player) && !(isNull cursorObject) && (alive cursorObject) ',-1]);};

    if!(AP_effSide isEqualTo independent) then {AP_actions pushBack(_plb_obj addAction ["Remove Blindfold", {[2,cursorObject]
                spawn AP_fnc_blindfoldAction},cursorObject,-1,false,true,"",'((cursorObject getVariable [ "AP_blinded",false ] ) && (cursorObject isKindOf "CAManBase") && (isPlayer cursorObject) && (alive cursorObject) && ((cursorObject distance player) < 5) && ((speed cursorObject) < 1))',6]);

        AP_actions pushBack(_plb_obj addAction ["TT Item Shop", {[cursorObject,"","","hospital"]
                call AP_fnc_virtualShopMenu},nil,1.5,false,false,"",'(AP_effSide isEqualTo civilian || AP_effSide isEqualTo west) && (typeOf cursorObject) isEqualTo "C_IDAP_supplyCrate_F" && cursorObject getVariable [ "AP_medSupply", false ]',5]);};

    if(AP_inv_adrenalineShot>0) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Give Adrenaline Shot</t>",AP_fnc_adrenalineShot,objNull,-1,false,true,"",'(!isNull cursorObject) && ((player distance cursorObject) <= 5) && (isPlayer cursorObject) && (alive cursorObject) && (cursorObject getVariable [ "AP_downed",false ] ) && (AP_inv_adrenalineShot > 0)',6]);};

    if(AP_inv_bloodbag>0) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Blood Transfusion Self</t>",AP_fnc_bloodbag,player,-1,false,false,"",'((AP_effSide in [ independent, civilian ] && damage player > 0) || ((94 in AP_side_talents) && damage player > 0.2) || ((95 in AP_side_talents) && damage player > 0.1) || ((96 in AP_side_talents) && damage player > 0)) && (AP_inv_bloodbag > 0)',6]);

        AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Give Blood Transfusion</t>",AP_fnc_bloodbag,cursorObject,-1,false,false,"",'isPlayer cursorObject && isNull objectParent player && ((AP_effSide in [ independent, civilian ] && damage cursorObject > 0) || ((94 in AP_side_talents) && damage player > 0.2) || ((95 in AP_side_talents) && damage player > 0.1) || ((96 in AP_side_talents) && damage cursorObject > 0)) && (AP_inv_bloodbag > 0)',6]);};

    if(AP_inv_firstAidKit>0) then {AP_actions pushBack(_plb_obj addAction ["<img image='\A3\Weapons_F\Items\data\UI\gear_FirstAidKit_CA' /> <t color='#65ff57'>Treat Yourself</t>",AP_fnc_medKit,player,-1,false,false,"",'isNull objectParent player && ((damage player > 0.25) || (player getHit "legs" >= 0.5)) && (AP_inv_firstAidKit > 0)',6]);

        AP_actions pushBack(_plb_obj addAction ["<img image='\A3\Weapons_F\Items\data\UI\gear_FirstAidKit_CA' /> <t color='#65ff57'>Treat Player</t>",AP_fnc_medKit,cursorObject,-1,false,false,"",'isPlayer cursorObject && isNull objectParent player && (player distance cursorObject <= 2) && (damage cursorObject > 0.25) && (AP_inv_firstAidKit > 0)',6]);};

    if((AP_inv_canna_papers>0)||(AP_inv_canna_bong>0)||(AP_inv_canna_rig>0)||(AP_inv_canna_vape>0)||(AP_inv_canna_joint>0)||(AP_inv_canna_prejoint>0)) then {AP_actions pushBack(_plb_obj addAction ["<img image='mpmissions\__cur_mp.altis\icons\canna_rawpapers.paa' /> <t color='#8b2b13'>Roll Joints with Raw Papers</t>", {["canna_papers"]
                spawn AP_fnc_cannabisItems},"",0,false,false,"",'(AP_inv_canna_papers > 0) && ((AP_inv_cannas_3 > 0) || (AP_inv_cannai_3 > 0) || (AP_inv_marijuana > 0) || (AP_inv_marijuanam > 0)) && !(player getVariable [ "AP_cannabisUsing", false ] )',6]);

        AP_actions pushBack(_plb_obj addAction ["<img image='mpmissions\__cur_mp.altis\icons\canna_bong.paa' /> <t color='#8bfdee'>Take Bong Rip</t>", {["canna_bong"]
                spawn AP_fnc_cannabisItems},"",0,false,false,"",'(AP_inv_canna_bong > 0) && ((AP_inv_cannas_3 > 0) || (AP_inv_cannai_3 > 0) || (AP_inv_marijuana > 0) || (AP_inv_marijuanam > 0)) && !(player getVariable [ "AP_cannabisUsing", false ] )',6]);

        AP_actions pushBack(_plb_obj addAction ["<img image='mpmissions\__cur_mp.altis\icons\canna_rig.paa' /> <t color='#ffda3f'>Take Dab With Glass Rig</t>", {["canna_rig"]
                spawn AP_fnc_cannabisItems},"",0,false,false,"",'(AP_inv_canna_rig > 0) && (AP_inv_canna_dab > 0) && !(player getVariable [ "AP_cannabisUsing", false ] )',6]);

        AP_actions pushBack(_plb_obj addAction ["<img image='mpmissions\__cur_mp.altis\icons\canna_vape.paa' /> <t color='#ff547f'>Rip Wax Pen</t>", {["smokeWeedJointOrVape", [true]]
                spawn AP_fnc_cannabisItems},"",0,false,false,"",'(AP_inv_canna_vape > 0) && !(player getVariable [ "AP_cannabisUsing", false ] )',6]);

        AP_actions pushBack(_plb_obj addAction ["<img image='mpmissions\__cur_mp.altis\icons\canna_joint.paa' /> <t color='#ca73fb'>Smoke Rolled Joint</t>", {["smokeWeedJointOrVape", [false,"canna_joint"]]
                spawn AP_fnc_cannabisItems},"",0,false,false,"",'(AP_inv_canna_joint > 0) && !(player getVariable [ "AP_cannabisUsing", false ] )',6]);

        AP_actions pushBack(_plb_obj addAction ["<img image='mpmissions\__cur_mp.altis\icons\canna_preroll.paa' /> <t color='#ca73fb'>Smoke Pre-Roll</t>", {["smokeWeedJointOrVape", [false,"canna_prejoint"]]
                spawn AP_fnc_cannabisItems},"",0,false,false,"",'(AP_inv_canna_prejoint > 0) && !(player getVariable [ "AP_cannabisUsing", false ] )',6]);};

    AP_actions pushBack(_plb_obj addAction ["Pull Out Unconscious", {private _vehicle=cursorObject;

            private _vehicleCrew=crew _vehicle- [driver _vehicle];

            private _locked=locked _vehicle;

            _vehicle lock 0;

            player moveInDriver _vehicle;

            moveOut player;

            player MoveInTurret [_vehicle, [0]];
 {moveOut player;

                player moveInCargo [_vehicle,_vehicle getCargoIndex _x];}
            forEach _vehicleCrew;
 [_vehicle,_locked]
            spawn {params ["_vehicle","_locked"];

                uiSleep 1.5;

                player action ["Eject",vehicle player];

                moveOut player;

                if(_locked isEqualTo 2) then {_vehicle lock 2};};},cursorTarget,0,false,false,"",'!isNull cursorTarget && (isNull objectParent player) && alive cursorTarget && (player distance cursorTarget) < 4 && (count crew cursorTarget) > 0 && { !alive _x } count crew cursorTarget > 0 && (cursorTarget isKindOF "Car" || cursorTarget isKindOf "Ship" || cursorTarget isKindOf "Air")',6]);

    AP_actions pushBack(_plb_obj addAction ["Destroy Medical Supplies", {[cursorObject]
            spawn AP_fnc_medSupplyDestroy},nil,1.5,false,false,"",'(typeOf cursorObject) isEqualTo "C_IDAP_supplyCrate_F" && cursorObject getVariable [ "AP_medSupply", false ]',3]);

    AP_actions pushBack(_plb_obj addAction ["Clean Up Campfire", {if((typeOf cursorObject isEqualTo"Land_Campfire_F")||(typeOf cursorObject isEqualTo"MetalBarrel_burning_F")) then {deleteVehicle cursorObject}},nil,-1,false,false,"",'!isNull cursorObject && (player distance cursorObject) <= 4 && ((typeOf cursorObject) isEqualTo "Land_Campfire_F" || (typeOf cursorObject) isEqualTo "MetalBarrel_burning_F") && cursorObject getVariable [ "AP_CampfireDeletable", true ]',4]);};

// FAST ROPE -- rope out of a hovering helicopter (core\actions\fn_fastRope.sqf).
// The condition is built with format so the envelope numbers come from the one config and
// this string can never drift from what fn_fastRope itself enforces. It is deliberately the
// same set of checks: the action is the advertisement, fn_fastRope is the gate.
private _fastRopeCondition = format [
    '!(AP_fastRoping) && !(isNull (objectParent player)) && ((typeOf (objectParent player)) in %1) && !(player isEqualTo (driver (objectParent player))) && (((getPosATL (objectParent player)) select 2) >= %2) && (((getPosATL (objectParent player)) select 2) <= %3) && (abs (speed (objectParent player)) <= %4) && alive player && !(player getVariable ["AP_restrained", false])',
    ["classes"] call AP_fnc_fastRopeCfg,
    ["minAltitude"] call AP_fnc_fastRopeCfg,
    ["maxAltitude"] call AP_fnc_fastRopeCfg,
    ["maxSpeed"] call AP_fnc_fastRopeCfg
];
AP_actions pushBack(_plb_obj addAction ["<t color='#7FD4FF'>Fast Rope</t>", {[] spawn AP_fnc_fastRope},nil,6,false,false,"",_fastRopeCondition,6]);

// BODY DRAG (owner 2026-09-16) -- drag a dead player's body until they respawn (core\actions\fn_dragBody.sqf,
// release in fn_dragBodyStop.sqf). All sides, so no per-side copies. The conditions run every frame
// unscheduled: every global is read nil-safe, cheap tests first, all lazy. The condition is the
// advertisement; fn_dragBody re-runs the same checks with messages and is the gate. Priority -2 keeps
// "Drag Body" under the defibrillator (-1) when a medic looks at a body. cursorObject is read when the
// action is USED, not when it is added (the defib entry's argument is evaluated once at add time).
// owner 2026-09-16: not while seated, in a timed emote, autorunning or carrying a barrel -- the same busy states
// parkour refuses on; each one's key handler or timer would knock the player out of the drag pose on the first step.
AP_actions pushBack(_plb_obj addAction ["<t color='#C9A0FF'>Drag Body</t>", {[cursorObject] spawn AP_fnc_dragBody},nil,-2,false,true,"",'!isNull cursorObject && {missionNamespace getVariable ["SRV_dragBodyEnabled", true]} && {isNull (missionNamespace getVariable ["AP_dragging", objNull])} && {cursorObject isKindOf "CAManBase"} && {!(alive cursorObject)} && {(player distance cursorObject) < (missionNamespace getVariable ["AP_dragCfg_startDist", 2.5])} && {isNull objectParent player} && {isNull objectParent cursorObject} && {isNull attachedTo cursorObject} && {((cursorObject getVariable ["AP_steamid", ""]) isNotEqualTo "") || {missionNamespace getVariable ["AP_dragDebug", false]}} && {isNull (cursorObject getVariable ["AP_reviving", objNull])} && {isNull (cursorObject getVariable ["AP_executing", objNull])} && {alive player} && {!(missionNamespace getVariable ["AP_isDead", false])} && {!(missionNamespace getVariable ["AP_isDowned", false])} && {!(player getVariable ["AP_restrained", false])} && {!(player getVariable ["AP_surrendered", false])} && {isNull (missionNamespace getVariable ["AP_escort", objNull])} && {!(missionNamespace getVariable ["AP_action_in_use", false])} && {!(isWeaponDeployed player)} && {isNull attachedTo player} && {isNull (missionNamespace getVariable ["AP_sittingChair", objNull])} && {!(player getVariable ["AP_inAnim", false])} && {!(missionNamespace getVariable ["AP_autoRun", false])} && {isNull (missionNamespace getVariable ["AP_holding_barrel", objNull])} && {(missionNamespace getVariable ["AP_parkourState", "idle"]) isEqualTo "idle"}',6]);
AP_actions pushBack(_plb_obj addAction ["<t color='#C9A0FF'>Release Body</t>", {["released"] call AP_fnc_dragBodyStop},nil,6,false,true,"",'!isNull (missionNamespace getVariable ["AP_dragging", objNull])',6]);

if!(AP_scrollDisabled) then {switch(AP_effSide) do {case civilian: {if(!isNil"SRV_cartelEvent") then {AP_actions pushBack(_plb_obj addAction ["<t color='#F53E4D'>Capture Event Point</t>", {[SRV_cartelEvent param [1,objNull]]
                        spawn AP_fnc_cartelEventCapture},nil,2,false,false,"",'private _flag = SRV_cartelEvent param [ 1, objNull ] ; !isNull _flag && { (_flag distance2D player < 2.5) && !(isObjectHidden _flag) && !(AP_gang_data isEqualTo [ ] ) && isNull objectParent player }',6]);};

            if(SRV_gangBoatFortressData select 0) then {AP_actions pushBack(_plb_obj addAction ["<t color='#F53E4D'>Capture Gang Boat Flag</t>", {[cursorObject]
                        spawn AP_fnc_captureGangBoatFlag},nil,2,false,false,"",'private _flags = SRV_gangBoatFortressData param [ 1, [ ] ] ; cursorTarget in _flags && { (cursorTarget distance2D player < 2.5) && !(AP_gang_data isEqualTo [ ] ) && isNull objectParent player }',6]);};

            AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Stop time trial</t>", {["stop"]
                    call AP_fnc_timeTrial},nil,-1,false,true,"",'player getVariable [ "AP_timeTrialActive", false ]',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#ff33cc'>Pickup easter bunny</t>", {["pickupBunny", [cursorObject]]
                    call AP_fnc_easterSeasonalEventCL},nil,-1,false,true,"",'cursorObject getVariable [ "easterRabbitActive", false ] && (player distance cursorObject) < 2',2]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#E40010'>Open</t> <t color='#1FD537'>present</t>", {["openPresent"]
                    call AP_fnc_openChristmasTreePresentCL},nil,-1,false,true,"",'cursorObject getVariable [ "AP_christmasPresent", false ] && (typeOf cursorObject) in [ "Land_PaperBox_01_small_closed_brown_F", "Box_EAF_Uniforms_F" ] && (player distance cursorObject) < 3',2]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Use Defibrillator</t>",AP_fnc_revivePlayer,cursorObject,-1,false,true,"",'!isNull cursorObject && cursorObject isKindOf "CAManBase" && !(alive cursorObject) && (cursorObject getVariable [ "AP_revivable",false ] || ((cursorObject getVariable [ "AP_group",grpNull ] isEqualTo group player) && !(isNull (cursorObject getVariable [ "AP_group",grpNull ] )))) && AP_inv_defib > 0 && (player distance cursorObject) < 3.5 && (isNull objectParent player) && (isNull objectParent cursorObject)',6]);

            AP_actions pushBack(_plb_obj addAction ["Rob Person", {[cursorObject]
                    call AP_fnc_robAction},nil,0,false,false,"",'!isNull cursorObject && !(currentWeapon player in [ "", "Binocular", "Rangefinder", "hgun_Pistol_Signal_F" ] ) && ((cursorObject getVariable [ "AP_surrendered",false ] ) || (cursorObject getVariable [ "AP_restrained",false ] && 16 in AP_honor_talents && 8 in AP_side_talents && cursorObject getVariable [ "AP_civRestrained",false ] )) && cursorObject isKindOf "CAManBase" && (isPlayer cursorObject) && alive cursorObject && cursorObject distance player < 5 && !(cursorObject getVariable [ "AP_escorting",false ] ) && speed cursorObject < 1',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#FF69B4'>Cover in Baby Oil</t>", {[cursorObject]
                    call AP_fnc_babyOil},nil,0,false,false,"",'AP_inv_babyoil>0 && !isNull cursorObject && (cursorObject getVariable [ "AP_restrained",false ] ) && cursorObject isKindOf "CAManBase" && (isPlayer cursorObject) && alive cursorObject && cursorObject distance player < 5 && speed cursorObject < 1 && (isNull objectParent player)',6]);

            if(AP_inv_ziptie>0) then {AP_actions pushBack(_plb_obj addAction ["Restrain", {[cursorObject]
                        call AP_fnc_restrain},nil,-1,false,true,"",'(cursorObject getVariable [ "AP_surrendered",false ] || cursorObject getVariable [ "AP_downed",false ] ) && cursorObject isKindOf "CAManBase" && (isPlayer cursorObject) && alive cursorObject && cursorObject distance player < 5 && !(cursorObject getVariable [ "AP_escorting",false ] ) && !(cursorObject getVariable [ "AP_restrained",false ] ) && speed cursorObject < 1 && AP_inv_ziptie > 0 && (isNull objectParent player) && (isNull objectParent cursorObject)',6]);};

            if((call AP_fnc_hasDeck)) then {AP_actions pushBack(_plb_obj addAction ["Lockpick Handcuffs", {[cursorObject,false,true]
                        spawn AP_fnc_lockpick},nil,-1,false,true,"",'(call AP_fnc_hasDeck) && !isNull cursorObject && cursorObject isKindOf "CAManBase" && (isPlayer cursorObject) && player distance cursorObject < 3.5 && (cursorObject getVariable [ "AP_restrained",false ] ) && !(cursorObject getVariable [ "AP_civRestrained",false ] ) && !(cursorObject getVariable [ "AP_escorting",false ] ) && !(cursorObject getVariable [ "AP_downed",false ] ) && (isNull objectParent player) && (isNull objectParent cursorObject)',6]);};

            if(AP_inv_boltCutter>=1) then {AP_actions pushBack(_plb_obj addAction ["Boltcut Handcuffs", {[cursorObject,true]
                        spawn AP_fnc_lockpick},nil,-1,false,true,"",'AP_inv_boltCutter >= 1 && !isNull cursorObject && cursorObject isKindOf "CAManBase" && (isPlayer cursorObject) && player distance cursorObject < 3.5 && (cursorObject getVariable [ "AP_restrained",false ] ) && !(cursorObject getVariable [ "AP_civRestrained",false ] ) && !(cursorObject getVariable [ "AP_escorting",false ] ) && !(cursorObject getVariable [ "AP_downed",false ] ) && (isNull objectParent player) && (isNull objectParent cursorObject)',6]);};

            if(AP_inv_blindfold>=1) then {AP_actions pushBack(_plb_obj addAction ["Apply Blindfold", {[1,cursorObject]
                        spawn AP_fnc_blindfoldAction},cursorObject,-1,false,true,"",'((cursorObject getVariable [ "AP_restrained",false ] ) && !(cursorObject getVariable [ "AP_blinded",false ] ) && (AP_inv_blindfold >= 1) && (cursorObject isKindOf "CAManBase") && (isPlayer cursorObject) && (alive cursorObject) && ((cursorObject distance player) < 5) && ((speed cursorObject) < 1)) && (isNull objectParent player)',6]);};

            if((call AP_fnc_hasDeck)) then {AP_actions pushBack(_plb_obj addAction ["Pick Vehicle Lock", {[cursorObject,false,true]
                        spawn AP_fnc_lockpick},nil,-1,false,true,"",'!isNull cursorObject && alive cursorObject && (player distance cursorObject) < 4 && (call AP_fnc_hasDeck) && (locked cursorObject != 0) && speed cursorObject < 2 && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship" || cursorObject isKindOf "Tank") && !(cursorObject in AP_vehicles) && (isNull objectParent player)',6]);};

            if(AP_inv_ignitionbomb>0) then {AP_actions pushBack(_plb_obj addAction ["<img image='mpmissions\__cur_mp.altis\icons\ignitionbomb.paa' /> <t color='#e99755'>Attach Ignition Bomb</t>", {[vehicle player]
                        call AP_fnc_ignitionBomb},nil,-1,false,true,"",'AP_inv_ignitionbomb > 0 && !(isNull objectParent player) && (driver (vehicle player) isEqualTo player)',6]);};

            if(!(isNull objectParent player) && (vehicle player isKindOf "B_T_VTOL_01_infantry_F")) then {AP_actions pushBack(_plb_obj addAction ["<t color='#e99755'>Toggle Ramp</t>", {private _v = vehicle player;
                        _v animateDoor ["Door_1_source", 1 - (_v animationSourcePhase "Door_1_source")]},nil,-1,false,true,"",'!(isNull objectParent player) && (vehicle player isKindOf "B_T_VTOL_01_infantry_F") && (driver (vehicle player) isEqualTo player)',6]);};

            if(AP_inv_remotekillswitch>0) then {AP_actions pushBack(_plb_obj addAction ["<img image='mpmissions\__cur_mp.altis\icons\phonebomb.paa' /><t color='#FF0000'>Insert Remote Engine Disabler</t>", {["attach",cursorObject]
                        spawn AP_fnc_remoteEngineKillSwitch},nil,-1,false,true,"",'AP_inv_remotekillswitch > 0 && (isNull objectParent player) && !isNull cursorObject && !AP_action_in_use && !(cursorObject getVariable [ "AP_remoteEngineKillSwitchActive", false ] ) && alive cursorObject && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship" || cursorObject isKindOf "Tank") && player distance cursorObject < 5',6]);};

            if(AP_inv_phonebomb>0) then {AP_actions pushBack(_plb_obj addAction ["<img image='mpmissions\__cur_mp.altis\icons\phonebomb.paa' /><t color='#FF0000'>Insert Remote Bomb</t>", {["attachBomb",cursorObject]
                        spawn AP_fnc_remoteExplosive},nil,-1,false,true,"",'AP_inv_phonebomb > 0 && (isNull objectParent player) && !isNull cursorObject && !AP_action_in_use && !(cursorObject getVariable [ "AP_phoneBombActive", false ] ) && alive cursorObject && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship" || cursorObject isKindOf "Tank") && player distance cursorObject < 5',6]);};

            if(AP_inv_arsonistkit>0) then {AP_actions pushBack(_plb_obj addAction ["<img image='mpmissions\__cur_mp.altis\icons\arsonistkit.paa' /> Set house on fire", {[cursorObject]
                        spawn AP_fnc_commitArsonClient},nil,-1,false,true,"",'AP_inv_arsonistkit > 0 && { (player distance cursorObject) < 10 } && (isNull objectParent player) && !isNull cursorObject && !AP_action_in_use && typeOf cursorObject in AP_houseTypes',6]);};

            if(isNull objectParent player) then {AP_actions pushBack(_plb_obj addAction ["Unrestrain", {[cursorObject,true]
                        spawn AP_fnc_unrestrain},nil,-1,false,true,"",'!isNull cursorObject && cursorObject isKindOf "CAManBase" && (isPlayer cursorObject) && player distance cursorObject < 3.5 && (cursorObject getVariable [ "AP_restrained",false ] ) && (cursorObject getVariable [ "AP_civRestrained",false ] ) && !(cursorObject getVariable [ "AP_escorting",false ] ) && !(cursorObject getVariable [ "AP_downed",false ] ) && !(currentWeapon player in [ "","Binocular","Rangefinder","hgun_Pistol_Signal_F" ] ) && (isNull objectParent player) && (isNull objectParent cursorObject)',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#FFF000'>Pull out of vehicle</t>", {[cursorObject]
                        call AP_fnc_pulloutAction},nil,-1,false,true,"",'!isNull cursorObject && (player distance cursorObject) < 4 && !(currentWeapon player in [ "", "Binocular", "Rangefinder", "hgun_Pistol_Signal_F" ] ) && (side player isEqualTo civilian) && (locked cursorObject isEqualTo 0) && (count crew cursorObject) > 0 && speed cursorObject < 2 && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship") && { alive _x } count crew cursorObject > 0 && (isNull objectParent player)',6]);

                AP_actions pushBack(_plb_obj addAction ["Remove Blindfold", {[2,cursorObject]
                        spawn AP_fnc_blindfoldAction},cursorObject,-1,false,true,"",'((cursorObject getVariable [ "AP_blinded",false ] ) && (cursorObject isKindOf "CAManBase") && (isPlayer cursorObject) && (alive cursorObject) && ((cursorObject distance player) < 5) && ((speed cursorObject) < 1)) && (isNull objectParent player)',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Execute!</t>", {[cursorObject]
                        call AP_fnc_execute},nil,-1,false,true,"",'!isNull cursorObject && !(alive cursorObject) && cursorObject isKindOf "CAManBase" && !(typeOf cursorObject in [ "Goat_random_F", "Cock_random_F", "Hen_random_F", "Sheep_random_F","Alsatian_Random_F" ] ) && !(currentWeapon player in [ "", "Binocular", "Rangefinder", "hgun_Pistol_Signal_F" ] ) && player distance cursorObject < 2 && (isNull objectParent player) && isNull (objectParent cursorObject)',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Harvest Organs</t>", {[cursorObject,true]
                        call AP_fnc_execute},nil,-1,false,true,"",'!isNull cursorObject && !(alive cursorObject) && cursorObject isKindOf "CAManBase" && player distance cursorObject < 2 && (isNull objectParent player) && AP_inv_skinningknife >= 1 && (isNull objectParent cursorObject) && !((cursorObject getVariable [ "AP_wasCop", false ] ) || (side cursorObject isEqualTo west))',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Circumcise</t>", {[cursorObject,true]
                        call AP_fnc_execute},nil,-1,false,true,"",'!isNull cursorObject && !(alive cursorObject) && cursorObject isKindOf "CAManBase" && player distance cursorObject < 2 && (isNull objectParent player) && AP_inv_skinningknife >= 1 && (isNull objectParent cursorObject) && ((cursorObject getVariable [ "AP_wasCop", false ] ) || (side cursorObject isEqualTo west))',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#ff27c0'>Executioner Move</t>", {["killerPlayer", [cursorObject]]
                        spawn AP_fnc_executionerMove},nil,-1,false,true,"",'!isNull cursorObject && cursorObject isKindOf "CAManBase" && (isPlayer cursorObject) && player distance cursorObject < 3.5 && (cursorObject getVariable [ "AP_restrained",false ] ) && (cursorObject getVariable [ "AP_civRestrained",false ] ) && !(cursorObject getVariable [ "AP_escorting",false ] ) && !(cursorObject getVariable [ "AP_downed",false ] ) && !(currentWeapon player in [ "", "Binocular", "Rangefinder", "hgun_Pistol_Signal_F", "hgun_P07_F", "hgun_P07_khk_F", "hgun_P07_blk_F" ] ) && ((( [ currentWeapon player ] call BIS_fnc_itemType) param [ 1, "" ] ) isEqualTo "Handgun") && (isNull objectParent player) && (isNull objectParent cursorObject)',6]);};

            if(457 in AP_completedLifetimeQuests) then {AP_actions pushBack(_plb_obj addAction ["<t color='#330000'>Skin Scalp</t>", {[cursorObject]
                        spawn AP_fnc_harvestScalp},nil,-1,false,true,"",'!isNull cursorObject && !(alive cursorObject) && cursorObject isKindOf "CAManBase" && player distance cursorObject < 2 && (isNull objectParent player) && AP_inv_skinningknife >= 1 && (isNull objectParent cursorObject) && (AP_effSide isEqualTo civilian)',6]);};

            if(AP_inv_snake>0||AP_inv_rabbit>0||AP_inv_chicken>0||AP_inv_dog>0||AP_inv_sheep>0||AP_inv_goat>0||AP_inv_manflesh>0) then {AP_actions pushBack(_plb_obj addAction ["Cook Raw Meat",AP_fnc_cookMeat,"",-1,false,false,"",'!isNull cursorObject && ((typeOf cursorObject) isEqualTo "Land_Campfire_F" || (typeOf cursorObject) isEqualTo "MetalBarrel_burning_F") && inflamed cursorObject && (AP_inv_snake > 0 || AP_inv_rabbit > 0 || AP_inv_chicken > 0 || AP_inv_dog > 0 || AP_inv_sheep > 0 || AP_inv_goat > 0 || AP_inv_manflesh > 0)',4]);};



            AP_actions pushBack(_plb_obj addAction ["Escort", {[cursorObject]
                    call AP_fnc_escortAction},"",-1,false,true,"",'!isNull cursorObject && cursorObject isKindOf "CAManBase" && (isPlayer cursorObject) && !(currentWeapon player in [ "", "Binocular", "Rangefinder", "hgun_Pistol_Signal_F" ] ) && alive cursorObject && cursorObject distance player < 3.5 && (cursorObject getVariable [ "AP_restrained",false ] ) && !(cursorObject getVariable [ "AP_escorting",false ] ) && (isNull objectParent player) && (isNull objectParent cursorObject)',6]);

            AP_actions pushBack(_plb_obj addAction ["Stop Escorting",AP_fnc_stopEscorting,"",-1,false,true,"",'!isNull (player getVariable [ "AP_escortObj",objNull ] ) && ((player getVariable [ "AP_escortObj",objNull ] ) getVariable [ "AP_escorting",false ] ) && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#FFF000'>Put in Vehicle</t>", {[cursorObject]
                    call AP_fnc_putInVeh},nil,-1,false,false,"",'!isNull cursorObject && (player distance cursorObject) < 6 && speed cursorObject < 2 && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship") && !isNull (player getVariable [ "AP_escortObj",objNull ] ) && isPlayer (player getVariable [ "AP_escortObj",objNull ] ) && alive (player getVariable [ "AP_escortObj",objNull ] ) && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["Virtual Item Storage", {[cursorObject]
                    spawn AP_fnc_storageOpen},nil,0,false,true,"",'!isNull cursorObject && (player distance cursorObject) < 6 && ((typeOf cursorObject) in [ "Land_TentA_F","Land_TentDome_F","B_CargoNet_01_ammo_F","C_IDAP_CargoNet_01_supplies_F", "B_CargoNet_01_ammo_F","O_Truck_03_covered_F", "Box_FIA_Ammo_F", "VirtualReammoBox_F", "I_E_CargoNet_01_ammo_F" ] )',5]);

            if((AP_is_arrested param [0,0]) isEqualTo 1&&AP_inv_shank>0) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Shank!</t>", {[cursorObject]
                        call AP_fnc_useShank},3,-1,false,false,"",' !isNull cursorTarget && cursorTarget isKindOf "CAManBase" && isPlayer cursorTarget && alive cursorTarget && AP_inv_shank > 0  && isNull objectParent player && player distance cursorTarget < 2 ',2]);};

            if(AP_delivery_type>0) then {AP_actions pushBack(_plb_obj addAction ["Attach sling to cargo", {private _r=ropeCreate [vehicle player,"slingload0",AP_delivery_object, [0,0,0],7];},"",2,true,true,"",' vehicle player != player && driver (vehicle player) == player && (vehicle player) isKindOf "AIR" && !(AP_delivery_object in (ropeAttachedObjects (vehicle player))) && ((getPos (vehicle player)) distance (getPos AP_delivery_object)) < 14 && (getPos (vehicle player)) select 2 < 12 ',-1]);

                AP_actions pushBack(_plb_obj addAction ["Detach all cargo", {{ropeDestroy _x}
                        forEach(ropes(vehicle player));},"",2,true,true,"",' vehicle player != player && (vehicle player) isKindOf "AIR" && AP_delivery_object in (ropeAttachedObjects (vehicle player)) ',-1]);};

            if((getPlayerUID player isEqualTo(SRV_governorData param [0,"GovUID"]))&& {player distance2D(getMarkerPos"gov")<=15}) then {AP_actions pushBack(_plb_obj addAction ["<t color='#2ef5ef'>Governor Laws</t>", {[]
                        spawn AP_fnc_govLawMenu},nil,0,false,false,"",'(AP_effSide isEqualTo civilian) && (typeOf cursorObject isEqualTo "Land_Laptop_Intel_01_F") && !(isNull cursorObject) && (player distance cursorObject < 5)',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#2ef5ef'>Governor Bank</t>", {[]
                        call AP_fnc_govBank},nil,0,false,false,"",'(AP_effSide isEqualTo civilian) && !(isNull cursorObject) && (typeOf cursorObject isEqualTo "Land_Laptop_Intel_01_F") && (player distance cursorObject < 5)',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#2ef5ef'>ATM</t>", {[]
                        call AP_fnc_atmMenu},nil,1.5,true,true,"""",'(AP_effSide isEqualTo civilian) && !(isNull cursorObject) && (typeOf cursorObject isEqualTo "Land_Laptop_Intel_01_F") && (player distance cursorObject < 5)',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#2ef5ef'>Toggle Governor Building Locks</t>", {["toggleGovBuildingLocks",cursorObject]
                        spawn AP_fnc_govSystem},nil,0,false,false,"",'(AP_effSide isEqualTo civilian) && !(isNull cursorObject) && (typeOf cursorObject isEqualTo "Land_Hotel_02_F") && (player distance cursorObject < 15)',6]);};

            AP_actions pushBack(_plb_obj addAction ["<t color='#0099FF'>Pick Barley</t>", {["barley",1,"neriumo2d"]
                    call AP_fnc_gatherObject},nil,1,true,true,"""",'player distance cursorObject < 3 && { [ str cursorObject,"neriumo2d" ] call KRON_StrInStr } && (!((cursorObject isKindOf "Car") || (cursorObject isKindOf "Air") || (cursorObject isKindOf "Ship"))) && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#0099FF'>Pick Berries</t>", {["berry",3,"neriumo"]
                    call AP_fnc_gatherObject},nil,1,true,true,"""",'player distance cursorObject < 3 && { [ str cursorObject,"neriumo" ] call KRON_StrInStr } && (!((cursorObject isKindOf "Car") || (cursorObject isKindOf "Air") || (cursorObject isKindOf "Ship"))) && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#0099FF'>Pick Berries</t>", {["berry",3,"colored"]
                    call AP_fnc_gatherObject},nil,1,true,true,"""",'player distance cursorObject < 3 && { [ str cursorObject,"b_colored" ] call KRON_StrInStr } && (!((cursorObject isKindOf "Car") || (cursorObject isKindOf "Air") || (cursorObject isKindOf "Ship"))) && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#0099FF'>Pick Rye</t>", {["rye",1,"arundod2s"]
                    call AP_fnc_gatherObject},nil,1,true,true,"""",'player distance cursorObject < 7 && { [ str cursorObject,"arundod2s" ] call KRON_StrInStr } && (!((cursorObject isKindOf "Car") || (cursorObject isKindOf "Air") || (cursorObject isKindOf "Ship")))',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#0099FF'>Pick Corn</t>", {["corn",1,"ficusc1s"]
                    call AP_fnc_gatherObject},nil,1,true,true,"""",'player distance cursorObject < 7 && { [ str cursorObject,"ficusc1s" ] call KRON_StrInStr } && (!((cursorObject isKindOf "Car") || (cursorObject isKindOf "Air") || (cursorObject isKindOf "Ship")))',6]);

            // MALDEN FIELDS 2026-07-26: every one of these blocks now asks whether the field's marker
            // EXISTS before it offers the action. A field the designer has not placed has no marker,
            // getMarkerPos hands back [0,0,0], and without this test every unplaced field's scroll
            // option turned up together in the map's SW corner. Same test guards fn_gather itself.
            if(markerType "illegal_marker_3_0" isNotEqualTo "" && {player distance(getMarkerPos"illegal_marker_3_0")<175}) then {AP_actions pushBack(_plb_obj addAction ["Gather Sparkdust",AP_fnc_gather,"",0,false,false,"",'!AP_action_in_use && (player distance (getMarkerPos "illegal_marker_3_0") < 150) && (isNull objectParent player)',6]);};

            if(markerType "illegal_marker_2_0" isNotEqualTo "" && {player distance(getMarkerPos"illegal_marker_2_0")<170}) then {AP_actions pushBack(_plb_obj addAction ["Gather Smash Powder",AP_fnc_gather,"",0,false,false,"",'!AP_action_in_use && (player distance (getMarkerPos "illegal_marker_2_0") < 150) && (isNull objectParent player) ',6]);};


            // Uranium on Malden is a SHIP (the designer's "Uranium Ship"), not Altis's mine tunnel, so
            // the old cursorObject gate on "factory_tunnel_f" could never pass here. It is replaced by
            // a tight 30 m radius: you have to be AT the ship, not just inside its 150 m ring.
            if(markerType "illegal_marker_4_0" isNotEqualTo "" && {player distance(getMarkerPos"illegal_marker_4_0")<150}) then {AP_actions pushBack(_plb_obj addAction ["Mine Uranium",AP_fnc_mineUranium,"",0,false,false,"",'!AP_action_in_use && (player distance (getMarkerPos "illegal_marker_4_0") < 30) && (isNull objectParent player) && (AP_inv_pickaxe > 0)',6]);};

            // Malden fields with no Altis ancestor. Raw ends only until the processor pass gives them
            // somewhere to go.
            if(markerType "tobacco_1" isNotEqualTo "" && {player distance(getMarkerPos"tobacco_1")<175}) then {AP_actions pushBack(_plb_obj addAction ["Gather Tobacco",AP_fnc_gather,"",0,false,false,"",'!AP_action_in_use && (player distance (getMarkerPos "tobacco_1") < 150) && (isNull objectParent player)',6]);};

            if(markerType "fentanyl_1" isNotEqualTo "" && {player distance(getMarkerPos"fentanyl_1")<175}) then {AP_actions pushBack(_plb_obj addAction ["Gather Boost",AP_fnc_gather,"",0,false,false,"",'!AP_action_in_use && (player distance (getMarkerPos "fentanyl_1") < 150) && (isNull objectParent player)',6]);};

            if(markerType "vineyard_1" isNotEqualTo "" && {player distance(getMarkerPos"vineyard_1")<120}) then {AP_actions pushBack(_plb_obj addAction ["Pick Grapes",AP_fnc_gather,"",0,false,false,"",'!AP_action_in_use && (player distance (getMarkerPos "vineyard_1") < 100) && (isNull objectParent player)',6]);};

            if({(markerType (format ["apple_%1",_x])) isNotEqualTo "" && {player distance getMarkerPos format ["apple_%1",_x]
                <75}}
            count [1,2,3,4,5]
            >0) then {AP_actions pushBack(_plb_obj addAction ["Pick Apples",AP_fnc_gather,"",0,false,false,"",'!AP_action_in_use && { player distance getMarkerPos format [ "apple_%1",_x ] < 50 } count [ 1,2,3,4,5 ] > 0 && (isNull objectParent player)',6]);};

            if({(markerType (format ["peaches_%1",_x])) isNotEqualTo "" && {player distance getMarkerPos format ["peaches_%1",_x]
                <75}}
            count [1,2,3,4]
            >0) then {AP_actions pushBack(_plb_obj addAction ["Pick Peaches",AP_fnc_gather,"",0,false,false,"",'!AP_action_in_use && { player distance getMarkerPos format [ "peaches_%1",_x ] < 50 } count [ 1,2,3,4 ] > 0 && (isNull objectParent player)',6]);};


            if({(markerType (format ["mine_%1",_x])) isNotEqualTo "" && {player distance getMarkerPos format ["mine_%1",_x]
                <90}}
            count [1,2,3,4,5,6,7]
            >0) then {AP_actions pushBack(_plb_obj addAction ["Mine Quarry",AP_fnc_gather,"",0,false,false,"",'!AP_action_in_use && ( { player distance getMarkerPos format [ "mine_%1",_x ] < 100 } count [ 1,2,3,4,5,6,7 ] > 0) && (isNull objectParent player) && (AP_inv_pickaxe > 0)',6]);};

            if({(markerType (format ["mine_%1",_x])) isNotEqualTo "" && {player distance getMarkerPos format ["mine_%1",_x]
                <90}}
            count [1,2,3,4,5,6,7]
            >0) then {AP_actions pushBack(_plb_obj addAction ["<t color='#0BEE0F'>Start Metal Detector</t>",AP_fnc_metalDetector,"",0,false,false,"",'!AP_action_in_use && ( { player distance getMarkerPos format [ "mine_%1",_x ] < 100 } count [ 1,2,3,4,5,6,7 ] > 0) && (isNull objectParent player) && (AP_inv_metaldetector > 0)',6]);};

            if(({(markerType (format ["salt_%1",_x])) isNotEqualTo "" && {player distance getMarkerPos format ["salt_%1",_x]
                <175}}
            count [1,2,3,4]
            >0)|| {markerType "salt_1" isNotEqualTo "" && surfaceType position player=="#GdtDead"}) then {AP_actions pushBack(_plb_obj addAction ["Gather Salt",AP_fnc_gather,"",0,false,false,"",'!AP_action_in_use && ((player distance (getMarkerPos "salt_1") < 150) || (player distance (getMarkerPos "salt_2") < 150) || (player distance (getMarkerPos "salt_3") < 150) || (player distance (getMarkerPos "salt_4") < 150) || (surfaceType position player == "#GdtDead")) && (isNull objectParent player) ',6]);};

            if({(markerType (format ["rock_%1",_x])) isNotEqualTo "" && {player distance getMarkerPos format ["rock_%1",_x]
                <175}}
            count [1,2,3,4]
            >0) then {AP_actions pushBack(_plb_obj addAction ["Gather Redshift",AP_fnc_gather,"",0,false,false,"",'!AP_action_in_use && ((player distance (getMarkerPos "rock_1") < 150) || (player distance (getMarkerPos "rock_2") < 150) || (player distance (getMarkerPos "rock_3") < 150) || (player distance (getMarkerPos "rock_4") < 150)) && (isNull objectParent player) ',6]);};

            if({(markerType (format ["oil_%1",_x])) isNotEqualTo "" && {player distance getMarkerPos format ["oil_%1",_x]
                <200}}
            count [1,2,3,4]
            >0) then {if(AP_inv_pickaxe>=1&&!((player nearEntities ["Car",15]
                select {typeOf _x in ["B_Truck_01_fuel_F","C_Truck_02_fuel_F","C_Van_01_fuel_F"]}) isEqualTo [])) then {AP_actions pushBack(_plb_obj addAction ["Gather Oil",AP_fnc_gather,"",0,false,false,"",'!AP_action_in_use && ((player distance (getMarkerPos "oil_1") < 150) || (player distance (getMarkerPos "oil_2") < 150) || (player distance (getMarkerPos "oil_3") < 150) || (player distance (getMarkerPos "oil_4") < 150)) && isNull objectParent player && (AP_inv_pickaxe > 0)',6]);}
                else {AP_actions pushBack(_plb_obj addAction ["Gather Toxic Slurry",AP_fnc_gather,"",0,false,false,"",'!AP_action_in_use && ((player distance (getMarkerPos "oil_1") < 150) || (player distance (getMarkerPos "oil_2") < 150) || (player distance (getMarkerPos "oil_3") < 150) || (player distance (getMarkerPos "oil_4") < 150)) && (isNull objectParent player) ',6]);};};

            if(AP_inv_woodaxe>0) then {AP_actions pushBack(_plb_obj addAction ["Chop Tree", {[cursorObject]
                        call AP_fnc_chopTree},"",0,false,false,"",'((player distance2D cursorObject) < 4) && (((str(cursorObject) find " t_") >= 0) || ((str(cursorObject) find " palm_") >= 0)) && (isNull objectParent player)',6]);};

            if({player inArea format ["turtle_%1",_x]}
            count [1,2]
            >0) then {AP_actions pushBack(_plb_obj addAction ["Grab Turtle",AP_fnc_catchTurtle,"",1.5,false,false,"",'(player inArea "turtle_1" || player inArea "turtle_2") && { count (nearestObjects [ player, [ "Turtle_F" ] ,4 ] ) > 0 } && (isNull objectParent player)',6]);};

            if({player inArea format ["turtle_%1",_x]}
            count [1,2]
            >0) then {AP_actions pushBack(_plb_obj addAction ["<t color='#7FFFD4'>Find Oysters</t>",AP_fnc_gather,"",0,false,false,"",'(player inArea "turtle_1" || player inArea "turtle_2") && { (isNull objectParent player) && !AP_action_in_use && { count (nearestObjects [ player, [ "Land_Wreck_Traw_F", "Land_Wreck_Traw2_F" ] ,20 ] ) > 0 } }',6]);};

            if(surfaceIsWater(getPosATL(vehicle player))) then {AP_actions pushBack(_plb_obj addAction ["Drop Fishing Net",AP_fnc_dropFishingNet,"",5,false,true,"",'(surfaceIsWater (getPosATL vehicle player)) && ((vehicle player isKindOf "Ship") || (typeOf (vehicle player) isEqualTo "I_MRAP_03_F")) && AP_carryWeight < AP_maxWeight && speed (vehicle player) < 2 && speed (vehicle player) > -1 && !AP_net_dropped ',6]);

                AP_actions pushBack(_plb_obj addAction ["Catch Fish",AP_fnc_catchFish,"",1.5,false,false,"",'(surfaceIsWater (getPosATL player)) && count(nearestObjects [ player, [ "Fish_Base_F" ] , 3 ] ) > 0 && (isNull objectParent player)',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#0099FF'>Collect Water</t>",AP_fnc_gatherWater,nil,1,false,true,"""",'surfaceIsWater position player && vehicle player == player && (getPosASL player) select 2 < 1 && (isNull objectParent player)',6]);

                if(AP_inv_excavator>0) then {AP_actions pushBack(_plb_obj addAction ["Search Wreck",AP_fnc_searchWreck,"",5,false,true,"",'(surfaceIsWater (getPosATL vehicle player)) && ((str(cursorObject) find "wreck_") >= 0) && ((player distance cursorObject) <= 20) && (AP_inv_excavator > 0) && (isNull objectParent player)',6]);};};

            AP_actions pushBack(_plb_obj addAction ["Setup Oil Pump", {[cursorObject]
                    call AP_fnc_oilPump},nil,0,false,false,"",'((typeOf cursorObject in [ "B_Truck_01_fuel_F","C_Truck_02_fuel_F","C_Van_01_fuel_F" ] ) && !(toLower("mpmissions\__cur_mp.altis\images\Van_01_adds_crank.jpg") in (getObjectTextures cursorObject)) && !isNull cursorObject && (player distance cursorObject) < 5 && !(cursorObject getVariable [ "AP_oilPump",false ] )) && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["Break Down Oil Pump", {[cursorObject]
                    call AP_fnc_oilPump},nil,0,false,false,"",'((typeOf cursorObject in [ "B_Truck_01_fuel_F","C_Truck_02_fuel_F","C_Van_01_fuel_F" ] ) && !isNull cursorObject && (player distance cursorObject) < 5 && (cursorObject getVariable [ "AP_oilPump",false ] )) && (isNull objectParent player)',6]);

            if((typeOf cursorObject in ["B_Truck_01_fuel_F","C_Truck_02_fuel_F","C_Van_01_fuel_F"])&&!isNull cursorObject&&(player distance cursorObject)<5&&(cursorObject getVariable ["AP_oilPump",false])) then {AP_actions pushBack(_plb_obj addAction ["Drill for Oil!", {[cursorObject]
                        call AP_fnc_drillOil},nil,0,false,false,"",'!AP_is_processing && (isNull objectParent player)',6]);};

            if(AP_inv_skinningknife>=1) then {AP_actions pushBack(_plb_obj addAction ["Skin Animal", {[cursorObject]
                        call AP_fnc_skinAnimal},"",0,false,false,"",'typeOf cursorObject in [ "Cock_random_F", "Hen_random_F", "Fin_random_F", "Alsatian_Random_F", "Goat_random_F", "Sheep_random_F", "Rabbit_F", "Snake_random_F" ] && !(alive cursorObject) && !AP_action_in_use && AP_inv_skinningknife >= 1 && (isNull objectParent player)',6]);};

            if("O_Truck_03_device_F"in(AP_vehicles apply {typeOf _x})) then {AP_actions pushBack(_plb_obj addAction ["Gather with device", {[cursorObject]
                        call AP_fnc_deviceMine},nil,0,false,false,"",'(typeOf cursorObject isEqualTo "O_Truck_03_device_F") && (objNull isEqualTo (cursorObject getVariable [ "AP_mining", objNull ] )) && { cursorObject in AP_vehicles } && (isNull objectParent player)',6]);};

            AP_actions pushBack(_plb_obj addAction ["Get the lab ready", {[cursorObject]
                    call AP_fnc_glitterLab},nil,0,false,false,"",'((typeOf cursorObject == "C_Van_01_box_F") && (toLower("mpmissions\__cur_mp.altis\images\Van_01_adds_crank.jpg") in (getObjectTextures cursorObject)) && !isNull cursorObject && (player distance cursorObject) < 5 && !(cursorObject getVariable [ "AP_labMode",false ] )) && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["Break down the lab", {[cursorObject]
                    call AP_fnc_glitterLab},nil,0,false,false,"",'((typeOf cursorObject == "C_Van_01_box_F") && (toLower("mpmissions\__cur_mp.altis\images\Van_01_adds_crank.jpg") in (getObjectTextures cursorObject)) && !isNull cursorObject && (player distance cursorObject) < 5 && (cursorObject getVariable [ "AP_labMode",false ] )) && (isNull objectParent player)',6]);

            if((typeOf cursorObject isEqualTo"C_Van_01_box_F")&&(toLower("mpmissions\__cur_mp.altis\images\Van_01_adds_crank.jpg") in(getObjectTextures cursorObject))&&!isNull cursorObject&&(player distance cursorObject)<5&&cursorObject getVariable ["AP_labMode",false]) then {AP_actions pushBack(_plb_obj addAction ["Mix Glitter Base",AP_fnc_processAction,"glitterbase",0,false,false,"",' AP_inv_sparkdust > 0 && AP_inv_redshift > 0 && AP_inv_toxicslurry > 0 && !AP_is_processing && (isNull objectParent player)',6]);};

            if((typeOf cursorObject isEqualTo"C_Van_01_box_F")&&(toLower("mpmissions\__cur_mp.altis\images\Van_01_adds_crank.jpg") in(getObjectTextures cursorObject))&&!isNull cursorObject&&(player distance cursorObject)<5&&cursorObject getVariable ["AP_labMode",false]) then {AP_actions pushBack(_plb_obj addAction ["Cook Glitter",AP_fnc_processAction,"glitter",0,false,false,"",' AP_inv_glitterbase > 0 && !AP_is_processing && (isNull objectParent player)',6]);};

            if("C_Van_01_fuel_F"in(AP_vehicles apply {typeOf _x})) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF9999'>Get the distillery ready</t>", {[cursorObject]
                        call AP_fnc_moonshineLab},nil,0,false,false,"",'((typeOf cursorObject == "C_Van_01_fuel_F") && (toLower("mpmissions\__cur_mp.altis\images\moonshineback.jpg") in (getObjectTextures cursorObject)) && !isNull cursorObject && (player distance cursorObject) < 5 && !(cursorObject getVariable [ "AP_labMode",false ] )) && (isNull objectParent player)',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#FF9999'>Break down the distillery</t>", {[cursorObject]
                        call AP_fnc_moonshineLab},nil,0,false,false,"",'((typeOf cursorObject == "C_Van_01_fuel_F") && (toLower("mpmissions\__cur_mp.altis\images\moonshineback.jpg") in (getObjectTextures cursorObject)) && !isNull cursorObject && (player distance cursorObject) < 5 && (cursorObject getVariable [ "AP_labMode",false ] )) && (isNull objectParent player)',6]);

                if((typeOf cursorObject isEqualTo"C_Van_01_fuel_F")&&(toLower("mpmissions\__cur_mp.altis\images\moonshineback.jpg") in(getObjectTextures cursorObject))&&!isNull cursorObject&&(player distance cursorObject)<5&&cursorObject getVariable ["AP_labMode",false]) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF9999'>Make Supplies into Corn Hash</t>",AP_fnc_processAction,"moonshinehash",0,false,false,"",' AP_inv_corn > 0 && AP_inv_yeast > 0 && AP_inv_water > 0 && !AP_is_processing && (isNull objectParent player)',6]);};

                if((typeOf cursorObject isEqualTo"C_Van_01_fuel_F")&&(toLower("mpmissions\__cur_mp.altis\images\moonshineback.jpg") in(getObjectTextures cursorObject))&&!isNull cursorObject&&(player distance cursorObject)<5&&cursorObject getVariable ["AP_labMode",false]) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF9999'>Distill Hash into Homebrew Moonshine</t>",AP_fnc_processAction,"moonshine",0,false,false,"",' AP_inv_moonshinehash > 0 && !AP_is_processing && (isNull objectParent player)',6]);};};

            if!(isNull AP_holding_barrel) then {AP_actions pushBack(_plb_obj addAction ["Drop Barrel",AP_fnc_dropOil,cursorTarget,-1,false,true,"",' !isNull AP_holding_barrel && speed player < 2 ',6]);

                AP_actions pushBack(_plb_obj addAction ["Place Barrel in Boat",AP_fnc_placeOil,cursorTarget,-1,false,true,"",'!isNull cursorTarget && !isNull AP_holding_barrel && (typeOf cursorTarget) in IL_Supported_Vehicles_BOAT && cursorTarget distance player < 5 && speed cursorTarget < 4',6]);};

            if(vest player=="V_HarnessOGL_brn") then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Activate Suicide Vest</t>", {["self"]
                        call AP_fnc_suicideVest},"",0,false,false,"",'vest player == "V_HarnessOGL_brn" && alive player && AP_effSide isEqualTo civilian && !AP_istazed && !(player getVariable [ "AP_restrained",false ] ) && !(player getVariable [ "AP_escorting",false ] ) && !(player getVariable [ "AP_transporting",false ] )',6]);};

            AP_actions pushBack(_plb_obj addAction ["<t color='#00FF00'>House Menu</t>", {[cursorObject]
                    call AP_fnc_houseMenu},nil,-1,false,false,"",'(cursorObject getVariable [ "AP_restricted_house", false ] != true) && (cursorObject isKindOf "House_F") && { !(isNull cursorObject) } && { (player distance cursorObject) < 10 } && { count ( [ typeOf cursorObject ] call AP_fnc_houseConfig) > 0 } && { (( [ typeOf cursorObject ] call AP_fnc_houseConfig) select 0) > -1 }',6]);

            // SHED HELIPAD deck reach: up on the pad cursorObject is deck concrete, never the shed,
            // so resolve the upgraded shed directly BELOW the player instead. Vertical extension only --
            // horizontal stays the same 10m as the ground action (distance2D), and the cursorObject
            // guard stops a duplicate entry when the shed itself is aimable through the rails.
            AP_actions pushBack(_plb_obj addAction ["<t color='#00FF00'>House Menu</t>", {private _shed = ((nearestObjects [player, ["Land_i_Shed_Ind_F"], 12]) select {!isObjectHidden _x && {_x getVariable ["AP_helipad", false]}}) param [0, objNull];
                    if (!isNull _shed) then {[_shed] call AP_fnc_houseMenu;};},nil,-1,false,false,"",'isNull objectParent player && {((getPosATL player) select 2) > 2.5} && {(typeOf cursorObject) isNotEqualTo "Land_i_Shed_Ind_F"} && { private _s = ((nearestObjects [player, ["Land_i_Shed_Ind_F"], 12]) select { !isObjectHidden _x && {_x getVariable ["AP_helipad", false]} && {!(_x getVariable ["AP_restricted_house", false])} } ) param [0, objNull]; !isNull _s && { (player distance2D _s) < 10 } }',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#33CC33'>Plant Sativa Seeds</t>", {["plant", [cursorObject,"s"]]
                    spawn AP_fnc_greenhouse},nil,1.5,false,false,"",'((cursorObject getVariable [ "AP_homeOwner","" ] isEqualTo (getPlayerUID player)) || { ((cursorObject getVariable [ "AP_house_keys", [ ] ] ) findIf { (_x param [ 0,"" ] ) isEqualTo (getPlayerUID player) } ) != -1 } ) && (cursorObject getVariable [ "AP_greenhouse_unaged",false ] ) && !isNull cursorObject && (player distance cursorObject < 12) && (AP_inv_cannas_0 > 0)',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#33CC33'>Plant Indica Seeds</t>", {["plant", [cursorObject,"i"]]
                    spawn AP_fnc_greenhouse},nil,1.5,false,false,"",'((cursorObject getVariable [ "AP_homeOwner","" ] isEqualTo (getPlayerUID player)) || { ((cursorObject getVariable [ "AP_house_keys", [ ] ] ) findIf { (_x param [ 0,"" ] ) isEqualTo (getPlayerUID player) } ) != -1 } ) && (cursorObject getVariable [ "AP_greenhouse_unaged",false ] ) && !isNull cursorObject && (player distance cursorObject < 12) && (AP_inv_cannai_0 > 0)',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#CB1EEC'>Harvest Greenhouse</t>", {["harvest", [cursorObject]]
                    spawn AP_fnc_greenhouse},nil,1.5,false,false,"",'((cursorObject getVariable [ "AP_homeOwner","" ] isEqualTo (getPlayerUID player)) || { ((cursorObject getVariable [ "AP_house_keys", [ ] ] ) findIf { (_x param [ 0,"" ] ) isEqualTo (getPlayerUID player) } ) != -1 } ) && (cursorObject getVariable [ "AP_greenhouse_unaged",false ] ) && !isNull cursorObject && (player distance cursorObject < 12) && (cursorObject getVariable [ "AP_gh_crop", [ ] ] isNotEqualTo [ ] )',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#FFD700'>Check Greenhouse</t>", {["status", [cursorObject]]
                    spawn AP_fnc_greenhouse},nil,1.5,false,false,"",'((cursorObject getVariable [ "AP_homeOwner","" ] isEqualTo (getPlayerUID player)) || { ((cursorObject getVariable [ "AP_house_keys", [ ] ] ) findIf { (_x param [ 0,"" ] ) isEqualTo (getPlayerUID player) } ) != -1 } ) && (cursorObject getVariable [ "AP_greenhouse_unaged",false ] ) && !isNull cursorObject && (player distance cursorObject < 12)',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#D2A679'>Lay Down Spirits to Age</t>", {["laydown", [cursorObject]]
                    spawn AP_fnc_barrel},nil,1.5,false,false,"",'((cursorObject getVariable [ "AP_homeOwner","" ] isEqualTo (getPlayerUID player)) || { ((cursorObject getVariable [ "AP_house_keys", [ ] ] ) findIf { (_x param [ 0,"" ] ) isEqualTo (getPlayerUID player) } ) != -1 } ) && (cursorObject getVariable [ "AP_barrel_unaged",false ] ) && !isNull cursorObject && (player distance cursorObject < 12) && (AP_inv_scotch_0 + AP_inv_whiskeyc_0 + AP_inv_whiskeyr_0 + AP_inv_rum_0 > 0)',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#CB1EEC'>Collect Aging Barrel</t>", {["collect", [cursorObject]]
                    spawn AP_fnc_barrel},nil,1.5,false,false,"",'((cursorObject getVariable [ "AP_homeOwner","" ] isEqualTo (getPlayerUID player)) || { ((cursorObject getVariable [ "AP_house_keys", [ ] ] ) findIf { (_x param [ 0,"" ] ) isEqualTo (getPlayerUID player) } ) != -1 } ) && (cursorObject getVariable [ "AP_barrel_unaged",false ] ) && !isNull cursorObject && (player distance cursorObject < 12) && (cursorObject getVariable [ "AP_barrel_crop", [ ] ] isNotEqualTo [ ] )',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#FFD700'>Check Aging Barrel</t>", {["status", [cursorObject]]
                    spawn AP_fnc_barrel},nil,1.5,false,false,"",'((cursorObject getVariable [ "AP_homeOwner","" ] isEqualTo (getPlayerUID player)) || { ((cursorObject getVariable [ "AP_house_keys", [ ] ] ) findIf { (_x param [ 0,"" ] ) isEqualTo (getPlayerUID player) } ) != -1 } ) && (cursorObject getVariable [ "AP_barrel_unaged",false ] ) && !isNull cursorObject && (player distance cursorObject < 12)',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#FFD700'>Set My MaxSec Title</t>", {[]
                    spawn {["<t align='center'>Enter your custom MaxSec rank title.</t>","MaxSec Rank Title","Set"]
                        call AP_fnc_inputMenu;

                        private _title=AP_input_response;

                        AP_input_response="";

                        if(_title isEqualTo "") exitWith {};

                        player setVariable ["AP_ownerCopTitle",_title,true];

                        profileNamespace setVariable ["AP_ownerCopTitle",_title];

                        saveProfileNamespace;
 [format ["MaxSec rank title set to: %1",_title],"basic"]
                        spawn AP_fnc_handleMessage;}},"",1.5,false,false,"",'AP_effSide isEqualTo west && (getPlayerUID player) isEqualTo "76561190000000001"',6]);

            if!(AP_houses isEqualTo []) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FFD700'>Show Furniture</t>", {[["show",cursorObject getVariable ["AP_houseID",-1],player],"APS_fnc_houseFurnitureSRV",2]
                        spawn AP_fnc_MP},nil,-1,false,false,"",'!isNull cursorObject && (player distance cursorObject) < 15 && cursorObject isKindOf "House_F" && ((cursorObject getVariable [ "AP_homeOwner","" ] ) isEqualTo getPlayerUID player) && (isNull objectParent player)',6]);

                // owner 2026-07-11 (MENTOR PROGRAM, Act 3 onboarding): veterans adopt a [NEW BLOOD] --
                // the state pays $1,000,000 when the mentee finishes parole. UNCONDITIONAL registration
                // (self-gates via the condition string) -- the first placement sat inside the shank's
                // AP_inv_shank>0 wrapper, so only shank-carrying vets ever saw it.
                AP_actions pushBack(_plb_obj addAction ["<t color='#00FF00'>Offer to Mentor (New Blood)</t>", {["offer"] call AP_fnc_mentor},3,-1,false,false,"",' !isNull cursorTarget && cursorTarget isKindOf "CAManBase" && isPlayer cursorTarget && alive cursorTarget && (cursorTarget getVariable ["AP_newBlood", false]) && ((cursorTarget getVariable ["AP_mentorUid", ""]) isEqualTo "") && !(player getVariable ["AP_newBlood", false]) && AP_effSide isEqualTo civilian && isNull objectParent player && player distance cursorTarget < 3 ',3]);

                // owner 2026-07-12: autopilot scroll actions REMOVED -- activation lives in the
                // TAB radial (driving-mode wedges), gated on the $300 garage module.

                AP_actions pushBack(_plb_obj addAction ["<t color='#FFD700'>Pack Away Furniture</t>", {[["hide",cursorObject getVariable ["AP_houseID",-1],player],"APS_fnc_houseFurnitureSRV",2]
                        spawn AP_fnc_MP},nil,-1,false,false,"",'!isNull cursorObject && (player distance cursorObject) < 15 && cursorObject isKindOf "House_F" && ((cursorObject getVariable [ "AP_homeOwner","" ] ) isEqualTo getPlayerUID player) && (isNull objectParent player)',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Toggle All House Locks</t>", {[cursorObject]
                        call AP_fnc_lockHouse},nil,-1,false,false,"",'!isNull cursorObject && (player distance cursorObject) < 20 && cursorObject isKindOf "House" && (cursorObject in AP_vehicles) && (isNull objectParent player)',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#FF7400'>Request TT House Repair</t>", {["requestRepair"]
                        spawn AP_fnc_civRepairBuilding},nil,1.5,true,true,"""",'private _building = if (AP_houses isNotEqualTo []) then {(nearestTerrainObjects [ player, [ "House" ] , 7, true, true ] ) param [ 0, objNull ] } else {objNull}; private _building = if (_building getVariable [ "AP_terrainObject_repaired", false ] ) then { (nearestObjects [ player, [ "House" ] , 7, true ] ) param [ 0, objNull ] } else { _building } ; ((_building isKindOf "House_F") && !(_building getVariable [ "AP_repairRequested", false ] ) && ((_building getVariable [ "AP_homeOwner", "" ] ) isEqualTo (getPlayerUID player)) && (damage _building >= 1))',6]);

                (_plb_obj addAction ["<t color='#33CC33'>Repair House (Kit)</t>", {["kitRepair"]
                        spawn AP_fnc_civRepairBuilding},nil,1.5,true,true,"""",'private _building = if ((AP_effSide isEqualTo civilian) && (AP_inv_houserepairkit > 0)) then { (nearestTerrainObjects [ player, [ "House" ] , 7, true, true ] ) param [ 0, objNull ] } else { objNull } ; private _building = if (_building getVariable [ "AP_terrainObject_repaired", false ] ) then { (nearestObjects [ player, [ "House" ] , 7, true ] ) param [ 0, objNull ] } else { _building } ; ((AP_effSide isEqualTo civilian) && (AP_inv_houserepairkit > 0) && (_building isKindOf "House_F") && ((_building getVariable [ "AP_homeOwner", "" ] ) isEqualTo (getPlayerUID player)) && (damage _building isEqualTo 1))',6]);};

            if(cursorObject in AP_gangBuilding||([cursorObject,getPlayerUID player,"accessInv"]
            call AP_fnc_keyHolderStatus)||!(AP_houses isEqualTo [])) then {if((cursorObject getVariable ["AP_house_tax", [false]]) select 0) exitWith {};

                AP_actions pushBack(_plb_obj addAction ["Vehicle Garage", {["Car",cursorObject]
                        call AP_fnc_handleVehicles},nil,0,false,true,"",'!isNull cursorObject && (player distance cursorObject) < 20 && cursorObject isKindOf "House" && (typeOf cursorObject in [ "Land_i_Garage_V1_F","Land_i_Garage_V2_F","Land_i_Garage_V1_dam_F","Land_i_Garage_V2_dam_F","Land_i_Shed_Ind_F","Land_House_Big_02_F","Land_House_Big_03_F" ] ) && (cursorObject in AP_vehicles || cursorObject in AP_gangBuilding || ( [ cursorObject, getPlayerUID player, "accessLock" ] call AP_fnc_keyHolderStatus)) && (isNull objectParent player)',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#37e8f0'>Helipad Garage</t>", {["Air",cursorObject]
                        call AP_fnc_handleVehicles},nil,0,false,true,"",'!isNull cursorObject && (player distance cursorObject) < 25 && (typeOf cursorObject isEqualTo "Land_i_Shed_Ind_F") && (cursorObject getVariable ["AP_helipad", false]) && (cursorObject in AP_vehicles || cursorObject in AP_gangBuilding || ( [ cursorObject, getPlayerUID player, "accessLock" ] call AP_fnc_keyHolderStatus)) && (isNull objectParent player)',6]);

                AP_actions pushBack(_plb_obj addAction ["Gang Garage", {["Car",cursorObject,true]
                        call AP_fnc_handleVehicles},nil,0,false,true,"",'!isNull cursorObject && (player distance cursorObject) < 20 && cursorObject isKindOf "House" && (typeOf cursorObject in [ "Land_i_Garage_V1_F","Land_i_Garage_V2_F","Land_i_Garage_V1_dam_F","Land_i_Garage_V2_dam_F","Land_i_Shed_Ind_F","Land_House_Big_02_F","Land_House_Big_03_F" ] ) && (cursorObject in AP_vehicles || cursorObject in AP_gangBuilding || ( [ cursorObject, getPlayerUID player, "accessLock" ] call AP_fnc_keyHolderStatus)) && (isNull objectParent player) && ((AP_gang_data param [ 0, -1 ] ) isNotEqualTo -1) && ((AP_gang_data param [ 2, 5 ] ) <= 3)',6]);

                AP_actions pushBack(_plb_obj addAction ["Store Vehicle in Garage",AP_fnc_storeVehicle,"""",0,false,true,"""",'!AP_garage_store && !isNull cursorObject && (player distance cursorObject) < 20 && cursorObject isKindOf "House" && (typeOf cursorObject in [ "Land_i_Garage_V1_F","Land_i_Garage_V2_F","Land_i_Garage_V1_dam_F","Land_i_Garage_V2_dam_F","Land_i_Shed_Ind_F","Land_House_Big_02_F","Land_House_Big_03_F" ] ) && (cursorObject in AP_vehicles || cursorObject in AP_gangBuilding || ( [ cursorObject, getPlayerUID player, "accessLock" ] call AP_fnc_keyHolderStatus)) && (isNull objectParent player)',6]);};

            // owner 2026-07-28: this offers on AP_FED_TERMPOS, the dome TERMINAL, not on AP_fedDome.
            // The brief was "the terminal game at the door of the side dome ... at
            // [11218.9, 4471.06, 18.16]" and that coordinate is 24 m from the dome object's model
            // centre, so a 12 m radius round the dome put the action out of reach of the only spot the
            // owner was ever told to stand on -- his DOMEDIAG there read distDome=26.28 with every
            // other clause passing. 8 m is fn_openVault's own refusal bound, so a player who can see
            // the option can never be refused by the function for the reason it was offered; the
            // server's 10 m in APS_fnc_maldenFedSRV "dome" is the looser outer bound and is meant to
            // be. The count check is the position-anchor equivalent of the gate's !isNull guard: a
            // client that has not received the publicVariable yet has no third clause to satisfy and
            // simply does not see the option.
            if(player distance getMarkerPos"fed_reserve"<=400) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Breach Dome Terminal</t>",AP_fnc_openVault,"",0,false,false,"",'(AP_effSide isEqualTo civilian) && ((count (missionNamespace getVariable [ "AP_FED_TERMPOS", [ ] ] )) isEqualTo 3) && ((player distance (missionNamespace getVariable [ "AP_FED_TERMPOS", [ 0, 0, 0 ] ] )) <= 8) && (((missionNamespace getVariable [ "SRV_maldenFed", [ 0 ] ] ) param [ 0, 0 ] ) isEqualTo 1) && ((call AP_fnc_hasDeck)) && (!AP_action_in_use) && (isNull objectParent player)',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Start an Alamo Fed</t>",AP_fnc_alamoFed,"",0,false,false,"",'(AP_effSide isEqualTo civilian) && (!isNull (missionNamespace getVariable [ "AP_fedCentre", objNull ] )) && ((player distance (missionNamespace getVariable [ "AP_fedCentre", objNull ] )) <= 12) && (((missionNamespace getVariable [ "SRV_maldenFed", [ 0 ] ] ) param [ 0, 0 ] ) isEqualTo 3) && (((missionNamespace getVariable [ "SRV_maldenFed", [ 0, -1, 0 ] ] ) param [ 2, 0 ] ) isEqualTo 0) && ((call AP_fnc_hasDeck)) && (!AP_action_in_use) && (isNull objectParent player)',6]);

                // owner 2026-07-28: the two safe actions used to offer at <= 6 m from the BUILDING CENTRE
                // while fn_openSafe refuses at >= 3 m from the nearest "door" selection -- two different
                // bounds measured from two different points, so a player standing at the corner of a safe
                // got the scroll option and then "You are not close enough to the safe door." The
                // condition now runs the same nearest-door-selection test the function does, at the
                // function's own 3 m bound, so the two are aligned by construction rather than by a
                // geometric coincidence that would drift the next time either number moved. 3 m is the
                // bound that had to win: fn_openSafe re-checks it every tick of the demo-charge progress
                // bar, so it is the one that actually governs whether the action can complete. findIf on
                // the filtered list also covers the case the function has to message about separately --
                // a class that names no door selection at all now simply does not offer the action. The
                // lazy && {} matters: the door test only runs once cursorObject is a known safe, so it is
                // never evaluated against objNull and costs nothing until the player aims at one.
                AP_actions pushBack(_plb_obj addAction ["Crack Safe",AP_fnc_openSafe,false,0,false,false,"",'(cursorObject in (missionNamespace getVariable [ "AP_fedSafes", [ ] ] )) && {(((selectionNames cursorObject) select { (_x find "door") >= 0 }) findIf { (player distance (cursorObject modelToWorld (cursorObject selectionPosition _x))) < 3 }) >= 0} && ((cursorObject getVariable [ "AP_vaultlocked", 1 ] ) isEqualTo 1) && (((missionNamespace getVariable [ "SRV_maldenFed", [ 0 ] ] ) param [ 0, 0 ] ) >= 2) && ((call AP_fnc_hasDeck)) && (!AP_action_in_use) && (isNull objectParent player)',6]);

                AP_actions pushBack(_plb_obj addAction ["Plant Demo Charge",AP_fnc_openSafe,true,0,false,false,"",'(cursorObject in (missionNamespace getVariable [ "AP_fedSafes", [ ] ] )) && {(((selectionNames cursorObject) select { (_x find "door") >= 0 }) findIf { (player distance (cursorObject modelToWorld (cursorObject selectionPosition _x))) < 3 }) >= 0} && ((cursorObject getVariable [ "AP_vaultlocked", 1 ] ) isEqualTo 1) && (((missionNamespace getVariable [ "SRV_maldenFed", [ 0 ] ] ) param [ 0, 0 ] ) >= 2) && (AP_inv_demoCharge >= 1) && (!AP_action_in_use) && (isNull objectParent player)',6]);

                // 2026-07-28: this action is PROXIMITY-based, not cursor-based, and must stay that way.
                // It used to require an exact cursorObject match on AP_fedGate, which meant the whole
                // Fed event could never be started: the gate is a large sliding wall-gate
                // (Land_ConcreteWall_01_l_gate_F) sitting on a cobblestone plate, and the cursor ray
                // lands on the ground, not the gate. Measured in-game at 2.41 m, aimed straight at it --
                // cursorObject returned Land_CobblestoneSquare_01_32m_F, so the match clause was false
                // while every other clause passed. The dome terminal beside this one never had the
                // problem because it only ever tested distance. 6 m is deliberately fn_openGate's own
                // refusal bound, so a player who can see the option can never be refused by the function
                // for the reason it was offered; the server's 8 m in APS_fnc_maldenFedSRV "gate" is the
                // looser outer bound and is meant to be.
                AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Breach Perimeter Gate</t>",AP_fnc_openGate,"",0,false,false,"",'(AP_effSide isEqualTo civilian) && (!isNull (missionNamespace getVariable [ "AP_fedGate", objNull ] )) && ((player distance (missionNamespace getVariable [ "AP_fedGate", objNull ] )) <= 6) && (((missionNamespace getVariable [ "SRV_maldenFed", [ 0 ] ] ) param [ 0, 0 ] ) isEqualTo 0) && ((call AP_fnc_hasDeck)) && (!AP_action_in_use) && (isNull objectParent player)',6]);};

                // PRISON SALLY-PORT GATE 2026-07-29 -- the prison break's TRIGGER. There was never one on this map:
                // AP_fnc_doPrisonBreak, the laptop upload path, has no callers anywhere in the tree and there is no
                // laptop prop within 170 m of the prison. PROXIMITY, never cursorObject, for exactly the reason
                // recorded on the Fed gate above: on a gate this size the cursor ray lands on the paving slab
                // underfoot. 6 m is deliberately AP_fnc_prisonGate's own refusal bound, so a player who can see the
                // option can never be refused for the reason it was offered; the server's 8 m in "gatehack" is the
                // looser outer bound and is meant to be. The AP_arrested clause keeps the option off a prisoner
                // standing at the inside face of the same gate -- a prisoner escapes through the query dialog, not by
                // hacking his own cell door.
                AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Breach Prison Gate</t>",AP_fnc_prisonGate,"",0,false,false,"",'(AP_effSide isEqualTo civilian) && (!isNull (missionNamespace getVariable [ "AP_prisonGateIn", objNull ] )) && ((player distance (missionNamespace getVariable [ "AP_prisonGateIn", objNull ] )) <= 6) && (!((missionNamespace getVariable [ "SRV_prisonData", [ 0, false ] ] ) param [ 1, false ] )) && ((call AP_fnc_hasDeck)) && (!AP_action_in_use) && (isNull objectParent player) && (!(player getVariable [ "AP_arrested", false ] ))',6]);

            // RADAR TOWER SABOTAGE (island air defences). Four footings, any order; the action only
            // offers itself at a footing that is still empty, and the fourth one arms a fuse nobody
            // can stop. Footings come from the server (AP_fedRadarPoints) so there is one copy of them.
            if (AP_effSide isEqualTo civilian
                && {!isNil "AP_fedRadarPoints"}
                && {!((missionNamespace getVariable ["SRV_fedRadar", []]) param [1, false])}
                && {({ player distance2D _x < 3 } count AP_fedRadarPoints) > 0}) then {
                AP_actions pushBack(_plb_obj addAction ["<t color='#FF3B30'>Plant Charge on Radar Footing</t>",AP_fnc_fedRadarCharge,"",5,false,false,"",'!AP_action_in_use && (AP_effSide isEqualTo civilian) && (AP_inv_demoCharge >= 1) && (isNull objectParent player) && !isNil "AP_fedRadarPoints" && !((missionNamespace getVariable ["SRV_fedRadar", []]) param [1, false]) && ({ player distance2D _x < 3 } count AP_fedRadarPoints) > 0',6]);};

            if(player distance [20898.6,19221.7,0.00143909]
            <=400) then {AP_actions pushBack(_plb_obj addAction ["Plant Demo Charge",AP_fnc_evidenceSystems,2,5,false,false,"",'(( { (player distance (cursorObject modelToWorld (cursorObject selectionPosition _x))) <= 2.75 } count ((selectionNames cursorObject) select { (_x find "door") >= 0 } )) >= 1) && (!(SRV_evidence_status select 1) && (SRV_evidence_status select 0)) && typeOf cursorObject isEqualTo "Land_Dome_Big_F" && (AP_inv_demoCharge >= 1) && !(AP_action_in_use) && (isNull objectParent player)',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Breach Evidence Vault</t>",AP_fnc_evidenceVaultOpen,nil,5,false,false,"",'(AP_effSide isEqualTo civilian) && (typeOf cursorObject isEqualTo "Land_Dome_Big_F") && (cursorObject getVariable [ "AP_evidenceOpen",false ] ) && !(cursorObject getVariable [ "AP_vaultBreached",false ] ) && (AP_inv_demoCharge >= 1) && !AP_action_in_use && (isNull objectParent player) && ((player distance cursorObject) < 12)',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#00BFFF'>Hack Defense Systems</t>",AP_fnc_evidenceSystems,0,5,false,false,"",'(AP_effSide isEqualTo civilian) && !isNull cursorObject && (cursorObject isEqualTo (missionNamespace getVariable [ "evidenceLaptop", objNull ] )) && ((cursorObject getVariable [ "AP_laptopstatus",1 ] ) in [ 1,3 ] ) && ((player distance cursorObject) < 3) && !AP_action_in_use && (isNull objectParent player)',6]);};

            if((AP_adminEvent select 2 isEqualTo 4)&&(AP_inEvent)) then {AP_actions pushBack(_plb_obj addAction ["<t color='#1EC57E'>Unearth Remains</t>", {["digGrave",cursorObject]
                        spawn AP_fnc_eventGraveyardClient},nil,0,false,false,"",'((typeOf cursorObject isEqualTo "Land_ShellCrater_01_F") && !isNull cursorObject && (player distance cursorObject) < 5 && (player inArea "graveyardshift1") && (isNull objectParent player))',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#CB1EEC'>Gather Skeletal Remains</t>", {["gatherBones",cursorObject]
                        spawn AP_fnc_eventGraveyardClient},nil,0,false,false,"",'((typeOf cursorObject in [ "Land_HumanSkeleton_F" ] ) && !isNull cursorObject && (player distance cursorObject) < 5 && (player inArea "graveyardshift1") && (isNull objectParent player))',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Burn Skeletal Remains</t>", {["burnBones",cursorObject]
                        spawn AP_fnc_eventGraveyardClient},nil,0,false,false,"",'((typeOf cursorObject isEqualTo "Land_Campfire_F") && !isNull cursorObject && inflamed cursorObject && (player distance cursorObject) < 5 && (player inArea "graveyardshift1") && (isNull objectParent player))',6]);};

            if(player distance2D (missionNamespace getVariable ["AP_lbPos_site", [4254.9, 3907.5, 0]]) <= 400) then {
                // LOONY BIN HEIST (Malden rework 2026-08-01). Every prop here is a client-local mapData
                // object, so cursorObject works and the class name IS the identity check -- there is no
                // named mission.sqm object to compare against. Phase gating reads AP_lbState via
                // AP_fnc_lbS; the server re-validates all of it (see APS_fnc_loonyBinSRV).
                AP_actions pushBack(_plb_obj addAction ["<t color='#1EC57E'>Breach Detonator</t>", {["lbTrolley", []]
                        spawn AP_fnc_loonyBin},nil,0,false,false,"",'(AP_effSide isEqualTo civilian) && (["AP_lbPos_trolley", [4201.07, 3940.99, 27.78], 5] call AP_fnc_lbAt) && !((call AP_fnc_lbS) param [0, false]) && !((call AP_fnc_lbS) param [7, false])',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#CB1EEC'>Arm Door Charge</t>", {["lbDoorHack", []]
                        spawn AP_fnc_loonyBin},nil,0,false,false,"",'(AP_effSide isEqualTo civilian) && (["AP_lbPos_laptop", [4245.09, 3910.81, 27.76], 5] call AP_fnc_lbAt) && ((call AP_fnc_lbS) param [0, false]) && (((call AP_fnc_lbS) param [1, 0]) isEqualTo 0) && !((call AP_fnc_lbS) param [2, false])',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Breach Patient Record Database</t>", {["lbDbHack", []]
                        spawn AP_fnc_loonyBin},nil,0,false,false,"",'(AP_effSide isEqualTo civilian) && (["AP_lbPos_rugged", [4250.0, 3910.94, 31.57], 5] call AP_fnc_lbAt) && ((call AP_fnc_lbS) param [2, false]) && (((call AP_fnc_lbS) param [3, 0]) isEqualTo 0) && !((call AP_fnc_lbS) param [4, false])',6]);};

            if(player distance2D (missionNamespace getVariable ["AP_lbPos_tablet", [4269.54, 3931.75, 27.74]]) <= 150) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Enter Keycode for Tomb</t>", {["mental_input"]
                        call AP_fnc_createDialog},nil,0,false,false,"",'(AP_effSide isEqualTo civilian) && (["AP_lbPos_tablet", [4269.54, 3931.75, 27.74], 5] call AP_fnc_lbAt) && ((call AP_fnc_lbS) param [4, false]) && !((call AP_fnc_lbS) param [5, false])',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Loot Patient Remains</t>", {["lootPatientsRemains", [cursorObject]]
                        spawn AP_fnc_loonyBin},nil,0,false,false,"",'(AP_effSide isEqualTo civilian) && (cursorObject isEqualTo (SRV_loonyBinData param [ 5, objNull ] )) && !isNull cursorObject && (player distance cursorObject) < 5',6]);};

            // 2026-07-28 (#152, offer side): Break Jewel Case used to gate on a whitelist of fourteen
            // AP_jewerlyCaseN variables. Nothing in this repo ever assigns them -- on the original map
            // they came from Eden object init lines this mission file does not carry -- and an undefined
            // variable in SQF raises rather than warns, so this condition threw every time the scroll
            // menu was built near the site and the action never offered at all. The gate is now the same
            // class-and-polygon test fn_jewelryEmporium already enforces on the case it is handed, so the
            // offer and the action agree: no case can be offered that the function will silently refuse,
            // and none refused that it would accept. typeOf is not redundant against nearestObjects --
            // that filters by isKindOf, so it also returns SUBCLASSES of Coffin_02_F, which the function
            // rejects. The polygon was corrected for this map earlier and clears all 8 cases by ~10 m.
            // 2026-07-28 (#152 again): the looted filter has to run BEFORE the head is taken. A smashed
            // case is never deleted and never hidden -- fn_jewelryEmporiumSRV case "createCase" only sets
            // AP_jewelCaseLooted on it -- so it stays in the world as an ordinary Coffin_02_F. Resolving
            // the NEAREST one and only then rejecting it for being looted meant a smashed case standing
            // marginally closer than an intact one two metres away MASKED it, and the player got no option
            // at all: exactly the "some glass cases do not give option to crack" symptom this line was
            // rewritten to kill. select-then-param skips the looted ones instead of stopping at them.
            // The expression is BYTE-IDENTICAL in the condition on the next line and in the handler below,
            // and must stay that way -- if the two ever resolve different objects, the option offers for
            // one case and acts on another. (The condition's trailing AP_jewelCaseLooted test is now
            // redundant against this filter; it is kept as the belt to this braces.)
            // The registration wrap immediately below is deliberately NOT filtered: it asks only "is there
            // any display case within reach", which is the right question for whether to register an action
            // at all, and registration is sticky while the condition is live. Filtering it would mean a
            // player standing among nothing but already-smashed cases when the menu was built gets no
            // action registered, and then the window-close reset (which un-loots every case) could not
            // bring the option back until fn_setupActions happened to run again.
            // owner 2026-07-29 (maldenjewelry2.md #2): the CROWBAR requirement is gone and the 25-second
            // pry bar with it -- each case is now its own Sequence Breach, eight of them, the owner's
            // explicit choice. The label says so. Two clauses were added to the condition to match the
            // refusals the action gained: the deck (a hack needs ICEBREAKER firmware) and being on foot.
            // Both are cheap and both are tested again inside fn_jewelryEmporium, so the option cannot
            // appear for a player the action will turn away. The casesLootable ([4]) gate deliberately
            // stays OUT of the condition: that refusal SPEAKS ("you can't open this until the emporium has
            // been breached"), and a player who walks in before the gate is done should be told the order
            // of the job, not shown an empty scroll menu. The agreeing-layers rule is about SILENT
            // refusals -- range and identity -- and those all match here at 5 m.
            if((getPosATL player) inPolygon AP_jewelryEmporiumPoly) then {if!(isNull((nearestObjects [player, ["Coffin_02_F"],3]) param [0,objNull])) then {AP_actions pushBack(_plb_obj addAction ["<t color='#1EC57E'>Hack Jewel Case</t>", {["breakGlassCase", [(((nearestObjects [ player, [ "Coffin_02_F" ] , 3 ] ) select {!(_x getVariable [ "AP_jewelCaseLooted", false ] )}) param [ 0, objNull ] )]]
                            spawn AP_fnc_jewelryEmporium},nil,0,false,false,"",'(AP_effSide isEqualTo civilian) && !AP_action_in_use && (isNull objectParent player) && ((call AP_fnc_hasDeck)) && {private _jewelCase = (((nearestObjects [ player, [ "Coffin_02_F" ] , 3 ] ) select {!(_x getVariable [ "AP_jewelCaseLooted", false ] )}) param [ 0, objNull ] ) ; (((typeOf _jewelCase) isEqualTo "Coffin_02_F") && {(getPosATL _jewelCase) inPolygon AP_jewelryEmporiumPoly}) && !isNull _jewelCase && (player distance _jewelCase) < 5 && !(isObjectHidden _jewelCase) && !(_jewelCase getVariable [ "AP_jewelCaseLooted", false ] )}',6]);};

                // 2026-07-28: proximity-based, not cursor-based, same as the Fed gate fix (f7f0ef9).
                // cursorObject isEqualTo AP_jewerlyEmporium could never be true here: the gate is a
                // large flat structure and the cursor ray lands on the paving underfoot, not the gate,
                // exactly as proven on the Fed's own gate. This wrap also used to anchor on Altis's
                // coordinate for this door (~14.5 km off Malden), then on AP_JEWEL_GATEPOS in 2D. It
                // now measures exactly what the two inner checks measure -- 3D distance to AP_jewelGate
                // itself, at the same 6 m -- so the three layers cannot disagree. Two reasons it had to
                // stop measuring the anchor: AP_JEWEL_GATEPOS is only the nearestObjects SEARCH SEED
                // (12 m radius, APS_fnc_maldenJewelSRV), so the resolved gate can sit metres away from
                // it and a player legitimately 6 m from the GATE could measure past 6 m from the SEED
                // and never have the action registered; and 2D is always <= 3D, so the outer wrap could
                // equally pass where the inner 3D checks refuse. Still getVariable-guarded like
                // AP_FED_TERMPOS above -- a client that has not yet received the publicVariable
                // measures against objNull, fails the check, and throws nothing. 6 m matches
                // fn_jewelryEmporium's own refusal radius so a visible option can never be refused for
                // the reason it was offered. The condition's trailing (player distance cursorObject) < 15
                // went with it: aimed at sky or past ray-cast range cursorObject is objNull, and distance
                // against a null object returns the documented 1e10 "distance cannot be calculated"
                // sentinel rather than any real range -- so the < 15 clause was false, the whole && chain
                // went false and the option flickered with wherever the player happened to be looking.
                // (It is NOT a measurement to world origin ~13 km off, as this note used to say: the
                // conclusion and the fix were both right, the stated mechanism was not, and 13 km is close
                // enough to a plausible threshold to mislead anyone later reasoning about one.) The Fed's
                // own gate entry above carries no such clause, and the 6 m gate proximity already bounds
                // range.
                // owner 2026-07-28, in game: 10 m, not 6. Standing against the gate measured 6.35 m
                // (JEWELDIAG, dist=6.35021 inPoly=true), so the option was unreachable at the one spot
                // it exists for. `distance` runs from the player's centre to the OBJECT ORIGIN, and this
                // gate's origin sits deep enough inside its own geometry that touching it still reads
                // over 6. All three layers move together -- the wrap here, the condition below, and the
                // refusal in fn_jewelryEmporium's "hackGate" -- or the option offers and then refuses.
                // owner 2026-07-29 (maldenjewelry2.md #2): the ten-second DRILL is gone -- this gate is a
                // Sequence Breach like every other opening on the job, and it is still the one that raises
                // the alarm and starts the event. Case renamed "startDrill" -> "hackGate" on both sides.
                // The condition gained the deck, the on-foot test and !AP_action_in_use to match the
                // refusals in fn_jewelryEmporium; the 10 m and the guarded AP_jewelGate read are unchanged
                // and still measure exactly what the wrap above and the action itself measure.
                // SRV_jewelryEmporiumSRV is read GUARDED here where it was bare. It is publicVariable'd
                // from server init.sqf:241, so a client that connects while the server is still booting can
                // evaluate this condition before it lands -- and a bare read of an undefined variable
                // RAISES inside a scroll condition, which deletes every entry registered after it. The
                // default is the real seed, so every slot reads the same as a fresh boot.
                if(player distance (missionNamespace getVariable [ "AP_jewelGate", objNull ] )
                <=10) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Breach Emporium Gate</t>", {["hackGate", []]
                            spawn AP_fnc_jewelryEmporium},nil,0,false,false,"",'!((missionNamespace getVariable [ "SRV_jewelryEmporiumSRV", [ -1800, false, false, false, false, 0, 6 ] ] ) param [ 1, false ] ) && (AP_effSide isEqualTo civilian) && (!AP_action_in_use) && (isNull objectParent player) && ((call AP_fnc_hasDeck)) && (!isNull (missionNamespace getVariable [ "AP_jewelGate", objNull ] )) && ((player distance (missionNamespace getVariable [ "AP_jewelGate", objNull ] )) <= 10)',6]);};

                AP_actions pushBack(_plb_obj addAction ["<t color='#CB1EEC'>Take Jewelry Piece</t>", {["takeJewelryContents", [cursorObject]]
                        spawn AP_fnc_jewelryEmporium},nil,0,false,false,"",'(AP_effSide isEqualTo civilian) && (typeOf cursorObject isEqualTo "Land_Trophy_01_gold_F") && !isNull cursorObject && (player distance cursorObject) < 8',6]);

                // owner 2026-07-29 (maldenjewelry2.md #3): the "Load Container" entry that stood here is
                // GONE, replaced by "Load Jewelry" at the crane further down. It could never fire on this
                // map -- its condition needed cursorObject to equal AP_jewerlyContainer, which
                // initPlayerLocal.sqf:118 binds to objNull by design -- and its handler was 100 %
                // client-side: the inventory removal, the counter and its publicVariable all ran on the
                // caller's machine, with no server case behind it at all. A stage that mints an armed
                // O_LSV_02_armed_F cannot live there. It also handled jewelBag only, had no bar, no
                // done-flag and no repeat guard. Its crane cannot be bound by cursor in any case: a
                // Land_RepairDepot_01_tan_F is a 7.8 x 6.5 x 4.9 m gantry and the ray lands on the deck
                // underfoot, the failure already proven on the Fed gate and again on this emporium's gate.

                // owner 2026-07-29: the offer now agrees with the action's refusal about STATE as well as
                // radius. It gated on AP_safeLooted ALONE, which is the jewelBag's one-shot and says
                // nothing about the Hope Diamond, while fn_jewelryEmporium case "takeSafeContents" refuses
                // only when BOTH prizes are gone. Those two disagree in a reachable state: the bag taken
                // and the diamond still in the safe hides the option on a safe that still holds $108,000,
                // with no way back in for the rest of the run. The action's own order-matters rule makes
                // that state hard to reach today (the diamond is asked for first and a diamond that will
                // not fit stops the bag too), but it is one edit away from being reachable and the cost of
                // it is the jackpot -- so the offer asks the same question the action asks: is EITHER prize
                // still there. Both reads are getVariable-guarded, so neither can raise inside a scroll
                // condition and delete the menu.
                // owner 2026-07-29 (b0131 follow-up): PROXIMITY TO THE PUBLISHED OPEN SAFE, not cursor
                // identity, and the payload is empty. The same conversion "Breach Safe Terminal" below and
                // "Breach Emporium Gate" above already carry. Three reasons, cheapest last:
                //   * the condition and the PAYLOAD were two SEPARATE reads of cursorObject, taken a frame
                //     apart -- the engine re-evaluates a scroll condition continuously, the payload is
                //     built when the entry FIRES. Aim drifts between the two and the action's typeOf test
                //     exits with NO MESSAGE AT ALL: the option is visible, the player clicks it, nothing
                //     whatever happens. The "Hack Jewel Case" note above states the rule this broke -- the
                //     resolution must be identical in the condition and in the handler, or the option
                //     offers for one object and acts on another.
                //   * it FLICKERED with wherever the player was looking, and the four gold trophies the
                //     weld drops 0.8 m IN FRONT OF THIS SAFE are what the cursor lands on while they are
                //     being collected. They stand between the looter and the safe at the one spot the safe
                //     is looted from, so the entry was at its least reliable exactly when it was wanted.
                //   * the cursor was doing no work at all. APS_fnc_jewelryEmporiumSRV case
                //     "takeSafeContents" reads its own AP_jewelSafeOpen and never looks at any object the
                //     client names, so the payload was a hazard with no purpose.
                // 5 m, not the gates' 10. The 10 exists because `distance` runs to the OBJECT ORIGIN and
                // those gates' origins sit deep inside their own geometry -- 6.35 m measured while standing
                // against the anchor. This object's does not: boundingBoxReal on Fridge_01_F.p3d, the model
                // BOTH halves of the pair share (they differ only in the Door_1 animation phase), is
                // [[-0.291,-0.359,-0.519],[0.291,0.359,0.519]] -- a 0.58 x 0.72 x 1.04 m box whose origin
                // is its own centre, so no point on its surface is further than 0.69 m from what `distance`
                // measures to. The open safe is created at getPosATL AP_jewelSafe, so this is the SAME
                // range the neighbouring weld gate measures at the same 5 m: a player who could weld the
                // safe can loot it. Well inside the server's 30 m slack, so no layer contradicts another.
                // Every AP_jewelSafeOpen read is getVariable-GUARDED. The server does not assign or
                // publish that name until the first weld of the session and sets it back to objNull when
                // the window closes, so a bare read is nil on a fresh boot -- and a raise inside a scroll
                // condition deletes every entry registered after it. objNull getVariable returns the
                // default rather than raising, so the two flag reads are safe on the same guard.
                // owner 2026-07-29 (report on b0131): THE LABEL HAS TO NAME THE PRIZE.
                // The owner reported the Hope Diamond "didn't spawn". It did -- the server flagged it and
                // logs every grant path, and that run has no takeSafeContents line at all, while banking 11
                // of the 12 gold trophies in the ~30 s between the weld and walking to the crane. He was
                // standing at this safe with this menu open and read "Take Safe Loot", which does not say
                // DIAMOND anywhere, next to a "Take Jewelry Piece" entry for each trophy he WAS collecting.
                // So while the diamond is still in there, the scroll entry says so. This is the cheapest of
                // the three wording changes and the one that lands in the place the player is already
                // looking; the other two are the weld broadcast and a direct hint to the welder, both in
                // APS_fnc_jewelryEmporiumSRV case "weldSafe".
                // IT IS LIVE, not a boot-time snapshot: fn_setupActions is re-run by AP_fnc_enableActions
                // every time the scroll menu is opened (core/fn_setupEVH.sqf:37 binds it to MouseZchanged),
                // so this reads the flag as it stands at that moment.
                // THE STEM "Take Safe Loot" IS KEPT. Half a dozen comments across this file, the client
                // action and the server case name it, and the diag_log at the weld quotes it -- a rename
                // would break every one of those references for no gain. The suffix is added, not swapped.
                // CONDITIONAL, because the action outlives the diamond: it still grants the jewelBag
                // afterwards (the offer condition below asks whether EITHER prize is left), so a fixed label
                // naming the diamond would be a lie the moment somebody takes it. Both reads are
                // getVariable-guarded exactly as the condition below is -- AP_jewelSafeOpen does not exist
                // until the first weld of the session, and objNull getVariable returns the default rather
                // than raising, which matters because a raise here would delete the whole scroll menu.
                private _plbSafeLootLbl = if (((missionNamespace getVariable [ "AP_jewelSafeOpen", objNull ] ) getVariable [ "AP_jewelHopeInSafe", false ] )) then {"Take Safe Loot -- HOPE DIAMOND"} else {"Take Safe Loot"};
                AP_actions pushBack(_plb_obj addAction [format ["<t color='#CB1EEC'>%1</t>", _plbSafeLootLbl], {["takeSafeContents", []]
                        spawn AP_fnc_jewelryEmporium},nil,0,false,false,"",'(AP_effSide isEqualTo civilian) && (!isNull (missionNamespace getVariable [ "AP_jewelSafeOpen", objNull ] )) && ((player distance (missionNamespace getVariable [ "AP_jewelSafeOpen", objNull ] )) < 5) && (!((missionNamespace getVariable [ "AP_jewelSafeOpen", objNull ] ) getVariable [ "AP_safeLooted", false ] ) || ((missionNamespace getVariable [ "AP_jewelSafeOpen", objNull ] ) getVariable [ "AP_jewelHopeInSafe", false ] ))',6]);

                // owner 2026-07-29 (maldenjewelry2.md #2): the PLASMA CUTTER requirement is gone and the
                // weld bar with it -- the safe is a Terminal Breach now, difficulty 2 (the bank-vault
                // tier). Two things changed besides the label.
                // (1) PROXIMITY, not cursor. The old condition needed cursorObject to BE the safe, so the
                //     option flickered with wherever the player happened to be looking, and against a null
                //     cursor `distance` returns the 1e10 "cannot be calculated" sentinel rather than a
                //     range. The action now measures 5 m to the safe object, which is exactly what
                //     fn_jewelryEmporium's own refusal measures.
                // (2) AP_jewelSafe read GUARDED, not AP_jewerlySafe. AP_jewerlySafe is a ONE-TIME
                //     snapshot taken at initPlayerLocal.sqf:116; a client that joined before the safe's
                //     publicVariable landed holds objNull for its whole session, so the option never
                //     appeared for them -- and the old handler then sent that objNull on, which the server
                //     answers with a "-SEC- safe object mismatch" row against an innocent player.
                // The safeDrilled ([2]) gate stays out of the condition on purpose, like the display
                // cases': that refusal speaks, and the order of the job is worth telling the player.
                AP_actions pushBack(_plb_obj addAction ["<t color='#CB1EEC'>Breach Safe Terminal</t>", {["weldSafe", []]
                        spawn AP_fnc_jewelryEmporium},nil,0,false,false,"",'(AP_effSide isEqualTo civilian) && (!AP_action_in_use) && (isNull objectParent player) && ((call AP_fnc_hasDeck)) && (!isNull (missionNamespace getVariable [ "AP_jewelSafe", objNull ] )) && ((player distance (missionNamespace getVariable [ "AP_jewelSafe", objNull ] )) < 5) && !((missionNamespace getVariable [ "SRV_jewelryEmporiumSRV", [ -1800, false, false, false, false, 0, 6 ] ] ) param [ 3, false ] )',6]);};

            // owner 2026-07-29 (maldenjewelry2.md #1, #3): THESE TWO ENTRIES MUST LIVE OUTSIDE THE POLYGON
            // WRAP ABOVE. AP_jewelryEmporiumPoly is [[7525,10595],[7562,10595],[7562,10548],[7525,10548]]
            // and BOTH of the things they anchor on fall outside it: the crane sits at x 7515.6, y 10596.1
            // (west of the polygon and north of its top edge) and the perimeter gates at B (x ~7504) and C
            // (y 10607.5) are outside it too. Registered inside that wrap they could never be offered from
            // the one spot each exists for.
            // The wrap here is the cheapest test that cannot raise: `count` over the published gate list,
            // which is [] on a client that has not received it yet.
            if(({!isNull _x && {(player distance _x) <= 10}} count (missionNamespace getVariable [ "AP_jewelGates", [ ] ] )) > 0) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Breach Perimeter Gate</t>", {["perimeterGate", [(((missionNamespace getVariable [ "AP_jewelGates", [ ] ] ) select {!isNull _x && {_x isNotEqualTo (missionNamespace getVariable [ "AP_jewelGate", objNull ] )} && {((_x getVariable [ "bis_disabled_Door_1", 0 ] ) isEqualTo 1)} && {(player distance _x) <= 10}}) param [ 0, objNull ] )]]
                        spawn AP_fnc_jewelryEmporium},nil,0,false,false,"",'(AP_effSide isEqualTo civilian) && (!AP_action_in_use) && (isNull objectParent player) && ((call AP_fnc_hasDeck)) && (!isNull (((missionNamespace getVariable [ "AP_jewelGates", [ ] ] ) select {!isNull _x && {_x isNotEqualTo (missionNamespace getVariable [ "AP_jewelGate", objNull ] )} && {((_x getVariable [ "bis_disabled_Door_1", 0 ] ) isEqualTo 1)} && {(player distance _x) <= 10}}) param [ 0, objNull ] ))',6]);};
            // The resolution expression above is BYTE-IDENTICAL in the handler payload and in the
            // condition and must stay that way -- if the two ever resolve different gates, the option
            // offers for one and breaches another. Three clauses are load-bearing:
            //   * the ANCHOR IS EXCLUDED. AP_jewelGates contains the breach anchor (the Fed's
            //     AP_fedGates does the same), and without this clause a player could open the one gate
            //     whose job is to trip the alarm without ever starting the event -- the whole heist, its
            //     cop requirement, its wanted sweep and its cooldown, all skipped for free.
            //   * bis_disabled_Door_1 isEqualTo 1 is "still sealed". That is what
            //     APS_fnc_maldenJewelSRV ["seal"] writes, published, so every client reads it. NEVER use
            //     the vanilla "Open Door" option as the tell: OpenDoor_1.condition tests the animation
            //     PHASE and is offered on a perfectly locked gate; only CloseDoor_1 reads the lock.
            //   * 10 m, the same radius the wrap and fn_jewelryEmporium's refusal use, for the reason the
            //     anchor needed 10 and not 6: `distance` runs to the object origin and these gates' origins
            //     sit inside their own geometry (measured 6.35 m while touching the anchor).
            // Where two sealed gates are in reach at once -- only possible at B, whose pair stand 8.76 m
            // apart -- list order decides, and the same order decides in both layers, so they agree. The
            // one just breached drops out of the filter, so the second is then the only candidate.

            // owner 2026-07-29 (maldenjewelry2.md #3, #6): LOAD JEWELRY. Anchored on a published
            // COORDINATE, never on an object: Land_RepairDepot_01_tan_F is a fn_mapData.sqf row with
            // _xIsServer = false, i.e. a per-client createSimpleObject the SERVER cannot see with
            // nearestObjects and the client only holds while that dynamicMap zone is loaded. A boot
            // resolver copied from the anchor gate would publish objNull here and every layer of the stage
            // would refuse for ever, silently. This is the shape the Fed's dome terminal already uses
            // (AP_FED_TERMPOS, fn_openVault.sqf:29-31), including the count-isEqualTo-3 guard that makes
            // a missing publicVariable refuse instead of raise.
            // distance2D: the crane deck is at ATL 3.838 and the Qilin pad below it at 0.19, so a loader
            // may legitimately stand on either. "At the crane" is a horizontal question.
            // The last clause is the offer half of "only offer it when the player is carrying something
            // loadable", and fn_jewelryEmporium tests the same two counters at the same guarded reads.
            if((count (missionNamespace getVariable [ "AP_JEWEL_CRANEPOS", [ ] ] )) isEqualTo 3 && {(player distance2D (missionNamespace getVariable [ "AP_JEWEL_CRANEPOS", [ 0, 0, 0 ] ] )) <= 10}) then {AP_actions pushBack(_plb_obj addAction ["<t color='#CB1EEC'>Load Jewelry</t>", {["loadJewelry", []]
                        spawn AP_fnc_jewelryEmporium},nil,0,false,false,"",'(AP_effSide isEqualTo civilian) && (!AP_action_in_use) && (isNull objectParent player) && ((count (missionNamespace getVariable [ "AP_JEWEL_CRANEPOS", [ ] ] )) isEqualTo 3) && ((player distance2D (missionNamespace getVariable [ "AP_JEWEL_CRANEPOS", [ 0, 0, 0 ] ] )) <= 10) && ((missionNamespace getVariable [ "SRV_jewelryEmporiumSRV", [ -1800, false, false, false, false, 0, 6 ] ] ) param [ 1, false ] ) && !(missionNamespace getVariable [ "AP_jewelLoaded", false ] ) && (((missionNamespace getVariable [ "AP_inv_jewelBag", 0 ] ) + (missionNamespace getVariable [ "AP_inv_jewelHope", 0 ] )) > 0)',6]);};
            // AP_jewelLoaded is the load's done-flag, and it is the SAME NAME the server publishes
            // (APS_fnc_jewelryEmporiumSRV case "loadJewelry" arms it, case "robberyStarted" and the
            // window-close reset clear it). It replaces a read of `SRV_jewelryEmporiumSRV param [ 5, false,
            // [ false ] ]` -- a slot the server has NEVER written. Server init.sqf:241 and the
            // "robberyStarted" state stamp both put the NUMBER 0 in slot 5, so that read could only ever
            // return the false default: the option stayed offered after a completed load, and the
            // type-checked read of a Number against a Bool logged an engine type error every time this
            // condition was evaluated -- which for a scroll condition is several times a second near the
            // crane. Read GUARDED because the flag does not exist until the first robbery of the session
            // starts, and a bare read of an undefined variable RAISES inside a scroll condition, which
            // deletes every entry registered after it.

            // 2026-08-22: was gated on markers AP_exchangeMarker1..5, which exist NOWHERE -- not in
            // mission.sqm, not in mapData, nowhere in the repo. getMarkerPos on a missing marker
            // returns [0,0,0], so this action was only ever offered within 55 m of the map corner.
            // Now it reads the Exchange NPC's own position out of the same mapData table that
            // places it (AP_exchangeSpots, built in core/init.sqf), so there is one source of truth
            // and no marker to place. Guarded default: this runs before init on a slow client.
            if((missionNamespace getVariable ["AP_exchangeSpots", []]) findIf {(player distance2D _x) < 55} > -1) then {AP_actions pushBack(_plb_obj addAction ["<t color='#4DF53E'>LoonyBin Exchange - List Vehicle</t>",AP_fnc_exchangeCreateListing,"vehicleItem",0,false,false,"",'!isNull cursorObject && (alive cursorObject) && !(isPlayer cursorObject) && (cursorObject in AP_vehicles) && (player distance cursorObject < 5) && ((cursorObject isKindOf "Car") || (cursorObject isKindOf "Air") || (cursorObject isKindOf "Ship"))',6]);};

            AP_actions pushBack(_plb_obj addAction ["Hack Bank Vault", {if ((missionNamespace getVariable ["AP_lastBankDrillClick", -999]) > serverTime - 15) exitWith {["Drill already starting, give it a moment.","basic"]
                        spawn AP_fnc_handleMessage;};

                    AP_lastBankDrillClick = serverTime;

                    if([]
                    call AP_fnc_activeFederalEvent) exitWith {["There is already another Federal Event happening.","basic"]
                        spawn AP_fnc_handleMessage;};

                    if!([4,true]
                    call AP_fnc_policeRequired) exitWith {};

                    if(SRV_lastRobbery>(serverTime-(60*15))) exitWith {[2,format ["Security is high due to a recent robbery and you cannot rob the bank. Try again in %1 minute(s).",ceil((SRV_lastRobbery-(serverTime-(60*15)))/60)]]
                        call AP_fnc_broadcast};

                    // LooneyBin 2026-07-18: Cyberdeck -- Terminal Breach (6 cmds) gates the bank job (was a drill)
                    private _bankRoot = [2] call AP_fnc_cyberdeckTerm;
                    if !(_bankRoot isEqualTo 1) exitWith {}; [[player,cursorObject],"APS_fnc_bankRobbery",2]
                    spawn AP_fnc_MP;
 ["bankdrill",1]
                    call AP_fnc_statArrUpdate;},nil,4,true,true,"",'(player distance (getMarkerPos "AP_bank_door") < 4) && (call AP_fnc_hasDeck) && !(AP_bank_robbed select 0) && (AP_bank_robbed select 1) < serverTime - 1200 && (isNull objectParent player)',6]);

            if(license_civ_bounty) then {if({player distance getMarkerPos format ["bounty_%1",_x]
                    <(AP_track_radius+100)}
                count [0,1,2,3]
                >0) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Track Fugitive 1</t>", {[0]
                            call AP_fnc_trackBounty},nil,0,false,true,"",' player distance (getMarkerPos "bounty_0") < AP_track_radius ',6]);

                    AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Track Fugitive 2</t>", {[1]
                            call AP_fnc_trackBounty},nil,0,false,true,"",' player distance (getMarkerPos "bounty_1") < AP_track_radius ',6]);

                    AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Track Fugitive 3</t>", {[2]
                            call AP_fnc_trackBounty},nil,0,false,true,"",' player distance (getMarkerPos "bounty_2") < AP_track_radius ',6]);

                    AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Track Fugitive 4</t>", {[3]
                            call AP_fnc_trackBounty},nil,0,false,true,"",' player distance (getMarkerPos "bounty_3") < AP_track_radius ',6]);};

                if((471 in AP_completedLifetimeQuests)&&(currentWeapon player in ["hgun_P07_F","hgun_P07_khk_F","hgun_P07_blk_F"])) then {private _toggleP07= {private _lethalState=player getVariable ["AP_lethalBH",false];

                        player setVariable ["AP_lethalBH",!(_lethalState),true];

                        private _text=if!(_lethalState) then {"lethal rounds"}
                        else {"downing rounds"};
 [format ["You switched to %1.",_text],"basic"]
                        spawn AP_fnc_handleMessage;};

                    AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Load Lethal Rounds for P07</t>",_toggleP07,nil,1.5,false,false,"",'!(player getVariable [ "AP_lethalBH",false ] ) && (currentWeapon player in [ "hgun_P07_F", "hgun_P07_khk_F", "hgun_P07_blk_F" ] )',6]);

                    AP_actions pushBack(_plb_obj addAction ["<t color='#00FF00'>Load Non-Lethal Rounds for P07</t>",_toggleP07,nil,1.5,false,false,"",'(player getVariable [ "AP_lethalBH",false ] ) && (currentWeapon player in [ "hgun_P07_F", "hgun_P07_khk_F", "hgun_P07_blk_F" ] )',6]);};

                AP_actions pushBack(_plb_obj addAction ["Send to Jail", {[cursorObject]
                        call AP_fnc_arrestAction},nil,0,false,false,"",'!isNull cursorObject && isPlayer cursorObject && license_civ_bounty && (side cursorObject isEqualTo civilian) && (cursorObject getVariable [ "AP_restrained",false ] ) && (cursorObject getVariable [ "AP_civRestrained",false ] ) && alive cursorObject && (player distance cursorObject < 3.5) && (( { player distance (getMarkerPos _x) < 19 } count [ "jail_release2" ] > 0) || { player distance getMarkerPos _x < 15 } count [ "marker_609","marker_606","marker_607","marker_608","marker_611","marker_610", "marker_612" ] > 0) && !(cursorObject getVariable [ "AP_escorting",false ] )',6]);

                AP_actions pushBack(_plb_obj addAction ["Send Combat Logger to Jail", {[cursorObject]
                        spawn AP_fnc_jailCL},"",0,false,false,"",'!isNull cursorObject && !(isPlayer cursorObject) && license_civ_bounty && (player distance cursorObject < 3.5) && ((typeOf cursorObject) isEqualTo "Land_Bodybag_01_black_F")',3]);

                AP_actions pushBack(_plb_obj addAction ["Bounty Hunter Enter as Driver", {["driver"]
                        call AP_fnc_forceVehicleEnter},nil,200,false,false,"",'(cursorObject in AP_vehicles) && { !isNull cursorObject && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship") && (locked cursorObject) != 0 && cursorObject distance player < 5 }',4.5]);

                AP_actions pushBack(_plb_obj addAction ["Bounty Hunter Enter as Passenger", {["passenger"]
                        call AP_fnc_forceVehicleEnter},nil,100,false,false,"",'(cursorObject in AP_vehicles) && { !isNull cursorObject && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship") && (locked cursorObject) != 0 && cursorObject distance player < 5 }',4.5]);

                if(player getVariable ["AP_activeBounty",false]
                ||!(AP_bounty_list isEqualTo [])) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF00FF'>Hide Badge</t>", {player setVariable ["AP_activeBounty",nil,true];},3,0,false,true,"",'player getVariable [ "AP_activeBounty", false ]',6]);

                    AP_actions pushBack(_plb_obj addAction ["<t color='#FF00FF'>Show Badge</t>", {player setVariable ["AP_activeBounty",true,true];},3,0,false,true,"",'!(player getVariable [ "AP_activeBounty", false ] ) && !(AP_bounty_list isEqualTo [ ] )',6]);};};

            AP_actions pushBack(_plb_obj addAction ["Destroy Spike Strip",AP_fnc_packupSpikes,"",0,false,false,"",'_spikes = nearestObjects [ player, [ "Land_Razorwire_F" ] ,8 ] select 0 ; !isNil "_spikes" && !isNil { (_spikes getVariable "AP_placed") }',6]);

            if(AP_juryVoteEnabled) then {AP_actions pushBack(_plb_obj addAction ["Vote <t color='#00FF00'>NOT GUILTY</t>", {["voteNotGuilty", [player]]
                        call AP_fnc_trialSystem},false,6,false,true,"",' !(AP_clientTrialData select 2)']);

                AP_actions pushBack(_plb_obj addAction ["Vote <t color='#FF0000'>GUILTY</t>", {["voteGuilty", [player]]
                        call AP_fnc_trialSystem},false,6,false,true,"",'!(AP_clientTrialData select 2)']);};

            AP_actions pushBack(_plb_obj addAction ["Enter DLC vehicle as Driver", {["dlcDriver"]
                    call AP_fnc_forceVehicleEnter},nil,200,false,false,"",'(locked cursorObject) isEqualTo 0 && { !isNull cursorObject && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship") && cursorObject distance player < 5 && !(getAssetDLCInfo [ typeOf cursorObject ] select 1) }',4.5]);};

        case west: {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Use Defibrillator</t>",AP_fnc_revivePlayer,cursorObject,-1,false,false,"",'!isNull cursorObject && cursorObject isKindOf "CAManBase" && !(alive cursorObject) && cursorObject getVariable [ "AP_revivable",false ] && AP_inv_defib > 0 && (98 in AP_side_talents) && (player distance cursorObject) < 3.5 && (isNull objectParent player) && (isNull objectParent cursorObject)',5]);

        // PRISON GATE DISARM 2026-07-29. The cop answer to the gate hack. Anchored on the gate: the hold used
        // to key off a laptop this map does not have, passed in by fn_doPrisonBreak, which has no callers.
        // 12 m matches AP_fnc_stopPrisonBreak's own refusal bound; APS_fnc_prisonGateSRV re-checks at 15 m
        // from remoteExecutedOwner. Offered only while a break is actually running.
        AP_actions pushBack(_plb_obj addAction ["<t color='#3399FF'>Restore Prison Security</t>",AP_fnc_stopPrisonBreak,"",0,false,false,"",'(AP_effSide isEqualTo west) && (!isNull (missionNamespace getVariable [ "AP_prisonGateIn", objNull ] )) && ((player distance (missionNamespace getVariable [ "AP_prisonGateIn", objNull ] )) <= 12) && (((missionNamespace getVariable [ "SRV_prisonData", [ 0, false ] ] ) param [ 1, false ] )) && (!AP_action_in_use) && (isNull objectParent player)',12]);

            AP_actions pushBack(_plb_obj addAction ["Restrain", {[cursorObject]
                    call AP_fnc_restrain},nil,-1,false,false,"",'if (isPlayer cursorObject) then { ((side cursorObject != west) && alive cursorObject && cursorObject isKindOf "CAManBase" && cursorObject distance player < 5 && !(cursorObject getVariable [ "AP_restrained",false ] ) && speed cursorObject < 1) && (isNull objectParent player) && (isNull objectParent cursorObject) } ;',6]);

            AP_actions pushBack(_plb_obj addAction ["Escort", {[cursorObject]
                    call AP_fnc_escortAction},"",0,false,false,"",'!isNull cursorObject && cursorObject isKindOf "CAManBase" && (isPlayer cursorObject) && alive cursorObject && cursorObject distance player < 3.5 && (cursorObject getVariable [ "AP_restrained",false ] ) && attachedTo cursorObject != player && (isNull objectParent player) && (isNull objectParent cursorObject)',6]);

            AP_actions pushBack(_plb_obj addAction ["Stop Escorting",AP_fnc_stopEscorting,"",0,false,false,"",' !isNull AP_escort',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Disarm</t>", {[cursorObject]
                    call AP_fnc_disarmAction},nil,-1,false,false,"",'!isNull cursorObject && !(alive cursorObject) && !(cursorObject getVariable [ "AP_disarmed", false ] ) && cursorObject isKindOf "CAManBase" && player distance cursorObject < 2 && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#FF8000'>Remove Firing Pin</t>", {[cursorObject]
                    call AP_fnc_removeFiringPin},nil,1.5,false,false,"",'(AP_effSide isEqualTo west) && !isNull cursorObject && (isPlayer cursorObject) && (side cursorObject isEqualTo civilian) && (cursorObject getVariable [ "AP_restrained",false ] ) && !(cursorObject getVariable [ "AP_civRestrained",false ] ) && !(cursorObject getVariable [ "AP_gunBroken",false ] ) && (player distance cursorObject < 4) && (isNull objectParent player)',6]);

            // owner 2026-06-28: the "Send Fugitive to Jail" claim action MOVED onto the bag itself (server-side,
            // fn_playerDisconnected -> global+JIP `addAction`). A small ground bag couldn't be cursorObject'd, and the
            // old gate required the BH to be actively tracking the fugitive -- too strict vs the server's any-cop/BH auth.

            AP_actions pushBack(_plb_obj addAction ["Give Ticket",AP_fnc_ticketAction,"",0,false,false,"",'if (!isNull cursorObject) then { if (isPlayer cursorObject) then { ((side cursorObject != west) && alive cursorObject && cursorObject distance player < 3.5 && !(cursorObject getVariable [ "AP_escorting",false ] ) && (cursorObject getVariable [ "AP_restrained",false ] )) && (isNull objectParent player) } ; } ;',6]);

            AP_actions pushBack(_plb_obj addAction ["Cop Enter as Driver", {["driver"]
                    call AP_fnc_forceVehicleEnter},nil,200,false,false,"",' !isNull cursorObject && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship") && (locked cursorObject) != 0 && cursorObject distance player < 5 && (isNull objectParent player)',7]);

            AP_actions pushBack(_plb_obj addAction ["Cop Enter as Passenger", {["passenger"]
                    call AP_fnc_forceVehicleEnter},nil,100,false,false,"",' !isNull cursorObject && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship") && (locked cursorObject) != 0 && cursorObject distance player < 5 && !(cursorObject isKindOf "B_Heli_Attack_01_F") && (isNull objectParent player)',7]);

            AP_actions pushBack(_plb_obj addAction ["Cop Enter as Commander", {["commander"]
                    call AP_fnc_forceVehicleEnter},nil,100,false,false,"",'!isNull cursorObject && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship") && (locked cursorObject) != 0 && cursorObject distance player < 5 && ((cursorObject isKindOf "B_Heli_Attack_01_F")||(cursorObject isKindOf "B_Heli_Transport_01_F")||(cursorObject isKindOf "B_MRAP_01_hmg_F") || cursorObject isKindOf "I_MRAP_03_F") && (isNull objectParent player)',7]);

            AP_actions pushBack(_plb_obj addAction ["Cop Enter as Gunner", {["gunner"]
                    call AP_fnc_forceVehicleEnter},nil,100,false,false,"",'!isNull cursorObject && ((cursorObject isKindOf "Car")||(cursorObject isKindOf "Air")||(cursorObject isKindOf "Ship")) && (locked cursorObject) != 0 && cursorObject distance player < 5 && (count (allTurrets [ cursorObject,true ] ) > 0) && !(cursorObject isKindOf "O_Heli_Light_02_unarmed_F") && (isNull objectParent player)',7]);

            AP_actions pushBack(_plb_obj addAction ["Exit", {["exit"]
                    call AP_fnc_forceVehicleEnter},nil,100,false,false,"",'(vehicle player != player) && (locked(vehicle player)==2)',8]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#FFF000'>Pull out of vehicle</t>", {[cursorObject]
                    call AP_fnc_pulloutAction},nil,0,false,false,"",'!isNull cursorObject && (player distance cursorObject) < 4 && (count crew cursorObject) > 0 && (cursorObject isKindOF "Car" || cursorObject isKindOf "Ship" || cursorObject isKindOf "Air") && { alive _x } count crew cursorObject > 0 && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#FFF000'>Put in Vehicle</t>", {[cursorObject]
                    call AP_fnc_putInVeh},nil,-1,false,false,"",'!isNull cursorObject && (player distance cursorObject) < 6 && speed cursorObject < 2 && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship") && !isNull (player getVariable [ "AP_escortObj",objNull ] ) && isPlayer (player getVariable [ "AP_escortObj",objNull ] ) && alive (player getVariable [ "AP_escortObj",objNull ] ) && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#FFFF00'>Emergency Lights (OFF)</t>", {if ((vehicle player) getVariable ["AP_lights", false]) then { [vehicle player] call AP_fnc_sirenLights; };},nil,-1,false,false,"",'!(isNull objectParent player) && (objectParent player getVariable [ "AP_side","civ" ] == "cop") && objectParent player getVariable [ "AP_lights", false ] && (player isEqualTo (driver vehicle player)) && (!isNil { vehicle player getVariable "AP_lights" } )',6]);

            if("B_UavTerminal"in(assignedItems player)) then {AP_actions pushBack(_plb_obj addAction ["<t color='#0000FF'>Connect to UAV</t>", {player connectTerminalToUAV cursorObject;
 [cursorObject,900]
                        call AP_fnc_setVehicleIdle;},false,90,false,false,"",'!isNull cursorObject && alive cursorObject && (player distance cursorObject) < 6 && (typeOf cursorObject == "B_UAV_01_F") && (!isUAVConnected cursorObject) && (isNull objectParent player)',6]);

                AP_actions pushBack(_plb_obj addAction ["Show UAV Feed", {showUAVFeed true},false,4,false,false,"",' !isNull (getConnectedUAV player) && !shownUAVFeed ',6]);

                AP_actions pushBack(_plb_obj addAction ["Hide UAV Feed", {showUAVFeed false},false,4,false,false,"",' shownUAVFeed ',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#FF69B4'>Show Security Cameras</t>", {AP_showCams=true},nil,1.5,false,false,"",'!AP_showCams',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#FF69B4'>Hide Security Cameras</t>", {AP_showCams=false},nil,1.5,false,false,"",'AP_showCams',6]);

                if(AP_showCams) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF69B4'>Jewelry Desk</t>", {[0]
                            call AP_fnc_trafficCams},nil,1.5,false,false,"",'AP_showCams && isNil "AP_trafficCam" && player distance2d [ 20714, 16625, 5 ] < 4500',6]);

                    AP_actions pushBack(_plb_obj addAction ["<t color='#FF69B4'>Jewelry Front Gate</t>", {[1]
                            call AP_fnc_trafficCams},nil,1.5,false,false,"",'AP_showCams && isNil "AP_trafficCam" && player distance2d [ 20714, 16625, 5 ] < 4500',6]);

                    AP_actions pushBack(_plb_obj addAction ["<t color='#FF69B4'>Jewelry Back Gate</t>", {[2]
                            call AP_fnc_trafficCams},nil,1.5,false,false,"",'AP_showCams && isNil "AP_trafficCam" && player distance2d [ 20714, 16625, 5 ] < 4500',6]);

                    AP_actions pushBack(_plb_obj addAction ["<t color='#FF69B4'>Fed Reserve Gate (W)</t>", {[3]
                            call AP_fnc_trafficCams},nil,1.5,false,false,"",'AP_showCams && isNil "AP_trafficCam" && player distance2d [ 16084, 17000, 5 ] < 3000',6]);

                    AP_actions pushBack(_plb_obj addAction ["<t color='#FF69B4'>Fed Reserve Gate (E)</t>", {[4]
                            call AP_fnc_trafficCams},nil,1.5,false,false,"",'AP_showCams && isNil "AP_trafficCam" && player distance2d [ 16084, 17000, 5 ] < 3000',6]);

                    AP_actions pushBack(_plb_obj addAction ["<t color='#FF69B4'>Fed Reserve Gate (SE)</t>", {[5]
                            call AP_fnc_trafficCams},nil,1.5,false,false,"",'AP_showCams && isNil "AP_trafficCam" && player distance2d [ 16084, 17000, 5 ] < 3000',6]);

                    AP_actions pushBack(_plb_obj addAction ["<t color='#FF69B4'>Prison Laptop</t>", {[6]
                            call AP_fnc_trafficCams},nil,1.5,false,false,"",'AP_showCams && isNil "AP_trafficCam" && player distance2d [ 16793, 13590, 5 ] < 2000',6]);

                    AP_actions pushBack(_plb_obj addAction ["<t color='#FF69B4'>Bank Vault</t>", {[7]
                            call AP_fnc_trafficCams},nil,1.5,false,false,"",'AP_showCams && isNil "AP_trafficCam" && player distance2d [ 14771, 10737, 5 ] < 4000',6]);

                    AP_actions pushBack(_plb_obj addAction ["<t color='#FF69B4'>Bank Back Door</t>", {[8]
                            call AP_fnc_trafficCams},nil,1.5,false,false,"",'AP_showCams && isNil "AP_trafficCam" && player distance2d [ 14771, 10737, 5 ] < 4000',6]);

                    AP_actions pushBack(_plb_obj addAction ["<t color='#FF69B4'>Bank Front Door</t>", {[9]
                            call AP_fnc_trafficCams},nil,1.5,false,false,"",'AP_showCams && isNil "AP_trafficCam" && player distance2d [ 14771, 10737, 5 ] < 4000',6]);

                    AP_actions pushBack(_plb_obj addAction ["<t color='#FF69B4'>Athira Square</t>", {[10]
                            call AP_fnc_trafficCams},nil,1.5,false,false,"",'AP_showCams && isNil "AP_trafficCam" && player distance2d [ 14038 , 18751, 5 ] < 1500',6]);

                    AP_actions pushBack(_plb_obj addAction ["<t color='#FF69B4'>Kavala Square</t>", {[11]
                            call AP_fnc_trafficCams},nil,1.5,false,false,"",'AP_showCams && isNil "AP_trafficCam" && player distance2d [ 3646, 13114, 5 ] < 2000',6]);

                    AP_actions pushBack(_plb_obj addAction ["<t color='#FF69B4'>Sofia Square</t>", {[12]
                            call AP_fnc_trafficCams},nil,1.5,false,false,"",'AP_showCams && isNil "AP_trafficCam" && player distance2d [ 25707, 21382, 5 ] < 3500',6]);

                    AP_actions pushBack(_plb_obj addAction ["<t color='#FF69B4'>Pyrgos Square</t>", {[13]
                            call AP_fnc_trafficCams},nil,1.5,false,false,"",'AP_showCams && isNil "AP_trafficCam" && player distance2d [ 16745, 12507, 5 ] < 1500',6]);};};

            AP_actions pushBack(_plb_obj addAction ["Send to Jail", {[cursorObject]
                    call AP_fnc_arrestAction},nil,0,false,false,"",'!isNull cursorObject && isPlayer cursorObject && !(side cursorObject isEqualTo west) && (cursorObject getVariable [ "AP_restrained",false ] ) && alive cursorObject && (player distance cursorObject < 3.5) && (( { (position player) inPolygon (AP_police_hq_polys select _x) } count [ 0,1,2,3,4,5,6 ] > 0) || ((player distance getMarkerPos "jail_release2") < 30) || (((SRV_mobileHQ param [ 1, objNull ] ) != objNull) && ((SRV_mobileHQ param [ 1, objNull ] ) getVariable [ "AP_mobileHeadQuartersTruckLocked", false ] ) && (((SRV_mobileHQ param [ 1, objNull ] ) distance2D player) < 20))) && !(cursorObject getVariable [ "AP_escorting",false ] ) && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["Send Combat Logger to Jail", {[cursorObject]
                    call AP_fnc_jailCL},"",0,false,false,"",'!isNull cursorObject && !(isPlayer cursorObject) && (player distance cursorObject < 3.5) && ((typeOf cursorObject) isEqualTo "Land_Bodybag_01_black_F") && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["Impound Vehicle", {[false,cursorObject]
                    call AP_fnc_impoundAction},nil,3,false,false,"",'!isNull cursorObject && alive cursorObject && (player distance cursorObject) < 6 && speed cursorObject < 2 && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship") && ((cursorObject getVariable [ "AP_side", "civ" ] in [ "cop", "med" ] ) || !(typeOf cursorObject in [ "O_MRAP_02_F","I_MRAP_03_F","B_G_Offroad_01_armed_F","O_LSV_02_armed_F","I_C_Offroad_02_LMG_F" ] ))',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Seize Vehicle</t>", {[true,cursorObject]
                    call AP_fnc_impoundAction},nil,0,false,false,"",'!isNull cursorObject && alive cursorObject && (player distance cursorObject) < 6 && speed cursorObject < 2 && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship") && (cursorObject getVariable [ "AP_side", "" ] isEqualTo "civ") && (typeOf cursorObject in [ "O_MRAP_02_F","I_MRAP_03_F","B_G_Offroad_01_armed_F","O_LSV_02_armed_F","I_C_Offroad_02_LMG_F", "B_MRAP_01_F" ] || (cursorObject getVariable [ "AP_canSeize",false ] ))',6]);

            AP_actions pushBack(_plb_obj addAction ["Search", {[cursorObject]
                    call AP_fnc_searchAction},nil,0,false,false,"",'!isNull cursorObject && cursorObject isKindOf "CAManBase" && (isPlayer cursorObject) && (cursorObject getVariable [ "AP_restrained",false ] || cursorObject getVariable [ "AP_civRestrained",false ] ) && (side cursorObject != west) && player distance cursorObject < 3.5 && !(cursorObject getVariable [ "AP_escorting",false ] ) && (isNull objectParent player)',6]);

            // owner 2026-09-05: the "Factory Reset Cyberdeck" scroll action is DELETED. It wiped id 0 (illegal
            // firmware) off a restrained suspect's phone; AP_fnc_hasDeck no longer reads id 0, so the wipe took
            // nothing away and the action was theatre. The server case behind it is gone too.

            AP_actions pushBack(_plb_obj addAction ["Search Trunk", {[cursorObject]
                    call AP_fnc_vehicleInvSearch},nil,0,false,false,"",'!isNull cursorObject && (player distance cursorObject) < 6 && speed cursorObject < 2 && alive cursorObject && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship" || typeOf cursorObject in [ "Land_TentA_F","Land_TentDome_F","B_CargoNet_01_ammo_F" ] ) && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["Check Registration", {[cursorObject]
                    call AP_fnc_searchVehAction},"",0,false,false,"",' ((call AP_adminLevel) <= 1) && !isNull cursorObject && (player distance cursorObject) < 5 && speed cursorObject < 2 && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship")',6]);

            AP_actions pushBack(_plb_obj addAction ["Search House Storage", {[cursorObject]
                    call AP_fnc_houseInvSearch},nil,0,false,false,"",'(cursorObject getVariable [ "AP_restricted_house", false ] != true) && !isNull cursorObject && (player distance cursorObject) < 8 && (typeOf cursorObject in AP_houseTypes) && (call AP_copLevel >= 5) && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["Seize House Storage", {[cursorObject]
                    call AP_fnc_houseInvSeize},nil,0,false,false,"",'(cursorObject getVariable [ "AP_restricted_house", false ] != true) && !isNull cursorObject && (player distance cursorObject) < 8 && (typeOf cursorObject in AP_houseTypes) && (call AP_copLevel >= 5) && (isNull objectParent player)',6]);

            if(player distance2D [9054.95,22465.4,0]
            <=60) then {AP_actions pushBack(_plb_obj addAction ["Seize Tent Trunk", {[cursorObject]
                        spawn AP_fnc_seizeIllegalTent},nil,0,false,false,"",'!isNull cursorObject && ((player distance cursorObject) < 6) && (typeOf cursorObject in [ "Land_TentA_F", "Land_TentDome_F" ] ) && (isNull objectParent player)',6]);}
            else {AP_actions pushBack(_plb_obj addAction ["Seize Trunk", {[cursorObject]
                        spawn AP_fnc_vehicleInvSeize},nil,0,false,false,"",'!isNull cursorObject && (player distance cursorObject) < 6 && speed cursorObject < 2 && alive cursorObject && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship" || typeOf cursorObject in [ "Land_TentA_F", "Land_TentDome_F", "B_CargoNet_01_ammo_F" ] ) && (isNull objectParent player)',6]);};

            AP_actions pushBack(_plb_obj addAction ["Seize virtual Items into Evidence", {[cursorObject,"HQ","ITEM"]
                    call AP_fnc_seizePlayerIllegal},"",0,false,false,"",'!isNull cursorObject && (player distance cursorObject) < 6 && speed cursorObject < 2 && ((cursorObject isKindOf "CAManBase" && (isPlayer cursorObject) && (side cursorObject != west) && (cursorObject getVariable [ "AP_restrained",false ] ))) && (call AP_copLevel) >= 1 && (( { (position player) inPolygon (AP_police_hq_polys select _x) } count [ 0,1,2,3,4,5,6 ] > 0) || (((SRV_mobileHQ param [ 1, objNull ] ) != objNull) && ((SRV_mobileHQ param [ 1, objNull ] ) getVariable [ "AP_mobileHeadQuartersTruckLocked", false ] ) && (((SRV_mobileHQ param [ 1, objNull ] ) distance2D player) < 20))) && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["Seize all Items into Evidence", {[cursorObject,"HQ","ALL"]
                    call AP_fnc_seizePlayerIllegal},"",0,false,false,"",'!isNull cursorObject && (player distance cursorObject) < 6 && speed cursorObject < 2 && ((cursorObject isKindOf "CAManBase" && (isPlayer cursorObject) && (side cursorObject != west) && (cursorObject getVariable [ "AP_restrained",false ] ) || ((cursorObject isKindOf "Car" || cursorObject isKindOf "Air") && alive cursorObject))) && (call AP_copLevel) >= 1 && (( { (position player) inPolygon (AP_police_hq_polys select _x) } count [ 0,1,2,3,4,5,6 ] > 0) || (((SRV_mobileHQ param [ 1, objNull ] ) != objNull) && ((SRV_mobileHQ param [ 1, objNull ] ) getVariable [ "AP_mobileHeadQuartersTruckLocked", false ] ) && (((SRV_mobileHQ param [ 1, objNull ] ) distance2D player) < 20))) && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["Seize virtual Items into Vehicle", {[cursorObject,"Field","ITEM"]
                    call AP_fnc_seizePlayerIllegal},"",0,false,false,"",'!isNull cursorObject && (player distance cursorObject) < 6 && speed cursorObject < 2 && cursorObject isKindOf "CAManBase" && (isPlayer cursorObject) && (side cursorObject != west) && (cursorObject getVariable [ "AP_restrained",false ] ) && (call AP_copLevel) >= 2 && (count(nearestObjects [ player, [ "Car","Air" ] , 20 ] ) > 0) && ( { player distance2D getMarkerPos format [ "police_hq_%1",_x ] < 50 } count [ 1,2,3,4,5,6 ] isEqualTo 0) &&!(((SRV_mobileHQ param [ 1, objNull ] ) != objNull) && ((SRV_mobileHQ param [ 1, objNull ] ) getVariable [ "AP_mobileHeadQuartersTruckLocked", false ] ) && (((SRV_mobileHQ param [ 1, objNull ] ) distance2D player) < 20)) && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["Seize all Items into Vehicle", {[cursorObject,"Field","ALL"]
                    call AP_fnc_seizePlayerIllegal},"",0,false,false,"",'!isNull cursorObject && (player distance cursorObject) < 6 && speed cursorObject < 2 && cursorObject isKindOf "CAManBase" && (isPlayer cursorObject) && (side cursorObject != west) && (cursorObject getVariable [ "AP_restrained",false ] ) && (call AP_copLevel) >= 2 && (count(nearestObjects [ player, [ "Car","Air" ] , 20 ] ) > 0) && ( { player distance2D getMarkerPos format [ "police_hq_%1",_x ] < 50 } count [ 1,2,3,4,5,6 ] isEqualTo 0) &&!(((SRV_mobileHQ param [ 1, objNull ] ) != objNull) && ((SRV_mobileHQ param [ 1, objNull ] ) getVariable [ "AP_mobileHeadQuartersTruckLocked", false ] ) && (((SRV_mobileHQ param [ 1, objNull ] ) distance2D player) < 20)) && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["Seize Objects", {[cursorObject]
                    call AP_fnc_seizeObjects},nil,0,false,false,"",'((cursorObject isKindOf "GroundWeaponHolder") || (cursorObject isKindOf "WeaponHolderSimulated") || (cursorObject isKindOf "WeaponHolder")) && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Track APB Target</t>", {[true]
                    call AP_fnc_trackAPB},nil,0,false,true,"",' player distance (getMarkerPos "bounty_apb") < AP_track_radius ',6]);

            AP_actions pushBack(_plb_obj addAction ["Pack up Spike Strip",AP_fnc_packupSpikes,"",0,false,false,"",'_spikes = nearestObjects [ player, [ "Land_Razorwire_F" ] ,8 ] select 0 ; !isNil "_spikes" && !isNil { (_spikes getVariable "AP_placed") }',6]);

            if((call AP_copLevel)>=5) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Toggle All House Locks</t>", {[cursorObject]
                        call AP_fnc_lockHouse},nil,-1,false,false,"",'!isNull cursorObject && (player distance cursorObject) < 20 && (typeOf cursorObject in AP_houseTypes) && ((call AP_copLevel) >= 5) && (cursorObject getVariable [ "AP_homeOwner","" ] != "") && (isNull objectParent player)',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Toggle Governor Building Locks</t>", {["toggleGovBuildingLocks",cursorObject]
                        spawn AP_fnc_govSystem},nil,0,false,false,"",'!(isNull cursorObject) && (typeOf cursorObject isEqualTo "Land_Hotel_02_F") && (player distance cursorObject < 15) && ((call AP_copLevel) >= 5) && (isNull objectParent player)',6]);};

            AP_actions pushBack(_plb_obj addAction ["<t color='#990000'>Charge with Crime</t>",AP_fnc_crimeCharge,cursorObject,-1,false,false,"",'!isNull cursorObject && (player distance cursorObject) < 5 && cursorObject isKindOf "CAManBase" && (isPlayer cursorObject) && (side cursorObject != west) && (cursorObject getVariable [ "AP_restrained",false ] ) && (call AP_copLevel) > 1 && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["Revoke Drivers License", {[cursorObject,"driver"]
                    call AP_fnc_revokeLicense},nil,0,false,false,"",'(isPlayer cursorObject) && (side cursorObject isEqualTo civilian) && alive cursorObject && cursorObject distance player < 5 && (cursorObject getVariable [ "AP_restrained",false ] ) && speed cursorObject < 1 && ((call AP_copLevel) >= 2) && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["Revoke Bounty Hunter License", {[cursorObject,"bounty"]
                    call AP_fnc_revokeLicense},nil,0,false,false,"",'(isPlayer cursorObject) && (side cursorObject isEqualTo civilian) && alive cursorObject && cursorObject distance player < 5 && (cursorObject getVariable [ "AP_restrained",false ] ) && (cursorObject getVariable [ "AP_isBountyHunter", false ] ) && speed cursorObject < 1 && (call AP_copLevel) >= 2 && (isNull objectParent player)',6]);

            if((call AP_copLevel)>=3) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Revoke BH License (Server Cycle)</t>", {[cursorObject,"bounty",true]
                        call AP_fnc_revokeLicense},nil,0,false,false,"",'(isPlayer cursorObject) && (side cursorObject isEqualTo civilian) && alive cursorObject && cursorObject distance player < 5 && (cursorObject getVariable [ "AP_restrained",false ] ) && (cursorObject getVariable [ "AP_isBountyHunter", false ] ) && speed cursorObject < 1 && (call AP_copLevel) >= 3 && (isNull objectParent player)',6]);};

            // owner 2026-07-28: the cop "Unlock Reserve Gate" action that stood here is removed. It was
            // doubly unreachable. Its condition required typeOf cursorObject to be "Land_BarGate_F" AND
            // cursorObject to be in AP_fed_gates -- but every object AP_fed_gates can hold is a
            // Reserve perimeter gate, class Land_ConcreteWall_01_l_gate_F, so no object can satisfy
            // both. And even if one could, it called AP_fnc_openGate, whose first line is
            // `if !(AP_effSide isEqualTo civilian) exitWith {}` -- it refuses police outright. MaxSec's
            // real tool at the Reserve is "Secure the Reserve" immediately below.
            // Corrected 2026-07-29: the line above used to say "initPlayerLocal builds AP_fed_gates
            // from AP_fedGate". Since e7e7c01 it builds from the LIST, AP_fedGates, and keeps the
            // scalar AP_fedGate only as a fallback for a client that lands between the two
            // publicVariables (initPlayerLocal.sqf:110-111). That is three gates now rather than one --
            // all of the same class, so the unreachability argument above is unaffected.
            AP_actions pushBack(_plb_obj addAction ["<t color='#3B7BFF'>Secure the Reserve</t>",{[["secure"], "APS_fnc_maldenFedSRV", 2] spawn AP_fnc_MP;},"",0,false,false,"",'(AP_effSide isEqualTo west) && ((player distance (missionNamespace getVariable [ "AP_FED_CENTRE", [ 0, 0, 0 ] ] )) <= 50) && (((missionNamespace getVariable [ "SRV_maldenFed", [ 0 ] ] ) param [ 0, 0 ] ) > 0) && (!AP_action_in_use) && (isNull objectParent player)',6]);

            AP_actions pushBack(_plb_obj addAction ["Open Police Gate", {private _gates=nearestObjects [player, ["Land_BarGate_F","Land_RoadBarrier_01_F"],15];

                    private _gate=_gates param [_gates findIf {!isNull _x},objNull];

                    if(!isNull _gate&& {!(_gate in AP_fed_gates)}) then {_gate animate ["Door_1_rot",1]};},"",3,false,false,"",'private _gates = nearestObjects [ player, [ "Land_BarGate_F", "Land_RoadBarrier_01_F" ] , 15 ] ; private _gate = _gates param [ _gates findIf { !isNull _x } , objNull ] ; !isNull _gate && { !(_gate in AP_fed_gates) && _gate animationPhase "Door_1_rot" isEqualTo 0 }',6]);

            AP_actions pushBack(_plb_obj addAction ["Close Police Gate", {private _gates=nearestObjects [player, ["Land_BarGate_F","Land_RoadBarrier_01_F"],15];

                    private _gate=_gates param [_gates findIf {!isNull _x},objNull];

                    if(!isNull _gate&& {!(_gate in AP_fed_gates)}) then {_gate animate ["Door_1_rot",0]};},"",3,false,false,"",'private _gates = nearestObjects [ player, [ "Land_BarGate_F", "Land_RoadBarrier_01_F" ] , 15 ] ; private _gate = _gates param [ _gates findIf { !isNull _x } , objNull ] ; !isNull _gate && { !(_gate in AP_fed_gates) && _gate animationPhase "Door_1_rot" isEqualTo 1 }',6]);

            AP_actions pushBack(_plb_obj addAction ["Remove Blindfold", {[2,cursorObject]
                    spawn AP_fnc_blindfoldAction},cursorObject,-1,false,true,"",'((cursorObject getVariable [ "AP_blinded",false ] ) && (cursorObject isKindOf "CAManBase") && (isPlayer cursorObject) && (alive cursorObject) && ((cursorObject distance player) < 5) && ((speed cursorObject) < 1)) && (isNull objectParent player)',6]);

            if(AP_copRole in ["scd","all"]) then {AP_actions pushBack(_plb_obj addAction ["Show Rank Identity", {player setVariable ["AP_showrank",true,true];},nil,-2,false,false,"",'!(player getVariable [ "AP_showrank",true ] )',6]);

                AP_actions pushBack(_plb_obj addAction ["Hide Rank Identity", {player setVariable ["AP_showrank",false,true];},nil,-2,false,false,"",'(player getVariable [ "AP_showrank",true ] )',6]);};

            if(AP_copRole in ["warrant","all"]) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Track Fugitive 1</t>", {[0]
                        call AP_fnc_trackBounty},nil,0,false,true,"",' player distance (getMarkerPos "bounty_0") < AP_track_radius ',6]);};

            if((call AP_copLevel)>=2) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Load Lethal Rounds</t>", {[]
                        call AP_fnc_nonLethal},nil,1.5,false,false,"",'player getVariable [ "AP_nonlethal",false ]',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#00FF00'>Load Non-Lethal Rounds</t>", {[]
                        call AP_fnc_nonLethal},nil,1.5,false,false,"",'!(player getVariable [ "AP_nonlethal",false ] )',6]);};

            AP_actions pushBack(_plb_obj addAction ["Deactivate MaxTac", {(_this select 1) setUnitLoadout AP_maxtacLoadout;

                    AP_maxtacLoadout=nil;

                    AP_activeMAXTAC=false;

                    AP_MAXTACActionAvail=false;},"",1.5,false,false,"","AP_activeMAXTAC && AP_MAXTACActionAvail"]);

            AP_actions pushBack(_plb_obj addAction ["Disable Drill",AP_fnc_stopBankRobbery,false,4,true,true,"",' (player distance (getMarkerPos "AP_bank_door") < 4 || player distance (getMarkerPos "AP_bank_door_2") < 4) && (AP_bank_robbed select 0) && isNull objectParent player',6]);

            if(!isNil"serverStartTime"&&!isNil"serverCycleLength"&& {(serverCycleLength-(serverTime-serverStartTime))<=240}) then {AP_actions pushBack(_plb_obj addAction ["Send to Jail (Anywhere)", {[cursorObject]
                        call AP_fnc_arrestAction},nil,0,false,false,"",'!isNull cursorObject && isPlayer cursorObject && !(side cursorObject isEqualTo west) && (cursorObject getVariable [ "AP_restrained",false ] ) && alive cursorObject && (player distance cursorObject < 3.5) && !(cursorObject getVariable [ "AP_escorting",false ] ) && (isNull objectParent player)',6]);};

            if(player distance [20898.6,19221.7,0.00143909]
            <=400) then {AP_actions pushBack(_plb_obj addAction ["Secure Dome",AP_fnc_evidenceSystems,3,5,false,false,"",'AP_evidence_dome isEqualTo cursorObject && (!(SRV_evidence_status select 1) && (SRV_evidence_status select 0)) && typeOf cursorObject isEqualTo "Land_Dome_Big_F" && !AP_action_in_use && isNull objectParent player',6]);

                AP_actions pushBack(_plb_obj addAction ["<t color='#00FF00'>Repair Defense Systems</t>",AP_fnc_evidenceSystems,1,5,false,false,"",'(AP_effSide isEqualTo west) && !isNull cursorObject && (cursorObject isEqualTo (missionNamespace getVariable [ "evidenceLaptop", objNull ] )) && !((cursorObject getVariable [ "AP_laptopstatus",1 ] ) isEqualTo 1) && ((player distance cursorObject) < 3) && !AP_action_in_use && (isNull objectParent player)',6]);};

            if(player distance2D (missionNamespace getVariable ["AP_lbPos_site", [4254.9, 3907.5, 0]]) <= 400) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Disable Mainframe Virus</t>", {["lbFirewall", []]
                        spawn AP_fnc_loonyBin},nil,0,false,false,"",'(AP_effSide isEqualTo west) && (["AP_lbPos_rugged", [4250.0, 3910.94, 31.57], 5] call AP_fnc_lbAt) && ((call AP_fnc_lbS) param [0, false]) && !((call AP_fnc_lbS) param [6, false])',6]);};

            if((call AP_copLevel)>=3||(call AP_adminLevel)>=2) then {AP_actions pushBack(_plb_obj addAction ["Force Open/Close Door", {[cursorObject,true]
                        spawn AP_fnc_doorAnimate},nil,1,false,false,"",'(typeOf cursorObject isEqualTo "Land_Dome_Big_F" || typeOf cursorObject isEqualTo "Land_Dome_Small_F" || (player distance (getMarkerPos "AP_bank_door") < 4 || player distance (getMarkerPos "AP_bank_door_2") < 4)) && !AP_action_in_use && isNull objectParent player',6]);};

            AP_actions pushBack(_plb_obj addAction ["Unrestrain", {[cursorObject,true]
                    spawn AP_fnc_unrestrain},nil,0,false,false,"",'if (!isNull cursorObject) then { if (isPlayer cursorObject) then { (cursorObject isKindOf "CAManBase" && player distance cursorObject < 3.5 && (cursorObject getVariable [ "AP_restrained",false ] ) && !(cursorObject getVariable [ "AP_escorting",false ] )) && (isNull objectParent player) && (isNull objectParent cursorObject) } ; } ;',6]);

            AP_actions pushBack(_plb_obj addAction ["Service Chopper ($1,000)", {[]
                    spawn AP_fnc_serviceChopper},nil,1.4,false,true,"",'(AP_effSide isEqualTo west) && (player distance [ 15186,17331,0 ] < 60) && !AP_action_in_use && (isNull objectParent player)',6]);

            if((call AP_copLevel)>=4) then {AP_actions pushBack(_plb_obj addAction ["Setup Mobile HQ", {["setupMobileHQ", [],player,vehicle player]
                        spawn AP_fnc_clientMobileHQ;},nil,0,false,false,"",'!(SRV_mobileHQ select 2) && (vehicle player) isKindOf "B_Truck_01_covered_F" && (driver (vehicle player)) isEqualTo player',6]);};};

        case independent: {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Use Defibrillator</t>",AP_fnc_revivePlayer,cursorObject,-1,false,true,"",'!isNull cursorObject && cursorObject isKindOf "CAManBase" && !(alive cursorObject) && cursorObject getVariable [ "AP_revivable",false ] && AP_inv_defib > 0 && (player distance cursorObject) < 3.5 && (isNull objectParent player) && (isNull objectParent cursorObject)',6]);

            if((call AP_medicLevel)>=4) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Toggle All House Locks</t>", {[cursorObject]
                        call AP_fnc_lockHouse},nil,-1,false,false,"",'!isNull cursorObject && (player distance cursorObject) < 20 && (typeOf cursorObject in AP_houseTypes) && ((call AP_medicLevel) >= 4) && (cursorObject getVariable [ "AP_homeOwner","" ] != "") && (isNull objectParent player)',6]);};

            AP_actions pushBack(_plb_obj addAction ["Medic Enter as Driver", {["driver"]
                    call AP_fnc_forceVehicleEnter},nil,200,false,false,"",'(cursorObject getVariable [ "AP_side", "" ] isEqualTo "med") && { !isNull cursorObject && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship") && (locked cursorObject) != 0 && cursorObject distance player < 5 }',7]);

            AP_actions pushBack(_plb_obj addAction ["Medic Enter as Passenger", {["passenger"]
                    call AP_fnc_forceVehicleEnter},nil,100,false,false,"",'(cursorObject getVariable [ "AP_side", "" ] isEqualTo "med") && { !isNull cursorObject && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship") && (locked cursorObject) != 0 && cursorObject distance player < 5 }',7]);

            AP_actions pushBack(_plb_obj addAction ["Exit", {["exit"]
                    call AP_fnc_forceVehicleEnter},nil,100,false,false,"",'!(isNull objectParent player) && (locked (vehicle player) isEqualTo 2) && (vehicle player getVariable [ "AP_side", "" ] isEqualTo "med")',8]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#FFFF00'>Emergency Lights (OFF)</t>", {if ((vehicle player) getVariable ["AP_lights", false]) then { [vehicle player] call AP_fnc_sirenLights; };},nil,-1,false,false,"",'!(isNull objectParent player) && (objectParent player getVariable [ "AP_side","civ" ] == "med") && objectParent player getVariable [ "AP_lights", false ] && (player isEqualTo (driver vehicle player)) && (!isNil { vehicle player getVariable "AP_lights" } )',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#FFFF00'>Emergency Lights (ON)</t>", {[vehicle player]
                    call AP_fnc_medicSirenLights;},nil,-1,false,false,"",'!(isNull objectParent player) && (objectParent player getVariable [ "AP_side","civ" ] == "med") && !(objectParent player getVariable [ "AP_lights", false ] ) && (player isEqualTo (driver vehicle player)) && (!isNil { vehicle player getVariable "AP_lights" } )',6]);

            AP_actions pushBack(_plb_obj addAction ["Impound Vehicle", {[false,cursorObject]
                    call AP_fnc_impoundAction},nil,3,false,false,"",'!isNull cursorObject && alive cursorObject && (player distance cursorObject) < 6 && speed cursorObject < 2 && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship" ) && !(typeOf cursorObject in [ "O_MRAP_02_F","B_G_Offroad_01_armed_F","O_LSV_02_armed_F","I_C_Offroad_02_LMG_F" ] ) && ((call AP_medicLevel) >= 3)',6]);

            if(AP_isActiveFirefighter&&(count SRV_houseOnFire!=0)) then {if!(isNull AP_hoseObject) then {if((typeOf cursorObject isEqualTo"O_Truck_03_fuel_F")&&!isNull cursorObject&&(player distance cursorObject)<5) then {AP_actions pushBack(_plb_obj addAction ["<t color='#2afffa'>Refill Hose</t>", {["fillHose"]
                                spawn AP_fnc_medicFireClient},nil,0,false,false,"",'(isNull objectParent player) && (count SRV_houseOnFire != 0) && (typeOf cursorObject isEqualTo "O_Truck_03_fuel_F") && (player distance cursorObject) < 5',6]);};

                    AP_actions pushBack(_plb_obj addAction ["<t color='#2afffa'>Toggle Fire Hose</t>", {["toggleFirehose", [(player getVariable ["AP_hoseOn",false]),cursorObject]]
                            spawn AP_fnc_medicFireClient},nil,0,false,false,"",'private _nearHouseFire = false ; { if (player distance2D _x <= 25) exitWith { _nearHouseFire = true ; } ; } foreach SRV_houseOnFire ; (isNull objectParent player) && (count SRV_houseOnFire != 0) && _nearHouseFire',6]);};};

            AP_actions pushBack(_plb_obj addAction ["TT Item Shop", {[cursorObject,"","","meditemshop"]
                    call AP_fnc_virtualShopMenu},nil,1.5,false,false,"",'AP_effSide isEqualTo independent && (typeOf cursorObject) isEqualTo "C_IDAP_supplyCrate_F" && cursorObject getVariable [ "AP_medSupply", false ]',5]);

            AP_actions pushBack(_plb_obj addAction ["Partner Up", {[1,cursorObject]
                    call AP_fnc_medicPartners},nil,-1,false,true,"",'!isNull cursorObject && cursorObject isKindOf "CAManBase" && isPlayer cursorObject && alive cursorObject && isNull objectParent player && side cursorObject isEqualTo independent',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#FFFF00'>Check Partners</t>", {[4,objNull]
                    call AP_fnc_medicPartners},nil,-1,false,true,"",'!(AP_medPartners isEqualTo [ ] )',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Wipe Partners</t>", {[5,objNull]
                    call AP_fnc_medicPartners},nil,-1,false,true,"",'!(AP_medPartners isEqualTo [ ] ) && isNull objectParent player',6]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#90EE90'>Clear Wreckage</t>", {[cursorObject]
                    spawn AP_fnc_medicDeleteVeh},nil,200,false,false,"",'!(alive cursorObject) && (cursorObject isKindOf "Car" || cursorObject isKindOf "Air" || cursorObject isKindOf "Ship") && (cursorObject distance player < 12)',12]);

            AP_actions pushBack(_plb_obj addAction ["<t color='#FF7400'>Repair Destroyed House</t>", {["actionRepair"]
                    spawn AP_fnc_medicRepairBuilding},nil,1.5,true,true,"""",'private _building = (nearestTerrainObjects [ player, [ "House" ] , 7, true, true ] ) param [ 0, objNull ] ; private _building = if (_building getVariable [ "AP_terrainObject_repaired", false ] ) then { (nearestObjects [ player, [ "House" ] , 7, true ] ) param [ 0, objNull ] } else { _building } ; ((_building isKindOf "House_F") && (_building getVariable [ "AP_repairRequested", false ] ) && (damage _building >= 1))',6]);

            AP_actions pushBack(_plb_obj addAction ["Open Gate", {private _gates=nearestObjects [player, ["Land_BarGate_F","Land_RoadBarrier_01_F"],15];

                    private _gate=_gates param [_gates findIf {!isNull _x},objNull];

                    private _copGate=false;

                    if(_gate in AP_cop_gates) then {_copGate=true};

                    if(!isNull _gate&& {!(_gate in AP_fed_gates)}
                    &&!_copGate) then {_gate animate ["Door_1_rot",1]};

                    if(_copGate) then {["Medics are unable to tamper with police gates.","basic"]
                        spawn AP_fnc_handleMessage;};},"",3,false,false,"",'private _gates = nearestObjects [ player, [ "Land_BarGate_F", "Land_RoadBarrier_01_F" ] , 15 ] ; private _gate = _gates param [ _gates findIf { !isNull _x } , objNull ] ; !isNull _gate && { !(_gate in AP_fed_gates) && _gate animationPhase "Door_1_rot" isEqualTo 0 }',6]);

            AP_actions pushBack(_plb_obj addAction ["Close Gate", {private _gates=nearestObjects [player, ["Land_BarGate_F","Land_RoadBarrier_01_F"],15];

                    private _gate=_gates param [_gates findIf {!isNull _x},objNull];

                    private _copGate=false;

                    if(_gate in AP_cop_gates) then {_copGate=true};

                    if(!isNull _gate&& {!(_gate in AP_fed_gates)}
                    && {!_copGate}) then {_gate animate ["Door_1_rot",0]};

                    if(_copGate) then {["Medics are unable to tamper with police gates.","basic"]
                        spawn AP_fnc_handleMessage;};},"",3,false,false,"",'private _gates = nearestObjects [ player, [ "Land_BarGate_F", "Land_RoadBarrier_01_F" ] , 15 ] ; private _gate = _gates param [ _gates findIf { !isNull _x } , objNull ] ; !isNull _gate && { !(_gate in AP_fed_gates) && _gate animationPhase "Door_1_rot" isEqualTo 1 }',6]);};};};
