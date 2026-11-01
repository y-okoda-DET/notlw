"""The printing on the snack scan (s09), repainted as made-up products (no real names or package designs in the game).
Works on the top view from scan_relabel.py top; writes the edited view and the mask of what changed:
    python3 scan_snacks_edit.py <top.png> <edit.png> <mask.png>
Pixel places are in the 2048 top view of s09 (scan_prep.py ... shoes 2048 40000 .0015).
  almonds   : the teal/cream label -> a brick-red label 「素焼きアーモンド」
  banana    : 'Banana chips', the rainbow maker's mark and '0g TRANS FAT' -> 'BANANA CHIPS' and 「みなみ果実」 with a sun
  caramel   : the red seals' circled character -> 「飴」
  cake      : the brushed name in the gold circle and the small marks -> 「栗どら」"""
import sys, math, numpy as np, cv2
from PIL import Image, ImageDraw, ImageFont
top, out, mout = sys.argv[1:4]
im = Image.open(top).convert('RGBA'); A = np.array(im)
rgb = A[:, :, :3].copy(); H, W = rgb.shape[:2]
mask = np.zeros((H, W), np.uint8)
SERIF = '/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc'
SANS = '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'
def font(path, px): return ImageFont.truetype(path, px, index=0)

def inpaint(m, r=9):
    global rgb
    rgb = cv2.inpaint(rgb, m, r, cv2.INPAINT_TELEA); mask[m > 0] = 255

def stamp(img_rgba, cx, cy, ang):
    """paste a drawn RGBA patch rotated by ang (deg, counter-clockwise on screen) centred at cx, cy"""
    global rgb
    p = img_rgba.rotate(ang, resample=Image.BICUBIC, expand=True)
    x0, y0 = int(cx - p.width / 2), int(cy - p.height / 2)
    base = Image.fromarray(rgb); base.paste(p, (x0, y0), p); rgb = np.array(base)
    al = np.array(p)[:, :, 3]
    sub = mask[y0:y0 + p.height, x0:x0 + p.width]; sub[al > 20] = 255

def text_patch(lines, fnt, fill, pad=4, spacing=0, vertical=False):
    d0 = ImageDraw.Draw(Image.new('RGBA', (8, 8)))
    if vertical:   # one column, top to bottom
        ch = list(lines[0]); size = fnt.size
        im2 = Image.new('RGBA', (size + 2 * pad, len(ch) * (size + spacing) + 2 * pad), (0, 0, 0, 0)); d = ImageDraw.Draw(im2)
        for i, c in enumerate(ch): d.text((pad, pad + i * (size + spacing)), c, font=fnt, fill=fill)
        return im2
    bb = [d0.textbbox((0, 0), l, font=fnt) for l in lines]
    w = max(b[2] - b[0] for b in bb); h = sum(b[3] - b[1] + spacing for b in bb)
    im2 = Image.new('RGBA', (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0)); d = ImageDraw.Draw(im2); y = pad
    for l, b in zip(lines, bb):
        d.text(((w - (b[2] - b[0])) / 2 + pad - b[0], y - b[1]), l, font=fnt, fill=fill); y += b[3] - b[1] + spacing
    return im2

hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)

# ---- almonds: the label is a rectangle of teal and cream; replace it whole
box = (300, 1250, 850, 1660)
sub = hsv[box[1]:box[3], box[0]:box[2]].astype(int); subr = rgb[box[1]:box[3], box[0]:box[2]].astype(int)
teal = (sub[:, :, 0] > 80) & (sub[:, :, 0] < 105) & (sub[:, :, 1] > 90) & (sub[:, :, 2] > 40)
cream = (subr[:, :, 0] > 170) & (subr[:, :, 0] - subr[:, :, 2] > 12) & (subr[:, :, 0] - subr[:, :, 2] < 60) & (sub[:, :, 1] < 90)
lab = ((teal | cream) * 255).astype(np.uint8)
lab = cv2.morphologyEx(lab, cv2.MORPH_CLOSE, np.ones((15, 15), np.uint8))
n, cc, st, _ = cv2.connectedComponentsWithStats(lab)
big = 1 + np.argmax(st[1:, cv2.CC_STAT_AREA])
ys, xs = np.nonzero(cc == big)
(rcx, rcy), (rw, rh), rang = cv2.minAreaRect(np.c_[xs + box[0], ys + box[1]].astype(np.float32))
if rw < rh: rw, rh = rh, rw; rang += 90
print('almond label', round(rcx), round(rcy), round(rw), round(rh), round(rang, 1))
lw, lh = int(rw) + 6, int(rh) + 6
L = Image.new('RGBA', (lw, lh), (142, 38, 30, 255)); d = ImageDraw.Draw(L)
d.rectangle((0, int(lh * .30), lw, int(lh * .74)), fill=(238, 226, 200, 255))
d.rectangle((0, int(lh * .30) - 4, lw, int(lh * .30) - 1), fill=(205, 160, 70, 255))
d.rectangle((0, int(lh * .74) + 1, lw, int(lh * .74) + 4), fill=(205, 160, 70, 255))
t = text_patch(['素焼きアーモンド'], font(SERIF, int(min(lh * .30, lw * .8 / 8))), (120, 30, 24, 255)); L.paste(t, ((lw - t.width) // 2, int(lh * .52) - t.height // 2), t)
t = text_patch(['食塩不使用　徳用二〇〇ｇ'], font(SANS, int(min(lh * .12, lw * .8 / 12))), (240, 228, 205, 255)); L.paste(t, ((lw - t.width) // 2, int(lh * .15) - t.height // 2), t)
t = text_patch(['ローストしたアーモンドだけ'], font(SANS, int(min(lh * .11, lw * .8 / 13))), (240, 228, 205, 255)); L.paste(t, ((lw - t.width) // 2, int(lh * .87) - t.height // 2), t)
# the old label reads upside down from this view (its 'NUTS' is nearer the bag's bottom edge): turn the new one the same way
stamp(L, rcx, rcy, -rang + 180)

# ---- banana chips: erase the white words, the maker's mark and the small badge on the dark/light green
def erase_box(x0, y0, x1, y1, keep_green=True, dil=7, lum=None):
    s = hsv[y0:y1, x0:x1].astype(int); r = rgb[y0:y1, x0:x1].astype(int)
    green = (s[:, :, 0] > 28) & (s[:, :, 0] < 80) & (s[:, :, 1] > 70)
    m = (~green).astype(np.uint8) * 255 if lum is None else ((r.mean(2) > lum) & (s[:, :, 1] < 80)).astype(np.uint8) * 255
    m = cv2.dilate(m, np.ones((dil, dil), np.uint8))
    full = np.zeros((H, W), np.uint8); full[y0:y1, x0:x1] = m
    full[A[:, :, 3] < 128] = 0
    inpaint(full, 11)
erase_box(1350 + 95, 700 + 110, 1350 + 430, 700 + 545, lum=105, dil=9)   # 'Banana chips' (white on dark green, shaded)
poly = np.array([(455, 205), (515, 290), (300, 565), (205, 500)]) + (1350, 700)   # rainbow mark + maker's name (on light green): the whole patch
pm = np.zeros((H, W), np.uint8); cv2.fillPoly(pm, [poly.astype(np.int32)], 255); pm[A[:, :, 3] < 128] = 0; inpaint(pm, 15)
erase_box(1560, 590, 1680, 780, lum=150)                               # '0g TRANS FAT'
hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
# the bag's words run down-left from 'B', the letters' tops face down-right: rotate -127 deg
t = text_patch(['BANANA', 'CHIPS'], font(SERIF, 54), (250, 246, 222, 255), spacing=6)
stamp(t, 1350 + 275, 700 + 270, -127)
# made-up maker: an orange sun and 「みなみ果実」
mk = Image.new('RGBA', (300, 110), (0, 0, 0, 0)); d = ImageDraw.Draw(mk)
d.ellipse((6, 18, 82, 94), fill=(236, 126, 30, 255))
for k in range(12):
    a = k / 12 * math.tau; d.line((44 + math.cos(a) * 44, 56 + math.sin(a) * 44, 44 + math.cos(a) * 54, 56 + math.sin(a) * 54), fill=(236, 126, 30, 255), width=5)
tt = text_patch(['みなみ果実'], font(SANS, 40), (24, 70, 30, 255)); mk.paste(tt, (100, 56 - tt.height // 2), tt)
stamp(mk, 1350 + 355, 700 + 385, -127)

# ---- caramel: the circled character on each red seal
for (cx, cy) in ((840, 865), (780, 1045)):
    yy, xx = np.ogrid[:H, :W]; m = (((xx - cx) ** 2 + (yy - cy) ** 2) < 36 ** 2).astype(np.uint8) * 255
    s = Image.new('RGBA', (80, 80), (0, 0, 0, 0)); d = ImageDraw.Draw(s)
    d.ellipse((2, 2, 78, 78), fill=(196, 38, 40, 255)); d.ellipse((8, 8, 72, 72), outline=(246, 214, 170, 255), width=3)
    tt = text_patch(['飴'], font(SERIF, 42), (246, 214, 170, 255)); s.paste(tt, (40 - tt.width // 2, 38 - tt.height // 2), tt)
    stamp(s, cx, cy, 25)

# ---- cake: the brushed name inside the gold ring, the small marks round the edge
cx, cy = 1055, 1350
yy, xx = np.ogrid[:H, :W]
inside = (((xx - cx) ** 2 + (yy - cy) ** 2) < 74 ** 2)
r = rgb.astype(int); dark = (r.mean(2) < 175) & inside
m = cv2.dilate(dark.astype(np.uint8) * 255, np.ones((7, 7), np.uint8)); m[~inside] = 0; inpaint(m, 9)
for (x0, y0, x1, y1) in ((1175, 1200, 1245, 1290), (1190, 1355, 1245, 1460), (885, 1225, 940, 1300)):
    r = rgb.astype(int); dk = np.zeros((H, W), bool); dk[y0:y1, x0:x1] = (r[y0:y1, x0:x1].mean(2) < 185)
    m = cv2.dilate(dk.astype(np.uint8) * 255, np.ones((7, 7), np.uint8)); inpaint(m, 9)
t = text_patch(['栗どら'], font(SERIF, 40), (70, 58, 40, 255), vertical=True)
stamp(t, cx, cy, 180)

o = A.copy(); o[:, :, :3] = rgb
Image.fromarray(o).save(out)
Image.fromarray(cv2.dilate(mask, np.ones((5, 5), np.uint8))).save(mout)
print('EDIT_OK', out)
