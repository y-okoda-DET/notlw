"""The rental house on floor plan v4 (plan/plan2.py → plan/plan_v4.png), western style (洋館風, 決定事項 2026-10-31).
Coordinates: the plan's metres (x west→east, y south/front→north/back) map to Blender by
    X = x - OX,  Y = YF - y        (the front wall stays at Y = YF = 6.3, like the old hall; the house runs back to -1.7)
build_house4(M, floors=('1F', '2F', 'B1')) builds walls, floors, ceilings, doors, windows and the stairs; returns anchors.
Walls: every partition is a core with a western-style face (hall.flat_wall) on each side; the outer walls get the
face inside only (house exterior comes from house.py)."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P
import bpy
from mathutils import Vector
import lib
import door as D
import hall as Hm
from lib import prim, mat_basic, mat_image

OX, YF = 4.8, 6.3
ZG = D.ZG                 # genkan floor (-.18)
H1 = D.H                  # 1F ceiling (2.45)
F2 = H1 + .3              # 2F floor
H2 = F2 + 2.4             # 2F ceiling
ZB = -2.45                # basement floor
T = .12                   # partition thickness (core + two faces)
SILL1, WH1 = .85, 1.25    # 1F window sill and height
SILL2, WH2 = F2 + .8, 1.1
DOOR_H = 2.0

def X(x): return x - OX
def Y(y): return YF - y

# ---------------------------------------------------------------- plan v4 (plan coordinates)
# walls: (axis, fixed, lo, hi, [(lo, hi) door openings], [(lo, hi) windows], outer side or 0 for a partition)
#   axis 'X': along plan x at plan y = fixed;  axis 'Y': along plan y at plan x = fixed
F1_WALLS = [
    ('X', 0, 0, 4, [], [(.6, 1.8), (2.4, 3.4)], -1),                                                       # front (south)
    ('X', 0, 4, 6, [(4.45, 5.55)], [(4.08, 4.28)], -1, ZG),   # slit 7 cm west of the plan's 4.15: its casing and the door's overlapped and z-fought                                                # front door + slit window, from the genkan floor
    ('X', 0, 6, 10, [], [(6.6, 7.6), (8.4, 9.4)], -1),
    ('X', 8, 0, 10, [], [(1.2, 2.8), (6.8, 8.0)], 1),                                                        # back (north)
    ('Y', 0, 0, 8, [], [(1.0, 1.8), (5.4, 7.0)], -1),                                                       # west
    ('Y', 10, 0, 8, [(4.4, 5.35)], [(1.0, 2.4), (6.0, 6.4)], 1),                                            # east (back porch door)
    ('Y', 4, 1.4, 8, [(3.1, 3.95), (6.1, 6.95)], [], 0),        # hall | living, dining
    ('Y', 6, 0, 1.4, [], [], 0, ZG),                            # genkan | study
    ('Y', 6, 1.4, 8, [(1.6, 2.45), (6.0, 6.85)], [], 0),        # hall | study (fusuma), kitchen
    ('X', 4.6, 0, 4, [(.6, 3.2)], [], 0),                       # living | dining: a wide opening
    ('X', 3.6, 6, 10, [], [], 0),                               # study | kitchen
    ('Y', 8.6, 6.6, 8, [(6.9, 7.6)], [], 0), ('X', 6.6, 8.6, 10, [], [], 0),   # pantry
    ('Y', 5.0, 6.8, 8, [(7.0, 7.7)], [], 0), ('X', 6.8, 5.0, 6, [], [], 0),    # toilet
    ('Y', 4, 0, 1.4, [], [], 0, ZG),                            # genkan's west side (the hall wall goes on down to the front)
]
F2_WALLS = [
    ('X', 0, 0, 10, [], [(.8, 2.2), (4.4, 5.6), (6.6, 8.0)], -1),
    ('X', 8, 0, 10, [], [(1.2, 2.8), (6.6, 7.6)], 1),
    ('Y', 0, 0, 8, [], [(1.2, 2.6), (5.4, 6.8)], -1),
    ('Y', 10, 0, 8, [], [(1.2, 2.6), (6.0, 7.0)], 1),
    ('Y', 4, 0, 8, [(3.1, 3.95), (6.6, 7.45)], [], 0),
    ('Y', 6, 0, 8, [(1.2, 2.05), (6.7, 7.55)], [], 0),
    ('X', 4.2, 0, 4, [], [], 0), ('X', 4.2, 6, 10, [], [], 0),
]
B1 = (4, 1.0, 10, 7.0)     # basement box (x0, y0, x1, y1)
STAIR = (5.1, 2.6, 5.95, 5.6)   # up-stair footprint; rises toward the back (north); the cellar stair runs under it the other way
NSTEP = 13

def _face_holes(holes, wins, z0, sill, wh, top):
    hs = [(a, b, z0, max(z0, 0) + DOOR_H) for (a, b) in holes] + [(a, b, sill, sill + wh) for (a, b) in wins]
    return hs

def wall_v4(M, w, z0, top, sill, wh):
    """One wall of the plan: faces (hall.flat_wall) and a core. Plan coords in, Blender out."""
    ax, fixed, lo, hi, holes, wins, outer = w[:7]
    if len(w) > 7: z0 = w[7]
    # Blender axis and range: plan 'X' walls run along Blender X at Blender Y = Y(fixed); plan 'Y' walls run along Blender Y
    if ax == 'X':
        bax, bfix, blo, bhi = 'X', Y(fixed), X(lo), X(hi)
        bh = [(X(a), X(b), c, d) for (a, b, c, d) in _face_holes(holes, wins, z0, sill, wh, top)]
    else:
        bax, bfix, blo, bhi = 'Y', X(fixed), Y(hi), Y(lo)
        bh = [(Y(b), Y(a), c, d) for (a, b, c, d) in _face_holes(holes, wins, z0, sill, wh, top)]
    # flat_wall's `inward` is the sign of the direction leaving the room it faces: its face sits at fixed - inward*.06.
    # A partition gets a face on each side (at the wall line ± T/2); an outer wall one face, on the room side.
    if outer:
        sides = [-outer if ax == 'X' else outer]   # plan y runs against Blender Y
    else:
        sides = [1, -1]
    for s in sides:
        Hm.flat_wall(bax, bfix, blo, bhi, bh, M, s, z0=z0, top=top)
    # core: fills the thickness between the faces (and the openings' reveals)
    def core(a, b, c, d):
        if b - a < .01 or d - c < .01: return
        if bax == 'X': prim('cube', 'wallcore', loc=((a + b) / 2, bfix, (c + d) / 2), scale=((b - a) / 2, T / 2 - .02, (d - c) / 2), mat=M['wallcore'])
        else: prim('cube', 'wallcore', loc=(bfix, (a + b) / 2, (c + d) / 2), scale=(T / 2 - .02, (b - a) / 2, (d - c) / 2), mat=M['wallcore'])
    rects = [(blo, bhi, z0, top)]
    for (ha, hb, h0, h1) in bh:
        nr = []
        for (a, b, c, d) in rects:
            if hb <= a or ha >= b or h1 <= c or h0 >= d: nr.append((a, b, c, d)); continue
            if ha > a: nr.append((a, ha, c, d))
            if hb < b: nr.append((hb, b, c, d))
            if h1 < d: nr.append((max(a, ha), min(b, hb), h1, d))
            if h0 > c: nr.append((max(a, ha), min(b, hb), c, h0))
        rects = nr
    for r in rects: core(*r)
    # linings in the openings' reveals (painted board, not the bare core)
    for (ha, hb, h0, h1) in bh:
        dep = T / 2 + .005 if not outer else T / 2 - .01
        def lin(a, b, c, d):
            if bax == 'X': prim('cube', 'lining', loc=((a + b) / 2, bfix, (c + d) / 2), scale=((b - a) / 2, dep, (d - c) / 2), mat=M['trim'])
            else: prim('cube', 'lining', loc=(bfix, (a + b) / 2, (c + d) / 2), scale=(dep, (b - a) / 2, (d - c) / 2), mat=M['trim'])
        lin(ha, ha + .015, h0, h1); lin(hb - .015, hb, h0, h1); lin(ha, hb, h1 - .015, h1)
        if h0 > z0 + .01: lin(ha - .03, hb + .03, h0 - .02, h0 + .005)   # window stool

def slab_xy(name, x0, y0, x1, y1, z, th, mat, uv=.87, holes=()):
    """A horizontal slab over plan rect (x0,y0)-(x1,y1) with its top at z, minus plan-rect holes."""
    rects = [(x0, y0, x1, y1)]
    for (hx0, hy0, hx1, hy1) in holes:
        nr = []
        for (a, b, c, d) in rects:
            if hx1 <= a or hx0 >= c or hy1 <= b or hy0 >= d: nr.append((a, b, c, d)); continue
            if hx0 > a: nr.append((a, b, hx0, d))
            if hx1 < c: nr.append((hx1, b, c, d))
            if hy0 > b: nr.append((max(a, hx0), b, min(c, hx1), hy0))
            if hy1 < d: nr.append((max(a, hx0), hy1, min(c, hx1), d))
        rects = nr
    for (a, b, c, d) in rects:
        o = prim('cube', name, loc=((X(a) + X(c)) / 2, (Y(b) + Y(d)) / 2, z - th / 2), scale=((c - a) / 2, (d - b) / 2, th / 2), mat=mat)
        lib.uv_box(o, uv)

def door_leaf(M, ax, fixed, a, b, z0, hinge='lo', ang=0, name='door', h=DOOR_H, knob=True, mat=None):
    """A plain panel door in plan opening (a, b) of a wall; `ang` degrees open, swinging into +side."""
    w = b - a
    if ax == 'X':
        hx, hy = (X(a), Y(fixed)) if hinge == 'lo' else (X(b), Y(fixed))
    else:
        hx, hy = (X(fixed), Y(a)) if hinge == 'lo' else (X(fixed), Y(b))
    piv = lib.link(bpy.data.objects.new(f'{name}_pivot', None)); piv.location = (hx, hy, 0)
    s = 1 if hinge == 'lo' else -1
    m = mat or M['door']
    if ax == 'X': o = prim('cube', name, loc=(hx + s * w / 2, hy, z0 + h / 2), scale=(w / 2 - .01, .02, h / 2 - .01), mat=m)
    else: o = prim('cube', name, loc=(hx, hy - s * w / 2, z0 + h / 2), scale=(.02, w / 2 - .01, h / 2 - .01), mat=m)
    lib.uv_box(o, 1.0); o.parent = piv; o.location = o.location - piv.location
    if knob:
        zk = max(z0, 0) + .95
        for d in (-1, 1):
            if ax == 'X': kl = (hx + s * (w - .07), hy + d * .045, zk)
            else: kl = (hx + d * .045, hy - s * (w - .07), zk)
            k = prim('uv_sphere', f'{name}_knob', loc=kl, scale=(.028, .028, .028), mat=M['chrome'], segments=12, ring_count=8)
            k.parent = piv; k.location = k.location - piv.location
    piv.rotation_euler.z = math.radians(ang)
    return piv

def window_glass(M, ax, fixed, a, b, sill, wh):
    if ax == 'X': g = prim('cube', 'winglass', loc=((X(a) + X(b)) / 2, Y(fixed), sill + wh / 2), scale=((b - a) / 2, .005, wh / 2), mat=M['glass'])
    else: g = prim('cube', 'winglass', loc=(X(fixed), (Y(a) + Y(b)) / 2, sill + wh / 2), scale=(.005, (b - a) / 2, wh / 2), mat=M['glass'])
    g.visible_shadow = False

def stairs_up(M, z_bottom, z_top):
    """Boxed stair in STAIR, rising toward the back (plan +y = Blender -Y)."""
    x0, y0, x1, y1 = STAIR
    rise = (z_top - z_bottom) / NSTEP; run = (y1 - y0) / NSTEP
    for i in range(NSTEP):
        y = y0 + (i + .5) * run; z = z_bottom + (i + 1) * rise
        t = prim('cube', f'tread{i}', loc=((X(x0) + X(x1)) / 2, Y(y) - .015, z - .015), scale=((x1 - x0) / 2, run / 2 + .02, .015), mat=M['agari']); lib.uv_box(t, 1.25)
        r = prim('cube', f'riser{i}', loc=((X(x0) + X(x1)) / 2, Y(y - run / 2) - .01, z - rise / 2 - .015), scale=((x1 - x0) / 2, .01, rise / 2 - .015), mat=M['trim'])
    L = math.hypot(y1 - y0, z_top - z_bottom); ang = math.atan2(z_top - z_bottom, y1 - y0)
    for xs in (x0, x1):
        prim('cube', 'stringer', loc=(X(xs), (Y(y0) + Y(y1)) / 2, (z_bottom + z_top) / 2 - .12), rot=(-ang, 0, 0), scale=(.02, L / 2 + .1, .14), mat=M['trim'])
    # open side (west, toward the hall) gets balusters and a rail; the east side runs along the hall's east wall
    def z_rail(y):   # the handrail's centre line (it runs .92 above the stringer line, half a run back)
        return (z_bottom + z_top) / 2 + .92 + (y - ((y0 + y1) / 2 - run / 2)) * (z_top - z_bottom) / (y1 - y0)
    for i in range(NSTEP):
        y = y0 + (i + .5) * run; z = z_bottom + (i + 1) * rise
        h = max(.1, z_rail(y) - .03 - z)   # up to the rail's underside (they poked through it at the foot)
        prim('cube', 'baluster', loc=(X(x0), Y(y), z + h / 2), scale=(.016, .016, h / 2), mat=M['trim'])
    hr = prim('cube', 'handrail', loc=(X(x0), (Y(y0) + Y(y1)) / 2 - run / 2, (z_bottom + z_top) / 2 + .92), rot=(-ang, 0, 0), scale=(.03, L / 2 + .05, .025), mat=M['door']); lib.uv_box(hr, 1.0)
    prim('cube', 'newel', loc=(X(x0), Y(y0) + .05, z_bottom + .55), scale=(.05, .05, .55), mat=M['trim'])
    prim('cube', 'newelcap', loc=(X(x0), Y(y0) + .05, z_bottom + 1.12), scale=(.065, .065, .025), mat=M['door'])

def stairs_down(M):
    """Cellar stair under the up-stair: from the cellar door at the stair's back end (plan y 5.6) down toward the front."""
    x0, y0, x1, y1 = STAIR
    n = 12; rise = (0 - ZB) / n; run = (y1 - y0) / n
    for i in range(n):
        y = y1 - (i + .5) * run; z = -(i + 1) * rise
        t = prim('cube', f'ctread{i}', loc=((X(x0) + X(x1)) / 2, Y(y), z), scale=((x1 - x0) / 2 - .02, run / 2 + .02, .02), mat=M['agari']); lib.uv_box(t, 1.25)

def fusuma(M, fixed, a, b):
    """Two sliding paper panels in a plan-'Y' opening, on two tracks (closed)."""
    if 'washi' not in M:
        M['washi'] = mat_basic('washi', (.62, .58, .49), .85)
        M['fusumaframe'] = mat_basic('fusumaframe', (.07, .055, .045), .4)
    a, b = a + .015, b - .015    # inside the reveal linings, so the outer frames show
    w = (b - a) / 2 + .02
    for i, (c, dx) in enumerate(((a + w / 2, -.018), (b - w / 2, .018))):
        x = X(fixed) + dx; y = Y(c)
        prim('cube', f'fusuma{i}', loc=(x, y, DOOR_H / 2), scale=(.01, w / 2 - .02, DOOR_H / 2 - .02), mat=M['washi'])
        for sy in (-1, 1): prim('cube', 'fusuma_fr', loc=(x, y + sy * (w / 2 - .02), DOOR_H / 2), scale=(.014, .02, DOOR_H / 2), mat=M['fusumaframe'])
        for z in (.02, DOOR_H - .02): prim('cube', 'fusuma_fr', loc=(x, y, z), scale=(.014, w / 2, .02), mat=M['fusumaframe'])
        for sx in (-1, 1):   # recessed pulls on both faces
            prim('cylinder', 'hikite', loc=(x + sx * .011, y + (w / 2 - .09) * (1 if i == 0 else -1), .85), rot=(0, math.pi / 2, 0), scale=(.025, .025, .002), mat=M['fusumaframe'])

def genkan_fit(M):
    """Shoe cabinet along the genkan's east wall, kick strips where the walls meet the lower genkan floor."""
    x0, x1, y0, y1 = 5.6, 5.94, .1, 1.3
    sc = prim('cube', 'shoecab', loc=((X(x0) + X(x1)) / 2, (Y(y0) + Y(y1)) / 2, ZG + .44), scale=((x1 - x0) / 2, (y1 - y0) / 2, .44), mat=M['door']); lib.uv_box(sc, 1.0)
    tp = prim('cube', 'shoecab_top', loc=((X(x0) + X(x1)) / 2 - .015, (Y(y0) + Y(y1)) / 2, ZG + .895), scale=((x1 - x0) / 2 + .02, (y1 - y0) / 2 + .02, .015), mat=M['agari']); lib.uv_box(tp, 1.25)
    for yy in (.1 + .4, .1 + .8):   # door gaps on the cabinet front
        prim('cube', 'shoecab_gap', loc=(X(x0) - .001, Y(yy), ZG + .46), scale=(.002, .004, .36), mat=M['fusumaframe'] if 'fusumaframe' in M else M['trim'])
    prim('cube', 'shoecab_plinth', loc=(X(x0) + .03, (Y(y0) + Y(y1)) / 2, ZG + .04), scale=(.005, (y1 - y0) / 2, .04), mat=M['trim'])

def under_stair(M):
    """Beadboard under the up-stair's open (west) side, stepping with the treads; the cellar door's wall at its back end."""
    x0, y0, x1, y1 = STAIR
    rise = F2 / NSTEP; run = (y1 - y0) / NSTEP
    for i in range(NSTEP):   # one board per tread, up to just under it, from below the floor (the cellar shaft is beneath)
        ya, yb = y0 + i * run, y0 + (i + 1) * run
        top = (i + 1) * rise - .035
        # like the hall's walls: beadboard to the chair rail, plaster above (one flat board read as a blank slab in print)
        wt = min(top, .92)
        o = prim('cube', 'understair', loc=(X(x0) + .01, (Y(ya) + Y(yb)) / 2, (wt - .06) / 2), scale=(.02, run / 2 + .001, (wt + .06) / 2), mat=M['beadboard']); lib.uv_box(o, 1.0)
        if top > .92:
            o = prim('cube', 'understair_pl', loc=(X(x0) + .01, (Y(ya) + Y(yb)) / 2, (top + .92) / 2), scale=(.02, run / 2 + .001, (top - .92) / 2), mat=M['plaster']); lib.uv_box(o, .87)
    ny = (.92 + .035) / rise * run   # where the stair's underside passes the chair rail's height
    yr = y0 + ny
    prim('cube', 'understair_rail', loc=(X(x0) - .015, (Y(yr) + Y(y1)) / 2, .94), scale=(.0175, (y1 - yr) / 2, .03), mat=M['trim'])
    prim('cube', 'understair_base', loc=(X(x0) - .015, (Y(y0) + Y(y1)) / 2, .065), scale=(.015, (y1 - y0) / 2, .065), mat=M['trim'])
    # the cellar door's wall (plan y 5.6), full height under the landing; door leaf hung in build_house4
    wall_v4(M, ('X', 5.6, x0 - .04, 6.0 - T / 2, [(5.12, 5.93)], [], 0), 0.0, H1, SILL1, WH1)
    # a hand-written note on the cellar door (hall side)
    nt = mat_image('note4', Hm.note_tex(f'{P.KF}/note_basement.png', ['地下', '発電機', '※換気注意']), rough=.8, bump=0)
    # faces the lobby (plan +y, Blender -Y), where the bulb is and where you read it from (it faced into the door before)
    return prim('plane', 'note', loc=(X(5.52), Y(5.6) - .03, 1.45), rot=(math.pi / 2, 0, 0), scale=(.09, .12, 1), mat=nt)

def cellar_shaft(M):
    """Walls round the cellar stair below the 1F floor, and the barred door at its foot (bar on the basement side)."""
    x0, y0, x1, y1 = STAIR
    for w in (('Y', x0 - .04, 2.5, y1, [], [], 0), ('Y', 6.0, 2.5, y1, [], [], 0), ('X', y1 + .04, x0 - .04, 6.0, [], [], 0),
              ('X', 2.5, x0 - .1, 6.0, [(5.12, 5.93)], [], 0)):
        wall_v4(M, w, ZB, -.031, -1, .1)   # tops just under the 1F floor (coplanar tops z-fought with it)
    # barred door, plank, swings into the basement; the bar sits in two brackets on the basement side (plan -y)
    dh = DOOR_H
    if 'barplanks' not in M: M['barplanks'] = mat_image('barplanks', lib.tex_path('door'), rough=.75, coords='UV', tint=(.55, .5, .45))
    piv = door_leaf(M, 'X', 2.5, 5.12, 5.93, ZB, name='door_barred', knob=False, mat=M['barplanks'])
    for z in (ZB + .35, ZB + 1.65):   # battens on the basement face
        o = prim('cube', 'batten', loc=(X(5.525), Y(2.5) + .035, z), scale=(.37, .015, .06), mat=M['barplanks']); lib.uv_box(o, 1.0)
        o.parent = piv; o.location = o.location - piv.location
    yb = Y(2.5) + .06
    for xx in (5.05, 6.0):
        prim('cube', 'bar_bracket', loc=(X(xx), yb + .02, ZB + 1.05), scale=(.03, .03, .05), mat=M['black'] if 'black' in M else M['chrome'])
    bar = prim('cube', 'bar', loc=(X(5.52), yb + .045, ZB + 1.05), scale=(.5, .03, .045), mat=M['agari']); lib.uv_box(bar, 1.25)
    return piv

def build_house4(M, floors=('1F', '2F', 'B1')):
    random.seed(41)
    Hm.style_mats(M)
    # the cores get their own plain material: sharing the plaster image with the faces turned the faces black in Cycles
    M['wallcore'] = mat_basic('wallcore', (.48, .44, .37), .9)
    a = {}
    if '1F' in floors:
        for w in F1_WALLS: wall_v4(M, w, 0.0, H1, SILL1, WH1)
        for w in F1_WALLS:
            for (lo, hi) in w[5]: window_glass(M, w[0], w[1], lo, hi, SILL1, WH1)
        # floors: genkan (tile, lower) in the hall's front 1.4 m, the rest wood; the cellar stair opening under the up-stair
        slab_xy('genkan', 4, 0, 6, 1.4, ZG, .04, M['tile'], 1.2)
        slab_xy('floor1', 0, 0, 10, 8, 0.0, .03, M['floor'], holes=[(4, 0, 6, 1.4), STAIR])
        o = prim('cube', 'agarikamachi', loc=(X(5), Y(1.4) + .05, -.09), scale=(1.0, .07, .105), mat=M['agari']); lib.uv_box(o, 1.25)
        slab_xy('ceiling1', 0, 0, 10, 8, H1 + .03, .03, M['plaster'], holes=[STAIR])
        stairs_up(M, 0.0, F2)
        # interior doors (closed unless a scene opens them); the front and back doors are left to the scene
        a['doors'] = {
            'living': door_leaf(M, 'Y', 4, 3.1, 3.95, 0, name='door_living'),
            'dining': door_leaf(M, 'Y', 4, 6.1, 6.95, 0, name='door_dining'),
            'kitchen': door_leaf(M, 'Y', 6, 6.0, 6.85, 0, name='door_kitchen'),
            'toilet': door_leaf(M, 'Y', 5.0, 7.0, 7.7, 0, name='door_toilet'),
            'pantry': door_leaf(M, 'Y', 8.6, 6.9, 7.6, 0, name='door_pantry'),
            # the front door swings out (Japanese genkan); the back door out onto the back porch
            'front': door_leaf(M, 'X', 0, 4.45, 5.55, ZG, hinge='lo', name='door_front', h=2.0 - ZG),
            'back': door_leaf(M, 'Y', 10, 4.4, 5.35, 0, hinge='lo', name='door_back'),
            'cellar': door_leaf(M, 'X', 5.6, 5.12, 5.93, 0, hinge='hi', name='door_cellar'),
        }
        a['doors']['front'].name = 'door_pivot'   # Godot finds the front door by this name (the knocks shake it)
        fusuma(M, 6, 1.6, 2.45)
        lobby_lamp(M)
        genkan_fit(M)
        note = under_stair(M)
        piv = a['doors']['cellar']; note.parent = piv; note.location = note.location - piv.location   # the note goes with the door
        # thresholds: the gap under each leaf shows a board, not the dark beyond
        for (ax, fx, lo, hi) in (('X', 5.6, 5.12, 5.93), ('Y', 4, 3.1, 3.95), ('Y', 4, 6.1, 6.95), ('Y', 6, 6.0, 6.85), ('Y', 5.0, 7.0, 7.7), ('Y', 8.6, 6.9, 7.6), ('Y', 6, 1.6, 2.45)):
            if ax == 'X': o = prim('cube', 'threshold', loc=((X(lo) + X(hi)) / 2, Y(fx), .006), scale=((hi - lo) / 2, T / 2, .006), mat=M['agari'])
            else: o = prim('cube', 'threshold', loc=(X(fx), (Y(lo) + Y(hi)) / 2, .006), scale=(T / 2, (hi - lo) / 2, .006), mat=M['agari'])
            lib.uv_box(o, 1.25)
    if '2F' in floors:
        for w in F2_WALLS: wall_v4(M, w, F2, H2, SILL2, WH2)
        for w in F2_WALLS:
            for (lo, hi) in w[5]: window_glass(M, w[0], w[1], lo, hi, SILL2, WH2)
        slab_xy('floor2', 0, 0, 10, 8, F2, .03, M['floor'], holes=[(STAIR[0], STAIR[1], STAIR[2], STAIR[3])])
        slab_xy('ceiling2', 0, 0, 10, 8, H2 + .03, .03, M['plaster'])
        # rail round the stairwell on the 2F landing side
        for (p0, p1) in (((STAIR[0], STAIR[1]), (STAIR[2], STAIR[1])), ((STAIR[0], STAIR[1]), (STAIR[0], STAIR[3]))):
            ax = 'X' if p0[1] == p1[1] else 'Y'
            if ax == 'X': prim('cube', 'wellrail', loc=((X(p0[0]) + X(p1[0])) / 2, Y(p0[1]), F2 + .9), scale=((p1[0] - p0[0]) / 2, .03, .025), mat=M['door'])
            else: prim('cube', 'wellrail', loc=(X(p0[0]), (Y(p0[1]) + Y(p1[1])) / 2, F2 + .9), scale=(.03, (p1[1] - p0[1]) / 2, .025), mat=M['door'])
    if 'B1' in floors:
        x0, y0, x1, y1 = B1
        for w in [('X', y0, x0, x1, [], [], -1), ('X', y1, x0, x1, [], [], 1), ('Y', x0, y0, y1, [], [], -1), ('Y', x1, y0, y1, [], [(6.15, 6.75)], 1)]:
            wall_v4(M, w, ZB, -.3, -1.6, .4)   # the small east window: Z -1.6..-1.2, above the ground on the east slope (外観スレッドと合わせた)
        slab_xy('floorB', x0, y0, x1, y1, ZB, .05, M['tile'], 1.2)
        stairs_down(M)
        cellar_shaft(M)
    a['F2'] = F2; a['H1'] = H1; a['H2'] = H2; a['ZB'] = ZB
    a['front_door'] = Vector((X(5.0), Y(0), 1.0))
    return a


# ---------------------------------------------------------------- scene helpers
LAMP = (5.55, 6.15)   # plan: the ceiling of the little lobby between the cellar door (y 5.6) and the toilet (y 6.8)
def lobby_lamp(M):
    """The one light left on at the back of the hall: a frosted globe on a small ceiling rose over the cellar door's
    lobby. The back of the hall has no window that sees the door (the toilet stands in the way), so this bulb is what
    lets the door and its note be read. Godot builds the light from 'lamp_lobby' in lights.json (main.gd)."""
    x, y, z = X(LAMP[0]), Y(LAMP[1]), H1
    if 'lampglass' not in M: M['lampglass'] = mat_basic('lampglass', (.95, .9, .8), .4, emit=lib.kelvin(2700), estr=6)
    if 'lampbrass' not in M: M['lampbrass'] = mat_basic('lampbrass', (.55, .42, .22), .35, metal=1)
    prim('cylinder', 'lamp_rose', loc=(x, y, z - .015), scale=(.06, .06, .015), mat=M['lampbrass'], vertices=24)
    prim('cylinder', 'lamp_stem', loc=(x, y, z - .1), scale=(.008, .008, .08), mat=M['lampbrass'], vertices=12)
    prim('cylinder', 'lamp_cap', loc=(x, y, z - .19), scale=(.045, .045, .02), mat=M['lampbrass'], vertices=24)
    g = prim('uv_sphere', 'lamp_globe', loc=(x, y, z - .28), scale=(.09, .09, .09), mat=M['lampglass'], segments=24, ring_count=12)
    lib.smooth(g)
    lib.point('lamp_lobby', (x, y, z - .28), 40, k=2700, radius=.06)

def prune(box, keep=('ext_',)):
    """Delete meshes whose bounds lie wholly outside box ((x0, y0, z0), (x1, y1, z1)): the rooms behind shut doors in a
    hall scene (they would take most of the lightmap's texels and are never seen)."""
    (x0, y0, z0), (x1, y1, z1) = box
    gone = 0
    for o in list(bpy.data.objects):
        if o.type != 'MESH' or o.name.startswith(keep): continue
        bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
        if (max(v.x for v in bb) < x0 or min(v.x for v in bb) > x1 or max(v.y for v in bb) < y0 or min(v.y for v in bb) > y1
                or max(v.z for v in bb) < z0 or min(v.z for v in bb) > z1):
            bpy.data.objects.remove(o, do_unlink=True); gone += 1
    print('prune: removed', gone)

COLLIDE = ('wallcore', 'floor1', 'genkan', 'shoecab', 'door_living', 'door_dining', 'door_kitchen', 'door_toilet',
           'door_pantry', 'door_cellar', 'door_front', 'door_back', 'fusuma', 'agarikamachi')
def colliders():
    """Axis-aligned boxes for the player (Blender centre + size), from the built meshes; the staircase is one block
    (no climbing), the genkan step a ramp so you can walk back up. Floors are made .5 m deep."""
    out = []; bpy.context.view_layer.update()
    for o in bpy.data.objects:
        if o.type != 'MESH' or not o.name.startswith(COLLIDE) or o.name.endswith('_knob'): continue
        bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
        lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
        hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
        if o.name.startswith(('floor1', 'genkan')): lo.z = hi.z - .5
        if o.name.startswith('wallcore'):   # the core is the wall less its faces: collide with the whole thickness
            if hi.x - lo.x < hi.y - lo.y: lo.x -= .02; hi.x += .02
            else: lo.y -= .02; hi.y += .02
        out.append(dict(c=[round(v, 3) for v in (lo + hi) / 2], s=[round(v, 3) for v in hi - lo]))
    x0, y0, x1, y1 = STAIR
    out.append(dict(c=[(X(x0) + X(x1)) / 2, (Y(y0) + Y(y1)) / 2, 1.3], s=[x1 - x0, y1 - y0, 2.6]))
    out.append(dict(c=[X(5), Y(1.4) + .2, ZG / 2], s=[2.0, .45, .04], rx=math.atan2(ZG, .4), ramp=True))
    return out
