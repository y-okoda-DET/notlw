"""Rebuild godot/fonts/SerifJP-Bold.otf with every character the scripts use (run from anywhere).
Needs fonts-noto-cjk (NotoSerifCJK-Bold.ttc) and fonttools."""
import re, glob, os
from fontTools.ttLib import TTCollection
from fontTools import subset
G = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tc = TTCollection('/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc')
f = [x for x in tc.fonts if 'JP' in x['name'].getDebugName(1)][0]
src = ''.join(open(p, encoding='utf-8').read() for p in sorted(glob.glob(G + '/scripts/*.gd'))) + open(G + '/lang/text.csv', encoding='utf-8').read()
chars = set(''.join(re.findall(r'"([^"]*)"', src))) | set('0123456789.０１２３４５６７８９ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz　、。，．・：；？！ー（）「」『』／｜＋－＝［］…● ')
o = subset.Options(); o.layout_features = ['*']; o.name_IDs = ['*']
s = subset.Subsetter(o); s.populate(text=''.join(chars)); s.subset(f); f.save(G + '/fonts/SerifJP-Bold.otf')
print('font subset:', len(chars), 'chars')
