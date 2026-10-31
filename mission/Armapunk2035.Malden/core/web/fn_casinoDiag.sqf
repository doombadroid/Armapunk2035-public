/*
    fn_casinoDiag.sqf — make a deaf casino page say WHY it is deaf.

    "It loads and nothing else happens" has three different causes that look
    identical on screen, and the browser console is unreachable (Esc opens it
    AND closes the dialog). So this paints the answer onto the page itself.

    ExecJS needs no bridge -- it is an engine call on the control -- so this
    works even when webui.js never loaded, which is the whole point.

    ARM FIRST, THEN OPEN THE CASINO:
        [] spawn AP_fnc_casinoDiag;    <- run this, close the console
        ... then open the phone -> Casino ...

    A banner appears across the top of the table. What it says:
      A3API    no  -> the control never bound the API; the url/whitelist is wrong
      WEBUI    no  -> the bridge never loaded. bootErr says whether RequestFile
                      rejected (a path/permission problem) or never ran at all
      AP       shim-> our shim is in charge (right); mock -> the designer's dev
                      stub won, so the shim did not install
      subs         -> channels the page actually subscribed to
      cas          -> whether a "casino" payload has arrived
      hErr         -> a channel handler THREW. webui.js catches those, so a
                      payload the page cannot read looks identical to one that
                      never arrived -- this is the difference
*/

if (!canSuspend) exitWith { diag_log "[CASDIAG] use spawn"; };

private _isCasino = { (allDisplays findIf { (ctrlIDD _x) in [930400,930410,930411,930412,930413,930414,930415] }) > -1 };

diag_log "[CASDIAG] armed -- open the casino now (waiting up to 60s)";
private _deadline = diag_tickTime + 60;
private _ctrl = controlNull;
waitUntil {
    uiSleep 0.5;
    _ctrl = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    (!isNull _ctrl && { call _isCasino }) || { diag_tickTime > _deadline }
};
if (isNull _ctrl || { !(call _isCasino) }) exitWith { diag_log "[CASDIAG] timed out -- the casino never opened"; };

uiSleep 4;   // past the 3s readiness drain, so the queue has flushed

private _js =
"(function(){var b=document.getElementById('__casdiag')||document.createElement('div');" +
"b.id='__casdiag';b.style.cssText='position:fixed;left:0;top:0;right:0;z-index:99999;background:#180000;" +
"color:#ffb020;font:11px ui-monospace,monospace;padding:6px 8px;white-space:pre-wrap;border-bottom:1px solid #ff5a3c';" +
"var w=(typeof WEBUI!=='undefined');" +
"var ap=(window.AP&&window.AP.__shim)?'shim':(window.AP?'mock-or-other':'MISSING');" +
"var subs=(window.__apSubs)?Object.keys(window.__apSubs).join(','):'(unknown)';" +
"b.textContent='CASDIAG  A3API:'+(typeof A3API!=='undefined'?'yes':'NO')+"+
"'  WEBUI:'+(w?'yes':'NO')+'  AP:'+ap+'  subs:'+subs+"+
"'  bootErr:'+(window.__apBootErr||'none')+'  cas:'+(window.__apGotCasino?'yes':'no')+"+
"'  hErr:'+(window.__apHandlerErr||'none')+"+
"'  ua:'+navigator.userAgent.slice(0,40);" +
"document.body.appendChild(b);})()";

[_ctrl, _js] call webui_fnc_exec;   // queued: raw ExecJS before PageLoaded is dropped silently
diag_log "[CASDIAG] banner painted -- read the top of the casino page";
