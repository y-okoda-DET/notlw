"""第2章 23:00 — 扉の前の沈黙. A 10 s shot from Mio's eye-line, slowly pushing toward the door.
Everything per frame is a function of t (seconds), so any frame can be rendered alone.
  python3 shot.py -- <outdir> <first> <last> <spp> <pct> [step]
Beats:
  0.0  rain, generator-fed fresnel breathing, Natsuki's palm on the slit glass, Kiryu reading his phone
  3.0  three knocks (her hand lifts and taps); Taiga presses his back into the door
  4.5  Kiryu looks up at the door ... and back down at 7.0
  6.0  her phone lights her fingers from below as she types against the glass
  8.2  lightning: one white-blue pulse through the slit, the fresnel dips with the generator
  10.0 end
"""
import sys, math, random
sys.path.insert(0, '/home/claude/kf')
import bpy
from mathutils import Vector, Matrix
import lib, door as D, hall as Hm, chars as C
from lib import prim, mat_basic, kelvin

FPS = 12
DUR = 10.0
CAM0 = Vector((-.5, 1.35, 1.52)); CAM1 = Vector((-.3, 2.15, 1.5))
TGT0 = CAM0 + Vector((1.1, 3.95, -.77)); TGT1 = CAM1 + Vector((.85, 4.0, -1.3))

def ease(x): x = max(0, min(1, x)); return x * x * (3 - 2 * x)
def pulse(t, t0, w): return math.exp(-((t - t0) / w) ** 2)

S = {}

def build():
    lib.reset()
    M = D.mats()
    A = Hm.build_hall(M, back_wall=True)
    Hm.genkan_props(M, shoes=4, umbrellas=6)
    S['fres'] = D.fresnel((1.25, 2.55), 2.0, (.35, 3.75, 0), M, energy=520, size=30)
    D.tripod((-.45, 4.35), math.radians(205), M)
    lib.spot('camtop_led', (-.43, 4.27, 1.62), (.5, 1.6, 1.2), 6, k=5600, size=70, blend=.6, radius=.02)
    Hm.tape_mark(.35, 3.75, CAM0[:2], 'tape_natsuki.png')
    cu = bpy.data.curves.new('cable', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = .007
    spl = cu.splines.new('BEZIER'); pts = [(1.25, 2.55, .01), (.9, 2.9, .008), (.6, 2.5, .008), (1.0, 1.9, .008), (1.7, 1.6, .008)]
    spl.bezier_points.add(len(pts) - 1)
    for bp, p in zip(spl.bezier_points, pts): bp.co = p; bp.handle_left_type = bp.handle_right_type = 'AUTO'
    co = bpy.data.objects.new('cable', cu); lib.link(co); co.data.materials.append(M['rubber'])
    ab = prim('cube', 'applebox', loc=(1.25, 3.3, .1), rot=(0, 0, .3), scale=(.25, .15, .1), mat=M['agari']); lib.uv_box(ab, 1.25)
    pnl = prim('cube', 'blue_panel', loc=(-.35, 5.05, 1.05), scale=(.13, .02, .1), mat=M['black'])
    d = (Vector((.85, 6.2, 1.25)) - Vector((-.35, 5.05, 1.05))); pnl.rotation_euler = d.to_track_quat('-Y', 'Z').to_euler()
    S['blue'] = lib.area('blue_door', (-.33, 5.08, 1.06), (.85, 6.2, 1.15), 4, color=(.4, .56, 1.0), size=(.24, .18), spread=55)
    S['slit_x'] = A['slit'].x; Y = Hm.YF
    # ---- outside: porch, rain, Natsuki herself (seen only through the slit)
    porch = prim('cube', 'porch', loc=(.75, Y + .9, Hm.ZG - .03), scale=(1.4, .9, .03), mat=M['floor']); lib.uv_box(porch, .87)
    S['sky'] = lib.area('rain_sky', (S['slit_x'] - .5, Y + 1.4, 2.2), (S['slit_x'], Y + .2, 1.1), 6, k=14000, size=(.8, .8))
    S['bolt'] = lib.area('lightning', (S['slit_x'] + .4, Y + 2.5, 2.2), (S['slit_x'], Y, 1.1), 0, k=16000, size=(1.5, 1.5))
    wet = mat_basic('wetknit', (.09, .09, .1), .3)
    nk = C.make_tripo('natsuki')   # Tripo-generated body and head (see tripo/prep_natsuki.py)
    S['n'] = nk[0]; nk[0].location = (S['slit_x'] + .06, Y + .26, Hm.ZG); nk[0].rotation_euler.z = math.pi
    C.wet(nk[0], (.42, .44, .5), .28)   # she has been standing in the rain
    # her phone
    S['nphone'] = C.phone('nphone', kelvin(9000), 7)
    S['nphone_l'] = lib.point('nphone_light', (0, 0, 0), 2.0, k=9000, radius=.02)
    # rain streaks outside (instanced as one mesh so it's cheap to move)
    random.seed(4); verts = []; faces = []
    for i in range(160):
        x = random.uniform(-.6, 2.2); y = random.uniform(Y + .3, Y + 3.0); z = random.uniform(-.2, 2.8)
        b = len(verts); w = .0018
        verts += [(x - w, y, z), (x + w, y, z), (x + w - .01, y - .015, z - .28), (x - w - .01, y - .015, z - .28)]
        faces.append((b, b + 1, b + 2, b + 3))
    rain = lib.mesh_obj('rain', verts, faces); rain.data.materials.append(mat_basic('rain', (.7, .8, 1), .2, emit=(.55, .68, 1), estr=.35))
    rain.visible_shadow = False; S['rain'] = rain
    # ---- inside
    S['k'] = C.make_tripo('kiryu')[0]
    S['k'].location = (-.32, 4.02, 0); S['k'].rotation_euler.z = math.radians(-14)
    S['t'] = C.make_tripo('taiga')[0]
    S['t'].location = (.98, Y - .30, Hm.ZG); S['t'].rotation_euler.z = math.radians(176)   # facing the door, both hands on it
    S['kphone'] = C.phone('kphone', kelvin(8500), 5)
    S['kphone_l'] = lib.spot('kiryu_phone_light', (0, 0, 0), (0, 0, 1), 2.2, k=8000, size=70, blend=.8, radius=.035)
    lib.haze(((-1.6, .6, -.2), (1.6, 6.3, 2.45)), density=.06, aniso=0)
    S['cam'] = lib.camera(tuple(CAM0), tuple(TGT0), lens=18)
    bpy.context.view_layer.update()

def at(t):
    """Set the whole scene to time t (seconds)."""
    Y = Hm.YF; sx = S['slit_x']
    # camera: slow push, a breath of handheld drift
    u = ease(t / DUR)
    cp = CAM0.lerp(CAM1, u) + Vector((math.sin(t * .9) * .006, 0, math.sin(t * 1.3 + 1) * .005))
    tg = TGT0.lerp(TGT1, u)
    S['cam'].location = cp; S['cam'].rotation_euler = (tg - cp).to_track_quat('-Z', 'Y').to_euler()
    S['cam'].data.lens = 18 + 3 * u
    # fresnel on a generator: slow breathing + the dip at the lightning
    dip = 1 - .55 * pulse(t, 8.35, .12) - .25 * pulse(t, 8.6, .08)
    S['fres'].data.energy = 520 * (1 + .03 * math.sin(t * 6.1) + .02 * math.sin(t * 17.3)) * dip
    S['bolt'].data.energy = 900 * (pulse(t, 8.2, .035) + .6 * pulse(t, 8.32, .03) + .25 * pulse(t, 8.5, .05))
    # rain falls (wraps every 0.25 s)
    S['rain'].location.z = -((t * 7.5) % 1.0) * .9
    # ---- Natsuki outside
    n = S['n']; C.reset_pose(n)
    knock = 0.0
    for k0 in (3.0, 3.35, 3.7):
        knock = max(knock, pulse(t, k0, .07))
    palm_up = 1.5 + .0
    hx = sx + .0; hy = Y + .03
    if t < 2.7 or t > 4.2:
        hand = Vector((hx, hy + .01, 1.32))
    else:
        hand = Vector((hx, hy + .05 - .05 * knock, 1.42))
    C.arm_to(n, 'l', hand, Vector((.25, .2, -.4)))
    C.arm_to(n, 'r', Vector((sx + .1, Y + .14, 1.02 + .02 * math.sin(t * 3))), Vector((-.3, .2, -.4)))
    C.rot_world(n, 'neck_01', (1, 0, 0), 8)
    C.grip(n, 'r', .8); C.grip(n, 'l', .15)
    bpy.context.view_layer.update()
    C.place_in_hand(S['nphone'], n, 'r', (0, .055, -.016), (90, 0, 0))
    S['nphone_l'].location = S['nphone'].matrix_world.translation + S['nphone'].matrix_world.to_quaternion() @ Vector((0, -.04, 0))
    # ---- Kiryu: phone, looks up at the knock, back down
    k = S['k']; C.reset_pose(k)
    kl = lambda v: C.local(k, v)
    C.arm_to(k, 'r', kl((-.04, -.3, 1.22)), Vector((-.3, .2, -.4)))
    C.arm_to(k, 'l', kl((.2, -.02, .84)), Vector((.3, .3, 0)))
    look_up = ease((t - 4.5) / .5) * (1 - ease((t - 7.0) / .8))
    C.rot_world(k, 'neck_01', k.matrix_world.to_3x3().normalized() @ Vector((1, 0, 0)), -16 + 22 * look_up)
    C.rot_world(k, 'head', (0, 0, 1), 10 * look_up)
    C.grip(k, 'r', .8); C.grip(k, 'l', .3)
    bpy.context.view_layer.update()
    C.palm_to(k, 'r', C.bone_head(k, 'head') + C.local(k, (0, -.06, .04)) - C.local(k, (0, 0, 0)))
    C.place_in_hand(S['kphone'], k, 'r', (0, .055, -.016), (90, 0, 0))
    head = C.bone_head(k, 'head') + Vector((0, 0, .1))
    S['kphone_l'].location = S['kphone'].matrix_world.translation + S['kphone'].matrix_world.to_quaternion() @ Vector((0, -.03, 0))
    S['kphone_l'].rotation_euler = (head - S['kphone_l'].location).to_track_quat('-Z', 'Y').to_euler()
    # ---- Taiga: back to the door, hands behind; flinches into it at the knocks
    tg_ = S['t']; C.reset_pose(tg_)
    tl = lambda v: C.local(tg_, v)
    press = ease((t - 3.0) / .3) * (1 - .4 * ease((t - 5.5) / 1.5))
    C.rot_world(tg_, 'spine_01', tg_.matrix_world.to_3x3().normalized() @ Vector((1, 0, 0)), 5 * press)
    C.arm_to(tg_, 'l', tl((.1, .16, .95)), Vector((.3, .4, 0)))
    C.arm_to(tg_, 'r', tl((-.1, .16, .95)), Vector((-.3, .4, 0)))
    C.rot_world(tg_, 'head', (0, 0, 1), 20 + 8 * press)
    bpy.context.view_layer.update()

if __name__ == '__main__':
    a = sys.argv[sys.argv.index('--') + 1:]
    out, f0, f1, spp, pct = a[0], int(a[1]), int(a[2]), int(a[3]), int(a[4])
    step = int(a[5]) if len(a) > 5 else 1
    import os; os.makedirs(out, exist_ok=True)
    build()
    s = bpy.context.scene
    s.view_settings.exposure = .8
    s.view_settings.look = 'AgX - Medium High Contrast'
    for f in range(f0, f1 + 1, step):
        p = f'{out}/f{f:04d}.png'
        if os.path.exists(p): continue
        at(f / FPS)
        lib.render(p, samples=spp, pct=pct)
