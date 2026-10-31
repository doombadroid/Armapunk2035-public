#!/usr/bin/env python3
"""skinlab/compose.py -- out/<skin>_page.png -> out/<skin>_over.png and a contact sheet.

The page is what the texture IS; the "_over" view lays it over the base UV sheet at 50% with the
islands' edges drawn in red, so the question "does the effect follow the seams?" is answerable at a
glance. contact.png tiles every skin (page | over) so one look covers the set.
"""
import os, sys, glob
from PIL import Image, ImageFilter, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out'); TEX = os.path.join(HERE, 'textures')
SKINS = os.path.abspath(os.path.join(HERE, '..', '..', 'server', 'AP_server', 'web', 'ui', 'html', 'skins'))

def base_for(skin):
    html = open(os.path.join(SKINS, skin + '.html'), encoding='utf-8').read()
    i = html.find('RequestTexture("')
    if i >= 0:
        p = html[i + 16: html.find('"', i + 16)]
    else:
        j = html.find('var BASE="')
        if j < 0: return None        # a static JPEG page asks the engine for nothing
        p = html[j + 10: html.find('"', j + 10)]
    return os.path.join(TEX, p.replace('\\\\', '/').replace('\\', '/').split('/')[-1][:-4].lower() + '.png')

tiles = []
for pg in sorted(glob.glob(os.path.join(OUT, '*_page.png'))):
    skin = os.path.basename(pg)[:-9]
    page = Image.open(pg).convert('RGB').resize((1024, 1024))
    bf = base_for(skin)
    if bf is None: print('skip (no base sheet, a static page)', skin); continue
    base = Image.open(bf).convert('RGB').resize((1024, 1024))
    # island edges from the base sheet: anything that isn't near-black is painted
    m = base.convert('L').point(lambda v: 255 if v > 20 else 0)
    edges = m.filter(ImageFilter.FIND_EDGES).point(lambda v: 255 if v > 40 else 0)
    over = Image.blend(base, page, 0.5)
    red = Image.new('RGB', over.size, (255, 40, 40))
    over.paste(red, (0, 0), edges)
    over.save(os.path.join(OUT, skin + '_over.png'))
    tile = Image.new('RGB', (2048 + 16, 1024 + 48), (12, 14, 18))
    tile.paste(page, (0, 48)); tile.paste(over, (1024 + 16, 48))
    ImageDraw.Draw(tile).text((8, 12), '%s   |   page (what the texture is)          over base sheet, seams in red' % skin, fill=(200, 210, 220))
    tiles.append(tile)
    print('composed', skin)

if tiles:
    w = max(t.width for t in tiles); h = sum(t.height for t in tiles)
    sheet = Image.new('RGB', (w, h), (0, 0, 0)); y = 0
    for t in tiles: sheet.paste(t, (0, y)); y += t.height
    sheet.thumbnail((2064, 4000)); sheet.save(os.path.join(OUT, 'contact.png'))
    print('contact.png', sheet.size)
