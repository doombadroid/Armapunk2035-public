#!/usr/bin/env python3
"""build_hatch_maxsec.py -- the MaxSec Hatchback livery: the owner's Firefly recolour as the ground, its
stripe and lettering erased (Firefly drew them on the belt line, where the fender/quarter islands' edges
curve, so they stepped at every door seam in-game), and the stripe + MAXSEC redrawn by the page on the
CALIBRATED band that fn skins hatch_ticker proved continuous: driver (profile A, nose-left) y 705-790,
passenger (profile B, nose-right) y 1140-1230 on the 2048 sheet."""
import base64, io
from PIL import Image, ImageDraw
SRC = 'scratchpad/skinlab/textures/hatch_maxsec_src_v2fix.png'
OUT = 'server/AP_server/web/ui/html/skins/hatch_maxsec.html'
im = Image.open(SRC).convert('RGB').resize((2048, 2048), Image.LANCZOS)
d = ImageDraw.Draw(im)
# erase Firefly's stripe + text on both profiles (2048 coords). The body is a vertical gradient --
# (42,40,54) under the windows down to (6,3,18) at the sills, sampled -- so the erase is the same
# gradient, not a flat slab (the first cut used one sampled colour and read as a lighter panel).
def erase(x0, y0, x1, y1, ytop, ybot):
    top, bot = (42, 40, 54), (6, 3, 18)
    for y in range(y0, y1):
        t = min(1.0, max(0.0, (y - ytop) / float(ybot - ytop)))
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        d.line([(x0, y), (x1, y)], fill=c)
erase(60, 640, 1400, 800, 630, 880); erase(470, 800, 1060, 860, 630, 880)      # A
erase(60, 1095, 1400, 1245, 1085, 1320); erase(390, 1245, 960, 1300, 1085, 1320)  # B
buf = io.BytesIO(); im.save(buf, 'JPEG', quality=84, optimize=True)
b64 = base64.b64encode(buf.getvalue()).decode()
html = '''<!doctype html><html><head><meta charset="utf-8"><title>hatch_maxsec</title>
<!-- MaxSec Hatchback livery. Ground = the owner's Firefly recolour (embedded, stripe/text erased);
     the stripe and MAXSEC are drawn here on the calibrated side bands (see build_hatch_maxsec.py).
     Static skin: [cursorObject, "hatch_maxsec"] call AP_fnc_htmlSkin; -->
<style>html,body{margin:0;width:100%%;height:100%%;overflow:hidden;background:#000}canvas{display:block;width:100vw;height:100vh}</style>
</head><body><canvas id="c" width="2048" height="2048"></canvas><script>
(function(){
  var cv=document.getElementById("c"),ctx=cv.getContext("2d");
  var img=new Image();
  // Per side: stripe segments [x0, x1, dy] (dy = UV offset of that panel, read off the hatch_ruler skin at
  // the seams: driver fender sits 12 px LOWER on the car than the door, so its stripe rides 12 px higher on
  // the sheet; door->quarter seam is clean), then yWhite, yBlue0, yBlue1, textX0, textX1, textY.
  // Driver = profile A (nose-left, door front edge x~475); passenger = profile B (nose-right).
  var SIDES=[{seg:[[310,440,-5],[440,1330,0]],w:698,b0:712,b1:762,tx0:470,tx1:1080,ty:822},
             {seg:[[150,1190,0]],w:1133,b0:1147,b1:1197,tx0:400,tx1:1130,ty:1257}];
  function draw(){
    ctx.drawImage(img,0,0,2048,2048);
    for(var i=0;i<SIDES.length;i++){var s=SIDES[i];
      for(var j=0;j<s.seg.length;j++){var g=s.seg[j],dy=g[2];
        ctx.fillStyle="#ffffff";ctx.fillRect(g[0],s.w+dy,g[1]-g[0],10);
        ctx.fillStyle="#4fb3e8";ctx.fillRect(g[0],s.b0+dy,g[1]-g[0],s.b1-s.b0);
      }
      ctx.fillStyle="#ffffff";ctx.font="bold 92px sans-serif";ctx.textAlign="center";ctx.textBaseline="middle";
      ctx.fillText("MAXSEC",(s.tx0+s.tx1)/2,s.ty);
    }
  }
  img.onload=draw; img.src="data:image/jpeg;base64,%s";
})();
</script></body></html>
''' % b64
open(OUT, 'w').write(html); print('wrote', OUT, len(html), 'chars')
