"""The real-looking outside of the house: lap siding board by board, slate roof slate by slate, the ground and its
weathering. House-agnostic: house.py (the look comparison) and the plan-v4 house call the same functions with their
own walls and openings.

  clapboard_wall(name, origin, u, n, L, z_lo, z_hi, holes, M, top=None, seed=0, north=0.)
      one wall of white-painted lap siding. origin = the wall line at along=0, z=0 (world); u = unit along the wall;
      n = unit outward. holes = [(a, b, z0, z1)] along-wall/z rectangles (windows, doors). top(along) -> z caps the
      boards (gable ends). Each wall gets its own colour and normal image (weathering placed by its openings:
      streaks under the sills, splash at the foot, peeling at the corners, the shadow under the eaves).
  slate_roof(name, origin, u, w, n, L, W, M, seed=0, north=0.)
      one roof slope of slates: origin = the eave corner, u along the eave, w up the slope, n out of the roof.
  trim_mat(M), concrete_mat(M), ground(M, ...)

Every image is computed with numpy from the Poly Haven (CC0) sources in assets/tex/ph (see docs/素材とアドオン.md),
written to blender/export_tex and cached in $WORK/cache/ext by a hash of the inputs.
All objects are named ext_* (outside the baked lightmap)."""
import sys, os, math, hashlib, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P
import numpy as np
from PIL import Image
from scipy import ndimage
import bpy
from mathutils import Vector
import lib

PH = f'{P.ASSETS}/tex/ph'
TEXOUT = f'{P.KF}/export_tex'
CACHE = f'{P.WORK}/cache/ext'
os.makedirs(TEXOUT, exist_ok=True); os.makedirs(CACHE, exist_ok=True)
VERSION = 'ext8'      # bump when the image recipes change (part of every cache key)

# ------------------------------------------------------------------ image helpers
_src = {}
def src(name, kind='diff', size=None):
    k = (name, kind, size)
    if k not in _src:
        im = Image.open(f'{PH}/{name}_{kind}.jpg').convert('RGB')
        if size: im = im.resize(size, Image.LANCZOS)
        _src[k] = np.asarray(im, np.float32) / 255
    return _src[k]

def lum(a): return a[..., 0] * .3 + a[..., 1] * .59 + a[..., 2] * .11

def fbm(shape, rng, scales=(64, 16, 4), weights=(1, .5, .25), aniso=(1, 1)):
    """Smooth noise ~N(0,1). scales in pixels (feature size); aniso stretches (y, x)."""
    h, w = shape; out = np.zeros(shape, np.float32)
    for s, wt in zip(scales, weights):
        sy, sx = max(1, s * aniso[0]), max(1, s * aniso[1])
        g = rng.standard_normal((int(h / sy) + 3, int(w / sx) + 3)).astype(np.float32)
        z = ndimage.zoom(g, (sy, sx), order=3)[:h, :w]
        if z.shape != shape: z = np.pad(z, ((0, h - z.shape[0]), (0, w - z.shape[1])), mode='edge')
        out += wt * z
    out -= out.mean(); out /= out.std() + 1e-6
    return out

def tile_sample(tex, shape, ppm_out, metres_per_tile, off=(0, 0)):
    """Repeat a square source image over `shape` at its world scale (nearest-ish: integer index lookup)."""
    th, tw = tex.shape[:2]
    ys = ((np.arange(shape[0]) / ppm_out / metres_per_tile * th) + off[0]).astype(np.int64) % th
    xs = ((np.arange(shape[1]) / ppm_out / metres_per_tile * tw) + off[1]).astype(np.int64) % tw
    return tex[ys[:, None], xs[None, :]]

def tile_smooth(img2d, shape, ppm_out, metres_per_tile, off=(0, 0), along=None):
    """Bilinear, wrapping sample of a square 2-D source at its world scale (no blocky texels when seen close)."""
    th, tw = img2d.shape
    ys = (np.arange(shape[0]) / ppm_out / metres_per_tile * th + off[0])
    xs = (np.arange(shape[1]) / ppm_out / metres_per_tile * tw + off[1])
    Y, Xx = np.meshgrid(ys, xs, indexing='ij')
    return ndimage.map_coordinates(img2d, [Y.ravel(), Xx.ravel()], order=1, mode='grid-wrap').reshape(shape).astype(np.float32)

def normal_from_height(hgt, strength):
    gy, gx = np.gradient(hgt.astype(np.float32))
    n = np.dstack([-gx * strength, gy * strength, np.ones_like(hgt)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * .5 + .5

def save_png(a, path):
    Image.fromarray((np.clip(a, 0, 1) * 255 + .5).astype(np.uint8)).save(path, optimize=False, compress_level=4)

def cached(key_obj, names, make):
    """make() -> dict name -> array; files cached by the hash of key_obj."""
    h = hashlib.sha256((VERSION + json.dumps(key_obj, sort_keys=True, default=str)).encode()).hexdigest()[:16]
    paths = {n: f'{CACHE}/{h}_{n}.png' for n in names}
    if not all(os.path.exists(p) for p in paths.values()):
        arrs = make()
        for n in names: save_png(arrs[n], paths[n])
    return paths

def mat_maps(name, albedo, normal=None, rough=.7, nstrength=1.0, alpha=False):
    """Principled with a colour image (and a tangent normal image) on the first UV: glTF carries both."""
    m = bpy.data.materials.new(name); m.use_nodes = True
    N = m.node_tree.nodes; Lk = m.node_tree.links; p = N['Principled BSDF']
    p.inputs['Roughness'].default_value = rough; p.inputs['Specular IOR Level'].default_value = .3
    t = N.new('ShaderNodeTexImage'); t.image = lib.img(albedo); Lk.new(t.outputs['Color'], p.inputs['Base Color'])
    if alpha:
        t.image.alpha_mode = 'STRAIGHT'
        r = N.new('ShaderNodeMath'); r.operation = 'ROUND'   # glTF: alpha through Round = alpha clip
        Lk.new(t.outputs['Alpha'], r.inputs[0]); Lk.new(r.outputs[0], p.inputs['Alpha'])
        m.use_backface_culling = False
    if normal:
        tn = N.new('ShaderNodeTexImage'); tn.image = lib.img(normal, srgb=False)
        nm = N.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value = nstrength
        Lk.new(tn.outputs['Color'], nm.inputs['Color']); Lk.new(nm.outputs['Normal'], p.inputs['Normal'])
    return m

# ------------------------------------------------------------------ lap siding
E_LAP, OV_LAP = .135, .03        # exposure of each board, the part hidden under the board above
T_BOT, T_TOP, T_BACK = .021, .006, .004
PAINT = np.array([.75, .74, .69], np.float32)      # 見比べ2: whiter printed as bare paper
WOOD = np.array([.36, .33, .29], np.float32)       # weathered bare cedar where the paint has gone
GRIME = np.array([.30, .29, .26], np.float32)
SOIL = np.array([.27, .22, .16], np.float32)
ALGAE = np.array([.31, .35, .26], np.float32)

def _cut(segs, ha, hb):
    out = []
    for a, b in segs:
        if hb <= a or ha >= b: out.append((a, b)); continue
        if ha > a: out.append((a, ha))
        if hb < b: out.append((hb, b))
    return out

def _courses(z_lo, z_hi, top_max):
    zs = []; z = z_lo
    while z < max(z_hi, top_max) - .01: zs.append(z); z += E_LAP
    return zs

def _joints(rng, L, n):
    """Butt joints of each course: boards 2.4-4.6 m, staggered at least .45 m from the course below."""
    out = []; prev = []
    for _ in range(n):
        for _try in range(20):
            js = []; x = rng.uniform(.3, 3.6)
            while x < L - .3: js.append(x); x += rng.uniform(2.4, 4.6)
            if all(min([abs(j - p) for p in prev] or [9]) > .45 for j in js): break
        out.append(js); prev = js
    return out

def clapboard_wall(name, origin, u, n, L, z_lo, z_hi, holes, M, top=None, seed=0, north=0.0, ppm=240, ground_z=None):
    origin = Vector(origin); u = Vector(u).normalized(); n = Vector(n).normalized()
    rng = np.random.default_rng(seed)
    top_max = max(top(a) for a in np.linspace(0, L, 64)) if top else z_hi
    zs = _courses(z_lo, z_hi if not top else top_max, top_max)
    joints = _joints(rng, L, len(zs))
    zi0, zi1 = z_lo - .03, (top_max if top else z_hi) + .02     # image covers z in [zi0, zi1]
    def topz(a): return min(z_hi, top(a)) if (top and False) else (top(a) if top else z_hi)
    V = []; F = []; UV = []
    def vert(a, z, o):
        V.append(tuple(origin + u * a + n * o + Vector((0, 0, z)))); return len(V) - 1
    def uvz(a, z): return (a / L, (z - zi0) / (zi1 - zi0))
    def face(idx, uvs): F.append(idx); UV.append(uvs)
    boards = []   # (course, a, b, tone) for the image
    for ci, zb in enumerate(zs):
        segs = [(0.0, L)]
        for (ha, hb, h0, h1) in holes:
            if zb + E_LAP + OV_LAP > h0 and zb < h1: segs = _cut(segs, ha, hb)
        cuts = []
        for (a, b) in segs:
            pts = [a] + [j for j in joints[ci] if a + .15 < j < b - .15] + [b]
            for k in range(len(pts) - 1): cuts.append((pts[k] + (.0015 if k else 0), pts[k + 1] - (.0015 if k < len(pts) - 2 else 0)))
        for (a, b) in cuts:
            if b - a < .03: continue
            dt = rng.normal(0, .0012); wav_a = rng.normal(0, .0012); ph = rng.uniform(0, 6.28)
            tilt = rng.normal(0, .0008)
            ns = max(1, int(math.ceil((b - a) / (.22 if top else .4))))
            us = np.linspace(a, b, ns + 1)
            rows = []
            for x in us:
                zt = zb + E_LAP + OV_LAP
                cap = top(x) if top else z_hi
                zt = min(zt, cap); zbb = min(zb + wav_a * .6 * math.sin(ph + x * 2.1), cap - .002)
                ob = T_BOT + dt + wav_a * math.sin(ph + x * 1.7) + tilt * (x - a)
                rows.append((x, zbb, zt, ob, T_TOP + dt * .3))
            boards.append((ci, a, b))
            for k in range(ns):
                (x0, b0, t0, o0, p0), (x1, b1, t1, o1, p1) = rows[k], rows[k + 1]
                if t0 - b0 < .004 and t1 - b1 < .004: continue
                # face
                i = [vert(x0, b0, o0), vert(x1, b1, o1), vert(x1, t1, p1), vert(x0, t0, p0)]
                face(i, [uvz(x0, b0), uvz(x1, b1), uvz(x1, t1), uvz(x0, t0)])
                # underside (in the image: just below the board, the shadow line of the board beneath)
                j = [vert(x0, b0, T_BACK), vert(x1, b1, T_BACK), vert(x1, b1, o1), vert(x0, b0, o0)]
                face(j, [uvz(x0, b0 - .006)] * 2 + [uvz(x1, b1 - .004), uvz(x0, b0 - .004)])
            for (x, zbb, zt, ob, ot), sgn in ((rows[0], -1), (rows[-1], 1)):   # board ends
                if zt - zbb < .004: continue
                e = [vert(x, zbb, T_BACK), vert(x, zbb, ob), vert(x, zt, ot), vert(x, zt, T_BACK)]
                if sgn > 0: e = e[::-1]
                face(e, [uvz(x - sgn * .004, zbb), uvz(x - sgn * .004, zbb), uvz(x - sgn * .004, zt), uvz(x - sgn * .004, zt)])
    # winding: faces must point along +n; build normal check on the first face
    me = bpy.data.meshes.new(name); me.from_pydata(V, [], F); me.update()
    uvl = me.uv_layers.new(name='UVMap')
    for poly, uvs in zip(me.polygons, UV):
        for li, uvv in zip(poly.loop_indices, uvs): uvl.data[li].uv = uvv
    flip = me.polygons[0].normal.dot(n) < 0
    if flip:
        me.flip_normals()
    ob = lib.link(bpy.data.objects.new(name, me))
    # the image
    key = dict(n=name, L=round(L, 3), z=(round(z_lo, 3), round(z_hi, 3), round(zi0, 3), round(zi1, 3)), holes=[tuple(round(x, 3) for x in h) for h in holes],
               seed=seed, north=north, ppm=ppm, gz=ground_z, top=[round(top(a), 3) for a in np.linspace(0, L, 17)] if top else None)
    paths = cached(key, ('a', 'n'), lambda: _siding_image(L, zi0, zi1, zs, joints, holes, seed, north, ppm, ground_z if ground_z is not None else z_lo, top))
    m = mat_maps(f'{name}_m', paths['a'], paths['n'], rough=.62, nstrength=1.0)
    ob.data.materials.append(m)
    return ob

def _siding_image(L, zi0, zi1, zs, joints, holes, seed, north, ppm, gz, top):
    rng = np.random.default_rng(seed + 1000)
    W = min(4096, int(L * ppm)); Hh = min(4096, int((zi1 - zi0) * ppm))
    sx, sz = W / L, Hh / (zi1 - zi0)
    xa = (np.arange(W) + .5) / sx                    # along (m)
    za = zi1 - (np.arange(Hh) + .5) / sz             # z (m), row 0 at the top
    X = np.broadcast_to(xa[None, :], (Hh, W)); Z = np.broadcast_to(za[:, None], (Hh, W))
    zs_a = np.array(zs)
    ci = np.clip(np.searchsorted(zs_a, za, side='right') - 1, 0, len(zs) - 1)
    t = np.clip((za - zs_a[ci]) / E_LAP, 0, 1.2)     # 0 at a board's bottom edge, 1 at the drip edge of the one above
    T = np.broadcast_to(t[:, None], (Hh, W)); CI = np.broadcast_to(ci[:, None], (Hh, W))
    # board id per pixel -> tone, grain offset
    seg = np.zeros((Hh, W), np.int32)
    for c in range(len(zs)):
        rows = ci == c
        if not rows.any(): continue
        sidx = np.searchsorted(np.array(joints[c] + [1e9]), xa)
        seg[rows, :] = sidx[None, :] + c * 64
    bid = seg
    tone_tab = rng.normal(0, 1, bid.max() + 1).astype(np.float32)
    tone = tone_tab[bid]
    # wood grain along the boards (anisotropic noise), its own phase per board
    grain = fbm((Hh, W), rng, scales=(6, 2), weights=(1, .6), aniso=(1, 14))
    grain += .5 * np.sin((X * 9 + tone * 3 + fbm((Hh, W), rng, scales=(40,), weights=(1,), aniso=(1, 4)) * .8) * 6.28 * .4)
    # paint
    low = fbm((Hh, W), rng, scales=(int(1.2 * ppm), int(.3 * ppm)), weights=(1, .5))
    brush = fbm((Hh, W), rng, scales=(3,), weights=(1,), aniso=(1, 20))
    pw = lum(src('acg_PaintedWood008A', 'diff')); pw = (pw - ndimage.gaussian_filter(pw, 40)); pw = pw / (pw.std() + 1e-6)
    PW = tile_smooth(pw.astype(np.float32), (Hh, W), ppm, 1.3, off=(rng.integers(0, 2048), rng.integers(0, 2048)))   # brushed, crazed old paint (ambientCG, CC0)
    v = 1 + .025 * low + .018 * tone + .006 * brush + .01 * grain + .035 * PW
    # lap shading: the shadow line under the board above, the board tilting out toward its foot
    shade = 1 - .035 * T - .40 * np.clip((T - .84) / .16, 0, 1) ** 1.4 + .03 * np.clip(1 - T / .05, 0, 1)
    hz = Z - gz
    # fields
    peel_src = src('wood_peeling_paint_weathered', 'diff')
    pd = peel_src[..., 0] - peel_src[..., 2]
    PD = tile_smooth(pd.astype(np.float32), (Hh, W), ppm, 1.1, off=(rng.integers(0, 2048), rng.integers(0, 2048)))
    edge = np.minimum(X, L - X)
    under_sill = np.zeros((Hh, W), np.float32); streak = np.zeros((Hh, W), np.float32); shadow = np.zeros((Hh, W), np.float32)
    for (ha, hb, h0, h1) in holes:
        if h0 > gz + .3:   # a window: sill at h0
            below = np.clip((h0 - Z) / 1.0, 0, 1) * (Z < h0)
            inx = np.exp(-((X - (ha + hb) / 2) / ((hb - ha) / 2 + .1)) ** 8)
            under_sill = np.maximum(under_sill, inx * (1 - below) * (Z < h0))
            shadow += inx * np.clip(1 - (h0 - Z) / .06, 0, 1) * (Z < h0) * .35          # under the sill
            for x0 in list(np.linspace(ha - .06, hb + .06, 2)) + list(rng.uniform(ha, hb, rng.integers(1, 4))):
                wdt = rng.uniform(.012, .035); ln = rng.uniform(.35, 1.4)
                s1 = np.exp(-((X - x0 - .02 * fbm((Hh, 1), rng, (30,), (1,))) / wdt) ** 2)
                s1 = s1 * np.clip(1 - (h0 - Z) / ln, 0, 1) * (Z < h0 - .02)
                streak = np.maximum(streak, s1 * rng.uniform(.4, 1))
        # the casing's shadow on the boards right beside the opening
        shadow += np.exp(-np.maximum(0, np.minimum(np.abs(X - ha), np.abs(X - hb))) / .015) * ((Z > h0) & (Z < h1)) * .25
    sfx = fbm((Hh, W), rng, scales=(4, 1), weights=(1, .5), aniso=(8, 1))   # streaks break up along their length
    streak = streak * np.clip(.6 + .5 * sfx, 0, 1)
    # under the eaves: the soffit's shadow and dust at the top of the wall
    ztop = np.array([top(x) for x in xa])[None, :] if top else np.full((1, W), zi1)
    dtop = ztop - Z
    eave = np.clip(1 - dtop / .7, 0, 1) ** 1.6 * (.32 if not top else .12) + np.clip(1 - dtop / .06, 0, 1) * .25
    # peeling: at the foot, the corners, under the sills; more on the sunny walls
    patch = np.clip(fbm((Hh, W), rng, scales=(int(.9 * ppm), int(.3 * ppm)), weights=(1, .4)) - 1.1, 0, 2)   # a few failing patches
    pe = .38 * np.exp(-np.maximum(hz, 0) / .35) + .28 * np.exp(-edge / .22) + .16 * under_sill + (.25 + .1 * (1 - north)) * patch
    pe = np.clip(pe * np.clip(1 + .5 * fbm((Hh, W), rng, scales=(int(.25 * ppm),), weights=(1,)), 0, 2), 0, .75)
    thr = .29 - .32 * pe
    pv = PD - thr
    peeled = np.clip(pv / .012 + .5, 0, 1)                         # soft-edged (anti-aliased) flakes
    rim = np.clip(ndimage.gaussian_filter(peeled, 1.3) * 2.5 - peeled * 3, 0, 1)   # the paint film's lifted edge round each flake
    # paint colour
    col = PAINT[None, None] * v[..., None]
    wood = WOOD[None, None] * (1 + .12 * grain + .08 * tone)[..., None]
    col = col * (1 - peeled[..., None]) + wood * peeled[..., None]
    col *= (1 - .22 * rim)[..., None]
    # splash at the foot (soil), algae on the shady walls
    sp = np.exp(-np.maximum(hz, 0) / .22) * np.clip(.55 + .45 * fbm((Hh, W), rng, scales=(10, 3), weights=(1, .7)), 0, 1)
    col = col * (1 - .55 * sp[..., None]) + SOIL[None, None] * (.55 * sp[..., None])
    al = (north * .7 + .15) * np.clip(np.exp(-np.maximum(hz, 0) / .9) + .6 * under_sill * np.exp(-np.maximum(hz - 1, 0) / 2), 0, 1)
    al = al * np.clip(.5 + .6 * fbm((Hh, W), rng, scales=(int(.4 * ppm), 20), weights=(1, .5)), 0, 1)
    col = col * (1 - .45 * al[..., None]) + ALGAE[None, None] * (.45 * al[..., None])
    col = col * (1 - .5 * streak[..., None]) + GRIME[None, None] * (.5 * streak[..., None])
    # nails: one per stud (.455 m) per board, near its foot; a few bleed rust
    for c, zb in enumerate(zs):
        r = int((zi1 - (zb + E_LAP * .22)) * sz)
        if not (2 <= r < Hh - 2): continue
        for xs in np.arange(.2 + (seed % 3) * .05, L - .1, .455):
            cx = int(xs * sx + rng.normal(0, 1.2))
            if not (2 <= cx < W - 2): continue
            col[r:r + 2, cx:cx + 2] *= .78
            if rng.random() < .07:
                ln = int(rng.uniform(.05, .22) * sz)
                fall = np.linspace(1, 0, ln)[:, None, None] ** 1.5
                r1 = min(Hh, r + ln)
                col[r:r1, cx - 1:cx + 2] = col[r:r1, cx - 1:cx + 2] * (1 - .45 * fall[:r1 - r]) + np.array([.42, .24, .12]) * .45 * fall[:r1 - r]
    # joints: the end grain darkens, the paint cracks across
    jm = np.zeros((Hh, W), np.float32)
    for c in range(len(zs)):
        rows = ci == c
        for j in joints[c]:
            cx = int(j * sx)
            if 1 <= cx < W - 1: jm[rows, cx - 1:cx + 2] = 1
    jm = ndimage.gaussian_filter(jm, 1.2) * 2.2
    col *= (1 - .35 * np.clip(jm, 0, 1))[..., None]
    col *= (shade * (1 - eave) * (1 - np.clip(shadow, 0, .6)))[..., None]
    # height for the normal image: grain, the paint film's edge where it has peeled, joint grooves
    hgt = .25 * grain + .35 * PW + 1.2 * (1 - peeled) + .4 * ndimage.gaussian_filter(PD, 1) - 1.5 * np.clip(jm, 0, 1)
    nrm = normal_from_height(ndimage.gaussian_filter(hgt, .7), 1.4)
    return {'a': col, 'n': nrm}

# ------------------------------------------------------------------ painted trim (casings, corner boards, fascia, bands)
def trim_mat(M):
    if 'ext_trim' in M: return M['ext_trim']
    def make():
        rng = np.random.default_rng(5); S = 1024
        g = fbm((S, S), rng, scales=(4, 2), weights=(1, .5), aniso=(1, 12))
        low = fbm((S, S), rng, scales=(200, 50), weights=(1, .5))
        grime = np.clip(fbm((S, S), rng, scales=(60, 12), weights=(1, .6)) - .6, 0, 2)
        c = PAINT[None, None] * .97 * (1 + .015 * g + .025 * low)[..., None]
        c = c * (1 - .25 * grime[..., None]) + GRIME * .25 * grime[..., None]
        return {'a': c, 'n': normal_from_height(ndimage.gaussian_filter(.3 * g, .8), 1.2)}
    # tileable: blend the edges so the box UVs repeat without a seam
    p = cached({'trim': 2}, ('a', 'n'), lambda: {k: _tileable(v) for k, v in make().items()})
    M['ext_trim'] = mat_maps('ext_trim', p['a'], p['n'], rough=.5)
    return M['ext_trim']

def _tileable(a, frac=.15):
    h, w = a.shape[:2]; b = np.roll(np.roll(a, h // 2, 0), w // 2, 1)
    wy = np.clip(np.minimum(np.arange(h), h - 1 - np.arange(h)) / (h * frac), 0, 1)
    wx = np.clip(np.minimum(np.arange(w), w - 1 - np.arange(w)) / (w * frac), 0, 1)
    m = np.minimum(wy[:, None], wx[None, :])
    if a.ndim == 3: m = m[..., None]
    return a * m + b * (1 - m)

# ------------------------------------------------------------------ slate roof
SL_EXP, SL_TH = .115, .007
def slate_roof(name, origin, u, w, n, L, W, M, seed=0, north=0.0, ppm=150):
    origin = Vector(origin); u = Vector(u).normalized(); w = Vector(w).normalized(); n = Vector(n).normalized()
    rng = np.random.default_rng(seed)
    V = []; F = []; UV = []
    def vert(a, b, h): V.append(tuple(origin + u * a + w * b + n * h)); return len(V) - 1
    def uvf(a, b): return (a / L, b / W)
    nc = int(W / SL_EXP)
    slates = []   # (a0, a1, b0, tone) for the image
    for c in range(nc):
        b0 = c * SL_EXP; b1 = min(W, b0 + SL_EXP + .02)
        x = -rng.uniform(0, .25) if c % 2 else -rng.uniform(.0, .12)
        while x < L:
            wd = rng.uniform(.2, .3); a0, a1 = max(0, x + .0018), min(L, x + wd - .0018); x += wd
            if a1 - a0 < .03: continue
            if rng.random() < .003: continue                       # a missing slate: the felt shows
            slip = rng.uniform(.03, .06) if rng.random() < .004 else 0
            hb = 2 * SL_TH + rng.normal(0, .0012); ht = SL_TH + rng.normal(0, .0008)
            dh = rng.normal(0, .0012, 4); da = rng.normal(0, .0012, 2)
            bb = max(0, b0 - slip)
            p = [(a0 + da[0], bb, hb + dh[0]), (a1 + da[1], bb, hb + dh[1]), (a1 + da[1], b1 - slip, ht + dh[2]), (a0 + da[0], b1 - slip, ht + dh[3])]
            i = [vert(*q) for q in p]; F.append(i); UV.append([uvf(q[0], q[1]) for q in p])
            # the slate's lower edge
            j = [vert(p[0][0], bb, SL_TH * .5), vert(p[1][0], bb, SL_TH * .5), i[1], i[0]]
            F.append(j); UV.append([uvf(p[0][0], bb - .004), uvf(p[1][0], bb - .004), uvf(p[1][0], bb - .002), uvf(p[0][0], bb - .002)])
            for (aa, k0, k1) in ((p[0][0], 0, 3), (p[1][0], 1, 2)):   # side edges
                s = [vert(aa, bb, SL_TH * .5), vert(aa, b1 - slip, SL_TH * .5), V and i[k1], i[k0]]
                if k0 == 1: s = s[::-1]
                F.append(s); UV.append([uvf(aa, bb)] * 4)
            slates.append((a0, a1, bb, b1 - slip, slip > 0))
    me = bpy.data.meshes.new(name); me.from_pydata(V, [], F); me.update()
    uvl = me.uv_layers.new(name='UVMap')
    for poly, uvs in zip(me.polygons, UV):
        for li, uvv in zip(poly.loop_indices, uvs): uvl.data[li].uv = uvv
    if me.polygons[0].normal.dot(n) < 0: me.flip_normals()
    ob = lib.link(bpy.data.objects.new(name, me))
    key = dict(n=name, L=round(L, 3), W=round(W, 3), seed=seed, north=north, ppm=ppm)
    paths = cached(key, ('a', 'n'), lambda: _slate_image(L, W, slates, seed, north, ppm))
    ob.data.materials.append(mat_maps(f'{name}_m', paths['a'], paths['n'], rough=.55, nstrength=1.0))
    return ob

def _slate_image(L, W, slates, seed, north, ppm):
    rng = np.random.default_rng(seed + 77)
    Wp, Hp = min(4096, int(L * ppm)), min(4096, int(W * ppm))
    sx, sy = Wp / L, Hp / W
    base = np.full((Hp, Wp), .55, np.float32); edge = np.zeros((Hp, Wp), np.float32)
    tone = np.zeros((Hp, Wp), np.float32)
    for (a0, a1, b0, b1, slipped) in slates:
        x0, x1 = int(a0 * sx), max(int(a0 * sx) + 1, int(a1 * sx))
        r1, r0 = Hp - int(b0 * sy), Hp - int(b1 * sy)   # rows (image top = ridge)
        r0 = max(0, r0); r1 = min(Hp, r1)
        if r1 <= r0: continue
        tone[r0:r1, x0:x1] = rng.normal(0, 1)
        base[r0:r1, x0:x1] = 1
        # darker toward the lower edge (the shadow it throws on the course below is in the row below)
        rr = np.arange(r0, r1); f = np.clip((rr - (r1 - .25 * sy * SL_EXP * 2)) / (.25 * sy * SL_EXP * 2), 0, 1)
        edge[r0:r1, x0:x1] = np.maximum(edge[r0:r1, x0:x1], f[:, None] * .25)
        if r1 < Hp: edge[r1:min(Hp, r1 + 3), x0:x1] = .7                     # shadow under its edge
        edge[r0:r1, max(0, x0 - 1):x0 + 1] = .6; edge[r0:r1, x1 - 1:min(Wp, x1 + 1)] = .6   # the gaps
    st = src('roof_slates_03', 'diff'); stl = lum(st); stl = (stl - stl.mean()) / (stl.std() + 1e-6)
    stone = tile_sample(stl[..., None], (Hp, Wp), ppm, 3.0, off=(rng.integers(0, 2048), rng.integers(0, 2048)))[..., 0]
    stone = ndimage.gaussian_filter(stone, .6)
    low = fbm((Hp, Wp), rng, scales=(int(1.5 * ppm), int(.4 * ppm)), weights=(1, .5))
    v = .17 * (1 + .14 * tone + .06 * stone + .05 * low)
    c = np.dstack([v * .93, v * .97, v * 1.05])
    # lichen (pale grey-green spots, clustered) and moss toward the eaves, more on the north slope
    Y = (Hp - np.arange(Hp))[:, None] / sy * np.ones((1, Wp))         # metres up from the eave
    cl = np.clip(fbm((Hp, Wp), rng, scales=(int(.8 * ppm), 30), weights=(1, .5)) * .8 + (north - .3), -3, 3)
    spots = (fbm((Hp, Wp), rng, scales=(3, 1), weights=(1, .4)) > 1.6 - .5 * np.clip(cl, 0, 2)).astype(np.float32)
    spots = ndimage.gaussian_filter(spots, .7)
    c = c * (1 - .7 * spots[..., None]) + np.array([.44, .46, .38]) * .7 * spots[..., None]
    moss = np.clip(np.exp(-Y / 1.2) * (.25 + .6 * north) + .25 * np.clip(cl - .8, 0, 1), 0, 1) * np.clip(.4 + .7 * fbm((Hp, Wp), rng, scales=(20, 5), weights=(1, .6)), 0, 1)
    moss = moss * (edge < .5)
    c = c * (1 - .6 * moss[..., None]) + np.array([.17, .20, .10]) * .6 * moss[..., None]
    # streaks down the slope
    stk = np.clip(fbm((Hp, Wp), rng, scales=(2, 1), weights=(1, .5), aniso=(60, 1)), 0, 3) * .06
    c *= (1 - stk)[..., None]
    c *= (1 - edge)[..., None]
    c[base < .9] = np.array([.05, .05, .05])                          # felt where a slate is missing
    hgt = .5 * stone + 2 * (base > .9) - 1.5 * edge
    return {'a': c, 'n': normal_from_height(ndimage.gaussian_filter(hgt, .6), 1.0)}

# ------------------------------------------------------------------ concrete foundation, ground
def concrete_mat(M):
    if 'ext_concrete' in M: return M['ext_concrete']
    def make():
        rng = np.random.default_rng(9); S = 1024
        g = src('forest_ground_04', 'diff', (S, S)); gl = lum(g); gl = (gl - gl.mean()) / gl.std()
        low = fbm((S, S), rng, scales=(160, 40, 8), weights=(1, .5, .3))
        v = .36 * (1 + .05 * gl + .06 * low)
        c = np.dstack([v, v * .98, v * .94])
        return {'a': c, 'n': normal_from_height(gl * .4, 1.0)}
    p = cached({'conc': 2}, ('a', 'n'), lambda: {k: _tileable(v) for k, v in make().items()})
    M['ext_concrete'] = mat_maps('ext_concrete', p['a'], p['n'], rough=.9)
    return M['ext_concrete']

def ph_mat(name, src_name, size=2048, tint=(1, 1, 1), rough=.9, alpha_fn=None, seed=0):
    """A Poly Haven texture as it is (resized, tinted), optionally with an alpha mask (tileable)."""
    def make():
        a = src(src_name, 'diff', (size, size)) * np.array(tint, np.float32)
        n = src(src_name, 'nor_gl', (size, size))
        out = {'a': a, 'n': n}
        if alpha_fn is not None: out['a'] = np.dstack([a, alpha_fn(np.random.default_rng(seed), size)])
        return out
    p = cached({'ph': name, 'src': src_name, 'size': size, 'tint': tint, 'alpha': alpha_fn is not None, 'seed': seed}, ('a', 'n'), make)
    return mat_maps(name, p['a'], p['n'], rough=rough, alpha=alpha_fn is not None)

def tileable_noise(rng, S, scale):
    """Periodic smooth noise (S x S), feature size `scale` pixels."""
    k = max(2, S // scale)
    g = rng.standard_normal((k, k)).astype(np.float32)
    big = ndimage.zoom(np.tile(g, (3, 3)), S / k, order=3, grid_mode=True, mode='grid-wrap')
    z = big[S:2 * S, S:2 * S]; z = (z - z.mean()) / (z.std() + 1e-6)
    return z
