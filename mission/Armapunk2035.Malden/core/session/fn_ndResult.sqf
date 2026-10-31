/*
    fn_ndResult.sqf  (AP_fnc_ndResult)  — New Drachma debit result + purchase continuation.
    The server ran the atomic SQL debit; this pops the pending token and, on success, runs the grant
    continuation the shop stashed (item/vehicle/clothes/loadout). Balance is always synced to the exact
    server value first. Called via AP_fnc_MP from APS_fnc_ndSRV.
      [ ok(bool), "<newBalanceStr>", "<token>" ]
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_ok", false, [false]], ["_newStr", "", [""]], ["_tok", "", [""]]];
if (_newStr isNotEqualTo "") then {AP_ndStr = _newStr;
    AP_nd = parseNumber _newStr;
    AP_ndCacheB = ((AP_nd / 4) + 5);
    };
// publish the result for any blocking waiter (AP_fnc_ndBuySync) BEFORE the continuation check --
// sync tokens carry no continuation, so they'd otherwise fall out at the pending-empty exit below.
if (isNil "AP_ndResults") then { AP_ndResults = createHashMap; };
AP_ndResults set [_tok, [_ok, _newStr]];
private _pending = AP_ndPending getOrDefault [_tok, []];
if (_pending isEqualTo []) exitWith {};        // unknown/expired token -> nothing to do (balance already synced)
AP_ndPending deleteAt _tok;
_pending params [["_onOk", {}, [{}]], ["_ctx", [], [[]]], ["_t0", 0, [0]]];
AP_action_in_use = false;
if (_ok) then {_ctx call _onOk;} else {
    [format ["Insufficient New Drachma. You have <t color='#ef3139'>%1 ND</t>.", [AP_ndStr] call AP_fnc_ndText], "basic"] spawn AP_fnc_handleMessage;
};
