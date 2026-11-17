# concept frames for the third interview: the room goes flat into the visual-novel type, made of the same paper and inks
import sys, numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
sys.path.insert(0, '/home/claude/work/iv')
from riso import print_frame, dots, PAPER, INK_A, INK_B
import os; D = os.path.dirname(os.path.abspath(__file__)) + '/'; F = os.path.join(D, '..', '..', '..', 'godot', 'fonts') + '/'
W, H = 1920, 1080; k = 1.0
MIS = (-3, 2)
def font(name, size): return ImageFont.truetype(F + name, size)
SHIP = 'ShipporiMinchoB1-SemiBold.ttf'; SHIPM = 'ShipporiMinchoB1-Medium.ttf'; BIZ = 'BIZUDMincho-Bold.ttf'; DOT = 'DotGothic16-Regular.ttf'

class Sheet:
    """an RGB print plus two plate masks we can keep inking into"""
    def __init__(self, img): self.rgb = np.asarray(img.convert('RGB')).astype(np.float32) / 255
    def paper(self, box, seed=3):
        x0, y0, x1, y1 = box; x0, y0 = max(x0, 0), max(y0, 0); x1, y1 = min(x1, W), min(y1, H)
        rng = np.random.default_rng(seed)
        self.rgb[y0:y1, x0:x1] = PAPER * (0.975 + 0.025 * rng.random((y1-y0, x1-x0, 1)))
    def ink(self, mask, plate, density=0.95):
        m = np.asarray(mask).astype(np.float32) / 255
        if plate == 'b': m = np.roll(np.roll(m, MIS[1], 0), MIS[0], 1)
        ink = INK_A if plate == 'a' else INK_B
        self.rgb *= 1 - (m * density)[..., None] * (1 - ink)
    def tint(self, mask, plate, cover):
        m = np.asarray(mask).astype(np.float32) / 255
        off = MIS if plate == 'b' else (0, 0)
        d = dots(H, W, 15 if plate == 'a' else 75, 3.6 * (1.05 if plate == 'b' else 1), off)
        self.ink(Image.fromarray(((m > 0.5) & ((1 - d) < cover)).astype(np.uint8) * 255), plate)
    def img(self): return Image.fromarray((np.clip(self.rgb, 0, 1) * 255).astype(np.uint8))

def mask(): return Image.new('L', (W, H), 0)
def text_mask(xy, s, f, anchor='la', sx=1.0):
    m = mask(); d = ImageDraw.Draw(m)
    if sx == 1.0: d.text(xy, s, font=f, fill=255, anchor=anchor); return m
    # long body (長体): draw wide then squeeze horizontally
    bb = d.textbbox((0, 0), s, font=f, anchor='lt'); tw, th = bb[2] + 4, bb[3] + 8
    t = Image.new('L', (tw, th), 0); ImageDraw.Draw(t).text((0, 0), s, font=f, fill=255, anchor='lt')
    t = t.resize((max(1, int(tw * sx)), th), Image.LANCZOS); m.paste(t, xy); return m
def teal_text(sh, xy, s, f, anchor='la', sx=1.0):
    m = text_mask(xy, s, f, anchor, sx); sh.ink(m, 'a'); sh.ink(m, 'b')
def blue_text(sh, xy, s, f, anchor='la', sx=1.0):
    sh.ink(text_mask(xy, s, f, anchor, sx), 'a')
def strike(sh, x0, x1, y, plate='a', gap=7, w=2):
    m = mask(); d = ImageDraw.Draw(m)
    d.line((x0, y - gap // 2, x1, y - gap // 2), fill=255, width=w); d.line((x0, y + gap // 2, x1, y + gap // 2), fill=255, width=w)
    sh.ink(m, plate)
def rect_mask(box):
    m = mask(); ImageDraw.Draw(m).rectangle(box, fill=255); return m
def card(sh, box, shadow=(8, 10)):
    # a sheet of paper laid on top: a flat blue tint as its shadow, square corners
    x0, y0, x1, y1 = box
    sh.tint(rect_mask((x0 + shadow[0], y0 + shadow[1], x1 + shadow[0], y1 + shadow[1])), 'a', 0.38)
    sh.paper(box)

def label(img, s):
    d = ImageDraw.Draw(img); f = font(BIZ, 30)
    bb = d.textbbox((14, 8), s, font=f); d.rectangle((0, 0, bb[2] + 14, bb[3] + 12), fill=(250, 248, 242))
    d.text((14, 8), s, font=f, fill=(20, 20, 20))
    return img

def person_cutout():
    p = Image.open(D + 'full_f.png').convert('RGBA')
    a = p.split()[3]
    pr = print_frame(Image.alpha_composite(Image.new('RGBA', p.size, (240, 236, 224, 255)), p).convert('RGB'), 1.0)
    margin = a.filter(ImageFilter.MaxFilter(23))
    return pr, a, margin

def window(sh, lines, name='聞き手', load=True, wait=True):
    y0 = 800
    card(sh, (0, y0, W, H + 20), shadow=(0, -10))
    # name tab, pasted on the strip like a cut label
    card(sh, (150, y0 - 46, 150 + 220, y0 + 8), shadow=(6, 0))
    teal_text(sh, (150 + 110, y0 - 19), name, font(SHIP, 30), 'mm')
    # ruled like the transcript form: one blue hairline under each line
    f = font(BIZ, 32); y = y0 + 52
    for (who, s, struck) in lines:
        if who: blue_text(sh, (180, y + 4), who, font(BIZ, 23), 'ls')
        x = 290
        (blue_text if struck else teal_text)(sh, (x, y), s, f, 'ls')
        if struck:
            tw = ImageDraw.Draw(mask()).textlength(s, font=f); strike(sh, x - 4, x + tw + 4, y - 11)
        y += 58
    if wait:
        tw = ImageDraw.Draw(mask()).textlength(lines[-1][1], font=f)
        m = mask(); xx, yy = 290 + tw + 22, y - 58 - 10
        ImageDraw.Draw(m).polygon([(xx, yy - 8), (xx + 18, yy - 8), (xx + 9, yy + 6)], fill=255); sh.ink(m, 'a')
    if load:
        blue_text(sh, (W - 120, H - 52), 'ロード', font(SHIP, 30), 'rs')
        m = mask(); ImageDraw.Draw(m).line((W - 236, H - 44, W - 120, H - 44), fill=255, width=2); sh.ink(m, 'a')

# ---- frame 2: the room has gone flat
bg = Image.open(D + 'full_c3.png').convert('RGB')
sh = Sheet(print_frame(bg, 1.0))
pr, a, margin = person_cutout()
sc_ = 0.8
pr = pr.resize((int(pr.width * sc_), int(pr.height * sc_)), Image.LANCZOS)
a = a.resize(pr.size, Image.LANCZOS); margin = margin.resize(pr.size, Image.LANCZOS)
# cut-out: paper margin + blue tint shadow, then the printed figure
px, py = (W - pr.width) // 2, 1000 - int(pr.height * 0.80)
mm = Image.new('L', (W, H), 0); mm.paste(margin, (px, py))
sh_m = Image.new('L', (W, H), 0); sh_m.paste(margin, (px + 14, py + 12))
sh.tint(sh_m, 'a', 0.38)
mmn = np.asarray(mm) > 128
sh.rgb[mmn] = PAPER
am_full = Image.new('L', (W, H), 0); am_full.paste(a, (px, py))
sh.tint(am_full, 'a', 0.16)
edge = Image.new('L', (W, H), 0); edge.paste(a.filter(ImageFilter.FIND_EDGES).point(lambda v: 255 if v > 40 else 0).filter(ImageFilter.MaxFilter(3)), (px, py))
sh.ink(edge, 'a')
cx = W // 2
teal_text(sh, (cx, py + int(pr.height * 0.14)), '立ち絵', font(SHIP, 44), 'mm')
blue_text(sh, (cx, py + int(pr.height * 0.14) + 56), '（画像生成で描く）', font(BIZ, 26), 'mm')
window(sh, [('澪', '勝手口の前で、倒れていました。', True), ('澪', '廊下に、倒れていました。', True), ('', 'さっきも、そうおっしゃいましたね。', False)])
im = sh.img(); im.save(D + 'frame2_raw.png')
label(im, '案：証言 三、部屋が平たくなった画面（立ち絵の所は空けてある）').save(D + 'frame2.png')

# ---- frame 3: the load list, every record at the same second
sh = Sheet(Image.new('RGB', (W, H), tuple(int(c * 255) for c in PAPER)))
sh.paper((0, 0, W, H), seed=9)
teal_text(sh, (120, 70), 'ロード', font(SHIPM, 84), 'lt', sx=0.85)
blue_text(sh, (122, 190), '証言 三　書き起こし', font(SHIP, 30), 'lt')
thumb = print_frame(Image.open(D + 'full_c.png').convert('RGB').resize((240, 135), Image.LANCZOS), 1.0, cell=2.2)
said = ['勝手口の前で、倒れていました。', '勝手口は、閉めてありました。', '勝手口から、雨が入っていました。', '廊下に、倒れていました。',
        '勝手口の、', '勝手口の', '廊下に、倒れていました。', '勝手口の', '', '']
for i in range(10):
    col, row = i % 2, i // 2
    x = 120 + col * 860; y = 270 + row * 158
    m = rect_mask((x, y + 140, x + 800, y + 141)); sh.ink(m, 'a')
    blue_text(sh, (x, y + 10), f'{i + 1:02d}', font(SHIP, 30), 'lt')
    if said[i] or i == 8:
        th = thumb if i != 8 else thumb
        sh.rgb[y + 2:y + 2 + 135, x + 70:x + 70 + 240] = np.asarray(th).astype(np.float32) / 255
        teal_text(sh, (x + 340, y + 12), '01:14:08', font(DOT, 32), 'lt')
        if said[i]:
            f = font(BIZ, 26); blue_text(sh, (x + 340, y + 90), said[i], f, 'ls')
            tw = ImageDraw.Draw(mask()).textlength(said[i], font=f); strike(sh, x + 336, x + 340 + tw + 4, y + 81)
    else:
        blue_text(sh, (x + 340, y + 12), '――', font(BIZ, 30), 'lt')
# the last slot is the one being written over
x, y = 120 + 0 * 860, 270 + 4 * 158
sh.tint(rect_mask((x - 16, y - 6, x + 816, y + 146)), 'a', 0.30)
blue_text(sh, (x + 340, y + 70), '上書きしますか？', font(SHIP, 40), 'lt')
im = sh.img(); im.save(D + 'frame3_raw.png')
label(im, '案：証言 三、ロードの一覧（どの記録も同じ秒。最後は「上書きしますか？」）').save(D + 'frame3.png')
print('== DONE')
