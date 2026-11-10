"""The outside of the plan-v4 house (house4.py builds the inside): white lap siding board by board, slate roof,
window casings and shutters, the front porch, the back porch and its stair down the slope, the foundation, the
ground falling away to the east (the cellar's east wall stands out of it with its small window), the stove chimney,
the sugi plantation and the sky ring.  Entry: build_ext4(M), after house4.build_house4(M, ...).
Everything is named ext_* (house4.prune keeps it; export_godot leaves it out of the baked lightmap).
Walls follow house4's rule: centre line ± .06; the outside face of the siding sits beyond centre + .06.
Heights (Blender Z): 1F floor 0, genkan -.18, 2F floor 2.75, 2F ceiling 5.15, cellar floor -2.45.
Ground: -.55 at the front and west; it falls to about -1.8 along the east wall and keeps going down eastward."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P
import numpy as np
import bpy
from mathutils import Vector
import lib, hall as Hm, house4 as H4, exterior as X, trees
from lib import prim, mat_basic

X0, X1 = H4.X(0), H4.X(10)        # -4.8 .. 5.2  (wall centre lines)
YS, YN = H4.Y(0), H4.Y(8)         # 6.3 (front) .. -1.7 (back)
EAVE = H4.H2 + .15                # 5.30: the top of the walls, under the soffit
PITCH = math.radians(33); OVER = .55
GZ = -.55
Z_SID = -.25                      # foot of the siding (the foundation shows below)
WOFF = .065                       # board backs this far out from the wall centre line

def ground(x, y):
    """Ground height at Blender (x, y): flat in front and to the west, falling to the east and toward the back-east."""
    def ss(a, b, v):
        t = min(1, max(0, (v - a) / (b - a))); return t * t * (3 - 2 * t)
    fall = ss(1.2, 5.2, x) * ss(YS + .6, YS - 1.2, y)            # 0 .. 1 toward the east wall, behind the front
    z = GZ - 1.25 * fall
    if x > 5.2: z -= .16 * (x - 5.2) * ss(YS + 3, YS - 1, y)       # keeps going down past the house
    return z

# ------------------------------------------------------------------ walls and openings from house4's plan
def _outer_walls():
    """{'S','N','W','E'}: (axis, fixed (Blender), lo, hi (Blender, along), outward unit, holes [(a, b, z0, z1)] Blender)."""
    W = {'S': ('X', YS, X0, X1, (0, 1, 0), []), 'N': ('X', YN, X0, X1, (0, -1, 0), []),
         'W': ('Y', X0, YN, YS, (-1, 0, 0), []), 'E': ('Y', X1, YN, YS, (1, 0, 0), [])}
    def side_of(w):
        ax, fixed = w[0], w[1]
        if ax == 'X': return 'S' if fixed == 0 else ('N' if fixed == 8 else None)
        return 'W' if fixed == 0 else ('E' if fixed == 10 else None)
    for walls, z0, sill, wh in ((H4.F1_WALLS, 0.0, H4.SILL1, H4.WH1), (H4.F2_WALLS, H4.F2, H4.SILL2, H4.WH2)):
        for w in walls:
            if not w[6]: continue
            s = side_of(w)
            if s is None: continue
            zz = w[7] if len(w) > 7 else z0
            for (a, b) in w[4]: W[s][5].append(('door', a, b, zz, max(zz, 0) + H4.DOOR_H))
            for (a, b) in w[5]: W[s][5].append(('win', a, b, sill, sill + wh))
    # cellar window in the east wall (out of the ground on the slope)
    W['E'][5].append(('cellar', 6.15, 6.75, -1.6, -1.2))
    out = {}
    for s, (ax, fixed, lo, hi, n, hs) in W.items():
        bh = []
        for (kind, a, b, z0, z1) in hs:
            if ax == 'X': ba, bb = H4.X(a), H4.X(b)
            else: ba, bb = sorted((H4.Y(a), H4.Y(b)))
            bh.append((kind, ba, bb, z0, z1))
        out[s] = (ax, fixed, lo, hi, Vector(n), bh)
    return out

def _at(ax, fixed, n, along, depth, z):
    return Vector((along, fixed, z)) + n * depth if ax == 'X' else Vector((fixed, along, z)) + n * depth

def _box(name, ax, fixed, n, along, depth, z, sa, sd, sz, mat):
    sc = (sa, sd, sz) if ax == 'X' else (sd, sa, sz)
    return prim('cube', name, loc=tuple(_at(ax, fixed, n, along, depth, z)), scale=sc, mat=mat)

SHUTTERS = {}
def window(M, ax, fixed, n, a, b, z0, z1, front, kind):
    """Casing, head, sill, muntins and (front, upper and lower) louvred shutters round one opening."""
    c, w, h = (a + b) / 2, b - a, z1 - z0
    tm = M['ext_trim']; d0 = WOFF + .035      # casing face stands out past the boards (boards reach ~ +.09)
    for s in (-1, 1):
        _box('ext_casing', ax, fixed, n, c + s * (w / 2 + .045), d0, z0 + h / 2 + (.0 if kind != 'door' else 0), .045, .03, h / 2 + .09 if kind != 'door' else h / 2 + .045, tm)
    _box('ext_head', ax, fixed, n, c, d0 + .01, z1 + .07, w / 2 + .1, .04, .06, tm)
    _box('ext_headcap', ax, fixed, n, c, d0 + .03, z1 + .135, w / 2 + .13, .05, .012, tm)
    if kind == 'win':
        _box('ext_sill', ax, fixed, n, c, d0 + .02, z0 - .03, w / 2 + .12, .06, .025, tm)
        g = _box('ext_mullion', ax, fixed, n, c, WOFF - .02, z0 + h / 2, .02, .015, h / 2, tm)
        _box('ext_mullion', ax, fixed, n, c, WOFF - .016, z0 + h * .55, w / 2, .015, .018, tm)
        if front and w > .5:
            for s in (-1, 1):
                sc = c + s * (w / 2 + .06 + w * .16)
                if any(abs(sc - o) < w * .16 + ow * .16 + .03 for (o, ow) in SHUTTERS.get((ax, fixed, z0), [])): continue   # would touch the neighbour's
                SHUTTERS.setdefault((ax, fixed, z0), []).append((sc, w))
                _box('ext_shutter', ax, fixed, n, sc, d0 + .045, z0 + h / 2, w * .16, .012, h / 2 + .02, M['ext_shutter'])
    elif kind == 'cellar':
        _box('ext_sill', ax, fixed, n, c, d0, z0 - .03, w / 2 + .08, .05, .03, M['ext_found'])
        g = _box('ext_cglass', ax, fixed, n, c, 0, (z0 + z1) / 2, w / 2, .005, h / 2, M['ext_glass']); g.visible_shadow = False
        for k in range(1, 4):   # bars over the cellar window
            _box('ext_bar', ax, fixed, n, a + w * k / 4, d0, (z0 + z1) / 2, .008, .008, h / 2, M['ext_ridge'])

def walls(M):
    OW = _outer_walls()
    for side, (ax, fixed, lo, hi, n, holes) in OW.items():
        hl = [(a - lo, b - lo, z0, z1) for (k, a, b, z0, z1) in holes if k != 'cellar']
        ym = (YS + YN) / 2; half = (YS - YN) / 2; rise = half * math.tan(PITCH)
        top = None
        if ax == 'Y':
            top = lambda al, lo=lo: max(EAVE, EAVE + rise - abs(lo + al - ym) * math.tan(PITCH) - .03)
            xg = fixed + n.x * WOFF   # dark backing in the gable triangle
            v = [(xg, YN, EAVE), (xg, YS, EAVE), (xg, ym, EAVE + rise)]
            if n.x < 0: v = v[::-1]
            lib.mesh_obj(f'ext_gable{side}', v, [(0, 1, 2)]).data.materials.append(M['ext_backing'])
        # backing behind the boards (shows in the board joints), with the openings cut out
        rects = [(lo, hi, Z_SID, EAVE)]
        for (k, a, b, z0, z1) in holes:
            nr = []
            for (ra, rb, rc, rd) in rects:
                if b <= ra or a >= rb or z1 <= rc or z0 >= rd: nr.append((ra, rb, rc, rd)); continue
                if a > ra: nr.append((ra, a, rc, rd))
                if b < rb: nr.append((b, rb, rc, rd))
                if z1 < rd: nr.append((max(ra, a), min(rb, b), z1, rd))
                if z0 > rc: nr.append((max(ra, a), min(rb, b), rc, z0))
            rects = nr
        for (ra, rb, rc, rd) in rects:
            if rb - ra < .01 or rd - rc < .01: continue
            _box('ext_backing', ax, fixed, n, (ra + rb) / 2, WOFF - .005, (rc + rd) / 2, (rb - ra) / 2, .005, (rd - rc) / 2, M['ext_backing'])
        origin = _at(ax, fixed, n, lo, WOFF, 0)
        u = (1, 0, 0) if ax == 'X' else (0, 1, 0)
        X.clapboard_wall(f'ext_siding{side}', origin, u, n, hi - lo, Z_SID, EAVE - .02, hl, M, top=top,
                         seed={'S': 21, 'N': 22, 'E': 23, 'W': 24}[side], north={'S': 0, 'N': 1, 'E': .35, 'W': .5}[side],
                         ppm=240 if side == 'S' else 190, ground_z=max(ground(*_at(ax, fixed, n, (lo + hi) / 2, .2, 0).xy), -1.2))
        for (k, a, b, z0, z1) in holes: window(M, ax, fixed, n, a, b, z0, z1, side == 'S', k)
        # corner boards, frieze under the eaves, water table at the foot
        for cpos in (lo, hi):
            inward = 1 if cpos == lo else -1
            _box('ext_corner', ax, fixed, n, cpos + inward * .055, WOFF + .045, (Z_SID + EAVE) / 2 - .02, .075, .025, (EAVE - Z_SID) / 2 + .03, M['ext_trim'])   # stands 1 cm proud of the bands (coplanar faces z-fight)
        _box('ext_band', ax, fixed, n, (lo + hi) / 2, WOFF + .035, EAVE - .1, (hi - lo) / 2 + .1, .02, .1, M['ext_trim'])
        _box('ext_band', ax, fixed, n, (lo + hi) / 2, WOFF + .035, Z_SID + .06, (hi - lo) / 2 + .1, .02, .07, M['ext_trim'])
    return OW

# ------------------------------------------------------------------ roof
def slates_on(o, name, M, seed, north):
    bpy.context.view_layer.update()
    mw = o.matrix_world; R = mw.to_3x3().normalized()
    xw, yw, zw = R.col[0], R.col[1], R.col[2]
    hx, hy, th = o.scale
    w = yw if yw.z > 0 else -yw
    org = mw.translation + zw * th - xw * hx - w * hy
    o.data.materials.clear(); o.data.materials.append(M['ext_felt'])
    return X.slate_roof(name, org, xw, w, zw, 2 * hx, 2 * hy, M, seed=seed, north=north)

def roof(M):
    xm = (X0 + X1) / 2; ym = (YS + YN) / 2; half = (YS - YN) / 2 + WOFF + OVER
    hx = (X1 - X0) / 2 + WOFF + OVER
    zr = EAVE + ((YS - YN) / 2 + WOFF) * math.tan(PITCH) + .1
    L = half / math.cos(PITCH)
    for s in (-1, 1):   # +1 front slope
        yc = ym + s * half / 2; zc = zr - half / 2 * math.tan(PITCH)
        o = prim('cube', 'ext_roof', loc=(xm, yc, zc), rot=(-s * PITCH, 0, 0), scale=(hx, L / 2, .06), mat=M['ext_felt'])
        slates_on(o, f'ext_slate{"S" if s > 0 else "N"}', M, 31 + s, 0 if s > 0 else 1)
        prim('cube', 'ext_fascia', loc=(xm, ym + s * half, zr - half * math.tan(PITCH) - .06), scale=(hx, .03, .11), mat=M['ext_trim'])
        prim('cube', 'ext_soffit', loc=(xm, ym + s * ((YS - YN) / 2 + WOFF + OVER / 2), EAVE - .02), scale=(hx, OVER / 2 + WOFF / 2, .015), mat=M['ext_soffit'])
        prim('cube', 'ext_ridgecap', loc=(xm, ym + s * .07, zr + .045), rot=(-s * PITCH, 0, 0), scale=(hx + .01, .09, .006), mat=M['ext_ridge'])
    for x in (xm - hx, xm + hx):   # barge boards
        for s in (-1, 1):
            prim('cube', 'ext_barge', loc=(x, ym + s * half / 2, zr - half / 2 * math.tan(PITCH) - .1), rot=(-s * PITCH, 0, 0), scale=(.03, L / 2, .11), mat=M['ext_trim'])
    # gable-end soffit returns under the barge (closing the roof's edge seen from below)
    for x in (X0 - WOFF - OVER / 2, X1 + WOFF + OVER / 2):
        for s in (-1, 1):
            prim('cube', 'ext_soffit', loc=(x, ym + s * half / 2, zr - half / 2 * math.tan(PITCH) - .2), rot=(-s * PITCH, 0, 0), scale=(OVER / 2, L / 2, .012), mat=M['ext_soffit'])
    # stove chimney on the west wall (plan y 3.0..3.45), stone, up past the ridge
    cy = (H4.Y(3.0) + H4.Y(3.45)) / 2
    prim('cube', 'ext_chimney', loc=(X0 - WOFF - .3, cy, (GZ + zr + .9) / 2), scale=(.3, .42, (zr + .9 - GZ) / 2), mat=M['ext_stone'])
    prim('cube', 'ext_chimcap', loc=(X0 - WOFF - .3, cy, zr + .93), scale=(.34, .46, .04), mat=M['ext_found'])
    return zr

# ------------------------------------------------------------------ porches, foundation
def porches(M):
    tm = M['ext_trim']
    # front porch: plan x 3.6..6.4, y -1.5..0, deck at the genkan floor, shed roof over the door, two steps down
    x0, x1 = H4.X(3.6), H4.X(6.4); y0, y1 = YS + WOFF, H4.Y(-1.5)
    zd = H4.ZG - .03
    if not bpy.data.objects.get('porch'):
        d = prim('cube', 'ext_porchdeck', loc=((x0 + x1) / 2, (y0 + y1) / 2, zd), scale=((x1 - x0) / 2, (y1 - y0) / 2, .03), mat=M['ext_deck']); lib.uv_box(d, 1.0)
    for (cx, cy, sx, sy) in (((x0 + x1) / 2, y1 - .02, (x1 - x0) / 2, .02), (x0, (y0 + y1) / 2, .02, (y1 - y0) / 2), (x1, (y0 + y1) / 2, .02, (y1 - y0) / 2)):
        gz = min(ground(cx, cy), GZ)
        prim('cube', 'ext_porchskirt', loc=(cx, cy, (gz + zd) / 2 - .02), scale=(sx, sy, (zd - gz) / 2), mat=tm)
    zb, zt = 2.36, 2.62
    for x in (x0 + .1, x1 - .1):
        prim('cube', 'ext_post', loc=(x, y1 - .1, (zd + zb) / 2), scale=(.06, .06, (zb - zd) / 2), mat=tm)
        prim('cube', 'ext_postbase', loc=(x, y1 - .1, zd + .05), scale=(.075, .075, .05), mat=tm)
    prim('cube', 'ext_porchbeam', loc=((x0 + x1) / 2, y1 - .1, zb + .07), scale=((x1 - x0) / 2, .07, .08), mat=tm)
    ang = math.atan2(zt - zb, y1 - y0 + .2)
    o = prim('cube', 'ext_porchroof', loc=((x0 + x1) / 2, (y0 + y1 + .2) / 2, (zt + zb) / 2 + .12), rot=(-ang, 0, 0),
             scale=((x1 - x0) / 2 + .2, (y1 - y0 + .2) / 2 / math.cos(ang), .04), mat=M['ext_felt'])
    slates_on(o, 'ext_slateP', M, 35, 0)
    for k, (zz, dy) in enumerate(((GZ + (zd - GZ) * 2 / 3, .3), (GZ + (zd - GZ) / 3, .6))):
        o = prim('cube', 'ext_step', loc=((x0 + x1) / 2, y1 + dy - .15, (GZ - .1 + zz) / 2), scale=(.75, .15, (zz - GZ + .1) / 2), mat=M['ext_found']); lib.uv_box(o, 1.0)
    # back porch: plan x 10..11.4, y 3.9..5.9, deck at the floor (0), posts down the slope, a stair down to the north
    bx0, bx1 = X1 + WOFF, H4.X(11.4); by0, by1 = H4.Y(5.9), H4.Y(3.9)
    d = prim('cube', 'ext_backdeck', loc=((bx0 + bx1) / 2, (by0 + by1) / 2, -.03), scale=((bx1 - bx0) / 2, (by1 - by0) / 2, .03), mat=M['ext_deck']); lib.uv_box(d, 1.0)
    for (x, y) in ((bx1 - .08, by0 + .08), (bx1 - .08, by1 - .08), (bx0 + .25, by0 + .08), (bx0 + .25, by1 - .08)):
        g = ground(x, y)
        prim('cube', 'ext_bpost', loc=(x, y, (g - .1 - .06) / 2), scale=(.06, .06, (-.06 - g + .1) / 2), mat=tm)
        prim('cube', 'ext_bfoot', loc=(x, y, g - .05), scale=(.14, .14, .1), mat=M['ext_found'])
    for (x, y, sx, sy) in ((bx1, (by0 + by1) / 2, .025, (by1 - by0) / 2), ((bx0 + bx1) / 2, by1, (bx1 - bx0) / 2, .025)):   # rail
        prim('cube', 'ext_rail', loc=(x, y, .9), scale=(sx, sy, .03), mat=tm)
        n = int(max(sx, sy) * 2 / .12)
        for i in range(n + 1):
            t = i / n - .5
            px, py = (x, y + t * 2 * sy) if sx < sy else (x + t * 2 * sx, y)
            prim('cube', 'ext_baluster', loc=(px, py, .45), scale=(.015, .015, .43), mat=tm)
    # stair from the deck's north edge down the slope (toward Blender -Y)
    g_end = ground((bx0 + bx1) / 2, by0 - 2.4)
    nst = max(3, int(round((0 - g_end) / .18))); rise = (0 - g_end) / nst; run = .26
    for i in range(nst):
        z = -(i + 1) * rise; y = by0 - (i + .5) * run
        o = prim('cube', 'ext_bstep', loc=((bx0 + bx1) / 2 + .15, y, z - .02), scale=(.45, run / 2 + .02, .02), mat=M['ext_deck']); lib.uv_box(o, 1.0)
    L = math.hypot(nst * run, nst * rise); a = math.atan2(nst * rise, nst * run)
    for sx in (-.47, .47):
        prim('cube', 'ext_bstringer', loc=((bx0 + bx1) / 2 + .15 + sx, by0 - nst * run / 2, -nst * rise / 2 - .1), rot=(a, 0, 0), scale=(.025, L / 2 + .05, .12), mat=tm)

def back_porch_boxes():
    """試作97 (ユーザー「勝手口から外に出ると落ちた」): the back porch's deck and stair had no collision (the player fell
    through to the slope under it, NOTES), nor its rail. The deck, the rail on the east and the south, the stair as a
    ramp, and the stair's two open sides. Boxes as export_house writes them (Blender coords, full sizes)."""
    bx0, bx1 = X1 + WOFF, H4.X(11.4); by0, by1 = H4.Y(5.9), H4.Y(3.9)
    cx, cy = (bx0 + bx1) / 2, (by0 + by1) / 2
    out = [dict(c=[cx, cy, -.06], s=[bx1 - bx0, by1 - by0, .12]),
           dict(c=[bx1, cy, .5], s=[.08, by1 - by0, 1.0]),                 # the east rail
           dict(c=[cx, by1, .5], s=[bx1 - bx0, .08, 1.0])]                 # the south rail
    g_end = ground(cx, by0 - 2.4)
    nst = max(3, int(round((0 - g_end) / .18))); rise = (0 - g_end) / nst; run = .26
    L, Hh = nst * run, nst * rise
    sx = cx + .15
    out.append(dict(c=[sx, by0 - L / 2, -Hh / 2 - .04], s=[.9, math.hypot(L, Hh), .04], ramp=1, rx=math.atan2(Hh, L)))
    for d in (-.5, .5):   # the stair's sides: no rail, but a body does not step off a stair's edge into the dark
        out.append(dict(c=[sx + d, by0 - L / 2, -Hh / 2 + .3], s=[.06, L, Hh + 1.0]))
    return out

def foundation(M, OW):
    """Concrete from the ground up to the siding's foot; on the east the cellar wall shows above the falling ground."""
    for side, (ax, fixed, lo, hi, n, holes) in OW.items():
        steps = np.linspace(lo, hi, 11)
        for a, b in zip(steps[:-1], steps[1:]):
            gz = min(ground(*_at(ax, fixed, n, a, .25, 0).xy), ground(*_at(ax, fixed, n, b, .25, 0).xy)) - .15
            o = _box('ext_found', ax, fixed, n, (a + b) / 2, WOFF - .01, (gz + Z_SID + .05) / 2, (b - a) / 2 + .004, .03, (Z_SID + .05 - gz) / 2, M['ext_found'])
            lib.uv_box(o, 1.0)
            cut = [h for h in holes if h[0] == 'cellar' and h[1] < b and h[2] > a]
            if cut: o.name = 'ext_found_cellar'
    # the cellar window's opening in the concrete is drawn as a dark recess (the concrete box is one piece)
    for side, (ax, fixed, lo, hi, n, holes) in OW.items():
        for (k, a, b, z0, z1) in holes:
            if k == 'cellar':
                _box('ext_cwell', ax, fixed, n, (a + b) / 2, WOFF + .025, (z0 + z1) / 2, (b - a) / 2, .006, (z1 - z0) / 2, M['ext_glass'])

# ------------------------------------------------------------------ ground, drive, trees, sky
def site(M, with_trees=True, cut_house=False):
    if WIDE:   # the whole-house scene: the land out to the forest road and the slip (outside.py, 2026-11-05)
        import outside; outside.site(M, cut_house); return
    # ground: a grid following ground(), coarse far out
    R = 30.0; xs = np.concatenate([np.linspace(-R, -12, 7)[:-1], np.arange(-12, 12.01, .5), np.linspace(12, R, 7)[1:]])
    V = []; F = []
    n = len(xs)
    for y in xs:
        for x in xs: V.append((x, y, ground(x, y)))
    for j in range(n - 1):
        for i in range(n - 1):
            a = j * n + i; F.append((a, a + 1, a + n + 1, a + n))
    if cut_house:
        # the ground's slope passes under the house at -.55 .. -1.8, through the cellar (-2.45 .. -.3): seen from inside
        # it, a slab of earth crossed the room (試作48の確認). The squares whose middle is inside the footprint go, and
        # the corners left inside it are pulled out to its edge, so the ground still meets the walls.
        x0, x1, y0, y1 = H4.X(0), H4.X(10), YN, YS
        inside = lambda x, y: x0 < x < x1 and y0 < y < y1
        F = [f for f in F if not inside(sum(V[k][0] for k in f) / 4, sum(V[k][1] for k in f) / 4)]
        for k, (x, y, z) in enumerate(V):
            if inside(x, y):
                d = min((x - x0, 'x', x0), (x1 - x, 'x', x1), (y - y0, 'y', y0), (y1 - y, 'y', y1))
                V[k] = (d[2], y, z) if d[1] == 'x' else (x, d[2], z)
    for nm, mat, dz, uvs in (('ext_ground', M['ext_ground'], 0, 3.0), ('ext_litter', M['ext_litter'], .008, 4.0)):
        o = lib.mesh_obj(nm, [(x, y, z + dz) for (x, y, z) in V], F); o.data.materials.append(mat); lib.uv_box(o, uvs)
    # gravel drive from the front porch toward the south-east (the private road, Natsuki's car)
    pts = [(H4.X(5.0), YS + 2.4), (H4.X(6.5), YS + 6), (H4.X(8.5), YS + 11), (H4.X(9.5), YS + 18)]
    V = []; F = []
    for k, (x, y) in enumerate(pts):
        if k < len(pts) - 1: dx, dy = pts[k + 1][0] - x, pts[k + 1][1] - y
        L = math.hypot(dx, dy); nx, ny = -dy / L, dx / L
        hw = 1.0 if k == 0 else 1.6
        for s in (-1, 1): V.append((x + s * nx * hw, y + s * ny * hw, ground(x + s * nx * hw, y + s * ny * hw) + .014))
        if k: F.append((2 * k - 2, 2 * k - 1, 2 * k + 1, 2 * k))
    o = lib.mesh_obj('ext_drive', V, F); o.data.materials.append(M['ext_gravel']); lib.uv_box(o, 2.0)
    # sky ring (house.py's), the sugi plantation round the clearing
    Hx_site_sky(M)
    def keep(x, y):
        if y > YS - 1 and abs(x) < 9: return False                     # the view from the porch
        for (px, py) in pts:
            if math.hypot(x - px, y - py) < 3.2: return False         # the drive
        if X1 < x < X1 + 4 and YN - 1 < y < YS: return False           # the back porch's stair
        return True
    if with_trees: trees.sugi_stand(M, centre=((X0 + X1) / 2, (YS + YN) / 2), r0=12.5, r1=26.5, keep=keep, ground=ground, seed=7, n_unique=14)

def Hx_site_sky(M):
    R, n = 28.0, 64
    rings = ((R, -10.0, 0.0), (R, 16.0, 1.0), (R * .7, 40.0, 1.0), (R * .05, 55.0, 1.0))
    v = []; f = []; uvs = []
    cx, cy = (X0 + X1) / 2, (YS + YN) / 2
    for i in range(n + 1):
        a = i / n * math.tau
        for (r, z, vv) in rings: v.append((cx + r * math.cos(a), cy + r * math.sin(a), z)); uvs.append((i / n, vv))
    k = len(rings)
    for i in range(n):
        for j in range(k - 1): f.append((k * i + j, k * i + j + 1, k * (i + 1) + j + 1, k * (i + 1) + j))
    o = lib.mesh_obj('ext_sky', v, f); o.data.materials.append(M['ext_sky']); o.visible_shadow = False
    o.data.uv_layers.new(); uv = o.data.uv_layers[0].data
    for p in o.data.polygons:
        for li, vi in zip(p.loop_indices, p.vertices): uv[li].uv = uvs[vi]

# ------------------------------------------------------------------ entry
def mats(M):
    if 'ext_trim' not in M: X.trim_mat(M)
    M.setdefault('ext_felt', mat_basic('ext_felt', (.035, .035, .035), .9))
    M.setdefault('ext_backing', mat_basic('ext_backing', (.05, .05, .045), .9))
    M.setdefault('ext_ridge', mat_basic('ext_ridge', (.10, .10, .10), .45, metal=.4))
    M.setdefault('ext_soffit', mat_basic('ext_soffit', (.42, .41, .38), .6))
    M.setdefault('ext_shutter', mat_basic('ext_shutter', (.06, .1, .09), .5))
    M.setdefault('ext_glass', mat_basic('ext_glass', (.03, .035, .045), .08, .6))
    M.setdefault('ext_stone', mat_basic('ext_stone', (.32, .31, .29), .9))
    M['ext_found'] = X.concrete_mat(M)
    if 'ext_deck' not in M: M['ext_deck'] = lib.mat_image('ext_deck', lib.tex_path('floor'), rough=.8, coords='UV', bump=0, tint=(.62, .6, .57))
    if 'ext_ground' not in M:
        M['ext_ground'] = X.ph_mat('ext_ground', 'forest_ground_04', tint=(.5, .47, .43), rough=.95)
        M['ext_litter'] = X.ph_mat('ext_litter', 'forest_leaves_03', tint=(.5, .44, .38), rough=.95,
                                   alpha_fn=lambda rng, S: (X.tileable_noise(rng, S, S * 220 // 2048) + .5 * X.tileable_noise(rng, S, S * 40 // 2048) > .15).astype(np.float32), seed=2)
        M['ext_gravel'] = X.ph_mat('ext_gravel', 'gravel_floor', tint=(.32, .31, .3), rough=.95)
        if TIME != 'night':
            for k in ('ext_ground', 'ext_litter', 'ext_gravel'): X.add_fill(M[k], .05)
    if 'ext_sky' not in M:
        sky = bpy.data.materials.new('ext_sky'); sky.use_nodes = True; N = sky.node_tree.nodes; L = sky.node_tree.links
        p = N['Principled BSDF']; t = N.new('ShaderNodeTexImage')
        if TIME == 'night':   # 23:00 in the storm: the same ridge of conifers under a low, dark rain sky
            def make():
                from PIL import Image
                a = np.asarray(Image.open(lib.tex_path('skyring')).convert('RGB'), np.float32) / 255
                l = a[..., 0] * .3 + a[..., 1] * .59 + a[..., 2] * .11
                return {'a': np.dstack([l * .55, l * .62, l * .75]) ** 1.3}
            t.image = lib.img(X.cached({'skynight': 1}, ('a',), make)['a'])
        else: t.image = lib.img(lib.tex_path('skyring'))
        L.new(t.outputs[0], p.inputs['Emission Color']); p.inputs['Emission Strength'].default_value = .12 if TIME == 'night' else .75   # 1.6 printed as bare paper through the open front door
        p.inputs['Base Color'].default_value = (0, 0, 0, 1)
        p.inputs['Roughness'].default_value = 1.0; p.inputs['Specular IOR Level'].default_value = 0.0
        M['ext_sky'] = sky

TIME = 'dusk'
WIDE = False
def build_ext4(M, with_trees=True, time='dusk', cut_house=False, wide=False):
    """time: 'dusk' (第1章の夕方) or 'night' (23:00, rain: a dark sky ring). cut_house: no ground inside the house's
    footprint (the whole-house scene, where the cellar can be walked: the ground's slope ran through it)."""
    global TIME, WIDE; TIME = time; WIDE = wide
    random.seed(51); SHUTTERS.clear()
    mats(M)
    OW = walls(M)
    roof(M)
    porches(M)
    foundation(M, OW)
    site(M, with_trees, cut_house)
    for o in [o for o in bpy.data.objects if o.name.startswith('ext_') and o.type == 'MESH' and o.data.materials and o.data.materials[0] == M['ext_trim']]:
        lib.uv_box(o, 1.0)
    return {'ground': ground}
