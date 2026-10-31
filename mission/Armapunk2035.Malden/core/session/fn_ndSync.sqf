/*
    fn_ndSync.sqf  (AP_fnc_ndSync)  — New Drachma balance push (server-authoritative).
    The server is the ONLY writer of the wallet; this is how the exact 4dp balance string reaches the
    client. Sets AP_ndStr (display truth) + the float mirror (legacy afford-checks). Optionally toasts
    an award. Called via AP_fnc_MP from APS_fnc_ndSRV.
      [ "<newBalanceStr>", "<reason>", "<deltaStr>" ]
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_newStr", "0", [""]], ["_reason", "sync", [""]], ["_delta", "", [""]]];
AP_ndStr = _newStr;
AP_nd = parseNumber _newStr;        // 32-bit mirror — DISPLAY/afford hints only, never persisted
AP_ndCacheB = ((AP_nd / 4) + 5);
// refresh the money HUD if the phone money panel is open

private _amtTxt = if (_delta isEqualTo "") then { "" } else { [_delta] call AP_fnc_ndText };
switch (_reason) do {case "warkill";
    case "quest";
    case "event": {if (_amtTxt isNotEqualTo "") then {
            [format ["<t size='1.1' color='#5be39c'>+%1 ND</t><br/>New Drachma awarded", _amtTxt], "basic"] spawn AP_fnc_handleMessage;};
    };
    case "mining": {if (_amtTxt isNotEqualTo "") then {
            [format ["Your rigs deposited <t color='#5be39c'>%1 ND</t> to your wallet", _amtTxt], "basic"] spawn AP_fnc_handleMessage;};
    };
    case "coinsell": {if (_amtTxt isNotEqualTo "") then {
            [format ["Sold coins for <t color='#5be39c'>%1 ND</t>", _amtTxt], "basic"] spawn AP_fnc_handleMessage;};};
    default {};   // "sync" / shop debits stay silent (the shop shows its own feedback)
};
