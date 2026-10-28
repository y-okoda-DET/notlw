"""Alternative B: 23:00 as Kiryu's blocking diagram. Every wall cut at 1.1 m, seen from above in parallel projection:
who stands where, which side of the door, which mark is empty."""
import sys, math, random
sys.path.insert(0, '/home/claude/kf')
import bpy
from mathutils import Vector
import lib, door as D, hall as Hm
from lib import prim, mat_basic, kelvin
CUT = 1.1

def build():
    lib.reset(); s = bpy.context.scene
    M = D.mats()
    A = Hm.build_hall(M, ceiling=False, back_wall=True, cut=CUT)
    # trim anything that rises above the cut (stairs, stringer, handrail, door top) except people
    for o in list(bpy.data.objects):
        if o.type != 'MESH': continue
        if any(o.name.startswith(k) for k in ('stringer', 'handrail', 'baluster', 'lintel', 'jamb', 'stairbeam')):
            bpy.data.objects.remove(o); continue
        if o.name.startswith('tread') and o.location.z > CUT + .1:
            bpy.data.objects.remove(o)
    # door pieces: clip by scaling down to the cut
    for o in list(bpy.data.objects):
        if o.name.startswith(('door_', 'understair', 'basement_door')) and o.type == 'MESH':
            bpy.context.view_layer.update()
            zs = [(o.matrix_world @ v.co).z for v in o.data.vertices]
            z0, z1 = min(zs), max(zs)
            if z0 >= CUT: bpy.data.objects.remove(o); continue
            if z1 > CUT:
                for v in o.data.vertices:
                    w = o.matrix_world @ v.co
                    if w.z > CUT: v.co = o.matrix_world.inverted() @ Vector((w.x, w.y, CUT))
    # section caps: a pale band where every wall is cut, like the poché of a plan drawing
    cap = mat_basic('cap', (.86, .84, .78), .9, emit=(.86, .84, .78), estr=.06)
    def capY(x, y0, y1): prim('cube', 'cap', loc=(x, (y0 + y1) / 2, CUT + .005), scale=(.14, (y1 - y0) / 2, .005), mat=cap)
    def capX(y, x0, x1): prim('cube', 'cap', loc=((x0 + x1) / 2, y, CUT + .005), scale=((x1 - x0) / 2, .14, .005), mat=cap)
    capY(Hm.XL, Hm.YB - .14, Hm.YF + .14); capY(Hm.XR, Hm.YB - .14, 1.35); capY(Hm.XR, 2.85, Hm.YF + .14)
    capX(Hm.YF, Hm.XL, Hm.DX0); capX(Hm.YF, Hm.DX1, Hm.XR); capX(Hm.YB, Hm.XL, Hm.XR)
    Hm.genkan_props(M, shoes=4, umbrellas=6)
    D.fresnel((1.25, 2.55), 2.0, (.35, 3.75, 0), M, energy=520, size=30)
    D.tripod((-.45, 4.35), math.radians(205), M)
    Hm.tape_mark(.35, 3.75, (-3, -2), 'tape_natsuki.png')
    pnl_l = lib.area('blue_door', (-.33, 5.08, 1.06), (.85, 6.2, 1.15), 4, color=(.4, .56, 1.0), size=(.24, .18), spread=55)
    Y = Hm.YF; sx = A['slit'].x
    # everyone at 23:00
    pockets = dict(lel=(.22, .03, 1.13), lwr=(.19, -.04, .93), lha=(.17, -.03, .86), rel=(-.22, .03, 1.13), rwr=(-.19, -.04, .93), rha=(-.17, -.03, .86))
    hands_back = dict(lel=(.2, .1, 1.12), lwr=(.12, .16, .95), lha=(.08, .17, .9), rel=(-.2, .1, 1.12), rwr=(-.12, .16, .95), rha=(-.08, .17, .9))
    phone_pose = dict(pockets, rel=(-.2, -.06, 1.12), rwr=(-.08, -.22, 1.2), rha=(-.03, -.26, 1.24))
    lib.figure('mio', top=M['knit'], pants=M['denim'], feet=M['sock'], skin=(.78, .58, .47), female=True, s=.95,
               loc=(-.45, 1.75, 0), yaw=170, head_yaw=0, head_pitch=0, pose=dict(lel=(.19, .02, 1.13), lwr=(.18, -.02, .9), lha=(.18, -.03, .82)))
    lib.figure('kiryu', top=M['plaid'], pants=M['olive'], feet=M['sockd'], skin=(.76, .57, .45), s=1.04,
               loc=(-.12, 4.32, 0), yaw=-14, head_yaw=6, head_pitch=11, pose=phone_pose)
    lib.figure('taiga', top=M['tee'], pants=M['track'], feet=M['sockd'], skin=(.74, .55, .43), sleeve='short', s=1.07, wide=1.1,
               loc=(1.05, Y - .2, Hm.ZG), yaw=-30, head_yaw=-28, head_pitch=6, pose=dict(hands_back, lean=(0, .05, 0)))
    knock = dict(rel=(-.2, -.1, 1.25), rwr=(-.1, -.22, 1.38), rha=(-.08, -.25, 1.46), lel=(.2, -.08, 1.12), lwr=(.12, -.22, 1.12), lha=(.08, -.25, 1.15))
    lib.figure('natsuki', top=mat_basic('wetknit', (.14, .14, .15), .35), pants=M['denim'], feet=M['sock'], skin=(.72, .54, .45), female=True, s=.96,
               loc=(sx + .05, Y + .32, Hm.ZG - .03), yaw=180 + 180, head_yaw=0, head_pitch=4, pose=knock)
    ph = prim('cube', 'nphone', loc=(sx + .13, Y + .1, 1.0), scale=(.026, .004, .052), mat=mat_basic('nph', (.6, .8, 1), .3, emit=kelvin(9000), estr=6))
    lib.point('nphone_light', (sx + .13, Y + .06, 1.05), 1.5, k=9000, radius=.03)
    # living room: Makoto at the radio
    tb = prim('cube', 'lowtable', loc=(2.3, 1.2, .2), scale=(.4, .3, .2), mat=M['agari']); lib.uv_box(tb, 1.25)
    rd = prim('cube', 'radio', loc=(2.3, 1.2, .48), scale=(.14, .06, .08), mat=mat_basic('radio', (.55, .45, .3), .5))
    dial = prim('cube', 'dial', loc=(2.24, 1.135, .5), scale=(.05, .004, .03), mat=mat_basic('dial', (1, .75, .35), .4, emit=kelvin(2200), estr=4))
    lib.point('radio_glow', (2.24, 1.08, .52), 3, k=2200, radius=.02)
    kneel_radio = dict(lhip=(.09, .02, .9), lkn=(.1, -.38, .52), lan=(.1, .12, .45), lto=(.1, .26, .43),
                       rhip=(-.09, .02, .9), rkn=(-.1, -.38, .52), ran=(-.1, .12, .45), rto=(-.1, .26, .43),
                       lel=(.2, -.14, 1.1), lwr=(.12, -.34, 1.0), lha=(.08, -.4, .98), rel=(-.2, -.14, 1.1), rwr=(-.1, -.34, 1.0), rha=(-.06, -.4, .98))
    lib.figure('makoto', top=M['white'], pants=M['denim'], feet=M['sock'], skin=(.8, .6, .49), female=True, s=.93,
               loc=(2.3, 1.85, -.4), yaw=180, head_yaw=0, head_pitch=10, pose=kneel_radio)
    lf = prim('cube', 'lr_rug', loc=(2.6, 1.8, .002), scale=(1.2, 1.4, .002), mat=mat_basic('rug', (.3, .22, .16), .9))
    # outside: the porch in the rain
    porch = prim('cube', 'porch', loc=(.2, Y + 1.0, Hm.ZG - .03), scale=(1.8, 1.0, .03), mat=M['floor']); lib.uv_box(porch, .87)
    ground = prim('plane', 'ground', loc=(.5, 6, Hm.ZG - .1), scale=(12, 12, 1), mat=mat_basic('mud', (.04, .045, .04), .25))
    random.seed(4)
    rain = mat_basic('rain', (.7, .8, 1), .2, emit=(.5, .62, 1), estr=.12)
    for i in range(260):
        x = random.uniform(-3, 4.5); y = random.uniform(-1.5, 9.5)
        if -1.65 < x < 1.65 and .55 < y < 6.35: continue
        if 1.6 < x < 3.4 and .2 < y < 3.6: continue
        z = random.uniform(.0, 2.6)
        c = D.cyl_between('drop', (x, y, z), (x - .02, y - .03, z - .32), .0025, rain, 4); c.visible_shadow = False
    lib.area('rain_sky', (sx, Y + 1.6, 2.4), (sx, Y + .3, 0), 30, k=14000, size=(2.5, 1.5))
    lib.haze(((-1.6, .6, -.2), (1.6, 6.3, 2.45)), density=.035, aniso=0)
    w = s.world.node_tree.nodes['Background']; w.inputs[0].default_value = (.4, .5, .8, 1); w.inputs[1].default_value = .012

def cam():
    tgt = Vector((.75, 4.05, .2)); d = Vector((-.42, -.9, 1.15)).normalized()
    c = lib.camera(tuple(tgt + d * 24), tuple(tgt), ortho=10.2)
    c.data.clip_end = 100
    return c

if __name__ == '__main__':
    a = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    out = a[0] if a else '/home/claude/kf/out/alt_b.png'
    spp = int(a[1]) if len(a) > 1 else 24; pct = int(a[2]) if len(a) > 2 else 50
    exp = float(a[3]) if len(a) > 3 else 1.0
    build(); cam()
    bpy.context.scene.view_settings.exposure = exp
    lib.render(out, samples=spp, pct=pct)
