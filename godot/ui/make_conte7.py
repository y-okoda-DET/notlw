"""第7章「去年の夏」：陽太の手描きの絵コンテ（Tab）。桐生の C-12（make_conte.py）と同じ紙と同じ青いインクで、手は別の人。
桐生は画面を写して清書する人、陽太は丸と棒で段取りだけ描く人。字は Zen Kurenaido（assets/fonts、SIL OFL 1.1）。
    python3 godot/ui/make_conte7.py
出す物（godot/ui/）：重ねて見せる4枚（ch7.gd _conte）
  conte7_base.png   紙、題、コマ1「窓を叩く」とコマ2「扉を叩く男」、コマ3の場所は空き
  conte7_ok1.png    コマ1に済みの丸（透明の上に線だけ）
  conte7_ok2.png    コマ2に済みの丸
  conte7_add.png    2時に描き足すコマ3「裏の窓」（急いだ線。枠も手で引く）
"""
import os, math
import numpy as np, cv2
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.join(HERE, '..', '..')
SW, SH = 2000, 1414
PEN = (0, 92, 156)
F = lambda s: ImageFont.truetype(f'{REPO}/assets/fonts/ZenKurenaido-Regular.ttf', s)

class Hand:
    """a pen that wobbles: every stroke is a polyline with a slow drift and a quick shake"""
    def __init__(self, im, seed, shake=1.3, width=5):
        self.d = ImageDraw.Draw(im); self.rng = np.random.default_rng(seed); self.shake = shake; self.w = width
    def line(self, p0, p1, w=None, over=0.0):
        n = max(6, int(math.dist(p0, p1) / 22)); pts = []
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        bow = self.rng.normal(0, 1) * math.dist(p0, p1) * .012
        for i in range(n + 1):
            t = -over + (1 + 2 * over) * i / n
            k = math.sin(max(0.0, min(1.0, t)) * math.pi) * bow
            L = max(1e-6, math.hypot(dx, dy))
            pts.append((p0[0] + dx * t - dy / L * k + self.rng.normal(0, self.shake), p0[1] + dy * t + dx / L * k + self.rng.normal(0, self.shake)))
        self.d.line(pts, fill=PEN + (255,), width=w or self.w, joint='curve')
    def box(self, x, y, w, h, over=.02, twice=False):
        for a, b in (((x, y), (x + w, y)), ((x + w, y), (x + w, y + h)), ((x + w, y + h), (x, y + h)), ((x, y + h), (x, y))):
            self.line(a, b, over=over)
            if twice: self.line((a[0] + self.rng.normal(0, 4), a[1] + self.rng.normal(0, 4)), (b[0] + self.rng.normal(0, 4), b[1] + self.rng.normal(0, 4)), w=max(2, self.w - 2), over=over)
    def ring(self, cx, cy, rx, ry, turns=1.15, w=None, start=None):
        a0 = self.rng.uniform(0, 6.28) if start is None else start; n = 60; pts = []
        for i in range(int(n * turns) + 1):
            a = a0 + 6.2832 * i / n; g = 1 + .05 * math.sin(a * 2 + 1) + .035 * i / n
            pts.append((cx + rx * g * math.cos(a) + self.rng.normal(0, self.shake), cy + ry * g * math.sin(a) + self.rng.normal(0, self.shake)))
        self.d.line(pts, fill=PEN + (255,), width=w or self.w, joint='curve')
    def text(self, xy, s, size, ang=0.0):
        if ang == 0.0: self.d.text(xy, s, font=F(size), fill=PEN + (255,)); return
        f = F(size); bb = f.getbbox(s); t = Image.new('RGBA', (bb[2] + 20, bb[3] + 20), (0, 0, 0, 0))
        ImageDraw.Draw(t).text((10, 10), s, font=f, fill=PEN + (255,)); t = t.rotate(ang, expand=True, resample=Image.BICUBIC)
        self.d._image.alpha_composite(t, (int(xy[0]), int(xy[1])))
    def man(self, x, y, s, arms='up', face=None):
        """a stick man, his feet at (x, y), s = his height"""
        hd = s * .13
        self.ring(x, y - s + hd, hd, hd * 1.08, 1.08)
        self.line((x, y - s + hd * 2.1), (x + s * .02, y - s * .42))
        self.line((x + s * .02, y - s * .42), (x - s * .12, y)); self.line((x + s * .02, y - s * .42), (x + s * .15, y))
        sh = (x, y - s * .72)
        if arms == 'up':
            self.line(sh, (x - s * .2, y - s * .86)); self.line((x - s * .2, y - s * .86), (x - s * .3, y - s * .98))
            self.line(sh, (x + s * .22, y - s * .84)); self.line((x + s * .22, y - s * .84), (x + s * .34, y - s * .95))
        elif arms == 'knock':
            self.line(sh, (x + s * .2, y - s * .66)); self.line((x + s * .2, y - s * .66), (x + s * .33, y - s * .82))
            self.line(sh, (x - s * .1, y - s * .5))
        else:
            self.line(sh, (x - s * .16, y - s * .48)); self.line(sh, (x + s * .17, y - s * .5))
        if face == 'zombie':
            ex = hd * .38
            for sx in (-1, 1):
                self.line((x + sx * ex - 6, y - s + hd - 8), (x + sx * ex + 6, y - s + hd + 4), w=3); self.line((x + sx * ex + 6, y - s + hd - 8), (x + sx * ex - 6, y - s + hd + 4), w=3)
            self.line((x - hd * .4, y - s + hd * 1.5), (x + hd * .4, y - s + hd * 1.45), w=3)
        elif face == 'grin':
            for sx in (-1, 1): self.ring(x + sx * hd * .38, y - s + hd * .8, 3, 3, 1.0, w=3)
            pts = [(x - hd * .5 + hd * i / 6, y - s + hd * 1.35 + math.sin(i / 6 * math.pi) * hd * .3) for i in range(7)]
            self.d.line(pts, fill=PEN + (255,), width=3)
    def palm(self, x, y, s, flip=1):
        """a hand flat on glass: a blob and five strokes"""
        self.ring(x, y, s * .42, s * .46, 1.1)
        for i, a in enumerate((-62, -30, -4, 22, 62)):
            L = s * (.62, .86, .95, .84, .6)[i]; r = math.radians(a * flip - 90)
            bx, by = x + math.cos(r) * s * .38, y + math.sin(r) * s * .4
            self.line((bx, by), (bx + math.cos(r) * L * .7, by + math.sin(r) * L * .7), w=self.w + 2)

def paper():
    rng = np.random.default_rng(3)
    base = np.ones((SH, SW, 3), np.float32) * np.array([241, 236, 223], np.float32)
    fib = cv2.GaussianBlur(rng.normal(0, 1, (SH, SW)).astype(np.float32), (0, 0), 1.2) * 2.5 + cv2.GaussianBlur(rng.normal(0, 1, (SH, SW)).astype(np.float32), (0, 0), 30) * 6
    base += fib[..., None]
    # folded in four and carried in a pocket: two creases
    for x in (SW // 2,):
        base[:, x - 2:x + 2] -= 9; base[:, x + 2:x + 6] += 4
    for y in (SH // 2,):
        base[y - 2:y + 2, :] -= 8; base[y + 2:y + 6, :] += 4
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).convert('RGBA')

PX = (90, 720, 1350); PY = 290; PW = 560; PH = 440

def base():
    im = paper(); h = Hand(im, 71)
    h.text((90, 62), '短編　いたずらの段取り（仮）', 84)
    h.text((1560, 92), 'ようた', 60)
    h.line((90, 180), (1250, 186), w=4)
    # 1: the window, from inside the room: two palms, his face a little under them
    x, y = PX[0], PY
    h.box(x, y, PW, PH, twice=True)
    h.text((x - 6, y - 78), '１', 70)
    h.box(x + 60, y + 50, PW - 120, PH - 120)                      # the window
    h.line((x + PW / 2, y + 50), (x + PW / 2, y + PH - 70), w=4); h.line((x + 60, y + 200), (x + PW - 60, y + 203), w=4)
    h.palm(x + 175, y + 190, 84, 1); h.palm(x + 385, y + 184, 84, -1)
    h.ring(x + 280, y + 300, 46, 52, 1.1)                          # the face, lower than the hands
    for sx in (-1, 1): h.line((x + 280 + sx * 18 - 7, y + 288), (x + 280 + sx * 18 + 7, y + 296), w=3)
    h.line((x + 262, y + 322), (x + 298, y + 320), w=3)
    for i in range(6): h.line((x + 80 + i * 10, y + PH - 56), (x + 64 + i * 10, y + PH - 22), w=3)   # the floor
    h.text((x, y + PH + 26), '窓を叩く。', 64)
    h.text((x, y + PH + 112), '中から見て、いちばん', 46); h.text((x, y + PH + 168), '怖い高さで（目より下）', 46)
    h.text((x + 380, y + 46), 'バン！', 56, 12)
    # 2: the door, from outside: the man knocking, his words
    x = PX[1]
    h.box(x, y, PW, PH, twice=True)
    h.text((x - 6, y - 78), '２', 70)
    h.box(x + 285, y + 40, 200, PH - 70)                           # the door
    h.ring(x + 315, y + 240, 8, 8, 1.2, w=4)                       # its knob
    h.line((x + 30, y + PH - 30), (x + PW - 30, y + PH - 32), w=4)
    h.man(x + 160, y + PH - 34, 290, 'knock', 'zombie')
    for i in range(3): h.line((x + 252 + i * 4, y + 118 + i * 24), (x + 276 + i * 3, y + 111 + i * 24), w=3)   # knock, knock
    h.text((x, y + PH + 26), '扉を叩く男', 64)
    h.text((x, y + PH + 112), '「開けて、怪我した！」', 50)
    h.text((x, y + PH + 172), '……誰が開けるか', 46)
    h.line((x + 250, y + PH + 240), (x + 480, y + PH + 236), w=3)
    # 3: not yet
    x = PX[2]
    h.text((x - 6, y - 78), '３', 70)
    h.text((x, y + PH + 180), '（最後のカット）ナイショ', 46)
    # what he needs, down the sheet
    h.text((90, 1010), '・メイク 40分（血のり、ラテックス）', 46)
    h.text((90, 1074), '・撮るのは夏希（手持ち）', 46)
    h.text((90, 1138), '・澪には言わない', 46)
    h.text((90, SH - 150), '※ 本物の悲鳴がほしい。先に言わない！', 52)
    return im.filter(ImageFilter.GaussianBlur(.5))

def ok(i, seed):
    # done: a ring round the number and a tick, not over the drawing
    im = Image.new('RGBA', (SW, SH), (0, 0, 0, 0)); h = Hand(im, seed, shake=1.5, width=6)
    x, y = PX[i], PY
    h.ring(x + 28, y - 36, 50, 46, 1.25)
    h.line((x + 96, y - 44), (x + 122, y - 16), w=7); h.line((x + 122, y - 16), (x + 186, y - 96), w=7)
    return im.filter(ImageFilter.GaussianBlur(.5))

def add():
    # two o'clock, on the porch, the pen in a hand that hurts: quicker, the frame not closed
    im = Image.new('RGBA', (SW, SH), (0, 0, 0, 0)); h = Hand(im, 207, shake=2.6, width=7)
    x, y = PX[2], PY
    h.line((x + 330, y + PH + 212), (x + 560, y + PH + 200), w=6)   # ナイショ struck out
    h.line((x - 4, y + 6), (x + PW + 10, y - 6)); h.line((x + PW + 6, y - 8), (x + PW - 4, y + PH + 4))
    h.line((x + PW - 2, y + PH), (x + 40, y + PH + 10)); h.line((x + 2, y + PH - 40), (x - 6, y + 4))
    h.box(x + 250, y + 50, 250, 170)                               # the back window, lit
    h.line((x + 375, y + 50), (x + 372, y + 220), w=4)
    for i in range(5): h.line((x + 262 + i * 22, y + 236), (x + 250 + i * 22, y + 262), w=3)
    h.man(x + 120, y + PH - 20, 230, 'up', 'grin')
    h.line((x + 190, y + 330), (x + 300, y + 250), w=6); h.line((x + 300, y + 250), (x + 268, y + 256), w=6); h.line((x + 300, y + 250), (x + 292, y + 282), w=6)
    h.text((x, y + PH + 26), '裏の窓', 84)
    h.text((x, y + PH + 124), 'そう来るなら、こっちも', 46)
    return im.filter(ImageFilter.GaussianBlur(.5))

if __name__ == '__main__':
    base().convert('RGB').save(f'{HERE}/conte7_base.png')
    ok(0, 11).save(f'{HERE}/conte7_ok1.png'); ok(1, 12).save(f'{HERE}/conte7_ok2.png')
    a = add(); a.save(f'{HERE}/conte7_add.png')
    # a look at the whole sheet as it ends
    b = base(); b.alpha_composite(ok(0, 11)); b.alpha_composite(ok(1, 12)); b.alpha_composite(a)
    os.makedirs('/home/claude/work/conte7', exist_ok=True); b.convert('RGB').save('/home/claude/work/conte7/all.png')
    print('CONTE7', b.size)
