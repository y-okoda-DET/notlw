"""字体の点検（試作127 の感想「「射」「影」のフォントだけが違う」）：台本・スクリプトの字が、ゲームの字体（godot/fonts の部分集合）に
全部入っているかを見る。足りない字は別の字体で描かれて浮く。足りなければ godot/fonts/make_subset.py を回し直す。
  python3 godot/check/glyph_check.py   → GLYPH_OK、または足りない字の一覧と GLYPH_MISSING"""
import re, glob, os, sys
from fontTools.ttLib import TTFont
G = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = ''.join(open(p, encoding='utf-8').read() for p in sorted(glob.glob(G + '/scripts/*.gd')))
chars = set(''.join(re.findall(r'"([^"]*)"', src)))
for p in [G + '/lang/text.csv'] + sorted(glob.glob(G + '/story/*.txt')):
    if os.path.exists(p): chars |= set(open(p, encoding='utf-8').read())
chars = {c for c in chars if c > ' ' and ord(c) > 0x2FF and c not in '\u200b\ufeff＞｜'}   # ＞ と ｜ は台本の記号（画面に出ない）
bad = 0
for name in ['BIZUDMincho-Bold.ttf', 'ShipporiMinchoB1-SemiBold.ttf', 'ShipporiMinchoB1-Medium.ttf']:
    cmap = TTFont(f'{G}/fonts/{name}').getBestCmap()
    miss = sorted(c for c in chars if ord(c) not in cmap)
    if miss: bad += len(miss); print(f'{name}: 足りない字 {len(miss)}：' + ''.join(miss))
print('GLYPH_MISSING' if bad else 'GLYPH_OK')
sys.exit(1 if bad else 0)
