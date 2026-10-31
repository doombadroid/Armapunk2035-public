#!/usr/bin/env python3
"""build_hatch_utu.py -- the owner's Gemini MaxSec livery (2048 source) with every piece of generated
pseudo-text erased and re-lettered in Chinese (owner 2026-09-06: "replace all the garbage text with
chinese letters"). Regions are 2048-sheet rects read off gridded crops; each is filled with the body
colour sampled just outside its left edge, then the text is drawn with Droid Sans Fallback in the
livery's own blue. Output goes through make_skin_page (static page, JPEG q84)."""
import subprocess, sys
from PIL import Image, ImageDraw, ImageFont
SRC = 'scratchpad/skinlab/textures/hatch_utu_src.jpg'
OUT = 'scratchpad/skinlab/textures/hatch_utu_cn.png'
PAGE = 'server/AP_server/web/ui/html/skins/hatch_utu.html'
FONT = '/usr/share/fonts/droid/DroidSansFallback.ttf'
BLUE = (58, 170, 240)
im = Image.open(SRC).convert('RGB'); d = ImageDraw.Draw(im)

def erase(x0, y0, x1, y1, sample=None):
    c = im.getpixel(sample or (max(0, x0 - 10), (y0 + y1) // 2))
    d.rectangle((x0, y0, x1, y1), fill=c)

def text(s, x, y, size, color=BLUE, anchor='la'):
    d.text((x, y), s, font=ImageFont.truetype(FONT, size), fill=color, anchor=anchor)

# ---- profile A (driver, nose-left): taglines under MAXSEC + four fake placards
erase(538, 830, 892, 894); erase(900, 892, 1015, 925)
erase(295, 718, 355, 748); erase(138, 792, 210, 828); erase(30, 828, 115, 858)
text('城市战术部队', 715, 834, 30, anchor='ma'); text('马尔登防卫安全部队', 715, 870, 19, anchor='ma')
text('最高安全 · 01', 957, 897, 18, anchor='ma')
text('巡逻', 325, 722, 18, anchor='ma'); text('警戒区', 174, 800, 16, anchor='ma'); text('防卫', 72, 834, 16, anchor='ma')
# ---- profile B (passenger, nose-right)
erase(545, 1272, 892, 1338); erase(378, 1322, 532, 1368)
erase(1070, 1152, 1140, 1192); erase(1222, 1242, 1300, 1278, sample=(1261, 1234)); erase(1302, 1278, 1392, 1306, sample=(1347, 1314))
text('城市战术部队', 720, 1276, 30, anchor='ma'); text('马尔登防卫安全部队', 720, 1312, 19, anchor='ma')
text('最高安全 · 01', 455, 1334, 18, anchor='ma')
text('巡逻', 1105, 1160, 18, anchor='ma'); text('警戒区', 1261, 1248, 16, anchor='ma'); text('防卫', 1347, 1282, 16, anchor='ma')
# ---- hood badge text, bumper placards, wheel hub, sill plates
# HOOD = as Gemini drew it (owner: "restore the original hood ... I meant pre chinese lettering"):
# the badge and its UNIT-01 / MDSF lines stay untouched.
erase(1372, 1472, 1440, 1498, sample=(1405, 1506)); erase(1648, 1472, 1716, 1498, sample=(1676, 1506))
d.rectangle((876, 1540, 1012, 1630), fill=(28, 30, 38))   # the 'book' placard on the wheel hub: solid dark
erase(528, 1790, 620, 1836); erase(735, 1790, 808, 1836, sample=(700, 1812))   # tread plates: blank (owner: no lettering on the tyre)
im.save(OUT)
subprocess.run([sys.executable, '/home/timb/arma-webui/examples/ui2texture/make_skin_page.py', OUT, PAGE, '--size', '2048', '--quality', '84'], check=True)

# ---- the ALERT page (owner: "a ticker that says stay back, red, only when the siren lights are on").
# fn_sirenLights swaps the vehicle to this LIVE page while AP_lights is true and back to the static one
# after. Same art underneath (embedded JPEG), plus one red LED ticker per side on the belt line just
# above the stripe: on the MAXSEC lettering both sides, the hood centre and the tailgate under the rear window -- the bands hatch_ruler proved.
import base64, io
buf = io.BytesIO(); im.save(buf, 'JPEG', quality=84, optimize=True)
b64 = base64.b64encode(buf.getvalue()).decode()
alert = '''<!doctype html><html><head><meta charset="utf-8"><title>hatch_utu_alert</title>
<!-- MaxSec Hatchback, lights-on state: the hatch_utu art plus a live red STAY BACK ticker on both sides.
     Built by scratchpad/skinlab/build_hatch_utu.py; applied by fn_sirenLights, never by hand. -->
<style>html,body{margin:0;width:100%%;height:100%%;overflow:hidden;background:#000}canvas{display:block;width:100vw;height:100vh}</style>
</head><body><canvas id="c" width="2048" height="2048"></canvas><script>
(function(){
  var cv=document.getElementById("c"),ctx=cv.getContext("2d"),t0=performance.now(),img=new Image(),ok=false;
  // Bands = [yTop, yBottom, [segments]], a segment = [x0, x1, dyAtX0, dyAtX1, text]. Owner 2026-09-06 plan:
  // the ticker rides the TOP of the MAXSEC lettering, starting and ending with it (driver A: MAXSEC x 518-967,
  // y 748-795; passenger B: x 455-920, y 1182-1240), plus one dead centre on the hood island (x 1455-1795,
  // y 700-950) and one right under the rear window on the tailgate panel (x 1365-1750, y 1090-1185).
  var BANDS=[[700,744,[[518,967,17,-9,true]]],[1134,1178,[[467,919,-1,22,true]]],   // MAXSEC is SLANTED on the sheet (measured: A top 765@518 -> 739@967, B 1181@467 -> 1204@919); the band follows its top edge, 4 px above
             [795,839,[[1462,1790,0,0,true]]],[1418,1452,[[1385,1700,0,0,true]]]];   // rear: hatch panel under the glass = x 1350-1710, y 1345-1450 (found with the 8x8 grid skin: cells F6/F7). Roof island tail = spoiler lip, trapezoid 1090-1185 = plate recess
  var MSG="   \\u25AA   STAY BACK   ";
  function band(t,B){
    var y0=B[0],y1=B[1],h=y1-y0;
    for(var k=0;k<B[2].length;k++){var g=B[2][k],x0=g[0],x1=g[1],w=x1-x0,sl=(g[3]-g[2])/w;
    ctx.save();ctx.beginPath();ctx.rect(x0,y0-40,w,h+80);ctx.clip();   // clip to the segment's x range, generous in y
    ctx.transform(1,sl,0,1,0,g[2]-sl*x0);                              // y -> y + dy(x): the slope
    ctx.beginPath();ctx.rect(x0,y0,w,h);ctx.clip();
    ctx.fillStyle="rgba(10,4,4,.94)";ctx.fillRect(x0,y0,w,h);
    ctx.fillStyle="#ff2a2a";ctx.fillRect(x0,y0,w,4);ctx.fillRect(x0,y1-4,w,4);
    ctx.font="bold "+Math.round(h*.7)+"px monospace";ctx.textBaseline="middle";ctx.textAlign="left";
    var on=((t*2.5)%%1)<0.75;   // strobe with the lights: three-quarter duty
    ctx.shadowColor="#ff4040";ctx.shadowBlur=on?18:0;ctx.fillStyle=on?"#ff3030":"#4a0c0c";
    if(g[4]){var mw=ctx.measureText(MSG).width,x=x0-((t*220)%%mw);for(;x<x1;x+=mw)ctx.fillText(MSG,x,y0+h/2);}
    else{for(var dx=x0+16;dx<x1-8;dx+=28)ctx.fillRect(dx,y0+h/2-5,10,10);}   // LED dots, same strobe
    ctx.shadowBlur=0;ctx.fillStyle="rgba(0,0,0,.3)";for(var y=y0;y<y1;y+=3)ctx.fillRect(x0,y,w,1);
    ctx.restore();}
  }
  function tick(){var t=(performance.now()-t0)/1000;
    if(ok)ctx.drawImage(img,0,0,2048,2048);else{ctx.fillStyle="#000";ctx.fillRect(0,0,2048,2048);}
    for(var i=0;i<BANDS.length;i++)band(t,BANDS[i]);
    requestAnimationFrame(tick);}
  img.onload=function(){ok=true;}; img.src="data:image/jpeg;base64,%s";
  requestAnimationFrame(tick);
})();
</script></body></html>
''' % b64
open('server/AP_server/web/ui/html/skins/hatch_utu_alert.html', 'w').write(alert)
print('wrote alert page', len(alert), 'chars')
