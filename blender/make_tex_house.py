"""Textures for the house exterior and the western-style (洋館風) interior, made from the photo textures already in
assets/tex so the grain matches:  python3 make_tex_house.py
  siding.png    white-painted lap siding, 8 boards per metre (uv_box size 1.0 = 1 m), shadow under each lap
  beadboard.png white-painted beadboard for the wainscot (vertical, 10 cm boards with a bead groove)
  plaster.png   pale plaster for the upper walls and the ceiling
  shingle.png   dark asphalt shingles, 5 courses per metre
  ground.png    dry grass and dirt, 1 tile = 2 m
  skyring.png   dusk sky with a ridge of conifers, wrapped round the site on a cylinder (u = angle)"""
import random, math
import numpy as np
from PIL import Image, ImageFilter
T = '/home/claude/assets/tex'
R = np.random.default_rng(7)
N = 1254

def grain(rot=False):
    g = np.asarray(Image.open(f'{T}/floor.png').convert('L'), np.float32) / 255
    if rot: g = g.T
    return (g - g.mean()) / (g.std() + 1e-6)

def blur_noise(shape, s):
    n = Image.fromarray((R.random(shape) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(s))
    a = np.asarray(n, np.float32) / 255; return (a - a.mean()) / (a.std() + 1e-6)

def save(a, name):
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(f'{T}/{name}.png'); print(name)

# ---- lap siding: boards run along u (horizontal), 8 per tile
g = grain(rot=True)
y = np.arange(N)[:, None] / N * 8 % 1          # 0 at the top of a board, 1 at its bottom edge
paint = np.array([.86, .85, .80])
shade = 1 - .05 * y                              # a lap board tilts out toward its bottom
shade = shade - .5 * np.clip((y - .86) / .14, 0, 1) ** 1.3    # the shadow line under the lap above
shade = shade + .04 * np.clip(1 - y / .06, 0, 1)             # the lit top edge
dirt = blur_noise((N, N), 40) * .025 + blur_noise((N, N), 6) * .01
a = paint[None, None] * (shade + .022 * g + dirt)[..., None]
save(a, 'siding')

# ---- beadboard: vertical boards 10 cm (tile 1 m = 10 boards), groove + bead at each joint
g = grain()
x = np.arange(N)[None, :] / N * 10 % 1
groove = np.exp(-((x - 0) / .012) ** 2) + np.exp(-((x - 1) / .012) ** 2)
bead = np.exp(-((x - .5) / .01) ** 2) * .5
sh = 1 - .35 * groove - .15 * bead + .02 * g
a = np.array([.66, .64, .59])[None, None] * (sh + blur_noise((N, N), 30) * .015)[..., None]
save(a, 'beadboard')

# ---- plaster
c = np.asarray(Image.open(f'{T}/chinking.png').convert('L'), np.float32) / 255
c = (c - c.mean()) / (c.std() + 1e-6)
v = .018 * blur_noise((N, N), 18) + .012 * blur_noise((N, N), 2) + .01 * c
a = np.array([.62, .58, .51])[None, None] * (1 + v)[..., None]   # an aged cream: a whiter wall prints as bare paper
save(a, 'plaster')

# ---- asphalt shingles: 5 courses per tile, tabs 33 cm with slots, colour varies per tab
a = np.zeros((N, N, 3), np.float32)
rows = 5; rh = N // rows
for r in range(rows + 1):
    off = (r % 2) * .5
    for t in range(-1, 4):
        x0 = int((t + off) / 3 * N); x1 = int((t + 1 + off) / 3 * N)
        col = np.array([.17, .16, .15]) * R.uniform(.75, 1.2) + R.uniform(-.015, .015, 3)
        y0 = r * rh; y1 = min(N, y0 + rh)
        a[y0:y1, max(0, x0):min(N, x1)] = col
        if 0 <= x0 < N: a[y0:y1, x0:x0 + 4] *= .35   # the slot between tabs
    if r * rh < N: a[min(N - 1, r * rh + rh - 6):min(N, r * rh + rh), :] *= .45   # shadow under the course above
a *= (1 + .12 * blur_noise((N, N), 1.2) + .06 * blur_noise((N, N), 25))[..., None]
save(a, 'shingle')

# ---- ground: dry grass over dirt
n1 = blur_noise((N, N), 60); n2 = blur_noise((N, N), 3); n3 = blur_noise((N, N), .8)
m = np.clip(.5 + .35 * n1 + .2 * n2, 0, 1)[..., None]
grass = np.array([.30, .28, .16]); dirt = np.array([.27, .21, .15])
a = (grass * m + dirt * (1 - m)) * (1 + .18 * n3)[..., None]
save(a, 'ground')

# ---- sky ring: 4096 x 1024, horizon at 62 % down, conifer ridge
W, H = 4096, 1024
yy = np.linspace(0, 1, H)[:, None]
top = np.array([.23, .26, .38]); mid = np.array([.78, .52, .38]); low = np.array([.95, .66, .42])
k = np.clip(yy / .62, 0, 1)
sky = top * (1 - k[..., None]) ** 1 * 1 + 0
sky = (top * (1 - k) [..., None] + mid * k[..., None]) * (yy < .5)[..., None] + \
      (mid * (1 - np.clip((yy - .5) / .12, 0, 1))[..., None] + low * np.clip((yy - .5) / .12, 0, 1)[..., None]) * (yy >= .5)[..., None]
sky = np.broadcast_to(sky, (H, W, 3)).copy()
# brighter toward the sunset side (u = .25 faces +y, the front of the house)
u = np.linspace(0, 1, W)[None, :]
glow = (np.exp(-((((u - .25 + .5) % 1) - .5) / .12) ** 2) * np.clip((yy - .15) / .35, 0, 1))[..., None]   # none at the top: the dome above takes the top row
sky = sky * (1 + .25 * glow)
ridge = .5 + .05 * np.sin(u * math.tau * 3 + 1) + .03 * np.sin(u * math.tau * 7)
im = sky
rng = random.Random(3)
treeline = np.broadcast_to(ridge, (1, W)).copy()
for _ in range(900):   # conifers: narrow triangles standing on the ridge
    cx = rng.random(); h = rng.uniform(.04, .14); w = h * rng.uniform(.18, .3) * H / W
    base = float(np.interp(cx, np.linspace(0, 1, W), ridge[0])) + .02
    x0 = int((cx - w) * W); x1 = int((cx + w) * W)
    for xi in range(x0, x1):
        d = abs(xi / W - cx) / w
        tt = base - h * (1 - d)
        treeline[0, xi % W] = min(treeline[0, xi % W], tt)
fy = np.arange(H)[:, None] / H
mask = (fy > treeline).astype(np.float32)[..., None]
forest = np.array([.05, .06, .06])
im = im * (1 - mask) + forest * mask
Image.fromarray((np.clip(im, 0, 1) * 255).astype(np.uint8)).save(f'{T}/skyring.png'); print('skyring')
