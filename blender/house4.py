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
from lib import prim, mat_basic

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
    ('X', 0, 0, 10, [(4.45, 5.55)], [(.6, 1.8), (2.4, 3.4), (6.6, 7.6), (8.4, 9.4), (4.15, 4.35)], -1),   # front (south)
    ('X', 8, 0, 10, [], [(1.2, 2.8), (6.8, 8.0)], 1),                                                        # back (north)
    ('Y', 0, 0, 8, [], [(1.0, 1.8), (5.4, 7.0)], -1),                                                       # west
    ('Y', 10, 0, 8, [(4.4, 5.35)], [(1.0, 2.4), (6.0, 6.4)], 1),                                            # east (back porch door)
    ('Y', 4, 1.4, 8, [(3.1, 3.95), (6.1, 6.95)], [], 0),        # hall | living, dining
    ('Y', 6, 0, 8, [(1.6, 2.45), (6.0, 6.85)], [], 0),          # hall | study (fusuma), kitchen
    ('X', 4.6, 0, 4, [(.6, 3.2)], [], 0),                       # living | dining: a wide opening
    ('X', 3.6, 6, 10, [], [], 0),                               # study | kitchen
    ('Y', 8.6, 6.6, 8, [(6.9, 7.6)], [], 0), ('X', 6.6, 8.6, 10, [], [], 0),   # pantry
    ('Y', 5.0, 6.8, 8, [(7.0, 7.7)], [], 0), ('X', 6.8, 5.0, 6, [], [], 0),    # toilet
    ('Y', 4, 0, 1.4, [], [], 0),                                # genkan's west side (the hall wall goes on down to the front)
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
    hs = [(a, b, z0, z0 + DOOR_H) for (a, b) in holes] + [(a, b, sill, sill + wh) for (a, b) in wins]
    return hs

def wall_v4(M, w, z0, top, sill, wh):
    """One wall of the plan: faces (hall.flat_wall) and a core. Plan coords in, Blender out."""
    ax, fixed, lo, hi, holes, wins, outer = w
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

def door_leaf(M, ax, fixed, a, b, z0, hinge='lo', ang=0, name='door'):
    """A plain panel door in plan opening (a, b) of a wall; `ang` degrees open, swinging into +side."""
    w = b - a
    if ax == 'X':
        hx, hy = (X(a), Y(fixed)) if hinge == 'lo' else (X(b), Y(fixed))
    else:
        hx, hy = (X(fixed), Y(a)) if hinge == 'lo' else (X(fixed), Y(b))
    piv = lib.link(bpy.data.objects.new(f'{name}_pivot', None)); piv.location = (hx, hy, 0)
    s = 1 if hinge == 'lo' else -1
    if ax == 'X': o = prim('cube', name, loc=(hx + s * w / 2, hy, z0 + DOOR_H / 2), scale=(w / 2 - .01, .02, DOOR_H / 2 - .01), mat=M['door'])
    else: o = prim('cube', name, loc=(hx, hy - s * w / 2, z0 + DOOR_H / 2), scale=(.02, w / 2 - .01, DOOR_H / 2 - .01), mat=M['door'])
    lib.uv_box(o, 1.0); o.parent = piv; o.location = o.location - piv.location
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
    for i in range(NSTEP):
        y = y0 + (i + .5) * run; z = z_bottom + (i + 1) * rise
        prim('cube', 'baluster', loc=(X(x0), Y(y), z + .45), scale=(.016, .016, .45), mat=M['trim'])
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
        slab_xy('ceiling1', 0, 0, 10, 8, H1 + .03, .03, M['plaster'], holes=[(STAIR[0], STAIR[1], STAIR[2], STAIR[3] + .75)])
        stairs_up(M, 0.0, F2)
        # interior doors (closed unless a scene opens them); the front and back doors are left to the scene
        a['doors'] = {
            'living': door_leaf(M, 'Y', 4, 3.1, 3.95, 0, name='door_living'),
            'dining': door_leaf(M, 'Y', 4, 6.1, 6.95, 0, name='door_dining'),
            'kitchen': door_leaf(M, 'Y', 6, 6.0, 6.85, 0, name='door_kitchen'),
            'toilet': door_leaf(M, 'Y', 5.0, 7.0, 7.7, 0, name='door_toilet'),
            'pantry': door_leaf(M, 'Y', 8.6, 6.9, 7.6, 0, name='door_pantry'),
        }
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
            wall_v4(M, w, ZB, -.3, -.75, .4)
        slab_xy('floorB', x0, y0, x1, y1, ZB, .05, M['tile'], 1.2)
        stairs_down(M)
    a['F2'] = F2; a['H1'] = H1; a['H2'] = H2; a['ZB'] = ZB
    a['front_door'] = Vector((X(5.0), Y(0), 1.0))
    return a
