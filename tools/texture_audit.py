#!/usr/bin/env python3
"""Re-extract referenced textures/rvmats straight from the Arma 3 install, with provenance.

    python3 tools/texture_audit.py LIST OUTROOT [--baseline DIR]...

LIST: one Arma path per line (`a3\\x\\y\\z_co.paa` or `a3\\...\\x.rvmat`); blank lines and `#` comments
ignored. OUTROOT/textures/<lowercase forward-slash path>.png|.rvmat, first (largest) mip, alpha kept
on _ca. Every .paa an rvmat's stages reference is extracted too. OUTROOT/textures/MANIFEST.md lists
Arma path, source PBO, SHA-1 of the .paa bytes, PNG size, replaced/unchanged/new against the first
baseline dir that holds the same relative PNG (pixels compared at the baseline's size), and per rvmat
the stage textures. PBOs are indexed by their own `prefix` property -- searched, never assumed.
"""
import hashlib, io, os, re, struct, subprocess, sys, tempfile
sys.path.insert(0, os.path.expanduser('~/blender_work'))
from paa_extract_textures import decode_paa          # PAA -> PIL image (DXT1/5, LZO mips), first mip
from PIL import Image, ImageChops

ARMA = os.path.expanduser('~/.local/share/Steam/steamapps/common/Arma 3')
PBO_DIRS = ['Addons', 'Expansion/Addons', 'Enoch/Addons', 'Argo/Addons', 'AoW/Addons']

def parse_pbo(path):
    """-> (prefix, [(name, offset, size)]) ; entries' names are relative to the prefix."""
    d = open(path, 'rb').read(); o = 0; prefix = ''
    def z(o):
        e = d.index(b'\0', o); return d[o:e], e + 1
    entries = []
    while True:
        name, o = z(o)
        mime, orig, rsv, ts, size = struct.unpack_from('<5I', d, o); o += 20
        if name == b'' and mime == 0x56657273:
            while True:
                k, o = z(o)
                if k == b'': break
                v, o = z(o)
                if k.lower() == b'prefix': prefix = v.decode('latin1')
            continue
        if name == b'' and size == 0: break
        entries.append([name.decode('latin1'), size])
    off = o; out = []
    for n, size in entries:
        out.append((n, off, size)); off += size
    return prefix, out, d

class Index:
    def __init__(self):
        self.files = {}   # lowercase full arma path -> (pbo relpath, offset, size, data)
        for sub in PBO_DIRS:
            dp = os.path.join(ARMA, sub)
            if not os.path.isdir(dp): continue
            for f in sorted(os.listdir(dp)):
                if not f.lower().endswith('.pbo'): continue
                if not re.search(r'structures_f|roads_f|data_f|props_f|map_malden', f, re.I): continue
                p = os.path.join(dp, f)
                prefix, ents, d = parse_pbo(p)
                rel = os.path.join(sub, f)
                for n, off, size in ents:
                    key = (prefix + '\\' + n).lower().replace('/', '\\')
                    self.files.setdefault(key, (rel, off, size, d))
        print(f'indexed {len(self.files)} files from {len(set(v[0] for v in self.files.values()))} PBOs', file=sys.stderr)
    def get(self, arma_path):
        k = arma_path.lower().replace('/', '\\')
        v = self.files.get(k)
        if not v: return None, None
        rel, off, size, d = v
        return rel, d[off:off + size]

def out_rel(arma_path):
    return arma_path.lower().replace('\\', '/')

def compare(new_img, baselines, rel_png):
    for b in baselines:
        p = os.path.join(b, rel_png)
        if os.path.exists(p):
            old = Image.open(p).convert('RGB')
            cand = new_img.convert('RGB')
            if cand.size != old.size: cand = cand.resize(old.size, Image.LANCZOS)
            diff = ImageChops.difference(cand, old)
            hist = diff.histogram()
            total = sum(hist); px = cand.size[0] * cand.size[1] * 3
            mean = sum(i * h for i, h in enumerate(hist[:256])) / px if px else 0   # R channel approx
            # proper mean over all channels:
            stat = sum(sum(i * h for i, h in enumerate(hist[c*256:(c+1)*256])) for c in range(3)) / px
            return ('unchanged' if stat < 2.0 else 'replaced'), f'{stat:.2f}', b
    return 'new', '-', ''

def main():
    if len(sys.argv) < 3: print(__doc__); sys.exit(2)
    lst, outroot = sys.argv[1], sys.argv[2]
    baselines = [a for i, a in enumerate(sys.argv) if i > 3 and sys.argv[i-1] == '--baseline']
    paths = [l.strip() for l in open(lst) if l.strip() and not l.startswith('#')]
    idx = Index()
    rows = []; rv_rows = []; done = set()
    def extract_paa(ap, why):
        key = ap.lower()
        if key in done: return
        done.add(key)
        rel, data = idx.get(ap)
        rel_png = out_rel(ap)[:-4] + '.png'
        if data is None:
            rows.append((ap, 'NOT FOUND', '', '', 'missing', '', why)); return
        try:
            img = decode_paa(data)
        except Exception as e:
            rows.append((ap, rel, hashlib.sha1(data).hexdigest()[:12], '', f'decode error: {e}', '', why)); return
        keep_alpha = ap.lower().endswith('_ca.paa')
        img = img.convert('RGBA' if keep_alpha else 'RGB')
        dst = os.path.join(outroot, 'textures', rel_png)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        img.save(dst)
        verdict, stat, bdir = compare(img, baselines, rel_png)
        rows.append((ap, rel, hashlib.sha1(data).hexdigest()[:12], f'{img.size[0]}x{img.size[1]}', verdict, stat, why))
    for ap in paths:
        if ap.lower().endswith('.paa'):
            extract_paa(ap, 'listed')
        elif ap.lower().endswith('.rvmat'):
            rel, data = idx.get(ap)
            if data is None:
                rv_rows.append((ap, 'NOT FOUND', [])); continue
            if data[:4] == b'\0raP':
                with tempfile.NamedTemporaryFile(suffix='.bin', delete=False) as t: t.write(data); tmp = t.name
                txt = subprocess.run(['armake2', 'derapify', tmp], capture_output=True, text=True).stdout
                os.unlink(tmp)
            else:
                txt = data.decode('latin1')
            dst = os.path.join(outroot, 'textures', out_rel(ap))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            open(dst, 'w', encoding='utf-8').write(txt)
            stages = re.findall(r'texture\s*=\s*"([^"]*)"', txt, re.I)
            rv_rows.append((ap, rel, stages))
            for s in stages:
                if s.lower().endswith('.paa') and s.lower().startswith('a3\\'):
                    extract_paa(s, f'stage of {ap.split(chr(92))[-1]}')
    os.makedirs(os.path.join(outroot, 'textures'), exist_ok=True)
    with open(os.path.join(outroot, 'textures', 'MANIFEST.md'), 'w', encoding='utf-8') as m:
        m.write('# Texture manifest -- re-extracted from the Arma 3 install\n\n')
        m.write(f'Source install: `{ARMA}`. PNG = first (largest) mip, alpha kept on `_ca`. '
                'Compared against the first baseline that had the same PNG: `unchanged` = mean pixel difference '
                '< 2/255 at the baseline\'s size, `replaced` otherwise, `new` = no baseline.\n\n')
        m.write(f'Baselines: {", ".join("`"+b+"`" for b in baselines) or "none"}\n\n')
        m.write('## Textures\n\n| Arma path | source PBO | SHA-1 (.paa) | PNG | status | mean diff | why |\n|---|---|---|---|---|---|---|\n')
        for r in rows: m.write('| `' + '` | `'.join(str(x) for x in r[:4]) + f'` | {r[4]} | {r[5]} | {r[6]} |\n')
        m.write('\n## Rvmats (derapified to `textures/<path>.rvmat`)\n\n| rvmat | source PBO | stage textures (in order) |\n|---|---|---|\n')
        for ap, rel, stages in rv_rows:
            m.write(f'| `{ap}` | `{rel}` | ' + ('<br>'.join('`'+s+'`' for s in stages) or '(none)') + ' |\n')
    print(f'{len(rows)} textures, {len(rv_rows)} rvmats -> {outroot}/textures')
    for r in rows:
        if r[4] not in ('unchanged',): print('  ', r[4].upper(), r[0], r[5])
    for ap, rel, stages in rv_rows:
        flag = [s for s in stages if re.search(r'rust|old|dirty', s, re.I)]
        print('  RVMAT', ap.split('\\')[-1], '->', len(stages), 'stages', ('SUSPECT: ' + ', '.join(flag)) if flag else '')

if __name__ == '__main__':
    main()
