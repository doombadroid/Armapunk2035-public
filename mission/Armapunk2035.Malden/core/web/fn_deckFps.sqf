/*
    fn_deckFps.sqf — print the phone's own frame rate ON the phone.

    "In game FPS is fine, the phone isn't" is a claim about the BROWSER's frame
    rate, not Arma's, and nothing in the RPT measures that. The old chassis diag
    does, but it has to be armed before the dialog opens and then left alone for
    fifteen seconds, which is why it keeps not getting run. This needs no timing:
    open the phone, run it, read the strip.

    It reports three numbers because they fail in different combinations, and the
    combination is the diagnosis:

      raf    frames/sec from requestAnimationFrame
      timer  setTimeout(0) callbacks/sec
      css    whether a compositor-driven transform is still advancing

    raf ~1 AND timer ~1  -> Chromium is BACKGROUND-THROTTLING this renderer. It
                            clamps both schedulers to 1Hz for a surface it thinks
                            is hidden or occluded. css usually keeps running,
                            because compositor animations are not clamped. This
                            is not a page problem and no page change fixes it.
      raf low, timer high -> frames are not being delivered: BeginFrame is the
                            bottleneck, not the schedulers.
      all three healthy   -> the page is fast and the lag is in what it is asked
                            to draw. Then, and only then, is the chassis
                            animation worth attacking (see AP_fnc_deckFx).

    Usage:  [] spawn AP_fnc_deckFps;    with the phone already open
*/

disableSerialization;
private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
if (isNull _c) exitWith { diag_log "[DECKFPS] no page is open"; };

private _js =
"(function(){" +
"var b=document.getElementById('__fps');" +
"if(!b){b=document.createElement('div');b.id='__fps';" +
"b.style.cssText='position:fixed;left:0;top:0;right:0;z-index:99999;background:#001018;color:#33ffbb;" +
"font:11px ui-monospace,monospace;padding:6px 8px;border-bottom:1px solid #33ffbb';" +
"document.body.appendChild(b);}" +
"b.textContent='MEASURING 3s...';" +
// compositor probe: a transform animation runs off the main thread, so it keeps
// advancing even when the schedulers are clamped
"var p=document.getElementById('__fpsp');" +
"if(!p){p=document.createElement('div');p.id='__fpsp';" +
"p.style.cssText='position:fixed;left:-9999px;top:0;width:10px;height:10px;animation:__fpsspin 2s linear infinite';" +
"var s=document.createElement('style');s.textContent='@keyframes __fpsspin{from{transform:rotate(0deg)}to{transform:rotate(360deg)}}';" +
"document.head.appendChild(s);document.body.appendChild(p);}" +
"var css0=getComputedStyle(p).transform;" +
"var r=0,t=0,t0=performance.now();" +
"(function tick(){r++;if(performance.now()-t0<3000)requestAnimationFrame(tick);})();" +
"(function tmr(){t++;if(performance.now()-t0<3000)setTimeout(tmr,0);})();" +
"setTimeout(function(){" +
"var el=(performance.now()-t0)/1000;" +
"var css1=getComputedStyle(p).transform;" +
"var moved=(css0!==css1);" +
"b.textContent='PHONE FPS  raf:'+(r/el).toFixed(1)+'/s  timer:'+(t/el).toFixed(1)+'/s  css:'+(moved?'advancing':'FROZEN')" +
"+'  vis:'+document.visibilityState+'  hidden:'+document.hidden;" +
"b.style.color=((r/el)<10)?'#ff5a3c':'#c9e21a';" +
"},3200);})()";

[_c, _js] call webui_fnc_exec;   // queued: raw ExecJS before PageLoaded is dropped silently
diag_log "[DECKFPS] measuring -- read the strip at the top of the phone in ~4s";
