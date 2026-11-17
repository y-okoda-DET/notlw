# 聞き手のテープ（MiniDV）のラベル：夏希の字で「上映用」（企画書：居間の空の箱と同じ字。桐生が 2時に知らずに上書きしたテープ）
# 書き方は blender/lived_tex.py の hand_text（Yomogi、SIL OFL、素材とアドオン.md 記載）と同じ。夏希のペンは「なつき」のラベルと同じ赤
import sys, random
import os; sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import paths as P, lived_tex as LT
from PIL import Image, ImageDraw
LT.R = random.Random(23)
W, H = 960, 520
im = LT.paper(W, H, (226, 222, 210, 255))
d = ImageDraw.Draw(im)
for k in range(3):   # ラベルに刷ってある薄い罫（メーカーの字は入れない）
    y = 300 + k * 70; d.line((60, y, W - 60, y), fill=(168, 176, 184, 255), width=3)
d.rectangle((0, 0, W, 40), fill=(150, 160, 170, 255))   # 上の帯（色だけ）
f = LT.hand(190)
# まっすぐに書く（ユーザー 2026-11-16「上映用の文字、傾かせたりしなくてOK」）：行の傾き・字ごとの回転と斜めを外し、ペンの揺れだけ残す
from PIL import ImageFilter
x = 150
for ch in '上映用':
    g = Image.new('RGBA', (f.size * 2, f.size * 2), (0, 0, 0, 0))
    ImageDraw.Draw(g).text((f.size * .5, f.size * .35), ch, font=f, fill=(170, 20, 20, 255), stroke_width=2, stroke_fill=(170, 20, 20, 255))
    g = g.filter(ImageFilter.GaussianBlur(.7)); im.alpha_composite(g, (int(x - f.size * .5), int(120 - f.size * .35)))
    x += f.getlength(ch) + f.size * .06
im.convert('RGB').save(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tex', 'tape_label.png')); print('ok')
