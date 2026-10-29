"""第1章 夕方 for the Godot prototype: the same hallway with the front door open onto the sunset,
Natsuki standing on the mark she has just taped, Kiryu framing her behind the camera, Taiga in the doorway
with an apple box. Exported like the 23:00 scene (env.glb + one glb per character + lights.json + lightmap)
into assets/dusk/."""
import sys, os, math, json
sys.path.insert(0, '/home/claude/kf')
import bpy
from mathutils import Vector
import lib, door as D, hall as Hm, chars as C
import export_godot as E
from lib import prim, mat_basic, kelvin
from night import CAM

E.OUT = OUT = '/home/claude/rules/assets/dusk'
os.makedirs(OUT, exist_ok=True)
S = {}

def face(rig, target_xy):
    p = rig.location; dx, dy = target_xy[0] - p.x, target_xy[1] - p.y
    rig.rotation_euler.z = math.atan2(dx, -dy)

def build():
    lib.reset()
    s = bpy.context.scene
    M = D.mats()
    Hm.build_hall(M, door_open=True, back_wall=True)
    Hm.genkan_props(M, shoes=5, umbrellas=5)
    Y = Hm.YF
    porch = prim('cube', 'porch', loc=(.75, Y + 1.0, Hm.ZG - .03), scale=(1.6, 1.0, .03), mat=M['floor']); lib.uv_box(porch, .87)
    sky = bpy.data.materials.new('sunset'); sky.use_nodes = True; N = sky.node_tree.nodes; L = sky.node_tree.links
    p = N['Principled BSDF']; t = N.new('ShaderNodeTexImage'); t.image = lib.img(lib.tex_path('sunset'))
    L.new(t.outputs[0], p.inputs['Base Color']); L.new(t.outputs[0], p.inputs['Emission Color']); p.inputs['Emission Strength'].default_value = 2.2
    p.inputs['Base Color'].default_value = (0, 0, 0, 1)
    bd = prim('plane', 'sunset_backdrop', loc=(.9, Y + 9, 1.6), rot=(math.pi / 2, 0, 0), scale=(8, 8 * 876 / 1358, 1), mat=sky)
    bd.visible_shadow = False
    S['sun'] = lib.sun('sun', (0, 0, 0), 14, k=2200, angle=.8)
    S['sun'].rotation_euler = Vector((.3, -.95, -.25)).to_track_quat('-Z', 'Y').to_euler()
    w = s.world.node_tree.nodes['Background']; w.inputs[0].default_value = (*kelvin(3400), 1); w.inputs[1].default_value = .35
    lib.area('door_sky', (.76, Y + .25, 1.1), (.6, 3.5, .7), 30, k=4200, size=(.8, 2.1), spread=120)
    D.fresnel((1.25, 2.55), 2.0, (.35, 3.75, 0), M, energy=160, size=30)
    D.tripod((-.45, 4.12), math.radians(205), M)
    Hm.tape_mark(.35, 3.75, CAM[:2], 'tape_natsuki.png')
    ab = prim('cube', 'applebox', loc=(1.25, 3.3, .1), rot=(0, 0, .3), scale=(.25, .15, .1), mat=M['agari']); lib.uv_box(ab, 1.25)
    # the reflector is held by Makoto (the new member helps: she holds things, lights hands), no stand
    rf = prim('cube', 'reflector', loc=(.95, 2.75, 1.0), scale=(.3, .006, .3), mat=mat_basic('refl', (.9, .9, .88), .7))
    rf.rotation_euler = (Vector((.36, 3.82, 1.5)) - Vector((.95, 2.75, 1.0))).to_track_quat('-Y', 'Z').to_euler()
    lib.area('reflector_bounce', (.93, 2.8, 1.02), (.36, 3.82, 1.5), 9, k=3000, size=(.6, .6), spread=150)
    # people
    n = C.make_tripo('natsuki')[0]; C.socks(n); n.location = (.36, 3.84, 0); face(n, CAM[:2]); n.rotation_euler.z += math.radians(-10)
    k = C.make_tripo('kiryu')[0]; k.location = (-.42, 4.5, 0); face(k, (.36, 3.84))
    t = C.make_tripo('taiga')[0]; t.location = (.82, Y + .17, Hm.ZG); face(t, (.2, 3.0))
    m = C.make_tripo('makoto')[0]; C.socks(m); m.location = (1.08, 2.52, 0); face(m, (.36, 3.84))
    bpy.context.view_layer.update()
    S['rf_l'] = rf.matrix_world @ Vector((1, .9, .05)); S['rf_r'] = rf.matrix_world @ Vector((-1, .9, .05))
    S.update(n=n, k=k, t=t, m=m)
    bpy.context.view_layer.update()
    roll = D.cyl_between('taperoll', (0, 0, 0), (0, 0, .05), .05, mat_basic('tapeyel', (.85, .65, .08), .5), 20)
    box = prim('cube', 'carrybox', loc=(0, 0, 0), scale=(.25, .15, .1), mat=M['agari']); lib.uv_box(box, 1.25)
    S.update(roll=roll, box=box)
    at(0.0)
    # props held in hands follow the bones
    for ob, rig, bone in ((roll, n, 'hand_l'), (box, t, 'spine_03')):
        if ob is roll:
            hb = C.bone_head(n, 'hand_l').lerp(C.bone_head(n, 'hand_r'), .5)
            ob.location = hb + n.matrix_world.to_3x3() @ Vector((0, -.04, -.01))
        else:
            ob.location = C.local(t, (0, -.3, 1.04)); ob.rotation_euler.z = t.rotation_euler.z
        bpy.context.view_layer.update()
        mw = ob.matrix_world.copy(); ob.parent = rig; ob.parent_type = 'BONE'; ob.parent_bone = bone
        bpy.context.view_layer.update(); ob.matrix_world = mw
    return M

TALK = ((2.0, 4.6), (9.0, 10.4), (14.5, 16.8))   # Natsuki says something to Mio

def pose_natsuki(n, t):
    nl = lambda v: C.local(n, v)
    tilt = E.noise1(t, 4.0, .5)
    # the tape roll held in both hands at the waist, elbows close to the body
    C.arm_to(n, 'l', nl((.05, -.17, .98 + .01 * tilt)), Vector((.1, .3, -.5)))
    C.arm_to(n, 'r', nl((-.05, -.17, .98 + .01 * tilt)), Vector((-.1, .3, -.5)))
    laugh = sum(E.snap(t, a, .35) * (1 - E.snap(t, b, .5)) for a, b in TALK)
    C.grip(n, 'l', .55); C.grip(n, 'r', .55)
    C.rot_world(n, 'head', (0, 0, 1), 8 + 6 * tilt)
    C.rot_world(n, 'neck_01', E.axis_local(n, (0, 1, 0)), 5 * laugh)
    C.rot_world(n, 'spine_03', E.axis_local(n, (1, 0, 0)), -3 * laugh)
    E.idle(n, t, 3.0, breath=.28, amp=1.0, rate=1.1)

def pose_kiryu(k, t):
    kl = lambda v: C.local(k, v)
    # framing her on the camera's flip-out screen; looks up over it twice
    up = E.snap(t, 6.5, .45) * (1 - E.snap(t, 8.6, .5)) + E.snap(t, 15.2, .45) * (1 - E.snap(t, 17.0, .5))
    C.arm_to(k, 'r', kl((-.1, -.34, 1.36 + .02 * up)), Vector((-.3, .2, -.4)))
    C.arm_to(k, 'l', kl((.12, -.34, 1.34)), Vector((.3, .2, -.4)))
    C.rot_world(k, 'neck_01', E.axis_local(k, (1, 0, 0)), 14 - 16 * up)
    C.grip(k, 'l', .45); C.grip(k, 'r', .45)
    E.idle(k, t, 1.0, breath=.21, amp=.8, rate=.8)

def pose_taiga(tg, t):
    tl = lambda v: C.local(tg, v)
    C.arm_to(tg, 'l', tl((.2, -.3, 1.02)), Vector((.4, .3, -.2)))
    C.arm_to(tg, 'r', tl((-.2, -.3, 1.02)), Vector((-.4, .3, -.2)))
    C.rot_world(tg, 'spine_01', E.axis_local(tg, (1, 0, 0)), -4)
    C.rot_world(tg, 'head', (0, 0, 1), -10 + 25 * E.snap(t, 11.0, .5) * (1 - E.snap(t, 13.5, .5)))
    C.grip(tg, 'l', .35); C.grip(tg, 'r', .35)
    E.idle(tg, t, 2.0, breath=.31, amp=1.1, rate=1.25)

def pose_makoto(m, t):
    # holding the reflector on Natsuki with both hands; the board stays still, so the body breathes under fixed hands
    E.idle(m, t, 7.0, breath=.26, amp=.7, rate=1.05)
    look = E.snap(t, 3.2, .5) * (1 - E.snap(t, 5.0, .6)) + E.snap(t, 12.0, .5) * (1 - E.snap(t, 13.6, .6))   # glances at Kiryu
    C.rot_world(m, 'head', (0, 0, 1), -8 + 30 * look)
    C.arm_to(m, 'l', S['rf_l'], Vector((.3, .25, -.3)))
    C.arm_to(m, 'r', S['rf_r'], Vector((-.3, .25, -.3)))
    C.grip(m, 'l', .7); C.grip(m, 'r', .7)

def at(t):
    for r, f in ((S['n'], pose_natsuki), (S['k'], pose_kiryu), (S['t'], pose_taiga), (S['m'], pose_makoto)):
        C.reset_pose(r); f(r, t)
    bpy.context.view_layer.update()

if __name__ == '__main__':
    build()
    for o in [o for o in bpy.data.objects if o.name.startswith(('haze', 'cam'))]: bpy.data.objects.remove(o)
    E.simplify_materials()
    chars = set()
    for r in (S['k'], S['t'], S['n'], S['m']): chars |= set(E.descendants(r))
    E.bake_bounce([o for o in bpy.data.objects if o not in chars and o.name != 'sunset_backdrop'])
    E.dump_lights()
    rigs = {'kiryu': (S['k'], lambda t: pose_kiryu(S['k'], t)), 'taiga': (S['t'], lambda t: pose_taiga(S['t'], t)),
            'natsuki': (S['n'], lambda t: pose_natsuki(S['n'], t)), 'makoto': (S['m'], lambda t: pose_makoto(S['m'], t))}
    for name, (rig, fn) in rigs.items(): E.bake_action(rig, fn)
    for name, (rig, fn) in rigs.items(): E.export(f'{OUT}/{name}.glb', E.descendants(rig))
    env = [o for o in bpy.data.objects if o not in chars and o.type in ('MESH', 'CURVE', 'EMPTY')]
    E.export(f'{OUT}/env.glb', env)
    json.dump(dict(scene='dusk', YF=Hm.YF, ZG=Hm.ZG, cam0=list(CAM), fps=E.FPS, loop=E.LOOP, talk=TALK,
                   mark=[.35, 3.75, 0]), open(f'{OUT}/scene.json', 'w'), indent=1)
    print('EXPORTED')
