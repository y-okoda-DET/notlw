"""Kiryu's storyboard #12 (the fixed camera in the hall) for the 第1章 puzzle: godot/ui/conte_12.png.
The frame is shot in the game from the answer (story.gd TARGET_POS / TARGET_LOOK, the small camera's angle) with the
print off and a check light, then drawn over as a pencil sketch on a storyboard sheet with his notes.
    python3 godot/ui/make_conte.py [pck]      (no pck: from the project)
Kiryu's hand is Yomogi (assets/fonts, SIL OFL 1.1)."""
import os, sys, math, subprocess, re
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'blender')); import paths as P
import numpy as np, cv2
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(f'{P.RULES}/scripts/story.gd', encoding='utf-8').read()
TP = [float(x) for x in re.search(r'TARGET_POS := \[([^\]]*)\]', src).group(1).split(',')]
TL = [float(x) for x in re.search(r'TARGET_LOOK := \[([^\]]*)\]', src).group(1).split(',')]
FOV = float(re.search(r'FINDER_FOV := ([0-9.]+)', src).group(1))
W = f'{P.WORK}/conte'; os.makedirs(W, exist_ok=True)

def shoot(out, light, pexp, prt):
    g = lambda v: (v[0], v[2], -v[1])
    p, l = g(TP), g(TL); d = [l[i] - p[i] for i in range(3)]; n = math.sqrt(sum(x * x for x in d))
    yaw = math.degrees(math.atan2(-d[0], -d[2])); pitch = math.degrees(math.asin(d[1] / n))
    pck = sys.argv[1] if len(sys.argv) > 1 else None
    base = f'--main-pack {pck}' if pck else f'--path {P.RULES}'
    shot = f'{p[0]:.3f},{p[2]:.3f},{yaw:.2f},{pitch:.2f},{p[1]:.3f},2.0'
    cmd = (f'cd /tmp && timeout 300 xvfb-run -a -s "-screen 0 1920x1080x24" {P.GODOT} {base} --windowed --resolution 1920x1080 '
           f'--write-movie {out}_.png --fixed-fps 24 --quit-after 12 -- --record=poses --nocard --scene=dusk --gi=baked '
           f'--pexp={pexp} --print={prt} --chklight={light} --noclip --nochars --fov={FOV} "--shots={shot}"')
    subprocess.run(cmd, shell=True, capture_output=True)
    return Image.open(f'{out}_00000010.png').convert('RGB')

def crop43(im):
    # the part the finder shows: 86 % of the height, 4:3, centred (story.gd FinderFrame)
    w, h = im.size; hh = int(h * .86); ww = hh * 4 // 3
    return im.crop(((w - ww) // 2, (h - hh) // 2, (w - ww) // 2 + ww, (h - hh) // 2 + hh))

def sketch(im, seed=12):
    rng = np.random.default_rng(seed)
    a = np.asarray(im).astype(np.float32) / 255.0
    g = cv2.cvtColor(a, cv2.COLOR_RGB2GRAY)
    g = cv2.bilateralFilter(g, 9, .12, 6)
    H, Wd = g.shape
    # the hand wobbles: a slow displacement of a pixel or two
    nx = cv2.resize(rng.normal(0, 1, (H // 60 + 2, Wd // 60 + 2)).astype(np.float32), (Wd, H), interpolation=cv2.INTER_CUBIC) * 2.2
    ny = cv2.resize(rng.normal(0, 1, (H // 60 + 2, Wd // 60 + 2)).astype(np.float32), (Wd, H), interpolation=cv2.INTER_CUBIC) * 2.2
    mx, my = np.meshgrid(np.arange(Wd, dtype=np.float32), np.arange(H, dtype=np.float32))
    g = cv2.remap(g, mx + nx, my + ny, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    # outlines: where the tone breaks, drawn in two passes like a pencil going over a line again
    e1 = cv2.Canny((g * 255).astype(np.uint8), 18, 52).astype(np.float32) / 255
    e2 = cv2.Canny((cv2.GaussianBlur(g, (0, 0), 2.2) * 255).astype(np.uint8), 10, 30).astype(np.float32) / 255
    lines = np.clip(cv2.GaussianBlur(e1, (0, 0), .7) * 1.6 * .55 + cv2.GaussianBlur(e2, (0, 0), 1.1) * 1.3 * .75, 0, 1)
    # tone: diagonal hatching in the shadows, cross-hatched in the deepest
    t = np.clip(1 - g / np.percentile(g, 92), 0, 1)
    t = cv2.GaussianBlur(t, (0, 0), 6)
    def hatch(angle, spacing, width):
        a_ = math.radians(angle); u = mx * math.cos(a_) + my * math.sin(a_)
        u = u + cv2.resize(rng.normal(0, 1, (H // 25 + 2, Wd // 25 + 2)).astype(np.float32), (Wd, H)) * 1.5
        return (np.abs(((u / spacing) % 1) - .5) < width / spacing / 2).astype(np.float32)
    h1 = hatch(52, 8.0, 1.3) * (t > .55); h2 = hatch(-38, 8.5, 1.2) * (t > .75); h3 = hatch(80, 6.0, 1.0) * (t > .9)
    hat = np.clip(h1 * .42 + h2 * .38 + h3 * .3, 0, 1) * (.6 + .4 * rng.random((H, Wd)).astype(np.float32))
    ink = np.clip(lines + hat * .85, 0, 1)
    return ink

def sheet(ink):
    # an A-ratio sheet: the frame on the left two thirds, his notes on the right
    SW, SH = 2000, 1414
    paper = np.array([241, 236, 223], np.float32)   # the print's paper (riso2.gdshader)
    rng = np.random.default_rng(3)
    base = np.ones((SH, SW, 3), np.float32) * paper
    fib = cv2.GaussianBlur(rng.normal(0, 1, (SH, SW)).astype(np.float32), (0, 0), 1.2) * 2.5 + cv2.GaussianBlur(rng.normal(0, 1, (SH, SW)).astype(np.float32), (0, 0), 30) * 6
    base += fib[..., None]
    fw = 1240; fh = fw * 3 // 4; fx, fy = 110, 230
    inkr = cv2.resize(ink, (fw, fh), interpolation=cv2.INTER_AREA)
    graphite = np.array([0, 92, 156], np.float32)   # the print's blue ink, a little deeper
    region = base[fy:fy + fh, fx:fx + fw]
    base[fy:fy + fh, fx:fx + fw] = region * (1 - inkr[..., None] * .92) + graphite * inkr[..., None] * .92
    im = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    pen = (0, 92, 156)
    def wob(p0, p1, w=3):
        n = 14; pts = []
        for i in range(n + 1):
            t = i / n; pts.append((p0[0] + (p1[0] - p0[0]) * t + rng.normal(0, .9), p0[1] + (p1[1] - p0[1]) * t + rng.normal(0, .9)))
        d.line(pts, fill=pen, width=w, joint='curve')
    for (a, b) in (((fx, fy), (fx + fw, fy)), ((fx + fw, fy), (fx + fw, fy + fh)), ((fx + fw, fy + fh), (fx, fy + fh)), ((fx, fy + fh), (fx, fy))):
        wob((a[0] - 6, a[1] + rng.normal(0, 2)), (b[0] + 6, b[1] + rng.normal(0, 2)), 4)
    F = lambda s: ImageFont.truetype(f'{P.REPO}/assets/fonts/Yomogi-Regular.ttf', s)
    d.text((fx, 70), 'S#4　廊下（夜通し）', font=F(78), fill=pen)
    d.text((fx + fw - 230, 80), 'C-12', font=F(96), fill=pen)
    nx_ = fx + fw + 70
    notes = [('定点。', 72), ('', 30), ('誰も見てない', 60), ('カメラが、', 60), ('ぜんぶ見てた', 60), ('みたいに。', 60), ('', 40),
             ('・上から見おろす', 50), ('・玄関ぜんぶ入れる', 50), ('・扉はまん中', 50), ('・下に上がり框', 50), ('', 40), ('朝まで回しっぱなし！', 50)]
    y = 240
    for t, s in notes:
        if t: d.text((nx_, y), t, font=F(s), fill=pen)
        y += int(s * 1.35)
    # a circled arrow at the door, his habit
    cx, cy = fx + fw // 2, fy + int(fh * .40)
    d.ellipse((cx - 120, cy - 150, cx + 120, cy + 150), outline=pen, width=4)
    wob((cx + 130, cy - 160), (nx_ - 30, 820), 3)
    d.text((fx, fy + fh + 40), '※ 照明は入れない。夜は真っ暗でOK（赤ランプだけ）', font=F(44), fill=pen)
    im = im.filter(ImageFilter.GaussianBlur(.5))
    return im

if __name__ == '__main__':
    ref = crop43(shoot(f'{W}/ref', 0.35, 1.0, 0))
    ref.save(f'{W}/ref.png')
    ink = sketch(ref)
    Image.fromarray((255 - ink * 255).astype(np.uint8)).save(f'{W}/ink.png')
    out = sheet(ink)
    out.save(f'{HERE}/conte_12.png')
    print('CONTE', f'{HERE}/conte_12.png', out.size)
