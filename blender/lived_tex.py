"""段階2: the owner's handwriting (ユーザー許可 2026-11-04「カレンダーや帳面に手書き風の文字」).
python3 blender/lived_tex.py  ->  assets/tex/lived_calendar.png, assets/tex/lived_ledger.png
The calendar is a November page: the 15th circled in red with 「解禁」 (the opening of the hunting season), his ×s
crossing off the days, stopping a few days after it. No year is printed (企画書: the year is never shown); the
weekdays are those of a November around 2020 (Sunday-first, as Japanese wall calendars are)."""
import os, sys, math, random, calendar
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = f'{P.ASSETS}/tex'
FD = '/usr/share/fonts/opentype/noto'
def font(w, size):
    for i in range(10):
        try:
            f = ImageFont.truetype(f'{FD}/NotoSansCJK-{w}.ttc', size, index=i)
        except OSError: break
        if 'JP' in f.getname()[0]: return f
    return ImageFont.truetype(f'{FD}/NotoSansCJK-{w}.ttc', size)

def hand(size):   # the handwriting face (assets/fonts, SIL OFL; already used for 桐生's storyboard)
    return ImageFont.truetype(f'{P.ASSETS}/fonts/Yomogi-Regular.ttf', size)

R = random.Random(7)
LAST_X = 18          # his last ×: three days after the opening
HOLI = {3, 4, 23}    # 文化の日, its substitute holiday, 勤労感謝の日 (that year's November)

def jline(d, p, q, col, w, n=6, j=1.6):
    """A hand-drawn stroke: a slightly wavering line that thins at its ends."""
    pts = []
    for k in range(n + 1):
        t = k / n
        pts.append((p[0] + (q[0] - p[0]) * t + R.uniform(-j, j), p[1] + (q[1] - p[1]) * t + R.uniform(-j, j)))
    for k in range(n):
        ww = max(1, int(w * (.6 + .4 * math.sin(math.pi * (k + .5) / n))))
        d.line([pts[k], pts[k + 1]], fill=col, width=ww)

def hand_text(img, xy, s, f, col, rot=-4, jit=3, sw=0):
    """Text written by hand: each character a little off its line, size and angle, then the ink's soft edge."""
    x, y = xy
    for ch in s:
        g = Image.new('RGBA', (f.size * 2, f.size * 2), (0, 0, 0, 0))
        ImageDraw.Draw(g).text((f.size * .5, f.size * .35), ch, font=f, fill=col, stroke_width=sw, stroke_fill=col)
        sc = R.uniform(.92, 1.08)
        g = g.resize((int(g.width * sc), int(g.height * R.uniform(.9, 1.05))), Image.LANCZOS)
        g = g.transform(g.size, Image.AFFINE, (1, R.uniform(-.12, .05), 0, 0, 1, 0), Image.BICUBIC)   # a slant
        g = g.rotate(rot + R.uniform(-5, 5), Image.BICUBIC).filter(ImageFilter.GaussianBlur(.7))
        img.alpha_composite(g, (int(x - f.size * .5), int(y + R.uniform(-jit, jit) - f.size * .35)))
        x += f.getlength(ch) * R.uniform(.95, 1.05) + f.size * .04

def paper(w, h, base):
    im = Image.new('RGBA', (w, h), base)
    px = im.load()
    for yy in range(0, h, 2):
        for xx in range(0, w, 2):
            v = R.randint(-5, 4)
            c = tuple(max(0, min(255, base[i] + v)) for i in range(3)) + (255,)
            px[xx, yy] = c
    return im.filter(ImageFilter.GaussianBlur(.8))

def calendar_page():
    W, H = 768, 1152
    im = paper(W, H, (236, 232, 222, 255)); d = ImageDraw.Draw(im)
    # the picture half: a plain print of autumn hills (a free calendar from a shop in the valley; no name on it)
    sky = (196, 206, 206); d.rectangle((0, 0, W, 440), fill=sky)
    for k, (col, base, amp) in enumerate((((150, 150, 120), 250, 60), ((128, 96, 58), 305, 50), ((92, 72, 44), 365, 36))):
        pts = [(0, 440)]
        for xx in range(0, W + 16, 16):
            pts.append((xx, base - amp * (.6 * math.sin(xx / 140 + k * 1.7) + .4 * math.sin(xx / 53 + k))))
        pts.append((W, 440)); d.polygon(pts, fill=col)
    for xx in range(-10, W, 23):   # the cedar plantation on the near slope
        yb = 395 + 18 * math.sin(xx / 90) + R.uniform(-6, 6); hh = R.uniform(40, 62)
        d.polygon([(xx, yb), (xx + 10, yb - hh), (xx + 20, yb)], fill=(52, 60, 44))
    d.rectangle((0, 405, W, 440), fill=(70, 58, 38))
    im.paste(im.crop((0, 0, W, 440)).filter(ImageFilter.GaussianBlur(1.2)), (0, 0))
    d = ImageDraw.Draw(im)
    d.text((48, 452), '11', font=font('Bold', 120), fill=(40, 38, 36))
    d.text((210, 502), 'NOVEMBER', font=font('Medium', 40), fill=(80, 76, 70))
    d.text((210, 550), '霜月', font=font('Medium', 34), fill=(80, 76, 70))
    # the grid, Sunday first
    x0, y0, cw, ch = 34, 630, 100, 96
    hf = font('Medium', 26); nf = font('Medium', 40)
    for i, s in enumerate('日月火水木金土'):
        col = (176, 40, 34) if i == 0 else (40, 70, 140) if i == 6 else (60, 58, 54)
        d.text((x0 + i * cw + 36, y0 - 6), s, font=hf, fill=col)
    weeks = calendar.Calendar(firstweekday=6).monthdayscalendar(2019, 11)
    cells = {}
    for r, wk in enumerate(weeks):
        for i, n in enumerate(wk):
            cx, cy = x0 + i * cw, y0 + 32 + r * ch
            d.line((cx, cy, cx + cw, cy), fill=(170, 165, 155), width=1)
            if not n: continue
            col = (176, 40, 34) if i == 0 or n in HOLI else (40, 70, 140) if i == 6 else (50, 48, 44)
            d.text((cx + 12, cy + 4), str(n), font=nf, fill=col); cells[n] = (cx, cy)
    # his hand: ×s in pencil-black felt pen on each day gone, the 15th circled in red
    ink = Image.new('RGBA', (W, H), (0, 0, 0, 0)); di = ImageDraw.Draw(ink)
    for n in range(1, LAST_X + 1):
        cx, cy = cells[n]; m = 16 + R.uniform(-3, 3)
        jline(di, (cx + m, cy + m), (cx + cw - m, cy + ch - m), (30, 30, 34, 240), 10)
        jline(di, (cx + cw - m + R.uniform(-4, 4), cy + m), (cx + m, cy + ch - m + R.uniform(-4, 4)), (30, 30, 34, 240), 10)
    cx, cy = cells[15]; ccx, ccy = cx + 34, cy + 30
    pts = [(ccx + (38 + R.uniform(-2, 2)) * math.cos(a), ccy + (30 + R.uniform(-2, 2)) * math.sin(a))
           for a in [math.radians(-40 + k * 13) for k in range(31)]]   # a little more than once round, as a pen does
    for k in range(len(pts) - 1): di.line([pts[k], pts[k + 1]], fill=(200, 30, 26, 245), width=11)
    ink = ink.filter(ImageFilter.GaussianBlur(.8)); im.alpha_composite(ink)
    hand_text(im, (cx + 12, cy + 58), '解禁', hand(38), (200, 30, 26, 250), rot=-6, jit=2, sw=3)
    # a nail hole and the faint curl of a page that hung for a season
    d = ImageDraw.Draw(im); d.ellipse((W / 2 - 7, 10, W / 2 + 7, 24), fill=(70, 66, 60))
    im.convert('RGB').save(f'{OUT}/lived_calendar.png')

def ledger_page():
    """Two facing pages of his ledger: ruled lines, his dates and catches in ballpoint. The last line is in November."""
    W, H = 1024, 768
    im = paper(W, H, (228, 222, 204, 255)); d = ImageDraw.Draw(im)
    for yy in range(70, H - 30, 44):
        d.line((30, yy, W / 2 - 24, yy), fill=(150, 170, 190), width=2); d.line((W / 2 + 24, yy, W - 30, yy), fill=(150, 170, 190), width=2)
    d.line((W / 2, 0, W / 2, H), fill=(170, 160, 140), width=3)
    for xx in (110, W / 2 + 104): d.line((xx, 40, xx, H - 20), fill=(200, 120, 120), width=2)
    f = hand(30); pen = (30, 40, 90, 230)
    rows = [('10/2', '罠 見回り　異常なし'), ('10/9', '罠 見回り　沢の上 足跡'), ('10/16', '罠 シカ 雌 1'),
            ('10/23', '罠 見回り'), ('10/30', '罠 イノシシ 1　山田さん'), ('11/6', '罠 見回り　異常なし'),
            ('11/10', '猟友会 寄合'), ('11/15', '解禁　キジ 雄 1'), ('11/16', 'シカ 雄 四尖'), ('11/17', '奥の沢')]
    for i, (dt, s) in enumerate(rows):
        x0 = 38 if i < 7 else W / 2 + 30; yy = 34 + (i if i < 7 else i - 7) * 88
        hand_text(im, (x0, yy), dt, hand(25), pen, rot=-2, jit=2, sw=1)
        hand_text(im, (x0 + (92 if i < 7 else 100), yy), s, f, pen, rot=-2, jit=2, sw=1)
    im.convert('RGB').save(f'{OUT}/lived_ledger.png')

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    calendar_page(); ledger_page(); print('LIVED_TEX_DONE')
