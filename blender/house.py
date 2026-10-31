"""The outside of the house for the look comparison (ログハウス / 白い下見板張りの洋館風), built round the hall of hall.py.
build_exterior(M) uses hall.STYLE ('log' | 'siding'). Every object is named ext_* (left out of the baked lightmap,
lit by the scene's lights in Godot).
Footprint after plan/plan_v4.png at its rough size: 12.4 m wide (x), 10.3 m deep (y), two storeys, gable roof with
the ridge along x, the porch in front of the front door, the stove chimney on the west (-x) wall.
Front = +y (the front door wall, y = hall.YF). The ground is .55 m below the hall floor."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P   # all paths: paths.env
import bpy
from mathutils import Vector
import lib, door as D, hall as Hm
from lib import prim, mat_basic, mat_image, tex_path

HX0, HX1, HY0, HY1 = -6.2, 6.2, -4.0, Hm.YF
H = Hm.H; F2 = H + .3; EAVE = F2 + 2.55; GZ = -.55
PITCH = math.radians(33); OVER = .55
COURSE = .226; Z_LOG0 = Hm.ZG + .09          # the hall's log courses, so the front wall continues them
# windows: (wall, centre along the wall, sill z, width, height). Walls: 'S' front (+y), 'N' back, 'W' -x, 'E' +x
WIN = [('S', -4.6, .85, .9, 1.25), ('S', -2.8, .85, .9, 1.25), ('S', 3.0, .85, .9, 1.25), ('S', 4.8, .85, .9, 1.25),
       ('S', -4.6, F2 + .8, .8, 1.1), ('S', -2.8, F2 + .8, .8, 1.1), ('S', .76, F2 + .8, .8, 1.1), ('S', 3.0, F2 + .8, .8, 1.1), ('S', 4.8, F2 + .8, .8, 1.1),
       ('E', 4.6, .85, .9, 1.25), ('E', -1.0, .85, .9, 1.25), ('E', 3.8, F2 + .8, .8, 1.1), ('E', -1.8, F2 + .8, .8, 1.1),
       ('W', 4.2, .85, .9, 1.25), ('W', -2.4, .85, .9, 1.25), ('W', 3.4, F2 + .8, .8, 1.1), ('W', -2.4, F2 + .8, .8, 1.1),
       ('N', -4.2, .85, .9, 1.25), ('N', 3.6, 1.2, .7, .9), ('N', -3.0, F2 + .8, .8, 1.1), ('N', 3.0, F2 + .8, .8, 1.1)]
GLOW = {(-4.6, .85), (-2.8, .85), (.76, F2 + .8)}   # lit from inside (the crew is in the house)
WALLS = {'S': ('X', HY1, HX0, HX1, 1), 'N': ('X', HY0, HX0, HX1, -1), 'E': ('Y', HX1, HY0, HY1, 1), 'W': ('Y', HX0, HY0, HY1, -1)}
DOOR = (Hm.DX0, Hm.DX1, Hm.ZG, 2.0)
HALL = (Hm.XL, Hm.XR)

def mats(M):
    Hm.style_mats(M)
    M['ext_roof'] = mat_image('ext_roof', tex_path('shingle'), rough=.8, coords='UV', bump=.1)
    M['ext_ground'] = mat_image('ext_ground', tex_path('ground'), rough=.95, coords='UV', bump=.1)
    M['ext_stone'] = mat_basic('ext_stone', (.32, .31, .29), .9)
    M['ext_found'] = mat_basic('ext_found', (.36, .35, .33), .9)
    M['ext_glass'] = mat_basic('ext_glass', (.03, .035, .045), .08, .6)
    M['ext_glow'] = mat_basic('ext_glow', (.9, .62, .34), .5, emit=(1, .62, .3), estr=1.6)
    M['ext_gravel'] = mat_basic('ext_gravel', (.33, .31, .28), .95)
    M['ext_shutter'] = mat_basic('ext_shutter', (.06, .1, .09), .5)
    sky = bpy.data.materials.new('ext_sky'); sky.use_nodes = True; N = sky.node_tree.nodes; L = sky.node_tree.links
    p = N['Principled BSDF']; t = N.new('ShaderNodeTexImage'); t.image = lib.img(tex_path('skyring'))
    L.new(t.outputs[0], p.inputs['Emission Color']); p.inputs['Emission Strength'].default_value = 1.6
    p.inputs['Base Color'].default_value = (0, 0, 0, 1)
    M['ext_sky'] = sky

def openings(side):
    ax, fixed, lo, hi, _ = WALLS[side]
    hs = [(c - w / 2, c + w / 2, z, z + h) for (s, c, z, w, h) in WIN if s == side]
    if side == 'S': hs.append(DOOR)
    return hs

def log_wall(side, M):
    """Round logs, course by course, running .35 m past the corners (crossed at the corners like saddle notches);
    the back and side walls sit half a course up from the front and back ones."""
    ax, fixed, lo, hi, out = WALLS[side]
    holes = openings(side)
    z = Z_LOG0 + (COURSE / 2 if ax == 'Y' else 0); i = 0
    while z < EAVE + .05:
        segs = [(lo - .35, hi + .35)]
        if side == 'S' and z < H + .1: segs = [(lo - .35, HALL[0]), (HALL[1], hi + .35)]   # the hall's own logs fill the middle
        for (ha, hb, z0, z1) in holes:
            if z + .11 > z0 and z - .11 < z1:
                ns = []
                for a, b in segs:
                    if hb <= a or ha >= b: ns.append((a, b))
                    else:
                        if ha > a: ns.append((a, ha))
                        if hb < b: ns.append((hb, b))
                segs = ns
        for a, b in segs:
            if b - a < .04: continue
            c = fixed - out * .03
            p0, p1 = ((c, a, z), (c, b, z)) if ax == 'Y' else ((a, c, z), (b, c, z))
            o = D.cyl_between(f'ext_log{side}{i}', p0, p1, .118 + random.uniform(-.006, .006), M['log'], seg=16); lib.uv_cyl(o, 1.25); i += 1
        z += COURSE
    # gable ends (W/E): logs shortened to the roof line
    if ax == 'Y':
        ym = (HY0 + HY1) / 2; half = (HY1 - HY0) / 2
        while True:
            w = half - (z - EAVE) / math.tan(PITCH)
            if w < .25: break
            c = fixed - out * .03
            o = D.cyl_between(f'ext_glog{side}{i}', (c, ym - w, z), (c, ym + w, z), .118, M['log'], seg=16); lib.uv_cyl(o, 1.25); i += 1
            z += COURSE
    # chinking behind (closes the gaps between the logs)
    plane_wall(side, M['chink'], -out * .06, holes, z_top=EAVE)

def plane_wall(side, mat, off, holes, z_top=EAVE, z0=Z_LOG0 - .09, skip_hall=True, th=0.0):
    """Flat skin of the wall at `off` from the wall line, the openings cut out (box `th` thick when th > 0)."""
    ax, fixed, lo, hi, out = WALLS[side]
    rects = [(lo, hi, z0, z_top)]
    if side == 'S' and skip_hall and Hm.STYLE == 'log':
        rects = [(lo, HALL[0], z0, z_top), (HALL[1], hi, z0, z_top), (HALL[0], HALL[1], H + .05, z_top)]
    for (ha, hb, h0, h1) in holes:
        nr = []
        for (a, b, c, d) in rects:
            if hb <= a or ha >= b or h1 <= c or h0 >= d: nr.append((a, b, c, d)); continue
            if ha > a: nr.append((a, ha, c, d))
            if hb < b: nr.append((hb, b, c, d))
            if h1 < d: nr.append((max(a, ha), min(b, hb), h1, d))
            if h0 > c: nr.append((max(a, ha), min(b, hb), c, h0))
        rects = nr
    f = fixed + off
    for (a, b, c, d) in rects:
        if b - a < .01 or d - c < .01: continue
        t = max(th, .01) / 2
        if ax == 'Y': o = prim('cube', f'ext_w{side}', loc=(f, (a + b) / 2, (c + d) / 2), scale=(t, (b - a) / 2, (d - c) / 2), mat=mat)
        else: o = prim('cube', f'ext_w{side}', loc=((a + b) / 2, f, (c + d) / 2), scale=((b - a) / 2, t, (d - c) / 2), mat=mat)
        lib.uv_box(o, 1.0)

def siding_wall(side, M):
    ax, fixed, lo, hi, out = WALLS[side]
    holes = openings(side)
    plane_wall(side, M['siding'], out * .0, holes, th=.08)
    # gable triangle (W/E)
    if ax == 'Y':
        ym = (HY0 + HY1) / 2; half = (HY1 - HY0) / 2; rise = half * math.tan(PITCH)
        x = fixed + out * .045
        v = [(x, HY0, EAVE), (x, HY1, EAVE), (x, ym, EAVE + rise)]
        if out < 0: v = v[::-1]
        o = lib.mesh_obj(f'ext_gable{side}', v, [(0, 1, 2)]); o.data.materials.append(M['siding'])
        o.data.uv_layers.new(); uv = o.data.uv_layers[0].data
        for li, vi in enumerate(o.data.polygons[0].vertices): uv[li].uv = (v[vi][1], v[vi][2])
    # corner boards, frieze under the eaves, water table at the bottom
    for c in (lo, hi):
        if ax == 'X':
            prim('cube', 'ext_corner', loc=(c - math.copysign(.07, c), fixed + out * .05, (Z_LOG0 + EAVE) / 2 - .05), scale=(.08, .025, (EAVE - Z_LOG0) / 2 + .05), mat=M['trim'])
        else:
            prim('cube', 'ext_corner', loc=(fixed + out * .05, c - math.copysign(.07, c - (lo + hi) / 2), (Z_LOG0 + EAVE) / 2 - .05), scale=(.025, .08, (EAVE - Z_LOG0) / 2 + .05), mat=M['trim'])
    for zc, hz in ((EAVE - .1, .1), (Z_LOG0, .08)):
        if ax == 'X': prim('cube', 'ext_band', loc=((lo + hi) / 2, fixed + out * .055, zc), scale=((hi - lo) / 2 + .02, .02, hz), mat=M['trim'])
        else: prim('cube', 'ext_band', loc=(fixed + out * .055, (lo + hi) / 2, zc), scale=(.02, (hi - lo) / 2 + .02, hz), mat=M['trim'])

def window(side, c, z, w, h, M):
    ax, fixed, lo, hi, out = WALLS[side]
    def at(along, depth, zz):   # point on the wall: `depth` outward from the wall line
        return (fixed + out * depth, along, zz) if ax == 'Y' else (along, fixed + out * depth, zz)
    def box(name, along, depth, zz, sa, sd, sz, mat):
        sc = (sd, sa, sz) if ax == 'Y' else (sa, sd, sz)
        return prim('cube', name, loc=at(along, depth, zz), scale=sc, mat=mat)
    glow = (c, z) in GLOW and side == 'S'
    g = box('ext_glass', c, -.03, z + h / 2, w / 2, .005, h / 2, M['ext_glow'] if glow else M['ext_glass'])
    g.visible_shadow = False
    siding = Hm.STYLE == 'siding'
    fm = M['trim'] if siding else M['door']
    d0 = .07 if siding else .14          # the frame stands out to the face of the wall (logs stand .15 out)
    box('ext_mullion', c, -.02, z + h / 2, .02, .02, h / 2, fm)
    box('ext_mullion', c, -.02, z + h * .55, w / 2, .02, .018, fm)
    for s in (-1, 1):
        box('ext_casing', c + s * (w / 2 + .045), d0 / 2, z + h / 2, .045, d0 / 2 + .01, h / 2 + .09, fm)
    box('ext_head', c, d0 / 2, z + h + .07, w / 2 + .1, d0 / 2 + .01, .06 if siding else .05, fm)
    box('ext_sill', c, d0 / 2 + .02, z - .03, w / 2 + .12, d0 / 2 + .04, .025, fm)
    if siding and side == 'S':   # louvred shutters on the front
        for s in (-1, 1):
            box('ext_shutter', c + s * (w / 2 + .08 + w * .2), d0 + .015, z + h / 2, w * .2, .012, h / 2 + .02, M['ext_shutter'])

def roof(M):
    ym = (HY0 + HY1) / 2; half = (HY1 - HY0) / 2 + OVER
    zr = EAVE + ((HY1 - HY0) / 2) * math.tan(PITCH) + .1
    L = half / math.cos(PITCH)
    for s in (-1, 1):   # s = +1 front slope
        yc = ym + s * half / 2; zc = zr - half / 2 * math.tan(PITCH)
        o = prim('cube', 'ext_roof', loc=(0, yc, zc), rot=(-s * PITCH, 0, 0), scale=((HX1 - HX0) / 2 + OVER, L / 2, .06), mat=M['ext_roof'])
        lib.uv_box(o, 1.0, rot90=False)
        fasc = prim('cube', 'ext_fascia', loc=(0, ym + s * half, zr - half * math.tan(PITCH) - .06), scale=((HX1 - HX0) / 2 + OVER, .03, .11), mat=M['trim'] if Hm.STYLE == 'siding' else M['door'])
    for x in (HX0 - OVER, HX1 + OVER):   # barge boards on the gables
        for s in (-1, 1):
            prim('cube', 'ext_barge', loc=(x, ym + s * half / 2, zr - half / 2 * math.tan(PITCH) - .1), rot=(-s * PITCH, 0, 0), scale=(.03, L / 2, .11), mat=M['trim'] if Hm.STYLE == 'siding' else M['door'])
    prim('cube', 'ext_ridgecap', loc=(0, ym, zr + .05), scale=((HX1 - HX0) / 2 + OVER, .12, .03), mat=M['ext_roof'])
    # soffit closing the underside of the front and back eaves
    for s in (-1, 1):
        prim('cube', 'ext_soffit', loc=(0, ym + s * ((HY1 - HY0) / 2 + OVER / 2), EAVE - .02), scale=((HX1 - HX0) / 2 + OVER, OVER / 2, .015), mat=M['trim'] if Hm.STYLE == 'siding' else M['door'])
    # stove chimney on the west wall (plan v4: the living room's outer wall)
    cy = -1.6
    prim('cube', 'ext_chimney', loc=(HX0 - .35, cy, (GZ + zr + .9) / 2), scale=(.32, .38, (zr + .9 - GZ) / 2), mat=M['ext_stone'])

def porch(M):
    """Deck, posts, a shed roof over the front door, and steps down to the ground (the deck itself is the scene's 'porch')."""
    Y = HY1; x0, x1 = -.85, 2.35; y1 = Y + 2.0
    siding = Hm.STYLE == 'siding'
    pm = M['trim'] if siding else M['log']
    prim('cube', 'ext_porchskirt', loc=((x0 + x1) / 2, y1 - .02, (GZ + Hm.ZG) / 2), scale=((x1 - x0) / 2, .02, (Hm.ZG - GZ) / 2), mat=pm if siding else M['door'])
    for x in (x0, x1):
        prim('cube', 'ext_porchskirt', loc=(x, (Y + y1) / 2, (GZ + Hm.ZG) / 2), scale=(.02, (y1 - Y) / 2, (Hm.ZG - GZ) / 2), mat=pm if siding else M['door'])
    zt = 2.62; zb = 2.36
    for x in (x0 + .1, x1 - .1):
        if siding: prim('cube', 'ext_post', loc=(x, y1 - .1, (Hm.ZG + zb) / 2), scale=(.06, .06, (zb - Hm.ZG) / 2), mat=pm)
        else: o = D.cyl_between('ext_post', (x, y1 - .12, Hm.ZG), (x, y1 - .12, zb), .1, M['log'], 14); lib.uv_cyl(o, 1.25)
    if siding: prim('cube', 'ext_porchbeam', loc=((x0 + x1) / 2, y1 - .1, zb + .07), scale=((x1 - x0) / 2, .07, .08), mat=pm)
    else: o = D.cyl_between('ext_porchbeam', (x0 - .1, y1 - .12, zb + .08), (x1 + .1, y1 - .12, zb + .08), .1, M['log'], 14); lib.uv_cyl(o, 1.25)
    ang = math.atan2(zt - zb, y1 - Y + .2)
    o = prim('cube', 'ext_porchroof', loc=((x0 + x1) / 2, (Y + y1 + .2) / 2, (zt + zb) / 2 + .12), rot=(-ang, 0, 0), scale=((x1 - x0) / 2 + .2, (y1 - Y + .2) / 2 / math.cos(ang), .04), mat=M['ext_roof'])
    lib.uv_box(o, 1.0)
    # steps: two treads from the ground up to the deck
    for k, (zz, dy) in enumerate(((GZ + (Hm.ZG - GZ) * 2 / 3, .3), (GZ + (Hm.ZG - GZ) / 3, .6))):
        o = prim('cube', 'ext_step', loc=(.75, y1 + dy - .15, (GZ + zz) / 2), scale=(.7, .15, (zz - GZ) / 2), mat=M['agari']); lib.uv_box(o, 1.25)

def site(M):
    g = prim('plane', 'ext_ground', loc=(0, 0, GZ), scale=(30, 30, 1), mat=M['ext_ground']); lib.uv_box(g, 2.0)
    prim('cube', 'ext_found', loc=((HX0 + HX1) / 2, (HY0 + HY1) / 2, (GZ + Z_LOG0 - .09) / 2), scale=((HX1 - HX0) / 2 + .02, (HY1 - HY0) / 2 + .02, (Z_LOG0 - .09 - GZ) / 2 + .01), mat=M['ext_found'])
    # gravel drive to the south-east (plan v4: the private road and Natsuki's car)
    o = prim('plane', 'ext_drive', loc=(3.6, HY1 + 8, GZ + .005), rot=(0, 0, .12), scale=(1.6, 7, 1), mat=M['ext_gravel'])
    # sky with the tree line all round, on an inward cylinder (u = angle, .25 toward +y)
    R, n = 28.0, 64
    rings = ((R, -10.0, 0.0), (R, 16.0, 1.0), (R * .7, 40.0, 1.0), (R * .05, 55.0, 1.0))   # (radius, z, v): the band, then a dome of the top colour
    v = []; f = []; uvs = []
    for i in range(n + 1):
        a = i / n * math.tau
        for (r, z, vv) in rings: v.append((r * math.cos(a), r * math.sin(a), z)); uvs.append((i / n, vv))
    k = len(rings)
    for i in range(n):
        for j in range(k - 1): f.append((k * i + j, k * i + j + 1, k * (i + 1) + j + 1, k * (i + 1) + j))
    o = lib.mesh_obj('ext_sky', v, f); o.data.materials.append(M['ext_sky']); o.visible_shadow = False
    o.data.uv_layers.new(); uv = o.data.uv_layers[0].data
    for p in o.data.polygons:
        for li, vi in zip(p.loop_indices, p.vertices): uv[li].uv = uvs[vi]
    # a few conifers near the house so it sits in the woods
    rnd = random.Random(11)
    tm = mat_basic('ext_tree', (.025, .04, .03), .95); bm = mat_basic('ext_bark', (.12, .09, .07), .9)
    for _ in range(40):
        a = rnd.uniform(0, math.tau); r = rnd.uniform(13, 22)
        x, y = r * math.cos(a), r * math.sin(a) - 1
        if y > 1: continue   # keep the front (the drive and the view from it) open
        h = rnd.uniform(7, 13)
        prim('cone', 'ext_tree', loc=(x, y, GZ + 1.5 + h / 2), vertices=10, radius1=h * .14, depth=h, mat=tm)
        prim('cylinder', 'ext_trunk', loc=(x, y, GZ + .8), vertices=8, radius=.18, depth=1.6, mat=bm)

def build_exterior(M):
    random.seed(21)
    mats(M)
    # the hall's front wall had its chinking on the outside face (unseen until now): the outside wall brings its own
    for o in [o for o in bpy.data.objects if o.name.startswith('chinkX') and o.location.y > HY1]: bpy.data.objects.remove(o)
    # the hall's own front-wall logs carry the baked light and the outside logs do not: from outside they read as a
    # lighter panel beside the door. In the comparison they leave the bake too, so the whole front is lit alike
    if Hm.STYLE == 'log':
        for o in [o for o in bpy.data.objects if o.name.startswith('logX') and o.location.y > HY1 - .2]: o.name = 'ext_h' + o.name
    for side in 'SNEW':
        if Hm.STYLE == 'siding': siding_wall(side, M)
        else: log_wall(side, M)
    for (s, c, z, w, h) in WIN: window(s, c, z, w, h, M)
    roof(M); porch(M); site(M)
