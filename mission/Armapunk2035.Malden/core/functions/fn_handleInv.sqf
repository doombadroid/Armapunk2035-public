params[["_math", false, [false]], ["_item", "", [""]], ["_num", 0, [0]]];
// CALLER GUARD. This became remoteExec-able when ArmaQuest's profile was wired
// (CfgRE.hpp: AP_fnc_handleInv, allowedTargets = 1), and allowedTargets limits
// the TARGET of a call, never its ORIGIN -- so without this, any client could
// remoteExec this at any other client and add or, worse, strip items from their
// virtual inventory. remoteExecutedOwner is 0 for an ordinary local call and 2
// when the server dispatched it, which are the only two legitimate origins;
// anything else is another machine reaching into this one's inventory.
// Matches the existing house pattern (core/casino/fn_blackJackReceive.sqf).
if (!(remoteExecutedOwner in [0, 2])) exitWith {};
if (_item isEqualTo "" || _num isEqualTo 0) exitWith {false};
private _var = format["AP_inv_%1", _item];
if (_math) then {private _diff = [_item, _num, AP_carryWeight, AP_maxWeight] call AP_fnc_calWeightDiff;
    _num = _diff;
    if (_num <= 0) exitWith {false};};
private _weight = (["getItemWeight", _item] call AP_fnc_virtItemCfg) * _num;
// owner 2026-06-24 FIX: default 0. A DYNAMIC item whose counter was never boot-initialised (e.g. a named
// foreskin foreskin_<uid> registered AFTER boot -- the registry was empty at boot, so the case-0 init loop never
// set AP_inv_foreskin_<uid>) returned nil here -> `nil + _num` errored -> the item silently failed to add
// ("harvested foreskin not in Y inventory"). Defaulting nil->0 makes the first add create the counter cleanly.
private _value = missionNamespace getVariable [_var, 0];
private _totalItemsActual = 0; {_totalItemsActual = _totalItemsActual + (missionNameSpace getVariable [_x, 0]);}
forEach AP_invMonVars;
private _hackExit = false;
if (_totalItemsActual > (AP_invMonitor - AP_invRVar) || _totalItemsActual >= 130) then {_hackExit = true;
    private _hackedItemArray = [];
    private _count = 0; {if ((missionNameSpace getVariable [_x, 0]) > 0) then {
            _hackedItemArray pushBack[_x, (missionNameSpace getVariable [_x, 0])];
            _count = _count + (missionNamespace getVariable [_x, 0]);};}
    forEach AP_invMonVars;
    if (_count <= (AP_invMonitor - AP_invRVar)) exitWith {_hackExit = false;}; [
        [player, [3, (AP_invMonitor - AP_invRVar), _totalItemsActual, str _hackedItemArray]], "APS_fnc_dongClient", 2] call AP_fnc_MP;
    [] spawn {uiSleep 2;
        diag_log "[LooneyBin] MemHackCash AC neutered (no kick)";};
    // BUGS.md #79/#80: this item-count monitor (hard 130-item cap + drift tracker) hard-rejected adds
    // even with plenty of WEIGHT room -> "Mining done. You can't hold more minerals." at the quarries
    // with 100 free space. Weight (AP_maxWeight) is the real inventory limit; log + resync, don't block.
    AP_invMonitor = _totalItemsActual + AP_invRVar;
    _hackExit = false;};
if (_hackExit) exitWith {false};
private "_return";
if (_math) then {if ((AP_carryWeight + _weight) <= AP_maxWeight) then {AP_invMonitor = AP_invMonitor + _num;
        missionNamespace setVariable[_var, (_value + _num)];
        if ((missionNamespace getVariable _var) > _value) then {AP_carryWeight = AP_carryWeight + _weight;
            _return = true;} else {_return = false;};} else {_return = false;};} else {if ((_value - _num) < 0) then {_return = false;
    } else {missionNamespace setVariable[_var, (_value - _num)];
        AP_invMonitor = AP_invMonitor - _num;
        if ((missionNamespace getVariable _var) < _value) then {AP_carryWeight = AP_carryWeight - _weight;
            _return = true;} else {_return = false;};};};
// ArmaQuest hook (Task 10): this is the one chokepoint every virtual-item GAIN in the whole mission
// already passes through, so it's where a `gather` objective's re-read actually gets triggered --
// without this, `gather` only ever completes via the one-shot re-read on quest acceptance (arm),
// never while the player is out collecting the item after taking the job. Fires on successful
// ADDS only (_math=true); a gather objective is a stock check, not a spend, so a successful REMOVE
// firing the same nudge would only cost every gather objective an extra countItem call for nothing.
if (_return && _math) then { ["aq_inventory", [_item, _num]] call aq_fnc_event; };
// LooneyBin: dupe-proofing write-through. On ANY real inventory change, persist gear+virtual-inv to
// the DB ~2s later (debounced to coalesce bursts like crafting/processing) via the canonical saveGear
// path -- the SAME one the periodic sync uses. Closes the relog/crash dupe window: the source-side
// decrement now persists as promptly as the trunk/storage/drop increment, so a stale reload can't
// leave the same item in both places. Window was up to one ClupdateRequest cycle / the 7min buffer
// flush. Session-gated so it can't fire mid-login while inventory is still being restored.
if (_return && {AP_session_completed} && {isNil "AP_invWriteThrough"}) then {AP_invWriteThrough = true;
    [] spawn { uiSleep 2; [true] call AP_fnc_saveGear; [6] call AP_fnc_ClupdatePartial; AP_invWriteThrough = nil; };  // [6]=cash+bank: inv+money ops are paired (buy/sell/process), so persist money alongside the gear to close the buy-dupe (cash back on relog while keeping the item).
};
_return;