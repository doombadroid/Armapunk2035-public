#!/usr/bin/env python3
# Extract _co (color/skinnable) .paa from Arma 3 PBOs (base + DLC), categorized, preserving internal paths.
# Skips encrypted/unparseable CDLC PBOs. Uncompressed entries only (Arma textures are stored raw).
import struct, sys, os, glob

ARMA = sys.argv[1]        # Arma 3 install root
OUT  = sys.argv[2]        # output root (arma_textures/)

# category by PBO basename prefix (startswith catches DLC variants: air_f_exp, armor_f_tank, *_enoch, *_orange...)
CATS = [
    ('aircraft', 'air_f'),
    ('armored',  'armor_f'),
    ('boats',    'boat_f'),
    ('cars',     'soft_f'),
    ('clothing', 'characters_f'),
    ('weapons',  'weapons_f'),
]
def category(pbo):
    b = os.path.basename(pbo).lower()
    for cat, pfx in CATS:
        if b.startswith(pfx):
            return cat
    return None

def parse_header(data):
    off = 0; entries = []
    # first entry: product/Vers entry -> followed by null-terminated property strings (prefix, etc.)
    end = data.find(b'\x00', off)
    if end < 0 or end - off > 512:
        raise ValueError("bad header")
    name = data[off:end].decode('latin-1', 'replace'); off = end + 1
    packing, orig, res, ts, dsize = struct.unpack('<5I', data[off:off+20]); off += 20
    if name == '' and packing == 0x56657273:      # 'Vers' product entry
        while True:                                # consume extension property strings until empty string
            end = data.find(b'\x00', off)
            if end < 0:
                raise ValueError("bad props")
            s = data[off:end]; off = end + 1
            if s == b'':
                break
    else:
        off = 0                                    # no product entry -> restart from top
    while True:
        end = data.find(b'\x00', off)
        if end < 0 or end - off > 512:
            raise ValueError("bad header")
        name = data[off:end].decode('latin-1', 'replace'); off = end + 1
        if off + 20 > len(data):
            raise ValueError("truncated")
        packing, orig, res, ts, dsize = struct.unpack('<5I', data[off:off+20]); off += 20
        if name == '' and packing == 0:
            break
        entries.append((name, packing, dsize))
    return entries, off   # off = start of data blob

def is_color(name):
    n = name.lower()
    return n.endswith('_co.paa')

stats = {}   # cat -> [files, bytes]
skipped = []
seen_pbos = 0
for pbo in glob.glob(os.path.join(ARMA, '**', '*.pbo'), recursive=True):
    cat = category(pbo)
    if not cat:
        continue
    seen_pbos += 1
    try:
        with open(pbo, 'rb') as f:
            data = f.read()
        entries, dstart = parse_header(data)
    except Exception as e:
        skipped.append((os.path.basename(pbo), str(e))); continue
    doff = dstart
    for name, packing, dsize in entries:
        if is_color(name) and packing in (0, 0x56657273):
            rel = name.replace('\\', '/').lstrip('/')
            # strip leading 'a3/' for cleanliness
            if rel.lower().startswith('a3/'):
                rel = rel[3:]
            dest = os.path.join(OUT, cat, rel)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with open(dest, 'wb') as o:
                o.write(data[doff:doff+dsize])
            stats.setdefault(cat, [0,0]); stats[cat][0]+=1; stats[cat][1]+=dsize
        doff += dsize

print("=== extracted _co color textures ===")
tf=tb=0
for cat,(n,b) in sorted(stats.items()):
    print(f"  {cat:10} {n:6} files  {b/1e6:8.1f} MB")
    tf+=n; tb+=b
print(f"  {'TOTAL':10} {tf:6} files  {tb/1e6:8.1f} MB  ({tb/1e9:.2f} GB)")
print(f"PBOs scanned (categorized): {seen_pbos} ; skipped (encrypted/bad): {len(skipped)}")
for b,e in skipped[:15]:
    print("   skip", b, "-", e)
