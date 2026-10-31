#!/usr/bin/env python3
"""
sqe_to_cryptorig.py -- convert an Eden composition.sqe into compositions/cryptorig.sqf
(placement-relative [[class,[ox,oy,oz],relDir,(anims)],...] read by APS_fnc_miningSRV _spawnRig).
sqe position[] = {x_east, z_up, y_north} (comp-center relative); angles[] = {pitch,yaw,roll} RADIANS.
Rules: oz normalized so the LOWEST piece = 0 (anchor = base piece); pieces sorted by oz ascending;
anim attributes with value 0 are dropped (0 = model default phase).
Usage: python3 sqe_to_cryptorig.py <composition.sqe> <out.sqf>
"""
import re, sys, math
src, out = sys.argv[1], sys.argv[2]
t = open(src, encoding='utf-8', errors='replace').read()
items = []
for m in re.finditer(r'class Item\d+\s*\{(.*?)\n\t\};', t, re.S):
    b = m.group(1)
    ty = re.search(r'type="([^"]+)"', b)
    po = re.search(r'position\[\]=\{([^}]+)\}', b)
    an = re.search(r'angles\[\]=\{([^}]+)\}', b)
    if not (ty and po): continue
    x, z, y = [float(v) for v in po.group(1).split(',')]
    yaw = 0.0
    if an:
        yaw = math.degrees(float(an.group(1).split(',')[1])) % 360
    # anim sources with non-zero phase only
    anims = []
    for am in re.finditer(r"animateSource \['(\w+)'.*?value=([\d.]+);", b, re.S):
        if float(am.group(2)) != 0: anims.append([am.group(1), float(am.group(2))])
    items.append([ty.group(1), x, y, z, yaw, anims])
zmin = min(i[3] for i in items)
items.sort(key=lambda i: i[3])
lines = []
for cls, x, y, z, yaw, anims in items:
    base = f'    ["{cls}", [{x:.3f}, {y:.3f}, {z-zmin:.3f}], {yaw:.2f}'
    if anims:
        a = ", ".join(f'["{s}", {p:g}]' for s, p in anims)
        base += f', [{a}]'
    lines.append(base + "]")
hdr = ('/*\n    compositions\\cryptorig.sqf -- the placeable Crypto Mining Rig composition (owner-built in 3DEN,\n'
       '    converted by scratchpad/sqe_to_cryptorig.py from Documents/Arma 3/compositions/CryptoMiningRig).\n'
       '    Read by APS_fnc_miningSRV _spawnRig: [[class, [ox,oy,oz], relDir, (anims)], ...]; offsets rotate\n'
       '    with placement dir, oz from the lowest piece (=0). Re-export in Eden + rerun the converter to change.\n*/\n')
open(out, 'w').write(hdr + "[\n" + ",\n".join(lines) + "\n]\n")
print(f"{len(items)} pieces -> {out}")
for l in lines: print(l)
