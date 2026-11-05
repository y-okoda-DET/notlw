"""段階2: the images for the upstairs rooms and the cellar (blender/lived2.py).
python3 blender/lived2_tex.py  ->  assets/tex/crew_<name>.png (the film crew's marker on tape), assets/tex/gen_diff.png
The crew write on everything they brought (企画書：手書きのラベルやガムテープなどサークルの痕跡): a strip of tape, a
name or what is in it, in black marker. The owner's tape on his generator is old masking tape gone brown, his hand in
ballpoint (the same Yomogi face as his calendar, smaller and finer). The generator's own image (Poly Haven, CC0) has its
model number painted out (no real maker's marks: the user has not decided on them, and none is needed)."""
import os, sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P
from PIL import Image, ImageDraw, ImageFilter
import lived_tex as LT

OUT = f'{P.ASSETS}/tex'
R = random.Random(11)
LT.R = R

# name: (text, tape colour, ink, width px, height px, font size)
GAFFER, MASK, OLDMASK = (54, 56, 58, 255), (226, 214, 176, 255), (196, 168, 112, 255)
LABELS = {
    'cam':     ('カメラ 桐生', GAFFER, (235, 235, 230, 255), 420, 110, 64),
    'light':   ('照明', GAFFER, (235, 235, 230, 255), 240, 110, 70),
    'makeup':  ('メイク ※割れ物', MASK, (20, 20, 25, 255), 520, 100, 56),
    'crate':   ('撮影部 備品', MASK, (20, 20, 25, 255), 380, 100, 58),
    'water':   ('飲み水', MASK, (20, 40, 120, 255), 260, 100, 64),
    'taiga':   ('大河', MASK, (20, 20, 25, 255), 200, 100, 66),
    'natsuki': ('なつき', MASK, (170, 20, 20, 255), 240, 100, 62),
    'gen':     ('チョーク 引いてから', OLDMASK, (40, 40, 70, 255), 520, 90, 46),
    'gas':     ('ガソリン', OLDMASK, (40, 40, 70, 255), 300, 90, 52),
}

def tape(w, h, col):
    im = LT.paper(w, h, col[:3] + (255,))
    # torn ends: a ragged edge on the left and right
    m = Image.new('L', (w, h), 255); d = ImageDraw.Draw(m)
    for side in (0, 1):
        pts = []
        for k in range(12):
            y = h * k / 11; x = R.uniform(0, 14)
            pts.append((x if side == 0 else w - x, y))
        poly = ([(0, 0)] + pts + [(0, h)]) if side == 0 else ([(w, 0)] + pts + [(w, h)])
        d.polygon(poly, fill=0)
    im.putalpha(m)
    return im

def label(n):
    s, col, ink, w, h, fs = LABELS[n]
    im = tape(w, h, col)
    f = LT.hand(fs)
    LT.hand_text(im, (26, (h - fs) * .45), s, f, ink, rot=R.uniform(-3, 2), jit=2, sw=1 if col == GAFFER else 0)
    bg = Image.new('RGBA', im.size, col[:3] + (0,))
    out = Image.alpha_composite(bg, im)
    out.save(f'{OUT}/crew_{n}.png')

def generator():
    """The generator's colour image with its model number painted out: each box is filled with the yellow sampled
    just above it, with a little of the image's grain kept."""
    src = f'{P.ASSETS}/phm/portable_generator/textures/portable_generator_diff_1k.jpg'
    im = Image.open(src).convert('RGB')
    W = im.width / 1024
    # (box, the clean patch of the same paint to tile over it)
    for (box, pat) in (((386, 986, 536, 1018), (540, 984, 572, 1016)),    # the big EN2500 on the front (yellow)
                       ((312, 882, 350, 895), (356, 882, 394, 895))):     # the small red badge (on the dark band)
        x0, y0, x1, y1 = [int(v * W) for v in box]
        p = im.crop(tuple(int(v * W) for v in pat))
        for x in range(x0, x1, p.width):
            for y in range(y0, y1, p.height):
                q = p.transpose(Image.FLIP_LEFT_RIGHT) if ((x - x0) // p.width) % 2 else p
                im.paste(q.crop((0, 0, min(p.width, x1 - x), min(p.height, y1 - y))), (x, y))
    im.save(f'{OUT}/gen_diff.png')

if __name__ == '__main__':
    for n in LABELS: label(n)
    generator()
    print('LIVED2_TEX_DONE')
