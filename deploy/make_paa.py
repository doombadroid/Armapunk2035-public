#!/usr/bin/env python3
"""
PAA generator for LooneyBin phone redesign.
Converts PNG → PAA (DXT5) using ImageMagick for DXT compression.

PAA format (Arma 3 BI format):
  [2B type][TAGG blocks][2B null term][mip data...][6B null end]

Mip entry: [2B width][2B height][3B data_size][data_size bytes raw DXT data]
SFFO: 16 × 4-byte file offsets of each mip (0-padded for unused slots)
"""

import os
import struct
import subprocess
import tempfile
from PIL import Image

# PAA type codes
DXT1 = 0xFF01  # no alpha
DXT5 = 0xFF05  # with alpha

OUTDIR = "/home/timb/loonybin-phone/mission/Armapunk2035.Malden/images/phone"


def convert_to_dxt5_dds(png_path, width, height):
    """Use magick to convert a PNG to DXT5-compressed DDS, return raw DXT5 bytes."""
    with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as tmp_png:
        tmp_png_path = tmp_png.name
    with tempfile.NamedTemporaryFile(suffix='.dds', delete=False) as tmp_dds:
        tmp_dds_path = tmp_dds.name

    try:
        # Resize to target size
        result = subprocess.run(
            ['magick', png_path,
             '-resize', f'{width}x{height}!',
             '-define', 'dds:compression=dxt5',
             '-define', 'dds:mipmaps=0',
             tmp_dds_path],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            raise RuntimeError(f"magick failed: {result.stderr}")

        with open(tmp_dds_path, 'rb') as f:
            dds_data = f.read()

        # DDS header is exactly 128 bytes; raw DXT data follows
        if len(dds_data) < 128:
            raise RuntimeError(f"DDS too small: {len(dds_data)} bytes")

        # Verify it's DXT5
        fourcc = dds_data[84:88]
        if fourcc != b'DXT5':
            raise RuntimeError(f"Expected DXT5 FourCC, got {fourcc!r}")

        dxt_data = dds_data[128:]
        expected = (max(1, width // 4)) * (max(1, height // 4)) * 16
        if len(dxt_data) != expected:
            raise RuntimeError(
                f"DXT5 data size mismatch: got {len(dxt_data)}, expected {expected}"
            )
        return dxt_data

    finally:
        for p in (tmp_png_path, tmp_dds_path):
            try:
                os.unlink(p)
            except OSError:
                pass


def convert_to_dxt1_dds(png_path, width, height):
    """Use magick to convert a PNG to DXT1-compressed DDS, return raw DXT1 bytes."""
    with tempfile.NamedTemporaryFile(suffix='.dds', delete=False) as tmp_dds:
        tmp_dds_path = tmp_dds.name

    try:
        result = subprocess.run(
            ['magick', png_path,
             '-resize', f'{width}x{height}!',
             '-define', 'dds:compression=dxt1',
             '-define', 'dds:mipmaps=0',
             tmp_dds_path],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            raise RuntimeError(f"magick DXT1 failed: {result.stderr}")

        with open(tmp_dds_path, 'rb') as f:
            dds_data = f.read()

        dxt_data = dds_data[128:]
        expected = (max(1, width // 4)) * (max(1, height // 4)) * 8
        if len(dxt_data) != expected:
            raise RuntimeError(
                f"DXT1 data size mismatch: got {len(dxt_data)}, expected {expected}"
            )
        return dxt_data

    finally:
        try:
            os.unlink(tmp_dds_path)
        except OSError:
            pass


def compute_average_color_bgra(png_path):
    """Compute average BGRA color from image for CGVA TAGG."""
    img = Image.open(png_path).convert('RGBA')
    pixels = list(img.getdata())
    total_a = sum(p[3] for p in pixels)
    n = len(pixels)
    if total_a == 0:
        return bytes([0, 0, 0, 0])
    # Weight RGB by alpha (premultiplied average)
    r = sum(p[0] * p[3] for p in pixels) // max(total_a, 1)
    g = sum(p[1] * p[3] for p in pixels) // max(total_a, 1)
    b = sum(p[2] * p[3] for p in pixels) // max(total_a, 1)
    a = total_a // n
    return bytes([b & 0xFF, g & 0xFF, r & 0xFF, a & 0xFF])


def build_mip_sizes(base_w, base_h, dxt_block=4):
    """Return list of (w, h) for all mip levels where w,h are multiples of dxt_block."""
    sizes = []
    w, h = base_w, base_h
    while True:
        if w % dxt_block == 0 and h % dxt_block == 0 and w >= dxt_block and h >= dxt_block:
            sizes.append((w, h))
        else:
            break
        if w == dxt_block and h == dxt_block:
            break
        w = max(dxt_block, w // 2)
        h = max(dxt_block, h // 2)
    return sizes


def build_paa_dxt5(png_path, out_path):
    """Convert a PNG with alpha to DXT5 PAA with full mipmap chain."""
    img = Image.open(png_path)
    base_w, base_h = img.size
    has_alpha = img.mode in ('RGBA', 'LA', 'PA') or 'A' in img.getbands()

    paa_type = DXT5
    mip_sizes = build_mip_sizes(base_w, base_h)
    if not mip_sizes:
        # Fallback: at least one mip, padded to 4
        pad_w = ((base_w + 3) // 4) * 4
        pad_h = ((base_h + 3) // 4) * 4
        mip_sizes = [(pad_w, pad_h)]

    print(f"  mip levels: {mip_sizes}")

    # Collect DXT data for each mip
    mip_data = []
    for (w, h) in mip_sizes:
        dxt = convert_to_dxt5_dds(png_path, w, h)
        mip_data.append((w, h, dxt))

    # Compute average color
    avg_bgra = compute_average_color_bgra(png_path)

    # Build PAA
    _build_paa(out_path, paa_type, mip_data, avg_bgra, is_dxt5=True)
    size = os.path.getsize(out_path)
    print(f"  -> {out_path} ({size} bytes)")
    return size


def _build_paa(out_path, paa_type, mip_data, avg_bgra, is_dxt5=True):
    """Assemble and write the PAA file."""

    # Compute mip file offsets
    # Header = 2 (type) + TAGGs + 2 (terminator)
    tagg_size = 16 + 16  # CGVA + CXAM
    if is_dxt5:
        tagg_size += 16  # GALF
    tagg_size += 12 + 64  # SFFO (12-byte header + 64 bytes data)

    header_total = 2 + tagg_size + 2  # type + TAGGs + 2-byte null term

    offsets = [0] * 16
    pos = header_total
    for i, (w, h, dxt) in enumerate(mip_data):
        offsets[i] = pos
        pos += 7 + len(dxt)  # 7-byte mip header + data

    # Build TAGG section
    def make_tagg(name4, data):
        tag = b'GGAT' + name4.encode('ascii')
        return tag + struct.pack('<I', len(data)) + data

    tags = b''
    tags += make_tagg('CGVA', avg_bgra)
    tags += make_tagg('CXAM', bytes([0xFF, 0xFF, 0xFF, 0xFF]))
    if is_dxt5:
        tags += make_tagg('GALF', struct.pack('<I', 1))
    tags += make_tagg('SFFO', struct.pack('<16I', *offsets))

    # Build mipmap section
    mip_section = b''
    for (w, h, dxt) in mip_data:
        sz = len(dxt)
        mip_section += struct.pack('<HH', w, h)
        mip_section += bytes([sz & 0xFF, (sz >> 8) & 0xFF, (sz >> 16) & 0xFF])
        mip_section += dxt

    # End marker (6 null bytes, matching BI format)
    end_marker = b'\x00' * 6

    # Final PAA
    paa = (
        struct.pack('<H', paa_type)
        + tags
        + b'\x00\x00'  # TAGG section terminator
        + mip_section
        + end_marker
    )

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, 'wb') as f:
        f.write(paa)


def verify_paa(paa_path):
    """Basic validity check: non-empty, valid type header, non-empty mip0."""
    with open(paa_path, 'rb') as f:
        data = f.read()

    if len(data) < 128:
        return False, f"too small ({len(data)} bytes)"

    paa_type = struct.unpack('<H', data[:2])[0]
    valid_types = {0xFF05, 0xFF01, 0x4444, 0x8080, 0x1555}
    if paa_type not in valid_types:
        return False, f"unknown type 0x{paa_type:04X}"

    # Find SFFO and verify first mip is non-empty
    pos = 2
    first_offset = None
    while pos < len(data):
        tag = data[pos:pos+8]
        if len(tag) < 8:
            break
        if tag[:4] == b'GGAT':
            sz = struct.unpack('<I', data[pos+8:pos+12])[0]
            if tag[4:8] == b'SFFO':
                first_offset = struct.unpack('<I', data[pos+12:pos+16])[0]
            pos += 12 + sz
        else:
            break

    if first_offset is None or first_offset == 0:
        return False, "no valid SFFO TAGG"
    if first_offset >= len(data):
        return False, f"first mip offset {first_offset} >= file size {len(data)}"

    mip_sz = (data[first_offset+4]
              | (data[first_offset+5] << 8)
              | (data[first_offset+6] << 16))
    if mip_sz == 0:
        return False, "mip0 data size is 0"

    return True, f"ok (type=0x{paa_type:04X}, mip0_data={mip_sz}B, file={len(data)}B)"


def main():
    import glob

    print("=== Converting chrome textures ===")
    chrome_pngs = ['card', 'squircle', 'dock']
    for name in chrome_pngs:
        png = f"{OUTDIR}/{name}.png"
        paa = f"{OUTDIR}/{name}.paa"
        print(f"\n{name}.paa:")
        try:
            build_paa_dxt5(png, paa)
            ok, msg = verify_paa(paa)
            print(f"  verify: {msg}")
        except Exception as e:
            print(f"  ERROR: {e}")

    print("\n=== Converting app icons ===")
    icon_dir = "/home/timb/loonybin-phone/design/phone/icons"
    icon_pngs = sorted(glob.glob(f"{icon_dir}/app_*.png"))
    print(f"Found {len(icon_pngs)} app icons")

    results = []
    for png_path in icon_pngs:
        base = os.path.basename(png_path).replace('.png', '')
        paa_path = f"{OUTDIR}/{base}.paa"
        try:
            sz = build_paa_dxt5(png_path, paa_path)
            ok, msg = verify_paa(paa_path)
            status = "OK" if ok else "INVALID"
            results.append((base, status, sz, msg))
        except Exception as e:
            results.append((base, "ERROR", 0, str(e)))

    print("\n=== Summary ===")
    for name, status, sz, msg in results:
        print(f"  {status:7} {name}.paa  {sz:8d}B  {msg}")


if __name__ == '__main__':
    main()
