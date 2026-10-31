#include "..\macro.h"
#include "\a3\editor_f\Data\Scripts\dikCodes.h"
params["_ctrl", "_code", "_shift", "_ctrlKey", "_alt"];
// owner 2026-07-20: SHIFT+Y (DIK 21) -- ICEBREAKER VISOR quick-hack ring.
// owner 2026-09-05: the fn used to enforce "VR goggles worn" + "illegal firmware flashed". BOTH GATES ARE
// GONE. All that is left in fn_visorOpen is the side check, so this bind is live for every civilian and
// every officer from the moment they spawn, and inert only for independent.
// owner 2026-07-22: while restrained, the phone (and thus the console) is locked, so SHIFT+Y instead fires the
// CUFF CRACKER -- breach your own restraints, no goggles. Every civilian has it now, not just the flashed ones.
if (_shift && {_code isEqualTo 21} && {!_alt} && {!_ctrlKey} && {!dialog} && {alive player}) exitWith {
// owner 2026-08-18: SHIFT+Y now opens the HTML VISOR (dialog 941700) instead of the dock. The
// restrained branch is unchanged and still wins -- the cuff cracker is the whole point of the key
// while cuffed, and the visor would be as useless there as the dock was.
    if (((player getVariable ["AP_restrained", false]) || {player getVariable ["AP_civRestrained", false]}) && {call AP_fnc_hasDeck}) then {
        [] spawn AP_fnc_qhCuffHack;} else {[] spawn AP_fnc_visorOpen;
    };
    true};
// FALLBACKS, kept on purpose (owner 2026-08-18). The three HTML screens are the primary UI now, but
// none of them had been loaded in a running game when they were promoted, so the proven native
// dialogs stay reachable one modifier away rather than being deleted:
//
//     CTRL+SHIFT+Y -> the deck's QH app     (the native dock 941300 was DELETED 2026-09-04
//                                            with the rest of the retired cyberdeck cluster,
//                                            so this modifier is now a fast path, not a fallback)
//     CTRL+SHIFT+T -> AP_fnc_openInventory   the old TrunkMenu (4500)
//     CTRL+SHIFT+I -> display 602            the old engine inventory (the web I-screen is dialog 938500)
//     SHIFT+TAB    -> AP_fnc_radioRadial     the old radial (515500, in fn_radioKeys.sqf)
//
// This costs nothing and means a page that turns out to be broken in front of players is a keypress
// away from working, not a redeploy. Delete them once the new screens have been played properly.
// The visor's fallback is already gone -- see above; the other three still stand.
// The SHIFT+Y block above requires !_ctrlKey, so CTRL+SHIFT+Y cannot collide with it.
//
// THE STORAGE FALLBACK MUST CARRY THE VEHICLE GATE ITSELF. fn_openInventory gates HOUSES (owner /
// keyholder / gangmate, and the distance check) but it does NOT check `in AP_vehicles` -- the only
// thing standing between a player and someone else's trunk is the gate in the native T tree below.
// A fallback bind that skips it is a theft-and-dupe vector, not a convenience. The first cut of
// this bind did exactly that and shipped in b0635; this is the fix.
//
// Houses and tents pass straight through, because fn_openInventory does gate those itself.
if (_ctrlKey && _shift && {!_alt} && {!dialog} && {alive player} && {_code in [21, 20, 23]}) exitWith {
    if (_code isEqualTo 23) exitWith {
        // I -> the native inventory once. fn_inventoryOpened consumes the flag and returns false, so the
        // engine opens 602 for this one press; every later I is the web screen again.
        AP_invForceNative = true;
        player action ["Gear", objNull];
        true
    };
    if (_code isEqualTo 21) then {
        // MEMO (cyberdeck consolidation, owner-approved 2026-08-26): the dock is
        // retired. CTRL+SHIFT+Y is now the FAST PATH the memo prescribed -- straight
        // into the deck's QH app, one keypress, no launcher stop.
        [["TAL OS", "ICEBREAKER OS"] select (AP_effSide isEqualTo civilian)] call AP_fnc_deckOpenApp;
    } else {
        private _t = if (vehicle player != player) then { vehicle player } else { cursorTarget };
        private _isVehTgt = (_t isKindOf "Car") || (_t isKindOf "Air") || (_t isKindOf "Ship") || (_t isKindOf "Tank");
        if (!isNull _t && {!_isVehTgt || {_t in AP_vehicles} || {(call AP_adminLevel) >= 3}}) then {
            [_t, _isVehTgt && {!(_t in AP_vehicles)}] spawn AP_fnc_openInventory;
        };
    };
    true};
if (_shift && (_code isEqualTo 74 || _code isEqualTo 25)) exitWith {
    ["This feature is disabled on LoonyBin Servers.", "basic"] spawn AP_fnc_handleMessage;
    disableUserInput true;
    disableUserInput false;
    true};
if (_code in (actionKeys "Diary") || inputAction "diary" > 0) exitWith {true};
if (visibleMap && {(_ctrlKey || _code isEqualTo 29) && !(currentChannel in [3, 4])}) exitWith {true};
private["_veh", "_locked"];
private _handled = false;
// owner 2026-06-15: CONSUME Shift+T on keydown so Arma's ENGINE tactical ping never fires. The engine ping is
// GROUP-scoped and leaked to the shared civilian slot-group ("tac pings seen by anyone"). The mission's OWN
// pseudo-ping is on KeyUP (fn_keyUpHandler) and is gated to your gang/squad -> it still works; this only kills
// the leaky engine duplicate. (This display's KeyDown EH doesn't fire while a chat/edit box has focus, so it
// never blocks typing a capital T.)
if (_shift && {_code isEqualTo 20} && {!visibleMap}) exitWith { true };
private _interactionKey =
if (((count actionKeys "User10") isEqualTo 0) && AP_scrollDisabled) then {219} else {((actionKeys "User10") select 0)};
private _mapKey = ((actionKeys "ShowMap") select 0);
private _interruptionKeys = [17, 30, 31, 32];
private _functionKeys = [4, 5, 6, 24, 15, 20, 38, 33, 34, 22];
private _allowedKeys = [1]; {_allowedKeys append _x}
forEach[actionKeys "User12"];
// owner 2026-09-16 (review round 1): V DURING A PARKOUR MOVE IS SWALLOWED HERE. The AP_action_in_use gate below
// returns nil, and only a true return stops the engine's own GetOver, so a second V (double tap, or OS key repeat
// while V is held) used to play the engine step-over on the attached player mid-move. Keyed on AP_parkourState, not
// AP_action_in_use, so it holds through pushoff/recover and after an Esc cleared the flag, and it changes nothing for
// any other flow that holds AP_action_in_use. AP_parkourLastV keeps a held V's repeats counted as the same press
// (fn_parkour.sqf, "ONE MOVE PER PHYSICAL PRESS"; review round 2: only a V KeyUp, or no V at all for
// latchStaleTime, starts a new press), so holding V through a move never starts the next one.
if ((_code in (actionKeys "GetOver")) && {!((missionNamespace getVariable ["AP_parkourState", "idle"]) isEqualTo "idle")}) exitWith {AP_parkourLastV = diag_tickTime; true};
if ((AP_action_in_use) && !(_code in _allowedKeys)) exitWith {};
private _restrained = player getVariable["AP_restrained", false];
if (AP_isDowned && {!_restrained}) exitWith {true};
if (_restrained && {((_code in (actionKeys "ShowMap")) && (call AP_adminLevel) <= 1)}) exitWith {true};
// owner 2026-08-13: M opens MALDEN GRID, the HTML map, instead of the paper
// one -- everywhere, always. Returning true is what stops the engine's own
// ShowMap action from opening the vanilla map. Sits AFTER the restraint guard
// above so cuffed players keep being denied a map at all, exactly as before.
// Plain M only: modified M chords stay whatever the engine thinks they are.
if (_code in (actionKeys "ShowMap") && {!_shift} && {!_ctrlKey} && {!_alt} && {!dialog} && {!visibleMap}) exitWith {
    [] spawn AP_fnc_webMap;
    true
};

if (_restrained && {
    _code in (actionKeys "MiniMap") || _code in (actionKeys "MiniMapToggle") || _code in (actionKeys "GetOver") || _code in (actionKeys "ReloadMagazine") || _code in (actionKeys "salute") || _code in (actionKeys "Throw") || _code in (actionKeys "GetOut") || _code in (actionKeys "Eject") || _code in (actionKeys "DefaultAction") || _code in (actionKeys "SitDown") || _code in (actionKeys "MenuSelect") || _code in (actionKeys "ForceCommandingMode") || _code in (actionKeys "PrevAction") || _code in (actionKeys "NextAction") || _code in (actionKeys "Action") || _code in (actionKeys "ActionContext") || _code in (actionKeys "OpenDLCmenu")
}) exitWith {true};
if ((outlw_MR_keybindingMenuActive || outlw_MR_isRepacking) && {_code in (actionKeys "ReloadMagazine")}) exitWith {
    ["You cannot reload while repacking your magazines.", "basic"] spawn AP_fnc_handleMessage;
    true};
// LooneyBin: Outlawed mag-repack trigger. The deobf kept the addon but dropped the keybind CHECK that
// opens it (default CTRL+R = [shift F, ctrl T, alt F, key 19=R]). Open the repack dialog on the combo.
if (!isNil "outlw_MR_keybinding" && {!dialog} && {alive player} && {!(outlw_MR_isRepacking)} && {!(outlw_MR_keybindingMenuActive)} && {_shift isEqualTo outlw_MR_shift} && {_ctrlKey isEqualTo outlw_MR_ctrl} && {_alt isEqualTo outlw_MR_alt} && {_code isEqualTo outlw_MR_keybinding}) exitWith {
    call outlw_MR_createDialog;
    true};
if ((call AP_adminLevel) >= 2) then {if (_code in (actionKeys("User14"))) then {if (!(isNull(findDisplay 12900)) || {!(isNull(findDisplay 937600))}) then {closeDialog 0;
        } else {[] call AP_fnc_staffMenu;};};};
// LooneyBin (#23): Custom 4 (User4) = restrain hotkey. fn_restrain self-validates the rest
// (distance, ziptie, passive, west-vs-west). Mirror the scroll-action gating here.
if (_code in (actionKeys "User4")) exitWith {private _t = cursorObject;
    if (alive player && {!isNull _t} && {isPlayer _t} && {alive _t} && {_t isKindOf "CAManBase"} && {(speed _t) < 1} && {isNull objectParent player} && {isNull objectParent _t} && {!(_t getVariable ["AP_restrained", false])}) then {
        private _allowed = if (AP_effSide isEqualTo west) then { (side _t) != west } else { (_t getVariable ["AP_surrendered", false]) || (_t getVariable ["AP_downed", false]) };
        if (_allowed) then { [_t] call AP_fnc_restrain; };};
    true};
// owner 2026-09-11: EITHER death screen (native 7300 or web 938800). Same gate, same
// User12 exemption; only the question of "is a death screen up" moved into one place.
if (([] call AP_fnc_deathUiOpen) && {!(_code in (actionKeys "User12"))}) exitWith {false};
if ((_code in _interruptionKeys) && !(isNull AP_sittingChair)) then {[AP_sittingChair] spawn AP_fnc_handleChair;};
if (_code in (actionKeys "TacticalView")) exitWith {true;};
if (_code in actionKeys "NavigateMenu") then {true};
if (_code in (actionKeys "Gear")) exitWith {if (_restrained) then {
        ["You cannot access your inventory while you're restrained!", "basic"] spawn AP_fnc_handleMessage;
        true;};};
// owner 2026-09-16: GetOver (V) is the PARKOUR key now -- vault / mantle / drop, and a wall run with the
// Reflex Tuning implant. AP_fnc_parkour decides from the geometry in front of the player and returns the
// bool this handler hands the engine: true = consumed (a move started, or the old running hop fired), false
// = let the engine's own step-over run. The old line here was `speed > 10 -> AP_fnc_jump; true`; that hop
// survives inside AP_fnc_parkour as the open-ground fallback and as the whole behaviour when the server's
// SRV_parkourEnabled kill switch is false. On false this does NOT exit, exactly like the old line at
// speed <= 10, so anything else bound to the same key further down still runs. It stays BELOW the
// AP_action_in_use gate, the downed gate and the restrained key block -- a cuffed player never reaches it.
// A V pressed mid-move never gets here either: the GetOver swallow line just above the AP_action_in_use gate
// returns true for it while AP_parkourState is not idle (AP_fnc_parkour's own busy check is the second line).
if (_code in (actionKeys "GetOver") && {[] call AP_fnc_parkour}) exitWith {true};
if (_code in (actionKeys "PushToTalk") || _code in (actionKeys "PushToTalkSide")) exitWith {if (currentChannel in [0, 1, 6]) then {
        systemChat format["The LoonyBin does not allow voice in this channel."];
        true;};};
if (_code in ((actionKeys "Diary") + (actionKeys "NetworkPlayers") + (actionKeys "forceCommandingMode") + (actionKeys "menuBack"))) exitWith {
    true;};
// owner 2026-06-28 (exact reference parity -- the player-preferred behavior): the 5s name/distance REVEAL pulse fires
// on ~ (DIK 41) + SelectAll + SwitchCommand. The 2026-06-25 User14 workaround (added when ~ was flagged "unusable" by
// Northhhhh, then superseded by a b0100 rollback that restored ~) is REMOVED so the keyset matches the reference 1:1.
// The command-mode keys are STILL consumed here so Arma's squad command menu never pops (players are in real groups).

// prevent command mode 
{if (_code in actionKeys format ["CommandingMenu%1", _x]) exitWith {true};} forEach [0,1,2,3,4,5,6,7,8,9];

if (_code isEqualTo 41 || _code in (actionKeys "SelectAll") || _code in (actionKeys "SwitchCommand")) exitWith {if !(AP_targetTag) then {
		[] spawn{AP_targetTag = true;
			uiSleep 5;
			AP_targetTag = false;};};
	true;};

if (count(actionKeys "User10") != 0 && {(_code in (actionKeys "User10"))}) exitWith {if !(AP_action_in_use) then {[] spawn {
            private _handle = [] spawn AP_fnc_actionKeyHandler;
            waitUntil {scriptDone _handle};
            if (AP_action_in_use) then {AP_action_in_use = false;};};};
    true;};
if ((_code in _functionKeys) && {scriptAvailable(0.4)}) exitWith {false;};
if (_alt && _code isEqualTo 62) exitWith {if ((call AP_adminLevel) isEqualTo 0) then {[] spawn {disableUserInput true;
            uiSleep 2;
            disableUserInput false;
            disableUserInput true;
            disableUserInput false;};
        _handled = true;};};
switch (_code) do {case 1: {if (AP_action_in_use) then {AP_action_in_use = false;
                _handled = true;};
            if (AP_effSide isEqualTo west && !isNil "AP_trafficCam") then {[-1] call AP_fnc_trafficCams;};};
    case 5: {if (AP_effSide isEqualTo west && !isNil "AP_trafficCam") then {[-1] call AP_fnc_trafficCams;};};
    case 6: {if (alive player) then {if (_restrained && (call AP_adminLevel) <= 1) then {
                    ["You cannot open your cell phone when you're restrained!", "basic"] spawn AP_fnc_handleMessage;} else {
                    if !(dialog) then {["Message"] call AP_fnc_deckOpenApp;};};};};
    case 7: {
            if (((call AP_adminLevel) >= 2) && ((AP_adminMode) || (player getVariable["AP_invisOn", false])) && (isNull objectParent player)) then {
                [] call AP_fnc_adminTeleportFacing;};};
    case 9: {if (AP_phoneCallStatus isEqualTo 1) then {["answerPhoneCall"] spawn AP_fnc_phoneCallClient;};};
    case 10: {if (AP_phoneCallStatus isEqualTo 1) then {["declinePhoneCallReciever"] spawn AP_fnc_phoneCallClient;};};
    case 11: {
            // owner 2026-06-24: the 0 key opens the online ROSTER -- every GANG with online members AND every active
            // GROUP/squad, each with member names, for civs AND cops. fn_gangListMenu self-toggles (re-press to close);
            // built client-side from broadcast gang_data + allPlayers groups.
            ["Gangs Online"] call AP_fnc_deckOpenApp;};
    case 35: {if (!_alt && !_ctrlKey && !dialog && (isNull objectParent player)) then {if !((currentWeapon player) isEqualTo "") then {
                    [true] spawn AP_fnc_holsterWeapon;} else {[false] spawn AP_fnc_holsterWeapon;};};};
    // F12: toggle the in-game map editor. Level 5 only, and the check here is UI
    // courtesy -- AP_fnc_mapEditor re-checks, and APS_fnc_mapEditSRV re-reads
    // adminlevel from the database on every single edit regardless.
    // Once the session is open its own display-46 handler consumes keys, so nothing
    // below competes with the editor's own bindings.
    case 88: {if ((call AP_adminLevel) >= 5) then { [] spawn AP_fnc_mapEditor; _handled = true; };};
    case 38: {if (AP_effSide in [west, independent] && _shift && (player isEqualTo(driver vehicle player))) then {
                if (!(isNull objectParent player) && (objectParent player != player)) then {if (!isNil {
                        vehicle player getVariable "AP_lights"}) then {if (AP_effSide isEqualTo west) then {
                            [vehicle player] call AP_fnc_sirenLights;} else {[vehicle player] call AP_fnc_medicSirenLights;};
                        _handled = true;};};};};
    case _interactionKey: {if (!(AP_action_in_use) && AP_scrollDisabled) then {[] spawn {
                    private _handle = [] spawn AP_fnc_actionKeyHandler;
                    waitUntil {scriptDone _handle};
                    AP_action_in_use = false;};};};
    case 20: {if !(isNull(findDisplay 2400)) exitWith {};
            // owner 2026-06-18 (#367): a vehicle you OWN but relogged/world-restored with isn't in AP_vehicles
            // (AP_vehicles = your KEYCHAIN). Login rebuilds the keychain from a server list (`_this select 18`)
            // that misses out-in-world vehicles (stream-in timing) -> the trunk keybind (gated on `in
            // AP_vehicles`) failed = "can lock/unlock but can't open the trunk until you store+pull". AP_vehOwners
            // (the PERSISTED owner/keyholder list lock/unlock use) IS restored, so if you're in it, restore the key
            // to your keychain here -> the `in AP_vehicles` checks below pass. (keyDrop also clears AP_vehOwners,
            // so a key you intentionally dropped won't match -> no unwanted re-grant.)
            private _trunkTgt = if (vehicle player != player) then { vehicle player } else { cursorTarget };
            if (!isNull _trunkTgt && {(_trunkTgt isKindOf "Car") || (_trunkTgt isKindOf "Air") || (_trunkTgt isKindOf "Ship") || (_trunkTgt isKindOf "Tank")} && {!(_trunkTgt in AP_vehicles)}) then {   // owner 2026-07-23: + Tank (Nyx)
                if (((_trunkTgt getVariable ["AP_vehOwners", [[]]]) findIf { (_x param [0, ""]) isEqualTo (getPlayerUID player) }) != -1) then {
                    AP_vehicles pushBackUnique _trunkTgt;};};
            if (!_alt && !_ctrlKey) then {if (vehicle player != player && alive vehicle player && !_shift) then {
                    if ((vehicle player) in AP_vehicles) then {[vehicle player, false] spawn AP_fnc_storageOpen;} else {
                        if ((call AP_adminLevel) >= 3) then {[vehicle player, true] spawn AP_fnc_storageOpen;};};} else {
                    if ((cursorTarget isKindOf "Car" || cursorTarget isKindOf "Air" || cursorTarget isKindOf "Ship" || cursorTarget isKindOf "Tank" || cursorTarget isKindOf "House_F" || typeOf cursorTarget in ["Land_TentA_F", "Land_TentDome_F"]) && player distance cursorTarget < (7 + 0.5 * (sizeOf typeOf cursorTarget)) && vehicle player == player && alive cursorTarget) then {   // owner 2026-07-23: + Tank (Nyx)
                        if (AP_effSide isEqualTo civilian) then {if (!(AP_gang_data isEqualTo[]) && {
                                (cursorTarget getVariable["AP_house_gang", -1] isEqualTo(AP_gang_data select 0))}) then {
                                if ((AP_gang_data select 2) <= 4) then {[cursorTarget, false] spawn AP_fnc_storageOpen;};} else {
                                if (cursorTarget in AP_vehicles || ([cursorObject, getPlayerUID player, "accessInv"] call AP_fnc_keyHolderStatus)) then {
                                    if ((cursorTarget getVariable["AP_house_tax", [false]]) select 0) exitWith {
                                        ["Housing"] call AP_fnc_deckOpenApp;};
                                    [cursorTarget, false] spawn AP_fnc_storageOpen;} else {if ((call AP_adminLevel) >= 3) then {
                                        [cursorTarget, true] spawn AP_fnc_storageOpen;};};};} else {
                            if (cursorTarget in AP_vehicles || {!(cursorTarget getVariable["AP_buildingLocked", true])}) then {
                                [cursorTarget, false] spawn AP_fnc_storageOpen;} else {if ((call AP_adminLevel) >= 3) then {
                                    [cursorTarget, true] spawn AP_fnc_storageOpen;};};};} else {private _object = cursorObject;
                        private _plb_display = findDisplay 39500;
                        if ((isNull _plb_display) && (_object isKindOf "CAManBase")) then {private _objectActionIDs = actionIDs _object;
                            private _shopActionIndex = _objectActionIDs findIf {
                                "AP_fnc_virtualShopMenu" in ((_object actionParams _x) select 1)};
                            private _hasShopAction = _shopActionIndex isNotEqualTo - 1;
                            if (_hasShopAction) then {
                                (_object actionParams _shopActionIndex) params["_title", "_script", "_args", "", "", "", "", "_condition", "_radius"];
                                _condition =
                                if (_condition isEqualTo "") then {"true"} else {_condition};
                                if (((player distance _object) <= _radius) && {call compile _condition}) then {
                                    [_object, player, _shopActionIndex, _args] spawn(compile _script);};};};};};};};
    case 33: {if !(AP_effSide isEqualTo west) exitWith {};
            private _veh = vehicle player;
            if (!(isNull objectParent player) && !(isNull _veh) && (player isEqualTo(driver vehicle player)) && _shift) then {
                _handled = true;};};
    // Y IS THE PHONE. It opened the native dialog until 2026-08-14 and the deck sat
    // behind CTRL+Y while the apps were ported one at a time; every app arrived, so
    // the handset is the phone now and the modifier split is gone with the dialog.
    case 21: {if (!_alt && !_shift && !_ctrlKey && !dialog) then {[] call AP_fnc_deckPhone; _handled = true;};};}; if (_code in (actionKeys "User2")) then {
    if (!_alt && !_ctrlKey) then {if (isNull objectParent player) then {if !(_restrained) then {if (alive player) then {closeDialog 0;
                    private _idx = (nearestObjects[player, [], 5]) findIf {!((_x getVariable["AP_droppedItems", []]) isEqualTo[])};
                    if !(_idx isEqualTo - 1) then {[nearestObjects[player, [], 3] select _idx] spawn AP_fnc_menuPickupItems;};
                    _handled = true;};};};};};
if (_code in (actionKeys "User11")) then {if (AP_inv_smash > 0) then {[] spawn AP_fnc_smash;} else {[] spawn AP_fnc_redgull;};
    _handled = true;};
if (_code in (actionKeys "User6")) then {if (isNull objectParent player) then {if (AP_inv_firstAidKit > 0) then {private _unit =
            switch (true) do {
                case (isPlayer cursorObject && isNull objectParent player && (player distance cursorObject <= 2) && ((damage cursorObject > 0.25) || (cursorObject getHit "legs" >= 0.5))):
                    {cursorObject};
                case (isNull objectParent player && ((damage player > 0.25) || (player getHit "legs" >= 0.5))): {player};
                default {objNull};}; if !(isNull _unit) then {["", "", "", _unit] spawn AP_fnc_medKit;
                _handled = true;};} else {["You don't have a Virtual First Aid Kit to use!", "basic"] spawn AP_fnc_handleMessage;};
    } else {["You can't use a FAK from within a vehicle!", "basic"] spawn AP_fnc_handleMessage;};};
if (_code in (actionKeys "User12")) then {if (AP_earplugsToggle && soundVolume isEqualTo AP_volume) then {
        0 fadeSound(parseNumber((AP_volume * 0.5) toFixed 2));} else {if (soundVolume < (AP_volume + 0.01)) then {0 fadeSound 1;
        } else {0 fadeSound AP_volume;};};
    systemChat format["Sound volume changed to %1%2.", soundVolume * 100, "%"];
    _handled = true;};
_handled;