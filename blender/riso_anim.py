"""Turn the rendered frames into two films:
  A: the render as is, preceded by the interview-question chapter card
  C: each frame re-printed in two Riso inks (Blue + Fluorescent Orange overprinting to a deep teal),
     a fresh halftone grain and a slightly different plate registration on every frame, like a flip-book of a zine.
usage: python3 riso_anim.py <frames_dir> <out_dir>"""
import sys, os, glob, subprocess, numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

PAPER = np.array([238, 232, 218]) / 255.
BLUE = np.array([0, 120, 191]) / 255.
ORANGE = np.array([255, 108, 47]) / 255.
Q = ['扉を開けなかったのは、', 'なぜですか？']
SUB = '第二章　籠城　二十三時'
SERIF_B = '/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc'
SERIF_M = '/usr/share/fonts/opentype/noto/NotoSerifCJK-Medium.ttc'

def noise(h, w, scale, rng):
    small = rng.random((h // scale + 2, w // scale + 2))
    im = Image.fromarray((small * 255).astype(np.uint8)).resize((w + scale * 2, h + scale * 2), Image.BICUBIC)
    return np.asarray(im, float)[:h, :w] / 255.

def screen(cov, angle, cell, rng):
    h, w = cov.shape
    y, x = np.mgrid[0:h, 0:w].astype(float)
    a = np.radians(angle); u = (x * np.cos(a) + y * np.sin(a)) / cell; v = (-x * np.sin(a) + y * np.cos(a)) / cell
    d = (np.cos(u * 2 * np.pi) + np.cos(v * 2 * np.pi)) / 4 + .5
    grain = (noise(h, w, 2, rng) - .5) * .22 + (noise(h, w, 40, rng) - .5) * .12
    return ((cov > (1 - d) + grain) & (cov > .03)).astype(float)

def blur(a, r):
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), float) / 255

def separate(im):
    L = im @ np.array([.299, .587, .114])
    warm = np.clip(im[..., 0] - im[..., 2], 0, 1); cold = np.clip(im[..., 2] - im[..., 0], 0, 1)
    dark = 1 - np.clip(L * 1.25, 0, 1) ** .8
    a = np.clip(dark * 1.05 + cold * 2.2 - warm * .8, 0, 1)
    b = np.clip(dark * .82 + warm * 1.9 - cold * .6, 0, 1)
    return blur(a, 1.0), blur(b, 1.0)

def print_riso(a, b, rng, drum):
    h, w = a.shape
    cell = max(3.2, w / 300)
    A = screen(a, 15, cell, rng); B = screen(b, 75, cell * 1.05, rng)
    dy, dx = rng.integers(-2, 3, 2)
    B = np.roll(B, (2 + dy, -3 + dx), (0, 1))
    ink = .82 + .18 * drum
    paper = PAPER * (.96 + .04 * noise(h, w, 3, rng))[..., None]
    out = paper * (1 - (A * ink)[..., None] * (1 - BLUE)) * (1 - (B * ink)[..., None] * (1 - ORANGE))
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))

def card_C(w, h, rng):
    """The question printed in Riso Blue on a bare page, set like the zine's section opener."""
    m = Image.new('L', (w, h), 0); d = ImageDraw.Draw(m)
    f = ImageFont.truetype(SERIF_B, int(h * .085), index=0); fs = ImageFont.truetype(SERIF_B, int(h * .042), index=0)
    x0, y0 = int(w * .1), int(h * .32)
    for i, line in enumerate(Q): d.text((x0, y0 + i * int(h * .12)), line, font=f, fill=255)
    d.text((x0, y0 + len(Q) * int(h * .12) + int(h * .04)), SUB, font=fs, fill=255)
    a = np.asarray(m, float) / 255 * .97
    return print_riso(a, np.zeros_like(a), rng, noise(h, w, 90, rng))

def card_A(w, h):
    im = Image.new('RGB', (w, h), (0, 0, 0)); d = ImageDraw.Draw(im)
    f = ImageFont.truetype(SERIF_M, int(h * .06), index=0); fs = ImageFont.truetype(SERIF_M, int(h * .024), index=0)
    for i, line in enumerate(['「' + Q[0], Q[1] + '」']):
        d.text((w // 2, int(h * .42) + i * int(h * .095)), line, font=f, fill=(232, 228, 220), anchor='mm')
    d.text((w // 2, int(h * .7)), SUB, font=fs, fill=(150, 146, 140), anchor='mm')
    return im

def encode(pattern, out, fps=12):
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(fps), '-i', pattern, '-vf', 'format=yuv420p',
                    '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '16', '-r', '24', out], check=True)

if __name__ == '__main__':
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(f'{out}/A', exist_ok=True); os.makedirs(f'{out}/C', exist_ok=True)
    frames = sorted(glob.glob(f'{src}/f*.png'))
    w, h = Image.open(frames[0]).size
    rng0 = np.random.default_rng(1)
    drum = noise(h, w, 90, rng0)
    CARD = 24   # 2 s at 12 fps; the riso card re-grains every frame, the A card holds still
    n = 0
    for i in range(CARD):
        card_A(w, h).save(f'{out}/A/{n:04d}.png'); card_C(w, h, np.random.default_rng(100 + i // 2)).save(f'{out}/C/{n:04d}.png'); n += 1
    for k, p in enumerate(frames):
        im = Image.open(p).convert('RGB'); im.save(f'{out}/A/{n:04d}.png')
        a, b = separate(np.asarray(im, float) / 255.)
        print_riso(a, b, np.random.default_rng(1000 + k), drum).save(f'{out}/C/{n:04d}.png')
        n += 1
    encode(f'{out}/A/%04d.png', f'{out}/rules_23h_A.mp4')
    encode(f'{out}/C/%04d.png', f'{out}/rules_23h_C.mp4')
    print('encoded', n, 'frames')
