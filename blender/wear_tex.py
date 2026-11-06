"""使い込みの跡の画像（godot/assets/wear/*.png、RGBA）。Claude が作る（写真なし、ライセンスの問題なし）。
  python3 blender/wear_tex.py
色は汚れの色（茶色がかった灰）、濃さはアルファ。Godot の Decal が下の色に重ねる。wear.py が置き場所を決める。
画像の上が天井側、左右は壁に沿う向き（床と天井は u の向き）。"""
import os, math
import numpy as np
from PIL import Image, ImageFilter, ImageDraw
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot', 'assets', 'wear')
R = np.random.default_rng(57)

def noise(h, w, s, seed=None):
    r = np.random.default_rng(seed) if seed is not None else R
    a = Image.fromarray((r.random((h, w)) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(s))
    a = np.asarray(a, np.float32); return (a - a.mean()) / (a.std() + 1e-6)

def fbm(h, w, scales=(48, 16, 5, 1.5), weights=(1, .6, .35, .2)):
    return sum(wt * noise(h, w, s) for s, wt in zip(scales, weights)) / sum(weights)

def save(rgb, a, name):
    os.makedirs(OUT, exist_ok=True)
    h, w = a.shape
    im = np.zeros((h, w, 4), np.float32)
    im[..., :3] = np.asarray(rgb, np.float32)[None, None, :] if np.ndim(rgb) == 1 else rgb
    im[..., 3] = np.clip(a * GAIN, 0, .9)   # 試作57 の初めの濃さ（×1）は刷りでも刷りなしでも見えなかった
    Image.fromarray((np.clip(im, 0, 1) * 255).astype(np.uint8), 'RGBA').save(f'{OUT}/{name}.png'); print(name, w, h)

GRIME = (.13, .10, .08)
GAIN = 3.2   # 試作57 の ×2 でも刷りではほぼ見えなかった（直す前と後の画）

def skirt(i):
    # 2 m x .22 m: 1024 x 112 (about 5 px per cm). Bottom = the floor.
    W, H = 1024, 112
    y = np.arange(H)[:, None] / (H - 1)            # 0 top .. 1 floor
    n = fbm(H, W)
    edge = .55 + .1 * noise(1, W, 60)[0] + .02 * noise(1, W, 10)[0]   # the mop line: wavy, a third of the way up
    band = np.clip((y - edge[None, :]) / .25 + .25, 0, 1) ** 1.4
    a = .38 * band * (1 + .25 * fbm(H, W, (30, 8), (1, .4)))
    a += .12 * np.clip(y - .2, 0, 1) * np.clip(n, 0, None) * .8        # dust settling above the line
    img = Image.fromarray(np.zeros((H, W), np.uint8)); d = ImageDraw.Draw(img)
    r = np.random.default_rng(100 + i)
    for _ in range(r.integers(10, 18)):            # black scuffs: shoes, the vacuum, a chair pushed back
        x0 = r.uniform(0, W); yy = r.uniform(.45, .92) * H; L = r.uniform(8, 60)
        d.line([(x0, yy), (x0 + L, yy + r.uniform(-3, 3))], fill=int(r.uniform(120, 230)), width=int(r.integers(1, 4)))
    sc = np.asarray(img.filter(ImageFilter.GaussianBlur(.8)), np.float32) / 255
    a = np.maximum(a, sc * .7)
    a *= np.clip(np.minimum(np.arange(W) / 12, (W - 1 - np.arange(W)) / 12), 0, 1)[None, :]   # soft ends: pieces meet without a seam
    save(GRIME, a, f'skirt{i}')

def jamb():
    # (door + .3) x 2.1 m: 384 x 1024. The outer 15 % each side is the casing and the wall beside it.
    W, H = 384, 1024
    x = np.arange(W)[None, :] / (W - 1); y = np.arange(H)[:, None] / (H - 1)   # y 0 = 2.1 m, 1 = the floor
    side = np.maximum(np.clip(1 - x / .17, 0, 1), np.clip(1 - (1 - x) / .17, 0, 1)) ** .8
    hgt = 2.1 * (1 - y)
    hands = np.exp(-((hgt - 1.15) / .28) ** 2)     # where a hand goes to steady or to open
    n = fbm(H, W, (24, 8, 2.5), (1, .6, .3))
    a = side * (.08 + .42 * hands) * (1 + .5 * n)
    # a few prints: soft ovals with finger smears
    img = Image.fromarray(np.zeros((H, W), np.uint8)); d = ImageDraw.Draw(img); r = np.random.default_rng(3)
    for sx in (0, 1):
        for _ in range(4):
            cx = (r.uniform(.03, .13) if sx == 0 else r.uniform(.87, .97)) * W
            cy = (1 - r.uniform(1.0, 1.35) / 2.1) * H
            d.ellipse([cx - 14, cy - 20, cx + 14, cy + 20], fill=int(r.uniform(60, 130)))
            for k in range(4):
                fx = cx - 12 + k * 8; d.line([(fx, cy - 18), (fx + r.uniform(-4, 4), cy - 18 - r.uniform(14, 26))], fill=90, width=5)
    pr = np.asarray(img.filter(ImageFilter.GaussianBlur(3)), np.float32) / 255
    a = np.maximum(a, pr * .55 * side)
    save(GRIME, a, 'jamb')

def floor():
    # opening x 1.7 m across: 512 x 512, worn where feet go (the middle), the varnish gone grey-brown
    W = H = 512
    x = np.arange(W)[None, :] / (W - 1) - .5; y = np.arange(H)[:, None] / (H - 1) - .5
    r2 = (x / .38) ** 2 + (y / .5) ** 2
    n = fbm(H, W, (40, 12, 3), (1, .5, .3))
    a = .32 * np.clip(1 - r2, 0, 1) ** .9 * (1 + .45 * n)
    img = Image.fromarray(np.zeros((H, W), np.uint8)); d = ImageDraw.Draw(img); rr = np.random.default_rng(9)
    for _ in range(40):                            # fine scratches along the way through
        cx, cy = rr.uniform(.2, .8) * W, rr.uniform(.05, .95) * H; L = rr.uniform(15, 70); t = rr.normal(math.pi / 2, .25)
        d.line([(cx, cy), (cx + L * math.cos(t), cy + L * math.sin(t))], fill=int(rr.uniform(80, 200)), width=1)
    a = np.maximum(a, np.asarray(img, np.float32) / 255 * .35 * np.clip(1 - r2, 0, 1))
    save((.24, .2, .15), a, 'floor')

def streak():
    # (window + .12) x .64 m under the sill: 384 x 256; streaks run down from the sill's ends and its middle
    W, H = 384, 256
    y = np.arange(H)[:, None] / (H - 1)
    a = np.zeros((H, W), np.float32); r = np.random.default_rng(5)
    for _ in range(26):
        cx = r.choice([r.uniform(.02, .16), r.uniform(.84, .98), r.uniform(.2, .8)], p=None) * W
        L = r.uniform(.25, 1.0); wdt = r.uniform(1.5, 6)
        xs = np.arange(W)[None, :]
        prof = np.exp(-((xs - cx - 3 * np.sin(y * r.uniform(4, 9))) / wdt) ** 2)
        a += r.uniform(.12, .3) * prof * np.clip(1 - y / L, 0, 1) ** .7
    a += .18 * np.clip(1 - y / .18, 0, 1) * (1 + .4 * noise(H, W, 6))   # the wet line right under the sill
    a *= (1 + .3 * noise(H, W, 10))
    save((.26, .21, .13), np.clip(a, 0, .6), 'streak')

def ceil():
    # a leak stain: a pale tide-marked blob, darker rings where it dried, 512 x 512
    W = H = 512
    x = np.arange(W)[None, :] / (W - 1) * 2 - 1; y = np.arange(H)[:, None] / (H - 1) * 2 - 1
    ang = np.arctan2(y, x); r = np.hypot(x, y)
    ph = np.random.default_rng(11).uniform(0, 6.283, 16)
    wob = 1 + sum(.16 / k * np.sin(k * ang + ph[k]) for k in range(2, 16))   # an irregular outline, not a flower
    a = np.zeros((H, W), np.float32)
    for k, (rad, wt) in enumerate(((.9, .7), (.78, .25), (.55, .18))):
        rr = r / (rad * wob * (1 + .04 * k))
        a += wt * np.exp(-((rr - 1) / .03) ** 2) * np.clip(1 - (rr - 1) / .03, 0, 1) ** 0 * (rr < 1.08)   # the tide line, sharp outside
        a += wt * .5 * np.exp(-((rr - 1) / .12) ** 2) * (rr < 1)
        a += .12 * np.clip(1 - rr, 0, 1)                   # the fill inside it
    a *= (1 + .35 * fbm(H, W, (20, 6, 2), (1, .5, .3)))
    a *= np.clip((1 - r) / .05, 0, 1)
    save((.36, .27, .13), np.clip(a * .55, 0, .65), 'ceil')

if __name__ == '__main__':
    for i in range(3): skirt(i)
    jamb(); floor(); streak(); ceil()
