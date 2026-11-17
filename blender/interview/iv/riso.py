# numpy port of godot/shaders/riso2.gdshader (look=0, the dusk/day print) for concept frames.
# usage: riso.py in.png out.png [exposure] [flat]
import sys, numpy as np
from PIL import Image, ImageFilter
PAPER = np.array([0.945, 0.925, 0.875]); INK_A = np.array([0.0, 0.47, 0.75]); INK_B = np.array([1.0, 0.424, 0.184])
def luma(c): return c[...,0]*0.299 + c[...,1]*0.587 + c[...,2]*0.114
def sstep(a, b, x): t = np.clip((x-a)/(b-a), 0, 1); return t*t*(3-2*t)
def coverage(c):
    L = np.clip(luma(c), 0, 1); mx = c.max(-1) + 1e-4
    warm = np.clip((c[...,0]-c[...,2])/mx, 0, 1); cold = np.clip((c[...,2]-c[...,0])/mx, 0, 1)
    d = 1 - L
    a = sstep(0.36, 0.86, d); a = a + cold*0.45*(1-a); a = a*(1 - 0.55*warm*sstep(0.08, 0.5, L))
    b = np.clip(warm*1.15, 0, 1)*(0.55 + 0.40*sstep(0.04, 0.4, L)); b = b*(1 - 0.55*sstep(0.35, 0.75, L))
    deep = sstep(0.84, 0.975, d); b = b + deep*0.92*(1-b)
    return np.clip(a, 0, 1), np.clip(b, 0, 1)
def dots(h, w, angle, cell, off=(0, 0)):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32); x += off[0]; y += off[1]
    t = np.radians(angle); u = (x*np.cos(t) + y*np.sin(t))/cell; v = (-x*np.sin(t) + y*np.cos(t))/cell
    fu = u - np.floor(u) - 0.5; fv = v - np.floor(v) - 0.5
    r = np.sqrt(fu*fu + fv*fv)/0.7071
    return 1 - r   # 1 at the dot centre
def srgb2lin(x): return np.where(x <= 0.04045, x/12.92, ((x+0.055)/1.055)**2.4)
def lin2srgb(x): x = np.clip(x, 0, 1); return np.where(x <= 0.0031308, x*12.92, 1.055*x**(1/2.4)-0.055)
def scan(c): return c/(1 + 0.55*c)
def print_frame(img, exposure=1.3, seed=1, cell=3.6, flat=False, grain=0.16, lift=0.0, day=False):
    rgb = (np.asarray(img.convert('RGB')).astype(np.float32)/255)
    h, w = rgb.shape[:2]; k = h/1080
    soft = (np.asarray(img.convert('RGB').filter(ImageFilter.GaussianBlur(1.0*k))).astype(np.float32)/255)
    c = scan((rgb*0.5 + soft*0.5)*exposure)
    a, b = coverage(c)
    if lift: a = np.clip((a - lift)/(1 - lift), 0, 1)   # 昼：薄い青を紙の白に返す
    if day:
        # 昼の刷り：障子の白（約234）だけを紙にして、その下の淡い影（葉の影など）から薄い網点を置く
        Lr = np.clip(luma(rgb*0.5 + soft*0.5), 0, 1)
        d = 1 - Lr; a = 0.30*sstep(0.06, 0.28, d) + 0.70*sstep(0.38, 0.92, d)   # 淡い影は薄い網点、壁の中間は白寄り、暗い所だけ濃く
    rng = np.random.default_rng(seed)
    mis = np.array([-3.0, 2.0])*k
    cellk = max(cell*k, 3.0)
    if flat:
        # the flattened room: no screen, three flat inks (paper / blue / teal), like a cut-out background
        tint = ((1 - dots(h, w, 15, cellk)) < 0.30).astype(np.float32)
        A = np.where(a > 0.55, 1.0, np.where(a > 0.03, tint, 0.0)).astype(np.float32)
        bb = np.roll(np.roll(b, int(round(mis[1])), 0), int(round(mis[0])), 1)
        tintb = ((1 - dots(h, w, 75, cellk*1.05, mis)) < 0.30).astype(np.float32)
        B = np.where(bb > 0.6, 1.0, np.where(bb > 0.25, tintb, 0.0)).astype(np.float32)
    else:
        g1 = (rng.random((h, w)) - 0.5)*grain; g2 = (rng.random((h, w)) - 0.5)*grain
        bb = np.roll(np.roll(b, int(round(mis[1])), 0), int(round(mis[0])), 1)
        A = ((1 - dots(h, w, 15, cellk) + g1) < a) & (a > 0.02)
        B = ((1 - dots(h, w, 75, cellk*1.05, mis) + g2) < bb) & (bb > 0.02)
        A = A.astype(np.float32); B = B.astype(np.float32)
    pap = PAPER*(0.975 + 0.025*rng.random((h, w, 1)))
    o = pap*(1 - A[..., None]*0.95*(1-INK_A))*(1 - B[..., None]*0.95*(1-INK_B))
    return Image.fromarray((np.clip(o, 0, 1)*255).astype(np.uint8))
if __name__ == '__main__':
    im = Image.open(sys.argv[1]); ex = float(sys.argv[3]) if len(sys.argv) > 3 else 1.3
    flat = len(sys.argv) > 4 and sys.argv[4] == 'flat'
    print_frame(im, ex, flat=flat).save(sys.argv[2])
