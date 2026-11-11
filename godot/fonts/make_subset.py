"""Rebuild the game's fonts with only the characters the game uses (run from anywhere; needs fonttools).
The three kinds of type are in docs/フォント設計.md. The whole fonts are fetched from Google Fonts (all SIL OFL 1.1,
no Reserved Font Name) into $WORK/fonts_src and are not kept in the repository; the subsets and the licences are."""
import re, glob, os, sys, urllib.request
from fontTools.ttLib import TTFont
from fontTools import subset
G = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.environ.get('WORK', '/home/claude/work')
for line in open(os.path.join(os.path.dirname(G), 'paths.env'), encoding='utf-8'):
    if line.startswith('WORK=') and 'WORK' not in os.environ: WORK = line.strip().split('=', 1)[1]
SRC = WORK + '/fonts_src'; os.makedirs(SRC, exist_ok=True)
RAW = 'https://raw.githubusercontent.com/google/fonts/main/ofl/'
# file in godot/fonts: (folder in google/fonts, file there)
FONTS = {'ShipporiMinchoB1-Medium.ttf': 'shipporiminchob1', 'ShipporiMinchoB1-SemiBold.ttf': 'shipporiminchob1',
         'BIZUDMincho-Bold.ttf': 'bizudmincho', 'DotGothic16-Regular.ttf': 'dotgothic16'}
src = ''.join(open(p, encoding='utf-8').read() for p in sorted(glob.glob(G + '/scripts/*.gd')))
chars = set(''.join(re.findall(r'"([^"]*)"', src)))
for p in [G + '/lang/text.csv'] + sorted(glob.glob(G + '/story/*.txt')): chars |= set(open(p, encoding='utf-8').read())
chars |= set('0123456789.:０１２３４５６７８９ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz　、。，．・：；？！ー（）「」『』／｜＋－＝［］…―●％ ')
chars = {c for c in chars if c >= ' ' and c != '​'}
for name, folder in FONTS.items():
    p = f'{SRC}/{name}'
    if not os.path.exists(p): urllib.request.urlretrieve(RAW + folder + '/' + name, p)
    lic = f'{G}/fonts/LICENSES/OFL_{folder}.txt'
    if not os.path.exists(lic):
        os.makedirs(os.path.dirname(lic), exist_ok=True); urllib.request.urlretrieve(RAW + folder + '/OFL.txt', lic)
    assert 'with Reserved Font Name' not in open(lic, encoding='utf-8').read()[:400], name + ': has a Reserved Font Name, rename the subset'
    f = TTFont(p)
    o = subset.Options(); o.layout_features = ['*']; o.name_IDs = ['*']; o.notdef_outline = True
    s = subset.Subsetter(o); s.populate(text=''.join(chars)); s.subset(f); f.save(f'{G}/fonts/{name}')
    cmap = f.getBestCmap(); miss = sorted(c for c in chars if ord(c) not in cmap)
    print(name, os.path.getsize(f'{G}/fonts/{name}') // 1024, 'KB', len(cmap), 'chars', ('MISSING ' + ''.join(miss)) if miss else '')
print('font subset:', len(chars), 'chars')
