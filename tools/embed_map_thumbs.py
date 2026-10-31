#!/usr/bin/env python3
"""
Bake Malden's 169 satellite tiles INTO map.html as 128px JPEG data-urls.

The visible cost of opening the map is tile conversion: RequestTexture converts
each PAA on demand, and until the first ones land the island is a wireframe.
Embedding the lowest mip in the page itself makes the whole island textured the
moment the page runs; the engine still serves 256/512 close-up detail lazily.

Reads the PBO directly (decode via ~/blender_work/paa_extract_textures.py --
DXT1/5 + LZO), writes between the /*EMBTILES-START*/ ... /*EMBTILES-END*/
markers. Rerun after any re-drop of map.html.

The consumer of window.EMB (the global this script writes) now lives in
ui/html/grid3d.js, not in this page -- the renderer was extracted there in
Task 3. This script still targets map.html because that is the only page
with the EMB block; grid3d.js just reads window.EMB if it finds it.
"""
import sys, base64, io, re, pathlib
sys.path.insert(0, "/home/timb/blender_work")
from paa_extract_textures import parse_pbo, decode_paa
from PIL import Image

PBO = "/home/timb/.local/share/Steam/steamapps/common/Arma 3/Argo/Addons/map_malden_data_layers.pbo"
PAGE = pathlib.Path("/home/timb/Armapunk2035/mission/Armapunk2035.Malden/ui/html/map.html")

_hdr, _prefix, elist = parse_pbo(PBO)   # (raw header, prefix str, [(name, method, offset, size)])
data = open(PBO, "rb").read()
byname = { str(name).lower(): (off, size) for name, method, off, size in elist }

out = []
n = 0
for r in range(13):
    for c in range(13):
        name = f"s_{c:03d}_{r:03d}_lco.paa"
        hit = next((k for k in byname if k.endswith(name)), None)
        if hit is None: continue
        off, size = byname[hit]
        img = decode_paa(data[off:off + size])
        img = img.convert("RGB").resize((128, 128), Image.LANCZOS)
        buf = io.BytesIO()
        img.save(buf, "JPEG", quality=66, optimize=True)
        b64 = base64.b64encode(buf.getvalue()).decode()
        out.append(f'"{c}_{r}":"data:image/jpeg;base64,{b64}"')
        n += 1

blob = "window.EMB={" + ",".join(out) + "};"
s = PAGE.read_text(encoding="utf-8")
s = re.sub(r"/\*EMBTILES-START\*/.*?/\*EMBTILES-END\*/",
           "/*EMBTILES-START*/\n" + blob + "\n/*EMBTILES-END*/", s, flags=re.S)
PAGE.write_text(s, encoding="utf-8")
print(f"embedded {n} thumbs, page now {PAGE.stat().st_size//1024}KB")
