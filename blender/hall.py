"""Entrance hall of the rental cabin: staircase on the left, basement door under the stairs,
genkan + front door on the far right, opening to the living room on the right.
build_hall(M) returns a dict of handy anchor points."""
import sys, math, random
sys.path.insert(0, '/home/claude/kf')
import bpy
from mathutils import Vector
import lib
import door as D
from lib import prim, mat_basic, mat_image, tex_path, kelvin
from door import cyl_between

XL, XR, YB, YF = -1.6, 1.6, .6, 6.3      # walls
ZG, H = D.ZG, D.H
YG = 4.6                                   # genkan step line (genkan spans x in [GX0, XR])
GX0 = -.05
DX0, DX1 = .35, 1.17                       # front door opening
ST_X0, ST_X1, ST_Y0, ST_Y1 = XL, -.78, 1.25, 4.6   # staircase footprint (rises toward +y)
NSTEP = 10

def note_tex(path, lines):
    from PIL import Image, ImageDraw, ImageFont
    im = Image.new('RGB', (360, 480), (226, 220, 204)); d = ImageDraw.Draw(im)
    f1 = ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc', 96, index=0)
    f2 = ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc', 44, index=0)
    d.text((180, 120), lines[0], font=f1, fill=(30, 28, 26), anchor='mm')
    d.text((180, 250), lines[1], font=f2, fill=(30, 28, 26), anchor='mm')
    d.text((180, 330), lines[2], font=f2, fill=(150, 30, 26), anchor='mm')
    d.rectangle((140, 0, 220, 26), fill=(200, 190, 150))
    im.save(path); return path

def build_hall(M, ceiling=True, back_wall=False, cut=None, door_open=False):
    random.seed(5)
    # ---- walls
    D.logs_along('Y', XL, YB, YF, [], M, -1, cut)
    D.logs_along('Y', XR, YB, YF, [(1.35, 2.85, ZG, 2.05)], M, 1, cut)
    D.logs_along('X', YF, XL, XR, [(DX0, DX1, ZG, 2.0)], M, 1, cut)
    if back_wall:
        # the living-room door, shut (the room beyond stays dark and unseen)
        D.logs_along('X', YB, XL, XR, [(-.78, .02, 0, 2.0)], M, -1, cut)
        bd = prim('cube', 'livingdoor', loc=(-.38, YB + .02, 1.0), scale=(.4, .02, 1.0), mat=M['door']); lib.uv_box(bd, 1.0, offset=(.6, 0))
        for x in (-.8, .04):
            fr = prim('cube', 'livingframe', loc=(x, YB + .03, 1.0), scale=(.025, .05, 1.03), mat=M['framewood']); lib.uv_box(fr, 1.0)
        fr = prim('cube', 'livingframe', loc=(-.38, YB + .03, 2.03), scale=(.445, .05, .025), mat=M['framewood']); lib.uv_box(fr, 1.0)
        kn = prim('cylinder', 'livingknob', loc=(-.05, YB + .06, 1.0), rot=(math.pi / 2, 0, 0), scale=(.025, .025, .03), mat=M.get('brass', M['door']))
    # ---- floors
    fl = prim('cube', 'floor', loc=(0, (YB + YG) / 2, -.015), scale=(XR - .02, (YG - YB) / 2, .015), mat=M['floor']); lib.uv_box(fl, .87)
    gk = prim('cube', 'genkan', loc=((GX0 + XR) / 2, (YG + YF) / 2, ZG - .02), scale=((XR - GX0) / 2, (YF - YG) / 2, .02), mat=M['tile']); lib.uv_box(gk, 1.2)
    ag = prim('cube', 'agarikamachi', loc=((GX0 + XR) / 2, YG - .05, -.09), scale=((XR - GX0) / 2, .07, .105), mat=M['agari']); lib.uv_box(ag, 1.25)
    # raised block left of the genkan (shoe cabinet + floor)
    sc = prim('cube', 'shoecab', loc=((ST_X1 + GX0) / 2 - .02, (YG + YF) / 2, .45), scale=((GX0 - ST_X1) / 2, (YF - YG) / 2 - .05, .45), mat=M['door']); lib.uv_box(sc, 1.0)
    top_ = prim('cube', 'shoecab_top', loc=((ST_X1 + GX0) / 2 - .02, (YG + YF) / 2, .915), scale=((GX0 - ST_X1) / 2 + .03, (YF - YG) / 2 - .02, .015), mat=M['agari']); lib.uv_box(top_, 1.25)
    fl2 = prim('cube', 'floor_l', loc=((XL + ST_X1) / 2, (YG + YF) / 2, -.015), scale=((ST_X1 - XL) / 2, (YF - YG) / 2, .015), mat=M['floor']); lib.uv_box(fl2, .87)
    # ---- ceiling with the stairwell open
    if ceiling:
        ce = prim('cube', 'ceiling', loc=((ST_X1 + XR) / 2, (YB + YF) / 2, H + .015), scale=((XR - ST_X1) / 2, (YF - YB) / 2, .015), mat=M['ceil']); lib.uv_box(ce, .87)
        ce2 = prim('cube', 'ceiling_l', loc=((XL + ST_X1) / 2, (YB + ST_Y0) / 2, H + .015), scale=((ST_X1 - XL) / 2, (ST_Y0 - YB) / 2, .015), mat=M['ceil']); lib.uv_box(ce2, .87)
        for yb in (1.2, 2.9, 4.6):
            b = cyl_between('beam', (ST_X1, yb, H - .1), (XR + .05, yb, H - .1), .1, M['log'], 16); lib.uv_cyl(b, 1.25)
        ridge = cyl_between('stairbeam', (ST_X1, ST_Y0 - .1, H - .12), (ST_X1, YF, H - .12), .12, M['log'], 16); lib.uv_cyl(ridge, 1.25)
    # ---- staircase: half-log treads on a log stringer, rising toward the front wall
    rise = H / NSTEP; run = (ST_Y1 - ST_Y0) / NSTEP
    for i in range(NSTEP):
        y = ST_Y0 + (i + .5) * run; z = (i + 1) * rise
        t = cyl_between(f'tread{i}', (ST_X0 + .05, y, z - .06), (ST_X1, y, z - .06), .17, M['log'], 16)
        t.scale = (1, .62, 1); lib.uv_cyl(t, 1.25)
    st = cyl_between('stringer', (ST_X1 + .02, ST_Y0 - .25, -.05), (ST_X1 + .02, ST_Y1 + .1, H + .1), .09, M['log'], 14); lib.uv_cyl(st, 1.25)
    for i in (0, 4, 8):
        y = ST_Y0 + (i + .5) * run; z = (i + 1) * rise
        p = cyl_between('baluster', (ST_X1 + .02, y, z), (ST_X1 + .02, y, z + .9), .03, M['log'], 10); lib.uv_cyl(p, 1.25)
    hr = cyl_between('handrail', (ST_X1 + .02, ST_Y0, .95), (ST_X1 + .02, ST_Y1 + .2, H + .95), .035, M['log'], 10); lib.uv_cyl(hr, 1.25)
    # under-stair wall + basement door facing the hall (+x)
    yd0, yd1 = 3.35, 4.05
    def under_panel(y0, y1):
        h = lambda y: max(.3, (y - ST_Y0) / run * rise - .25)
        hgt = min(h(y0), h(y1))
        o = prim('cube', 'understair', loc=(ST_X1 - .03, (y0 + y1) / 2, hgt / 2), scale=(.025, (y1 - y0) / 2, hgt / 2), mat=M['door']); lib.uv_box(o, 1.0)
    for a, b in ((ST_Y0 + 1.1, 2.5), (2.5, yd0), (yd1, ST_Y1)): under_panel(a, b)
    bd = prim('cube', 'basement_door', loc=(ST_X1 - .02, (yd0 + yd1) / 2, .85), scale=(.02, (yd1 - yd0) / 2 - .01, .85), mat=M['door']); lib.uv_box(bd, 1.0, offset=(.3, 0))
    nt = mat_image('note', note_tex('/home/claude/kf/note_basement.png', ['地下', '発電機', '※換気注意']), rough=.8, bump=0)
    n = prim('plane', 'note', loc=(ST_X1 + .005, 3.7, 1.35), rot=(math.pi / 2, 0, math.pi / 2), scale=(.09, .12, 1), mat=nt)
    lv = prim('cube', 'bd_lever', loc=(ST_X1 + .02, yd0 + .08, .95), scale=(.012, .05, .01), mat=M['chrome'])
    # ---- front door (slit window, left of centre)
    dm = M['door']; zc = (ZG + 2.0) / 2; hz = (2.0 - ZG) / 2
    sx0, sx1 = DX0 + .14, DX0 + .27
    parts = [(DX0, sx0, ZG, 2.0), (sx1, DX1, ZG, 2.0), (sx0, sx1, 1.72, 2.0), (sx0, sx1, ZG, .45)]
    piv = lib.link(bpy.data.objects.new('door_pivot', None)); piv.location = (DX0, YF - .02, 0)
    for i, (a, b, z0, z1) in enumerate(parts):
        o = prim('cube', f'door_{i}', loc=((a + b) / 2, YF - .02, (z0 + z1) / 2), scale=((b - a) / 2, .025, (z1 - z0) / 2), mat=dm); lib.uv_box(o, 1.0, offset=(0, 0))
        o.parent = piv; o.location = o.location - piv.location
    gl = prim('plane', 'slitglass', loc=((sx0 + sx1) / 2, YF - .02, (1.72 + .45) / 2), rot=(math.pi / 2, 0, 0), scale=((sx1 - sx0) / 2, (1.72 - .45) / 2, 1), mat=M['glass'])
    gl.visible_shadow = False; gl.parent = piv; gl.location = gl.location - piv.location
    if door_open: piv.rotation_euler.z = math.radians(105)   # Japanese front doors swing outward
    for x in (DX0 - .035, DX1 + .035):
        o = prim('cube', 'jamb', loc=(x, YF - .04, zc), scale=(.035, .09, hz + .02), mat=M['framewood'])
    prim('cube', 'lintel', loc=((DX0 + DX1) / 2, YF - .04, 2.04), scale=((DX1 - DX0) / 2 + .07, .09, .04), mat=M['framewood'])
    prim('cube', 'lever', loc=(DX1 - .1, YF - .07, .9), scale=(.06, .012, .01), mat=M['chrome'])
    # ---- living room through the right opening: a couch edge
    lf = prim('cube', 'lr_floor', loc=(XR + 1.5, 2.2, -.01), scale=(1.5, 2.0, .01), mat=M['floor']); lib.uv_box(lf, .87)
    prim('cube', 'couch', loc=(XR + 1.0, 2.0, .25), scale=(.45, .9, .25), mat=M['corduroy'])
    return dict(slit=Vector(((sx0 + sx1) / 2, YF, 1.1)), slit_x=(sx0, sx1), door_c=Vector(((DX0 + DX1) / 2, YF, 1.0)))

def genkan_props(M, shoes=4, umbrellas=6):
    random.seed(9)
    shoe = [mat_basic('shoe0', (.08, .08, .09), .6), mat_basic('shoe1', (.72, .7, .66), .7), mat_basic('shoe2', (.25, .19, .13), .6),
            mat_basic('shoe3', (.1, .12, .2), .6), mat_basic('shoe4', (.55, .3, .25), .6)]
    for i in range(shoes):
        for d in (-.06, .06):
            o = prim('cube', 'shoe', loc=(.2 + i * .22 + d, 4.95 + (i % 2) * .3, ZG + .045), scale=(.045, .13, .04), mat=shoe[i])
            o.rotation_euler.z = random.uniform(-.3, .3)
    prim('cylinder', 'ustand', loc=(1.42, 6.05, ZG + .22), vertices=16, radius=.09, depth=.44, mat=M['black'])
    for i in range(umbrellas):
        a = i / umbrellas * math.tau
        cyl_between('umb', (1.42 + math.cos(a) * .04, 6.05 + math.sin(a) * .04, ZG + .05), (1.42 + math.cos(a) * .1, 6.05 + math.sin(a) * .1, ZG + .95), .03, M['umb'], 8)
        cyl_between('uh', (1.42 + math.cos(a) * .1, 6.05 + math.sin(a) * .1, ZG + .95), (1.42 + math.cos(a) * .12, 6.05 + math.sin(a) * .12, ZG + 1.06), .009, M['white'], 6)

def tape_mark(x, y, cam_xy, name_png):
    """Gaffer-tape X plus a short strip with the name, turned to read from the camera."""
    xm = mat_image('tapeX', '/home/claude/kf/tape_blank.png', rough=.6, bump=0)
    for k, r in enumerate((.62, -.62)):
        prim('plane', 'tapeX', loc=(x, y, .004 + k * .0008), rot=(0, 0, r), scale=(.13, .026, 1), mat=xm)
    ang = math.atan2(y - cam_xy[1], x - cam_xy[0]) - math.pi / 2
    nm = mat_image('tapeN', f'/home/claude/kf/{name_png}', rough=.6, bump=0)
    off = Vector((math.cos(ang + math.pi / 2), math.sin(ang + math.pi / 2), 0)) * -.21
    prim('plane', 'tapeN', loc=(x + off.x, y + off.y, .0045), rot=(0, 0, ang), scale=(.2, .0375, 1), mat=nm)
