"""Keyframe: 第2章 23:00 扉の前の沈黙 (main direction: the house lit like a film set)."""
import sys, math
import os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P   # all paths: paths.env
import bpy
from mathutils import Vector
import lib, door as D, hall as Hm
from lib import prim, mat_basic, kelvin

CAM = (-.5, 1.45, 1.55)

def build():
    lib.reset()
    M = D.mats()
    A = Hm.build_hall(M)
    Hm.genkan_props(M, shoes=4, umbrellas=6)
    # film gear
    D.fresnel((1.25, 2.55), 2.0, (.35, 3.75, 0), M, energy=520, size=30)
    D.tripod((-.45, 4.35), math.radians(205), M)
    lib.spot('camtop_led', (-.43, 4.27, 1.62), (.5, 1.6, 1.2), 6, k=5600, size=70, blend=.6, radius=.02)
    Hm.tape_mark(.35, 3.75, CAM[:2], 'tape_natsuki.png')
    cu = bpy.data.curves.new('cable', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = .007
    spl = cu.splines.new('BEZIER'); pts = [(1.25, 2.55, .01), (.9, 2.9, .008), (.6, 2.5, .008), (1.0, 1.9, .008), (1.7, 1.6, .008)]
    spl.bezier_points.add(len(pts) - 1)
    for bp, p in zip(spl.bezier_points, pts): bp.co = p; bp.handle_left_type = bp.handle_right_type = 'AUTO'
    co = bpy.data.objects.new('cable', cu); lib.link(co); co.data.materials.append(M['rubber'])
    ab = prim('cube', 'applebox', loc=(1.25, 3.3, .1), rot=(0, 0, .3), scale=(.25, .15, .1), mat=M['agari']); lib.uv_box(ab, 1.25)
    # a small LED panel on the shoe cabinet, gelled blue and aimed at the door: tonight's planned shot was "the thing at the door"
    pnl = prim('cube', 'blue_panel', loc=(-.35, 5.05, 1.05), scale=(.13, .02, .1), mat=M['black'])
    d = (Vector((.85, 6.2, 1.25)) - Vector((-.35, 5.05, 1.05))); pnl.rotation_euler = d.to_track_quat('-Y', 'Z').to_euler()
    lib.area('blue_door', (-.33, 5.08, 1.06), (.85, 6.2, 1.15), 4, color=(.4, .56, 1.0), size=(.24, .18), spread=55)
    for k in range(2):
        cyl_ = D.cyl_between('pnl_leg', (-.35 + (k - .5) * .2, 5.03, .93), (-.35 + (k - .5) * .2, 5.0, 1.0), .008, M['metal'], 6)
    # outside: Natsuki's hand on the slit glass, her phone glowing below it
    sx = A['slit'].x; Y = Hm.YF
    M['nskin'] = mat_basic('nskin', (.7, .5, .42), .5, sss=.2)
    prim('cube', 'palm', loc=(sx, Y + .012, 1.3), scale=(.045, .008, .05), mat=M['nskin'])
    for i, (dx, ang) in enumerate(((-.034, .18), (-.012, .05), (.012, -.05), (.033, -.17))):
        f = prim('cube', 'finger', loc=(sx + dx * 1.3, Y + .012, 1.395 + (.012 if i in (1, 2) else 0)), rot=(0, ang, 0), scale=(.009, .008, .045), mat=M['nskin'])
    prim('cube', 'thumb', loc=(sx - .062, Y + .012, 1.285), rot=(0, .8, 0), scale=(.01, .008, .032), mat=M['nskin'])
    ph = prim('plane', 'phone_glow', loc=(sx + .03, Y + .3, .98), rot=(math.pi / 2 - .3, 0, 0), scale=(.035, .07, 1), mat=M['phone']); ph.visible_shadow = False
    lib.spot('phone_light', (sx + .02, Y + .38, 1.05), (sx, Y - 3, 1.1), 60, k=9500, size=50, blend=.4, radius=.03)
    lib.area('rain_sky', (sx, Y + 1.2, 1.2), (sx, Y, 1.2), 40, k=14000, size=(.4, 1.6))
    # people
    hands_back = dict(lel=(.2, .1, 1.12), lwr=(.12, .16, .95), lha=(.08, .17, .9), rel=(-.2, .1, 1.12), rwr=(-.12, .16, .95), rha=(-.08, .17, .9))
    pockets = dict(lel=(.22, .03, 1.13), lwr=(.19, -.04, .93), lha=(.17, -.03, .86), rel=(-.22, .03, 1.13), rwr=(-.19, -.04, .93), rha=(-.17, -.03, .86))
    lib.figure('taiga', top=M['tee'], pants=M['track'], feet=M['sockd'], skin=(.74, .55, .43), sleeve='short', s=1.07, wide=1.1,
               loc=(1.05, Y - .2, Hm.ZG), yaw=-30, head_yaw=-28, head_pitch=6, pose=dict(hands_back, lean=(0, .05, 0)))
    # Kiryu reads the news on his phone; its screen is the only light on his face
    phone_pose = dict(pockets, rel=(-.2, -.06, 1.12), rwr=(-.08, -.22, 1.2), rha=(-.03, -.26, 1.24), lel=(.21, .02, 1.13), lwr=(.18, -.04, .93), lha=(.16, -.03, .86))
    k = lib.figure('kiryu', top=M['plaid'], pants=M['olive'], feet=M['sockd'], skin=(.76, .57, .45), s=1.04,
               loc=(-.12, 4.32, 0), yaw=-14, head_yaw=6, head_pitch=11, pose=phone_pose)
    bpy.context.view_layer.update()
    hp = k.matrix_world @ Vector((-.04, -.29, 1.27 * 1.04))
    kp = prim('cube', 'kiryu_phone', loc=hp, scale=(.026, .004, .052), mat=lib.mat_basic('kphone', (.6, .8, 1), .3, emit=kelvin(9000), estr=5)); kp.rotation_euler = (math.radians(-55), 0, math.radians(-14))
    kp.visible_shadow = False
    head = k.matrix_world @ Vector((0, 0, 1.62 * 1.04))
    lib.spot('kiryu_phone_light', tuple(hp + Vector((0, -.02, .02))), tuple(head), 2.2, k=8000, size=70, blend=.8, radius=.035)
    lib.haze(((-1.6, .6, -.2), (1.6, 6.3, 2.45)), density=.06, aniso=0)
    return M

def cam():
    return lib.camera(CAM, (.6, 5.3, .75), lens=18)

if __name__ == '__main__':
    a = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    out = a[0] if a else f'{P.KF}/out/night_t.png'
    spp = int(a[1]) if len(a) > 1 else 24; pct = int(a[2]) if len(a) > 2 else 50
    exp = float(a[3]) if len(a) > 3 else 1.0
    build(); cam()
    bpy.context.scene.view_settings.exposure = exp
    bpy.context.scene.view_settings.look = 'AgX - Medium High Contrast'
    lib.render(out, samples=spp, pct=pct)
