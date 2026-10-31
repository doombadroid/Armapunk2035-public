/*
    fn_mapDiag.sqf — which input events actually reach the 3D map's page.

    Drag gestures have never been validated in this CEF surface: every shipped
    screen is click-based, and clicks prove nothing about pointermove-with-
    button-held or setPointerCapture. Three different faults look identical
    ("tilt and pan do nothing"), and the console cannot be opened while the map
    is up because Esc closes the dialog -- so this arms first, then waits.

        [] spawn AP_fnc_mapDiag;     <- run, close console, open the map
        ... drag around ...            banner accumulates every event kind seen

    Reading the banner:
      mouse* only            -> CEF injects mouse events, no pointer synthesis;
                                the page must bind mouse events
      pointer* + JSERR       -> pointer events arrive but setPointerCapture (or
                                the handler) throws; the JSERR text says which
      everything, no JSERR   -> input is fine and the fault is page logic
      nothing accumulates    -> input never reaches the document at all; the
                                fault is below the page (control/dialog layer)
*/

if (!canSuspend) exitWith { diag_log "[MAPDIAG] use spawn"; };

diag_log "[MAPDIAG] armed -- open the map now (waiting up to 60s)";
private _deadline = diag_tickTime + 60;
private _ctrl = controlNull;
waitUntil {
    uiSleep 0.5;
    _ctrl = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    (!isNull _ctrl && { !isNull (findDisplay 930430) }) || { diag_tickTime > _deadline }
};
if (isNull _ctrl || { isNull (findDisplay 930430) }) exitWith { diag_log "[MAPDIAG] timed out -- the map never opened"; };

uiSleep 2;

private _js =
"(function(){" +
"var b=document.getElementById('__mapdiag');if(!b){" +
"b=document.createElement('div');b.id='__mapdiag';" +
"b.style.cssText='position:fixed;left:0;top:0;right:0;z-index:99999;background:#180000;color:#ffb020;" +
"font:11px ui-monospace,monospace;padding:6px 8px;white-space:pre-wrap;border-bottom:1px solid #ff5a3c';" +
"document.body.appendChild(b);}" +
"var seen={};" +
"function rpt(m){ if (window.WEBUI) { WEBUI.call('log', ['MAPDIAG ' + m]); } }" +
"window.onerror=function(m){ b.textContent='JSERR '+m; rpt('JSERR '+m); return false; };" +
"var evs=['pointerdown','pointermove','pointerup','mousedown','mousemove','mouseup','wheel','touchstart'];" +
"for (var i=0;i<evs.length;i++){ (function(n){" +
"document.addEventListener(n,function(e){" +
"if(seen[n])return; seen[n]=1;" +
"var btns=(e.buttons!==undefined)?e.buttons:-1;" +
"b.textContent='EV: '+Object.keys(seen).join(' ');" +
"rpt('EV '+n+' btns='+btns);" +
"},true); })(evs[i]); }" +
"b.textContent='EV: (none yet -- drag on the map)';" +
// State snapshot at injection, and the camera on every gesture end: a drag that
// moves the camera but not the screen is a render fault; a drag that moves
// neither is logic; no HF is a dead terrain feed (its catch only console.errors,
// which the bridge does NOT forward).
"function st(){ var L=document.getElementById('loading');" +
"rpt('state hf='+(window.HF?window.HF.n:'NONE')+' cam d='+Math.round(cam.dist)+' tilt='+cam.tilt.toFixed(2)+" +
"' yaw='+cam.yaw.toFixed(2)+' tx='+Math.round(cam.tx)+' ty='+Math.round(cam.ty)+" +
"' live='+(window.live?'yes':'no')+' mk='+(window.markers?markers.length:0)+" +
"' loading='+(L&&L.style.display!=='none'?L.textContent:'(hidden)')); }" +
"st();" +
"document.addEventListener('pointerup', st, true);" +
"document.addEventListener('wheel', function(){ setTimeout(st, 50); }, true);" +
"rpt('probe live');" +
"})()";

[_ctrl, _js] call webui_fnc_exec;
diag_log "[MAPDIAG] probe injected -- drag on the map and read the banner";
