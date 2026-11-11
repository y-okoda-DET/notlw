"""段階2 外（2026-11-05）: the land round the house for the whole-house scene (export_house.py), built on outside_geo.py.

  site(M, cut_house)  replaces house4_ext.site there: the ground (one triangulation, fine near the roads), the gravel
                      drive, the forest road (old asphalt, faded edge lines, a concrete gutter and a 間知ブロック
                      retaining wall on the cut side, the white guardrail with orange delineators on the fill side),
                      the shoulder that goes in the storm, Natsuki's car on the drive, the sugi along it all, the sky
                      ring pushed out.
The shoulder in its two states (export_house.set_time and main.gd _house_state switch them, times.STATE 'slip'):
  ext_slipok_*    before: a crack along the outer lane, the outer edge a few cm down, a cone someone put on it, the
                  road board 「路肩注意」 that was there long before tonight
  ext_slipfall_*  after: the outer lane gone, the asphalt broken off over its gravel bed, the slumped earth below, the
                  guardrail hanging into the gap from the posts either side, the cone down the slope
Everything is named ext_* (no baked light outside; house4.prune keeps it).
walk_boxes(), tree_trunks(): what scene.json needs so the outside can be walked (main.gd builds the ground's
collision from the meshes named in WALK_MESHES)."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P
import numpy as np
import bpy
from mathutils import Vector
import lib, exterior as X, trees
import outside_geo as G
from lib import prim, mat_basic

WALK_MESHES = ('ext_ground', 'ext_road', 'ext_drive', 'ext_slipok_ground', 'ext_slipfall_ground', 'ext_slipok_road', 'ext_slipfall_road')
SKY_R = 175.0

def _mesh(name, V, F, mat=None, uv=None, mats=None, fmat=None):
    me = bpy.data.meshes.new(name)
    V = np.asarray(V, np.float32); F = np.asarray(F, np.int32)
    me.vertices.add(len(V)); me.vertices.foreach_set('co', V.ravel())
    nl = F.shape[1]
    me.loops.add(len(F) * nl); me.loops.foreach_set('vertex_index', F.ravel())
    me.polygons.add(len(F)); me.polygons.foreach_set('loop_start', np.arange(0, len(F) * nl, nl, dtype=np.int32))
    me.update(calc_edges=True)
    if uv is not None:
        ul = me.uv_layers.new(name='UVMap'); ul.data.foreach_set('uv', np.asarray(uv, np.float32)[F.ravel()].ravel())
    for m in (mats or ([mat] if mat else [])): me.materials.append(m)
    if fmat is not None: me.polygons.foreach_set('material_index', np.asarray(fmat, np.int32))
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    return o

# ------------------------------------------------------------------ materials
def _desat(a, k, tint):
    l = X.lum(a)[..., None]; return (l + (a - l) * k) * np.array(tint, np.float32)

def mats(M):
    if 'ext_asphalt' in M: return
    def asphalt():
        S = 1024; rng = np.random.default_rng(21)
        a = _desat(X.src('worn_asphalt', 'diff', (S, S)), .25, (1.0, 1.02, 1.06))
        l = X.lum(a); a = a / max(l.mean(), 1e-3) * .27                # old asphalt, bleached: .27 (.2 printed as solid ink at dusk, 試作55)
        # patches: older and newer tar, a few repaired squares' worth of tone
        low = X.tileable_noise(rng, S, 180); a = a * (1 + .1 * low)[..., None]
        return {'a': a, 'n': X.src('worn_asphalt', 'nor_gl', (S, S))}
    p = X.cached({'asph': 3}, ('a', 'n'), asphalt)
    M['ext_asphalt'] = X.mat_maps('ext_asphalt', p['a'], p['n'], rough=.85)
    def soil():
        S = 1024
        a = X.src('excavated_soil_wall', 'diff', (S, S)) * np.array([.72, .66, .6], np.float32)
        return {'a': a, 'n': X.src('excavated_soil_wall', 'nor_gl', (S, S))}
    p = X.cached({'soil': 1}, ('a', 'n'), soil)
    M['ext_soil'] = X.mat_maps('ext_soil', p['a'], p['n'], rough=.95)
    def base():
        S = 512
        a = _desat(X.src('brown_mud_rocks_01', 'diff', (S, S)), .5, (.95, .92, .9)) * .9
        return {'a': a, 'n': X.src('brown_mud_rocks_01', 'nor_gl', (S, S))}
    p = X.cached({'roadbase': 1}, ('a', 'n'), base)
    M['ext_roadbase'] = X.mat_maps('ext_roadbase', p['a'], p['n'], rough=.95)
    p = X.cached({'kenchi': 3}, ('a', 'n'), kenchi_image)
    M['ext_kenchi'] = X.mat_maps('ext_kenchi', p['a'], p['n'], rough=.9)
    M['ext_gutter'] = M.get('ext_concrete') or X.concrete_mat(M)
    M['ext_rail'] = mat_basic('ext_rail', (.6, .6, .58), .45, metal=.2)          # white paint: .6 (paper-white at .75)
    M['ext_railpost'] = mat_basic('ext_railpost', (.52, .52, .5), .5, metal=.2)
    M['ext_reflect'] = mat_basic('ext_reflect', (.75, .3, .04), .3, emit=(.75, .3, .04), estr=.15)
    M['ext_line'] = mat_basic('ext_line', (.5, .5, .47), .85)
    M['ext_crack'] = mat_basic('ext_crack', (.015, .014, .013), .95)
    M['ext_cone'] = mat_basic('ext_cone', (.8, .12, .05), .5)          # .55 red printed as ink in the shade (試作55)
    M['ext_conew'] = mat_basic('ext_conew', (.72, .72, .7), .4)
    M['ext_spray'] = mat_basic('ext_spray', (.68, .68, .64), .7)
    M['ext_coneb'] = mat_basic('ext_coneb', (.03, .03, .03), .8)
    M['ext_signpost'] = mat_basic('ext_signpost', (.5, .5, .5), .5, metal=.5)
    M['ext_sign'] = X.mat_maps('ext_sign', X.cached({'sign': 2}, ('a',), sign_image)['a'], None, rough=.5)

def kenchi_image():
    """間知ブロックの谷積み: square concrete blocks laid on the diagonal, a diamond net of mortar, damp and moss coming down
    from the slope above, and a black PVC weep hole (水抜き穴) with a dark streak below it. Tile: 6 blocks (2.97 m)."""
    S = 1024; rng = np.random.default_rng(5)
    bs = .35; T = bs * math.sqrt(2) * 6
    u, v = np.meshgrid(np.arange(S) / S * T, np.arange(S) / S * T)
    v = T - v                                                  # image row 0 is the top of the tile
    p = (u + v) / math.sqrt(2) / bs; q = (u - v) / math.sqrt(2) / bs
    fp, fq = p - np.floor(p), q - np.floor(q)
    ip, iq = np.floor(p).astype(int) % 12, np.floor(q).astype(int) % 12
    jitter = rng.normal(0, 1, (12, 12))
    edge = np.minimum(np.minimum(fp, 1 - fp), np.minimum(fq, 1 - fq))   # 0 at the joints
    mortar = edge < .035
    dome = np.clip(edge / .2, 0, 1) ** .5
    gl = X.lum(X.src('concrete_moss', 'diff', (S, S))); gl = (gl - gl.mean()) / gl.std()
    base = .44 + .035 * jitter[ip, iq] + .025 * gl
    base = np.where(mortar, .3, base)
    # damp from the top down (the wall is under the slope's water), streaks
    streak = X.tileable_noise(rng, S, 22)
    streak = np.clip(np.repeat(streak[:1, :], S, 0) * .5 + X.tileable_noise(rng, S, 120) * .5, 0, None)
    wet = np.clip((v / T - .45) * 1.8, 0, 1) * (.5 + .5 * np.clip(streak, 0, 1.5))
    # weep hole at u .6 T, height .55 m; its stain down to the foot
    hx, hy = .5 * T, .55
    r = np.hypot(u - hx, v - hy)
    stain = np.exp(-((u - hx) / .07) ** 2) * (v < hy) * np.clip(1 - (hy - v) / .55, .3, 1)
    c = np.dstack([base, base * .985, base * .95])
    moss = np.array([.17, .2, .13], np.float32)
    mm = np.clip(wet * (1 - dome * .4) + .25 * np.clip(gl, 0, None) * (v / T > .3), 0, .85)[..., None]
    c = c * (1 - mm) + moss * mm
    c = c * (1 - .45 * stain[..., None])
    c = np.where((r < .045)[..., None], .03, c)
    c = np.where(((r >= .045) & (r < .06))[..., None], .32, c)
    hgt = dome * 1.0 - mortar * .6 + .05 * gl - (r < .05) * 1.5
    return {'a': c, 'n': X.normal_from_height(hgt, 3.0)}

def sign_image():
    """the road board: 「路肩注意」 in red on white, written down the board (the old municipal kind, a red border)"""
    from PIL import Image, ImageDraw, ImageFont
    W, H = 300, 900
    im = Image.new('RGB', (W, H), (150, 150, 145)); d = ImageDraw.Draw(im)
    d.rectangle([10, 10, W - 11, H - 11], outline=(120, 22, 18), width=14)
    f = None
    for path in ('/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc', '/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc'):
        if os.path.exists(path): f = ImageFont.truetype(path, 170); break
    for k, ch in enumerate('路肩注意'):
        d.text((W / 2, 130 + k * 200), ch, font=f, fill=(128, 22, 16), anchor='mm')
    a = np.asarray(im, np.float32) / 255
    rng = np.random.default_rng(3)
    a = a * (1 - .08 * np.clip(X.fbm(a.shape[:2], rng, scales=(60, 15, 4)), -1, 1))[..., None]   # weathered
    a[-120:] *= np.linspace(1, .8, 120)[:, None, None]                                          # rain splash at the foot
    return {'a': a}

# ------------------------------------------------------------------ the ground
def _ground_points(cut_house):
    pts = []
    C = np.array(G.HC)
    g = np.arange(-SKY_R, SKY_R + .1, 5.0); xx, yy = np.meshgrid(g + C[0], g + C[1]); pts.append(np.c_[xx.ravel(), yy.ravel()])
    g = np.arange(-70, 140, 1.5); xx, yy = np.meshgrid(g, g - 30); m = np.c_[xx.ravel(), yy.ravel()]
    dr, _, _ = G.ROAD.query(m[:, 0], m[:, 1]); dd, _, _ = G.DRIVE.query(m[:, 0], m[:, 1])
    pts.append(m[(dr < 45) | (dd < 30)])
    g = np.arange(-70, 140, .5); xx, yy = np.meshgrid(g, g - 30); m = np.c_[xx.ravel(), yy.ravel()]
    dr, _, ir = G.ROAD.query(m[:, 0], m[:, 1]); dd, _, _ = G.DRIVE.query(m[:, 0], m[:, 1])
    hb = (m[:, 0] > G.HX0 - 14) & (m[:, 0] < G.HX1 + 14) & (m[:, 1] > G.HYN - 12) & (m[:, 1] < G.HYS + 14)
    pts.append(m[(dr < G.ROAD.hw + 7) | (dd < G.DRIVE.hw + 6) | hb])
    # the road's own edges exact (the asphalt's edge and the wall's foot lie on vertices)
    for road, offs in ((G.ROAD, (-G.ROAD.hw - .5, -G.ROAD.hw, G.ROAD.hw, G.ROAD.hw + .5)), (G.DRIVE, (-G.DRIVE.hw, G.DRIVE.hw))):
        idx = np.arange(0, len(road.s), 2)
        for o in offs: pts.append(road.P[idx] + road.N[idx] * o)
    P2 = np.concatenate(pts)
    P2 = P2[np.hypot(P2[:, 0] - C[0], P2[:, 1] - C[1]) < SKY_R + 2]
    edge = None
    if cut_house:
        # 試作98 (ユーザー「外、このへん描画が崩れる」, under the back porch): the outline's points were thinned away by the
        # 15 cm rule below in favour of the 50 cm grid, so the hole under the house followed the grid's triangles, not the
        # walls, and gaped up to half a metre past the foundation on the east, where the ground falls: the sky showed
        # through it. Now the outline is kept, every 25 cm, and nothing else lies inside it or within 20 cm of it
        ex = np.linspace(G.HX0, G.HX1, max(2, int(np.ceil((G.HX1 - G.HX0) / .25)) + 1))
        ey = np.linspace(G.HYN, G.HYS, max(2, int(np.ceil((G.HYS - G.HYN) / .25)) + 1))
        edge = np.unique(np.round(np.concatenate([np.c_[ex, np.full_like(ex, G.HYN)], np.c_[ex, np.full_like(ex, G.HYS)],
                                                  np.c_[np.full_like(ey, G.HX0), ey], np.c_[np.full_like(ey, G.HX1), ey]]), 3), axis=0)
        dx = np.maximum(np.maximum(G.HX0 - P2[:, 0], P2[:, 0] - G.HX1), 0); dy = np.maximum(np.maximum(G.HYN - P2[:, 1], P2[:, 1] - G.HYS), 0)
        P2 = P2[np.hypot(dx, dy) > .2]
    P2 = np.unique(np.round(P2, 2), axis=0)
    # no point a hair from another (the triangulation makes slivers): drop the later of any pair closer than 15 cm
    from scipy.spatial import cKDTree
    kd = cKDTree(P2); drop = set()
    for i, j in kd.query_pairs(.15):
        if i not in drop: drop.add(j)
    keep = np.ones(len(P2), bool); keep[list(drop)] = False
    P2 = P2[keep]
    return P2 if edge is None else np.concatenate([P2, edge])

def ground(M, cut_house):
    from scipy.spatial import Delaunay
    P2 = _ground_points(cut_house)
    tri = Delaunay(P2).simplices
    cen = P2[tri].mean(axis=1)
    keep = np.hypot(cen[:, 0] - G.HC[0], cen[:, 1] - G.HC[1]) < SKY_R
    if cut_house:
        keep &= ~((cen[:, 0] > G.HX0) & (cen[:, 0] < G.HX1) & (cen[:, 1] > G.HYN) & (cen[:, 1] < G.HYS))
    tri = tri[keep]; cen = cen[keep]
    # counter-clockwise from above
    a, b, c = P2[tri[:, 0]], P2[tri[:, 1]], P2[tri[:, 2]]
    cw = (b[:, 0] - a[:, 0]) * (c[:, 1] - a[:, 1]) - (b[:, 1] - a[:, 1]) * (c[:, 0] - a[:, 0]) < 0
    tri[cw] = tri[cw][:, [0, 2, 1]]
    z_ok = G.final(P2[:, 0], P2[:, 1], 'ok')
    z_fall = z_ok - G.slip_depth(P2[:, 0], P2[:, 1])
    slip = G.slip_region(cen[:, 0], cen[:, 1])
    dr, _, _ = G.ROAD.query(cen[:, 0], cen[:, 1]); dd, _, _ = G.DRIVE.query(cen[:, 0], cen[:, 1])
    uv = P2 / 3.0
    def part(name, mask, z, mats, fmat=None, lift=0.0, uvs=uv):
        t = tri[mask]; used = np.unique(t); remap = -np.ones(len(P2), int); remap[used] = np.arange(len(used))
        V = np.c_[P2[used], z[used] + lift]
        return _mesh(name, V, remap[t], mats=mats, uv=uvs[used], fmat=None if fmat is None else fmat[mask])
    part('ext_ground', ~slip, z_ok, [M['ext_ground']])
    part('ext_slipok_ground', slip, z_ok, [M['ext_ground']])
    raw = (z_ok - z_fall)[tri].max(axis=1) > .05
    part('ext_slipfall_ground', slip, z_fall, [M['ext_ground'], M['ext_soil']], fmat=raw.astype(int))
    # fallen needles and leaves over the forest floor (not on the roads, nor on the raw earth)
    lit = ~slip & (dr > G.ROAD.hw + .8) & (dd > G.DRIVE.hw + .3)
    part('ext_litter', lit, z_ok, [M['ext_litter']], lift=.008, uvs=P2 / 4.0)

# ------------------------------------------------------------------ the roads
def _strip(name, road, idx, offs, zoff, mat, uvscale=4.0, edge_fn=None, zfn=None):
    """a surface following the road over stations idx, across at offsets offs (or edge_fn(i) -> offsets)"""
    V = []; UV = []; F = []
    n = None
    for k, i in enumerate(idx):
        o = edge_fn(i) if edge_fn else offs
        n = len(o)
        for a in o:
            p = road.P[i] + road.N[i] * a
            V.append((p[0], p[1], road.z[i] + zoff + (zfn(i, a) if zfn else 0))); UV.append((a / uvscale, road.s[i] / uvscale))
        if k:
            b0, b1 = (k - 1) * n, k * n
            for j in range(n - 1): F.append((b0 + j, b0 + j + 1, b1 + j + 1, b1 + j))
    # the strip runs the road's way; faces must face up
    F = [f if True else f for f in F]
    o = _mesh(name, V, F, mat=mat, uv=UV)
    o.data.update();
    if o.data.polygons and o.data.polygons[0].normal.z < 0: o.data.flip_normals()
    return o

def _runs(mask):
    out = []; i = 0; n = len(mask)
    while i < n:
        if mask[i]:
            j = i
            while j < n and mask[j]: j += 1
            out.append((i, j)); i = j
        else: i += 1
    return out

def roads(M):
    R, D = G.ROAD, G.DRIVE
    st = 4                                                   # every metre
    a0 = G.SLIP_IDX - int((G.SLIP_HALF + 1.5) / R.step); a0 -= a0 % st
    a1 = G.SLIP_IDX + int((G.SLIP_HALF + 1.5) / R.step); a1 += st - a1 % st
    hw = R.hw; full = np.linspace(-hw, hw, 5)
    main = [i for i in range(0, len(R.s), st)]
    if main[-1] != len(R.s) - 1: main.append(len(R.s) - 1)
    for nm, part in (('ext_road', [i for i in main if i <= a0]), ('ext_road', [i for i in main if i >= a1])):
        _strip(nm, R, part, full, 0.0, M['ext_asphalt'])
    sl = list(range(a0, a1 + 1))
    out = G.SLIP_SIDE
    # before: the outer slab has already settled a few cm along a crack where it will break (the step and the crack
    # read in the print; a hairline did not, 試作55)
    def crack_e(i):
        return min(float(G.scarp_edge(G.slip_u(i))) + .05, hw - .1)
    def drop(i):
        u = float(G.slip_u(i)); return .055 * max(0.0, 1 - (u / G.SLIP_HALF) ** 2) ** .8
    def ok_offs2(i):
        e = crack_e(i)
        return sorted([-hw * out, -hw / 2 * out, 0, e * .5 * out, e * out, (e + .035) * out, hw * out])
    def ok_z(i, a):
        e = crack_e(i)
        return -drop(i) * min(1.0, max(0.0, (abs(a) - e) / .035)) if a * out > 0 else 0.0
    _strip('ext_slipok_road', R, sl, None, 0.0, M['ext_asphalt'], edge_fn=ok_offs2, zfn=ok_z)
    V = []; F = []
    for k, i in enumerate(sl):
        e = crack_e(i); d = drop(i)
        for (a, dz) in ((e - .004, .002), (e + .035, -d + .002)):
            p = R.P[i] + R.N[i] * out * a; V.append((p[0], p[1], R.z[i] + dz))
        if k: F.append((len(V) - 4, len(V) - 3, len(V) - 1, len(V) - 2))
    o = _mesh('ext_slipok_crack', V, F, mat=M['ext_crack']); _up(o)
    # the road crew's white spray paint round the crack (道路管理者のマーキング): the line on the road side stays after the
    # bank goes, cut off at the broken edge; the outer line and the ends go with it
    def mark_line(name, ii, afn):
        V = []; F = []
        for k, i in enumerate(ii):
            a = afn(i)
            for w in (-.03, .03):
                p = R.P[i] + R.N[i] * out * (a + w); V.append((p[0], p[1], R.z[i] + ok_z(i, (a + w) * out) + .005))
            if k: F.append((len(V) - 4, len(V) - 3, len(V) - 1, len(V) - 2))
        o = _mesh(name, V, F, mat=M['ext_spray']); _up(o); return o
    mi = [i for i in sl if abs(float(G.slip_u(i))) < 5.2]
    mark_line('ext_slipmark', mi, lambda i: float(G.scarp_edge(G.slip_u(i))) - .3 if abs(float(G.slip_u(i))) < 4.6 else
              float(G.scarp_edge(G.slip_u(i))) - .3)
    mark_line('ext_slipok_mark', mi, lambda i: hw - .35)
    for ie in (mi[0], mi[-1]):   # the ends, across the lane
        V = []; F = []
        a0_ = float(G.scarp_edge(G.slip_u(ie))) - .3; a1_ = hw - .35
        for k, a in enumerate(np.linspace(min(a0_, a1_), max(a0_, a1_), 6)):
            for w in (-.03, .03):
                p = R.P[ie] + R.N[ie] * out * a + R.T[ie] * w; V.append((p[0], p[1], R.z[ie] + ok_z(ie, a * out) + .005))
            if k: F.append((len(V) - 4, len(V) - 3, len(V) - 1, len(V) - 2))
        _up(_mesh('ext_slipok_mark', V, F, mat=M['ext_spray']))
    # after: the road only to the broken edge
    def fall_offs2(i):
        e = min(float(G.scarp_edge(G.slip_u(i))), hw)
        lo = [-hw * out, -hw / 2 * out, 0, e * .5 * out, e * out]
        return sorted(lo)
    _strip('ext_slipfall_road', R, sl, None, 0.0, M['ext_asphalt'], edge_fn=fall_offs2)
    # the broken edge: the asphalt's 6 cm, the gravel bed under it
    V = []; F = []; UV = []; FM = []
    for k, i in enumerate(sl):
        e = min(float(G.scarp_edge(G.slip_u(i))), hw)
        p = R.P[i] + R.N[i] * out * e; z = R.z[i]
        for dz in (0, -.065, -.07, -.38):
            q = p + R.N[i] * out * (.02 if dz < -.3 else 0)
            V.append((q[0], q[1], z + dz)); UV.append((R.s[i] / 1.5, dz / 1.5))
        if k:
            b0, b1 = (k - 1) * 4, k * 4
            for j, m in ((0, 0), (2, 1)):
                F.append((b0 + j, b1 + j, b1 + j + 1, b0 + j + 1)); FM.append(m)
    o = _mesh('ext_slipfall_edge', V, F, mats=[M['ext_asphalt'], M['ext_roadbase']], uv=UV, fmat=FM)
    _fix_out(o, R.P[G.SLIP_IDX] + R.N[G.SLIP_IDX] * out * 8)
    # faded edge lines (外側線), worn into pieces
    rng = np.random.default_rng(12)
    for side in (-1, 1):
        V = []; F = []; i = 0
        while i < len(R.s) - 8:
            L = int(rng.uniform(1.0, 3.5) / R.step); gap = int(rng.uniform(.1, 1.2) / R.step)
            seg = list(range(i, min(i + L, len(R.s) - 1), 2))
            if len(seg) > 1 and not (a0 - 4 <= i <= a1 + 4 and side == out):
                for k, j in enumerate(seg):
                    for a in (hw - .32, hw - .2):
                        p = R.P[j] + R.N[j] * side * a; V.append((p[0], p[1], R.z[j] + .003))
                    if k: n0 = len(V) - 4; F.append((n0, n0 + 1, n0 + 3, n0 + 2))
            i += L + gap
        o = _mesh(f'ext_roadline', V, F, mat=M['ext_line']); _up(o)
    # the drive: gravel, down to the road
    _strip('ext_drive', D, list(range(0, len(D.s), 2)) + [len(D.s) - 1], np.linspace(-D.hw, D.hw, 5), -.01, M['ext_gravel'], uvscale=2.0)
    return a0, a1

def _up(o):
    if o.data.polygons and o.data.polygons[0].normal.z < 0: o.data.flip_normals()

def _fix_out(o, toward):
    """turn the faces of a wall-like mesh to face the point `toward`"""
    me = o.data; me.update()
    bad = 0
    for p in me.polygons:
        c = Vector((toward[0], toward[1], toward[2] if len(toward) > 2 else p.center.z))
        if (c - p.center).dot(p.normal) < 0: bad += 1
    if bad > len(me.polygons) / 2: me.flip_normals()

def walls_and_rails(M, a0, a1):
    R = G.ROAD; hw = R.hw; out = G.SLIP_SIDE
    idx = np.arange(0, len(R.s), 2)
    upL = np.array([float(G.side_heights(R, i, 1)) for i in idx]); upR = np.array([float(G.side_heights(R, i, -1)) for i in idx])
    away = np.abs(R.s[idx] - R.s[G.J_IDX]) > G.J_GAP          # the drive's mouth: open
    for side, up in ((1, upL), (-1, upR)):
        cut = (up > 0) & away
        # the gutter along the cut side's foot
        for (b, e) in _runs(cut):
            if e - b < 3: continue
            ii = idx[b:e]
            prof = [(hw, 0), (hw + .06, 0), (hw + .06, -.32), (hw + .4, -.32), (hw + .4, 0), (hw + .5, 0)]
            V = []; F = []; UV = []
            for k, i in enumerate(ii):
                for (a, dz) in prof:
                    p = R.P[i] + R.N[i] * side * a; V.append((p[0], p[1], R.z[i] + dz + .002)); UV.append((R.s[i] / 2, (a + dz) / 2))
                if k:
                    n = len(prof); b0, b1 = (k - 1) * n, k * n
                    for j in range(n - 1): F.append((b0 + j, b0 + j + 1, b1 + j + 1, b1 + j))
            o = _mesh('ext_gutter', V, F, mat=M['ext_gutter'], uv=UV)
            if o.data.polygons[0].normal.z < 0 and False: o.data.flip_normals()
            _fix_up(o)
        # the retaining wall where the cut is more than a step
        W = np.clip(up - .3, 0, G.WALL_MAX)
        for (b, e) in _runs((W > .08) & away):
            if e - b < 4: continue
            ii = idx[b:e]; ww = W[b:e]
            V = []; F = []; UV = []
            for k, (i, w) in enumerate(zip(ii, ww)):
                lean = .3 * w
                for (a, dz) in ((hw + .5, -.05), (hw + .5 + lean, w), (hw + .5 + lean + .18, w + .02)):
                    p = R.P[i] + R.N[i] * side * a; V.append((p[0], p[1], R.z[i] + dz)); UV.append((R.s[i], R.z[i] + dz))
                if k:
                    b0, b1 = (k - 1) * 3, k * 3
                    for j in range(2): F.append((b0 + j, b0 + j + 1, b1 + j + 1, b1 + j))
            # UV: along the road in metres, up the face in metres; the image tile is 2.97 m
            UV = [(u / 2.97, v / 2.97) for (u, v) in UV]
            o = _mesh('ext_rwall', V, F, mat=M['ext_kenchi'], uv=UV)
            mid = ii[len(ii) // 2]; _fix_out(o, R.P[mid] - R.N[mid] * side * 3 + 0)
    # guardrail on the fill side where the bank drops more than a metre
    for side, up in ((1, upL), (-1, upR)):
        fill = up < -1.0
        runs = [(b, e) for (b, e) in _runs(fill) if (e - b) * 2 * R.step > 8]
        for (b, e) in runs:
            b = max(0, b - 4); e = min(len(idx), e + 4)
            ii = [int(i) for i in idx[b:e]]
            if side == out:
                pre = [i for i in ii if i <= a0]; post = [i for i in ii if i >= a1]; mid = [i for i in ii if a0 <= i <= a1]
                if mid:
                    for seg in (pre, post):
                        if len(seg) > 1: rail(M, seg, side, 'ext_rail')
                    rail(M, mid, side, 'ext_slipok_rail')
                    rail(M, mid, side, 'ext_slipfall_rail', fallen=True)
                    continue
            rail(M, ii, side, 'ext_rail')

def _fix_up(o):
    pass

W_PROF = [(0, .52), (.03, .55), (.05, .6), (.02, .655), (.02, .705), (.05, .76), (.03, .81), (0, .84)]   # (out, up) of the beam
def rail(M, ii, side, name, fallen=False):
    """the W-beam on posts every 2 m; with `fallen` the middle hangs down into the gap"""
    R = G.ROAD; hw = R.hw; a_r = hw + .28
    V = []; F = []; UV = []
    sag_of = lambda i: 0.0
    if fallen:
        def sag_of(i):
            u = float(G.slip_u(i)); t = max(0.0, 1 - (u / (G.SLIP_HALF + .8)) ** 2)
            return t
    for k, i in enumerate(ii):
        t = sag_of(i)
        for (o, h) in W_PROF:
            p = R.P[i] + R.N[i] * side * (a_r + o + 1.1 * t)
            z = R.z[i] + h - 2.3 * t ** 1.3
            V.append((p[0], p[1], z)); UV.append((R.s[i], h))
        if k:
            n = len(W_PROF); b0, b1 = (k - 1) * n, k * n
            for j in range(n - 1): F.append((b0 + j, b0 + j + 1, b1 + j + 1, b1 + j))
    o = _mesh(name + '_beam', V, F, mat=M['ext_rail'], uv=UV)
    mid = ii[len(ii) // 2]; _fix_out(o, R.P[mid])
    lib.smooth(o, 50)
    # posts, and a round orange reflector on every fourth
    every = int(2.0 / R.step)
    nposts = 0
    for i in ii:
        if i % every: continue
        t = sag_of(i)
        p = R.P[i] + R.N[i] * side * (a_r + .14)
        if t > .15:     # torn out with the bank: hangs off the beam, tipped down the slope
            p2 = R.P[i] + R.N[i] * side * (a_r + .2 + 1.1 * t)
            z = R.z[i] + .55 - 2.3 * t ** 1.3
            d = R.N[i] * side
            prim('cylinder', name + '_post', loc=(p2[0] + d[0] * .25, p2[1] + d[1] * .25, z - .45), rot=(d[1] * .7, -d[0] * .7, 0),
                 scale=(.07, .07, .6), mat=M['ext_railpost'], vertices=10)
            continue
        prim('cylinder', name + '_post', loc=(p[0], p[1], R.z[i] + .3), scale=(.07, .07, .7), mat=M['ext_railpost'], vertices=10)
        prim('cylinder', name + '_cap', loc=(p[0], p[1], R.z[i] + 1.0), scale=(.075, .075, .012), mat=M['ext_railpost'], vertices=10)
        if nposts % 4 == 0:
            q = R.P[i] + R.N[i] * side * (a_r - .02)
            rot = math.atan2(R.T[i][1], R.T[i][0])
            prim('cylinder', name + '_refl', loc=(q[0], q[1], R.z[i] + 1.12), rot=(math.pi / 2, 0, rot), scale=(.05, .05, .01), mat=M['ext_reflect'], vertices=16)
            prim('cylinder', name + '_reflstem', loc=(p[0], p[1], R.z[i] + 1.06), scale=(.012, .012, .06), mat=M['ext_railpost'], vertices=6)
        nposts += 1

def slip_props(M):
    R = G.ROAD; out = G.SLIP_SIDE; i0 = G.SLIP_IDX; hw = R.hw
    # the board, 「路肩注意」, at the shoulder before the bend (it stays: it stands just past where the bank goes)
    ib = i0 - int(9.5 / R.step)                       # on the outside, behind the guardrail, before the bend going down
    p = R.P[ib] + R.N[ib] * out * (hw + .75)
    yaw = math.atan2(R.T[ib][1], R.T[ib][0])
    prim('cylinder', 'ext_signpole', loc=(p[0], p[1], R.z[ib] + .9), scale=(.03, .03, 1.0), mat=M['ext_signpost'], vertices=10)
    s = prim('cube', 'ext_signboard', loc=(p[0], p[1], R.z[ib] + 1.25), rot=(0, 0, yaw + math.pi / 2), scale=(.15, .012, .45), mat=M['ext_sign'])
    _sign_uv(s)
    # the cone: before, on the crack; after, down the slumped bank on its side
    i = i0 - int(1.5 / R.step)
    e = float(G.scarp_edge(G.slip_u(i)))
    p = R.P[i] + R.N[i] * out * (e + .25)
    cone('ext_slipok_cone', M, (p[0], p[1], R.z[i]), (0, 0, .3))
    p = R.P[i0] + R.N[i0] * out * (hw + 5.5)
    z = float(np.ravel(G.final(p[0], p[1], 'ok') - G.slip_depth(p[0], p[1]))[0])
    cone('ext_slipfall_cone', M, (p[0], p[1], z + .17), (1.45, .3, 1.1))
    # broken asphalt down the slope
    rng = np.random.default_rng(31)
    for k in range(7):
        u = rng.uniform(-4, 4); i = i0 + int(u / R.step)
        a = hw + rng.uniform(1.0, 6.5)
        p = R.P[i] + R.N[i] * out * a
        z = float(np.ravel(G.final(p[0], p[1], 'ok') - G.slip_depth(p[0], p[1]))[0])
        sx, sy = rng.uniform(.25, .7), rng.uniform(.2, .5)
        o = prim('cube', 'ext_slipfall_chunk', loc=(p[0], p[1], z + .02), rot=(rng.normal(0, .5), rng.normal(0, .5), rng.uniform(0, 6.3)),
                 scale=(sx, sy, .045), mat=M['ext_asphalt'])
        lib.uv_box(o, 4.0)

def _sign_uv(o):
    me = o.data; ul = me.uv_layers.get('UVMap') or me.uv_layers.new(name='UVMap')
    for p in me.polygons:
        for li in p.loop_indices:
            v = me.vertices[me.loops[li].vertex_index].co
            ul.data[li].uv = ((v.x + 1) / 2, (v.z + 1) / 2)

def cone(name, M, loc, rot):
    """a road cone (カラーコーン): red, a white reflective band, a black square foot"""
    from mathutils import Matrix, Euler
    parts = []
    parts.append(prim('cube', name, loc=(0, 0, .02), scale=(.19, .19, .02), mat=M['ext_coneb']))
    parts.append(prim('cone', name, loc=(0, 0, .37), scale=(.15, .15, .33), mat=M['ext_cone'], vertices=16, radius1=1, radius2=.15))
    parts.append(prim('cylinder', name, loc=(0, 0, .46), scale=(.083, .083, .07), mat=M['ext_conew'], vertices=16))
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]; bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active; o.name = name
    o.location = loc; o.rotation_euler = rot
    return o

# ------------------------------------------------------------------ the car
def car(M):
    import furnish as F
    D = G.DRIVE
    i = int(round(6.3 / D.step)); t = D.T[i]
    p = D.P[i] + D.N[i] * .35
    # nose up the drive to the house (Tripo's front is -Y)
    rz = math.atan2(-t[0], t[1]) + math.pi
    g = (D.z[i - 8] - D.z[i + 8]) / (16 * D.step)
    o = F.tripo_prop('car', (p[0], p[1], D.z[i] - .02), rz, 4.0, name='ext_car')
    if o:
        o.rotation_euler = (-math.atan(g), 0, rz)
        if o.data.materials:
            for k, m in enumerate(o.data.materials): pass
    return o, (p[0], p[1], D.z[i]), rz

# ------------------------------------------------------------------ trees and sky
def plant(M):
    R, D = G.ROAD, G.DRIVE
    def keep(x, y):
        if (G.HX0 - 6 < x < G.HX1 + 6) and (G.HYN - 5 < y < G.HYS + 8): return False      # the clearing round the house
        if y > G.HYS - 1 and abs(x) < 9 and y < 22: return False                          # the view from the porch
        dr, sr, ir = R.query(x, y); dr = float(dr[0])
        dd = float(D.query(x, y)[0][0])
        if dd < D.hw + 1.6: return False
        if dr < R.hw + 1.2: return False
        if dr < R.hw + 3.5 and float(G.side_heights(R, int(ir[0]), int(sr[0]))) > .3: return False   # on top of the retaining wall
        if bool(np.ravel(G.slip_region(x, y, pad=1.5))[0]): return False
        if dr > 40 and math.hypot(x - G.HC[0], y - G.HC[1]) > 34: return False
        return True
    gz = lambda x, y: float(np.ravel(G.final(x, y, 'ok'))[0])
    return trees.sugi_stand(M, centre=G.HC, r0=10.0, r1=130.0, keep=keep, ground=gz, seed=7, n_unique=14, spacing=3.0)

def sky(M):
    """house4_ext's sky ring, pushed out past the woods (the near wall of trees is real now)"""
    R, n = SKY_R, 96
    rings = ((R, -75.0, 0.0), (R, 38.0, 1.0), (R * .7, 110.0, 1.0), (R * .05, 140.0, 1.0))
    v = []; f = []; uvs = []
    cx, cy = G.HC
    for i in range(n + 1):
        a = i / n * math.tau
        for (r, z, vv) in rings: v.append((cx + r * math.cos(a), cy + r * math.sin(a), z)); uvs.append((i / n * 3, vv))
    k = len(rings)
    for i in range(n):
        for j in range(k - 1): f.append((k * i + j, k * i + j + 1, k * (i + 1) + j + 1, k * (i + 1) + j))
    o = lib.mesh_obj('ext_sky', v, f); o.data.materials.append(M['ext_sky']); o.visible_shadow = False
    o.data.uv_layers.new(); uv = o.data.uv_layers[0].data
    for p in o.data.polygons:
        for li, vi in zip(p.loop_indices, p.vertices): uv[li].uv = uvs[vi]

def site(M, cut_house=False):
    mats(M)
    ground(M, cut_house)
    a0, a1 = roads(M)
    walls_and_rails(M, a0, a1)
    slip_props(M)
    car(M)
    sky(M)
    n = plant(M)
    print('outside: ground, roads, slip, car, trees', n, flush=True)

# ------------------------------------------------------------------ for scene.json
def walk_boxes(cell=1.0):
    """unseen walls round where one may walk: a box on every edge between a walkable and an unwalkable cell"""
    xs = np.arange(-30, 100, cell); ys = np.arange(-20, 112, cell)
    X2, Y2 = np.meshgrid(xs + cell / 2, ys + cell / 2)
    W = G.walkable(X2, Y2)
    Z = G.final(X2, Y2, 'ok')
    boxes = []
    ny, nx = W.shape
    for j in range(ny):
        for i in range(nx):
            if not W[j, i]: continue
            for (dj, di) in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                jj, ii = j + dj, i + di
                if 0 <= jj < ny and 0 <= ii < nx and W[jj, ii]: continue
                cx = xs[i] + cell / 2 + di * cell / 2; cy = ys[j] + cell / 2 + dj * cell / 2
                z = float(Z[j, i])
                sx, sy = (.1, cell + .1) if di else (cell + .1, .1)
                boxes.append(dict(c=[round(float(cx), 3), round(float(cy), 3), round(z + 1.0, 3)], s=[sx, sy, 4.0]))
    # in the storm's state: no walking into the gap
    R = G.ROAD; out = G.SLIP_SIDE
    for u in np.arange(-G.SLIP_HALF - 1, G.SLIP_HALF + 1.01, .5):
        i = G.SLIP_IDX + int(u / R.step); e = min(float(G.scarp_edge(u)), R.hw) - .15
        p = R.P[i] + R.N[i] * out * e
        boxes.append(dict(c=[round(float(p[0]), 3), round(float(p[1]), 3), round(float(R.z[i]) + 1.0, 3)], s=[.6, .6, 4.0], times=['t02', 't0330', 't0430']))
    return boxes

def tree_trunks():
    """the trunks one can walk up to (in or beside the walkable ground): cylinders"""
    out = []
    for o in bpy.data.objects:
        if o.name.startswith('ext_sugi') and o.type == 'MESH' and o.location.z > -50:
            x, y = o.location.x, o.location.y
            near = G.walkable(np.array([[x - 1.2, x + 1.2], [x - 1.2, x + 1.2]]), np.array([[y - 1.2, y - 1.2], [y + 1.2, y + 1.2]])).any()
            if near: out.append([round(x, 3), round(y, 3), round(.3 * o.scale.x, 3)])
    # trunk and foliage share a location: one each
    seen = set(); res = []
    for t in out:
        k = (t[0], t[1])
        if k not in seen: seen.add(k); res.append(t)
    return res

def car_boxes():
    """the car as three boxes along its length (main.gd's boxes are not turned)"""
    D = G.DRIVE; i = int(round(6.3 / D.step)); p = D.P[i] + D.N[i] * .35
    out = []
    for f in (-1.35, 0, 1.35):
        q = p + D.T[i] * f
        out.append(dict(c=[round(float(q[0]), 3), round(float(q[1]), 3), round(float(D.z[i]) + .8, 3)], s=[1.75, 1.75, 1.6]))
    return out
