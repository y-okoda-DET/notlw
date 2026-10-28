"""Alternative C: the film circle's riso-printed zine. Two inks (Riso Blue + Riso Orange) on off-white paper,
halftoned at different screen angles, slightly mis-registered. Separation computed from the night render."""
import sys, numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

PAPER = np.array([242, 237, 226]) / 255.
BLUE = np.array([0, 120, 191]) / 255.      # Riso Blue
ORANGE = np.array([255, 108, 47]) / 255.   # Riso Orange

def noise(h, w, scale, seed):
    r = np.random.default_rng(seed)
    small = r.random((h // scale + 2, w // scale + 2))
    im = Image.fromarray((small * 255).astype(np.uint8)).resize((w + scale * 2, h + scale * 2), Image.BICUBIC)
    return np.asarray(im, float)[:h, :w] / 255.

def screen(cov, angle, cell, seed):
    h, w = cov.shape
    y, x = np.mgrid[0:h, 0:w].astype(float)
    a = np.radians(angle); u = (x * np.cos(a) + y * np.sin(a)) / cell; v = (-x * np.sin(a) + y * np.cos(a)) / cell
    d = (np.cos(u * 2 * np.pi) + np.cos(v * 2 * np.pi)) / 4 + .5          # 0..1 dot field
    grain = (noise(h, w, 2, seed) - .5) * .22 + (noise(h, w, 40, seed + 1) - .5) * .12
    return (cov > (1 - d) + grain).astype(float)

def run(src, out, title=None, sub=None):
    im = np.asarray(Image.open(src).convert('RGB'), float) / 255.
    h, w, _ = im.shape
    L = im @ np.array([.299, .587, .114])
    Lq = np.clip(L / np.percentile(L, 99.3), 0, 1) ** .68
    warm = np.clip((im[..., 0] - im[..., 2]) / (im.sum(-1) + .02), 0, 1)
    cold = np.clip((im[..., 2] - im[..., 0]) / (im.sum(-1) + .02), 0, 1)
    a = np.clip((1 - Lq) * 1.1 - .05 + cold * .25 - warm * Lq * .9, 0, 1)   # blue: the dark and the cold
    b = np.clip(warm * 2.4 * Lq ** .7 - .08, 0, 1)                          # orange: only what the warm lights touch
    a = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0)), float) / 255
    b = np.asarray(Image.fromarray((b * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0)), float) / 255
    cell = max(3.5, w / 420)
    A = screen(a, 15, cell, 3); B = screen(b, 75, cell * 1.05, 7)
    B = np.roll(B, (3, -4), (0, 1))                                    # mis-registration
    ink_var = .82 + .18 * noise(h, w, 90, 11)                          # uneven drum coverage
    paper = PAPER * (.96 + .04 * noise(h, w, 3, 13))[..., None]
    outp = paper * (1 - (A * ink_var)[..., None] * (1 - BLUE)) * (1 - (B * ink_var)[..., None] * (1 - ORANGE))
    img = Image.fromarray((np.clip(outp, 0, 1) * 255).astype(np.uint8))
    if title:
        d = ImageDraw.Draw(img)
        bw, bh = int(w * .30), int(h * .2)
        knock = Image.fromarray((np.clip(paper[:bh + int(h * .07), :bw + int(w * .045)], 0, 1) * 255).astype(np.uint8))
        img.paste(knock, (0, 0))
        f = ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc', int(h * .045), index=0)
        fs = ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSerifCJK-Medium.ttc', int(h * .018), index=0)
        x0, y0 = int(w * .045), int(h * .07)
        for i, line in enumerate(title):
            d.text((x0, y0 + i * int(h * .062)), line, font=f, fill=tuple(int(c * 255) for c in BLUE))
        if sub: d.text((x0, y0 + len(title) * int(h * .062) + int(h * .01)), sub, font=fs, fill=tuple(int(c * 255) for c in BLUE))
    img.save(out)

if __name__ == '__main__':
    run(sys.argv[1], sys.argv[2], ['扉を開けなかったのは、', 'なぜですか？'], '第二章　籠城　二十三時')
