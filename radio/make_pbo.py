#!/usr/bin/env python3
"""Minimal uncompressed PBO writer: make_pbo.py <src_dir> <out.pbo> <prefix>"""
import hashlib, pathlib, struct, sys

def entry(name: bytes, packing=0, orig=0, ts=0, size=0) -> bytes:
    return name + b"\x00" + struct.pack("<5I", packing, orig, 0, ts, size)

def main(src, out, prefix):
    src = pathlib.Path(src)
    files = sorted(p for p in src.rglob("*") if p.is_file())
    blob = bytearray()
    # header extension entry with the prefix property
    blob += entry(b"", packing=0x56657273)  # 'Vers' marker entry
    blob += b"prefix\x00" + prefix.encode() + b"\x00" + b"\x00"
    datas = []
    for p in files:
        data = p.read_bytes()
        rel = str(p.relative_to(src)).replace("/", "\\").encode()
        blob += entry(rel, size=len(data), orig=len(data))
        datas.append(data)
    blob += entry(b"")  # terminator
    for d in datas:
        blob += d
    digest = hashlib.sha1(bytes(blob)).digest()
    pathlib.Path(out).write_bytes(bytes(blob) + b"\x00" + digest)
    print(f"wrote {out} ({len(blob)+21} bytes, {len(files)} files, prefix={prefix})")

if __name__ == "__main__":
    main(*sys.argv[1:4])
