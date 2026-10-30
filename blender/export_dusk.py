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
    # people
    n = C.make_tripo('natsuki_s', label='natsuki')[0]; n.location = (.36, 3.84, 0);   # indoors: the socks body
    for ob in n.children_recursive: ob.name = ob.name.replace('natsuki_s_', 'natsuki_')
    n.location = (.36, 3.84, 0); face(n, CAM[:2]); n.rotation_euler.z += math.radians(-10)
    k = C.make_tripo('kiryu')[0]; k.location = (-.32, 4.43, 0); k.rotation_euler.z = math.radians(205 - 180 + 8)   # squarely behind the camera, which points at yaw 205
    t = C.make_tripo('taiga')[0]; t.location = (.82, Y + .17, Hm.ZG); face(t, (.2, 3.0))
    m = C.make_tripo('makoto')[0]; C.socks(m); m.location = (1.08, 2.52, 0); face(m, (.36, 3.84))
    bpy.context.view_layer.update()
    # the reflector, held as in the reference photos: in front of her belly, its face toward Natsuki's face (so it
    # leans back toward Makoto by the angle up to that face), hands at the side edges low down, elbows bent at her sides
    nface = Vector((.36, 3.82, 1.5))
    ctr = C.local(m, (0, -.21, 0)); ctr.z = (C.bone_head(m, 'upperarm_l').z + C.bone_head(m, 'upperarm_r').z) / 2 - .1   # wrists at elbow height, forearms forward
    rf = prim('cube', 'reflector', loc=tuple(ctr), scale=(.25, .006, .25), mat=mat_basic('refl', (.9, .9, .88), .7))
    rf.rotation_euler = (nface - ctr).to_track_quat('-Y', 'Z').to_euler(); bpy.context.view_layer.update()
    lib.area('reflector_bounce', tuple(ctr + (nface - ctr).normalized() * .03), tuple(nface), 9, k=3000, size=(.5, .5), spread=150)
    print('reflector at', tuple(round(x, 2) for x in ctr), 'leans back', round(math.degrees(math.asin((nface - ctr).normalized().z)), 1), 'deg')
    # she grips the board by its side edges: wrists just outside each edge, palms toward the centre, fingers curling round
    # the board faces Natsuki along its local -Y (scale .006 -> 1 unit = 6 mm); Makoto stands on the +Y (back) side.
    # Board local +X points away from her (toward -x world), so her LEFT hand takes the board's +X edge.
    # Wrists 2 cm outside each edge and 8 cm behind the board, a little below centre; palms face the board's centre
    S['rf_l'] = rf.matrix_world @ Vector((1.07, 6, -.45)); S['rf_r'] = rf.matrix_world @ Vector((-1.07, 6, -.45))
    S['rf_lf'] = rf.matrix_world @ Vector((0, 0, -.45)); S['rf_rf'] = S['rf_lf']; S['rf'] = rf
    S.update(n=n, k=k, t=t, m=m)
    bpy.context.view_layer.update()
    roll = D.cyl_between('taperoll', (0, 0, 0), (0, 0, .05), .058, mat_basic('tapeyel', (.95, .62, .04), .45), 24)   # a 115 mm roll of gaffer tape, saturated so it reads through the print
    box = prim('cube', 'carrybox', loc=(0, 0, 0), scale=(.25, .15, .1), mat=M['agari']); lib.uv_box(box, 1.25)
    S.update(roll=roll, box=box)
    at(0.0)
    # props held in hands follow the bones
    for ob, rig, bone in ((roll, n, 'hand_r'), (box, t, 'spine_03')):
        if ob is roll:
            C.place_in_hand(roll, n, 'r', (0, .085, -.012), (0, 90, 0))   # fingers through the hole, roll across the palm
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
    # arms down, the tape roll hanging from the fingers of the right hand at the thigh; the left hand rests on her hip
    laugh = sum(E.snap(t, a, .35) * (1 - E.snap(t, b, .5)) for a, b in TALK)
    C.arm_to(n, 'r', nl((-.23, -.07 + .01 * tilt, .79 + .01 * laugh)), Vector((-.35, .3, 0)))
    C.arm_to(n, 'l', nl((.235, -.08, .96)), Vector((.5, .3, -.1))); C.palm_to(n, 'l', nl((.1, -.08, .96)))
    C.palm_to(n, 'r', nl((-.6, -.07, .79)))   # palm inward toward the thigh, the roll hangs below
    C.grip(n, 'r', .85); C.grip(n, 'l', .5)
    C.rot_world(n, 'head', (0, 0, 1), 8 + 6 * tilt)
    C.rot_world(n, 'neck_01', E.axis_local(n, (0, 1, 0)), 5 * laugh)
    C.rot_world(n, 'spine_03', E.axis_local(n, (1, 0, 0)), -3 * laugh)
    E.idle(n, t, 3.0, breath=.28, amp=1.0, rate=1.1)

def pose_kiryu(k, t):
    kl = lambda v: C.local(k, v)
    # framing her on the camera's flip-out screen; looks up over it twice
    up = E.snap(t, 6.5, .45) * (1 - E.snap(t, 8.6, .5)) + E.snap(t, 15.2, .45) * (1 - E.snap(t, 17.0, .5))
    # his hands are on the camera on the tripod: right hand round the grip side of the body, left at the flip-out screen
    cx, cy = -.45, 4.12
    # the body is turned with the lens toward Natsuki (yaw 205 deg): its two sides are at +-(-.906, -.42) * 0.07
    # he stands behind the camera (its back toward him): right hand on the near side of the body, left on the far side
    # the body's long axis runs along yaw 205 deg: its sides are at +-(cos 205, sin 205) * .06 = +-(-.054, -.025)
    # perpendicular... no: the sides are across the axis, at +-(-sin, cos)*.06 = +-(.025, -.054). He is north of it.
    # body sides are across its axis (yaw 205): +-(.025, -.054) * (.06/.06); he is on its +axis side (north-east)
    # the body (11 x 22 x 12 cm) points along yaw 205: its long sides are at +-(-.906, -.423) * .065 from the centre;
    # he stands at its back (+axis side (.42, -.9) reversed = north-west... he is at (-.32, 4.43): north). His right
    # hand takes the west side, the left the east side, both a little toward the back half of the body
    # right hand rests on top of the camera body (palm down), left hand grips the tripod head under it (palm in)
    C.arm_to(k, 'r', Vector((cx - .03, cy + .07, 1.575)), Vector((-.35, .2, -.3))); C.palm_to(k, 'r', Vector((cx - .03, cy + .07, 1.2)))
    C.grip(k, 'r', .25, thumb=.2)
    C.arm_to(k, 'l', Vector((cx + .045, cy + .06, 1.37)), Vector((.35, .25, -.4))); C.palm_to(k, 'l', Vector((cx, cy, 1.37)))
    C.grip(k, 'l', .8)
    C.rot_world(k, 'neck_01', E.axis_local(k, (1, 0, 0)), 14 - 16 * up)
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
    # each hand holds a side edge from behind as in the photos: palm and fingers under the board (on the back face,
    # which leans down toward her), the thumb round the edge
    rf = S['rf']; R = rf.matrix_world.to_3x3().normalized()
    bx = R @ Vector((1, 0, 0)); f = -(R @ Vector((0, 1, 0))); ub = R @ Vector((0, 0, 1))
    for side, sx in (('l', 1), ('r', -1)):
        out = bx * sx
        edge = rf.matrix_world @ Vector((sx * 1.0, 0, -.45))
        fing = (ub * .55 - out * .85).normalized()                        # fingers spread on the back face, inward and up
        wrist = edge - out * .002 - f * .021 - fing * .065                 # the palm on the back face just inside the edge
        C.arm_to(m, side, wrist, Vector((sx * .15, .3, -.8)))      # elbows down at her sides (armpits closed)
        pz = f * C.palm_sign(m, side)
        C.set_hand_frame(m, side, fing, pz); C.settle_forearm(m, side); C.set_hand_frame(m, side, fing, pz)
        # each finger curls until it meets the back face, the thumb until it meets the front (bones + 8 mm of skin)
        key = ('mk_curl', side)
        if key not in S:
            Mi = rf.matrix_world.inverted(); half = .006 + .008
            def hits(f_):
                for j_ in ('01', '02', '03'):
                    pb = m.pose.bones[f'{f_}_{j_}_{side}']
                    for q in (m.matrix_world @ pb.head, (m.matrix_world @ pb.head + m.matrix_world @ pb.tail) / 2, m.matrix_world @ pb.tail):
                        l_ = Mi @ q
                        if abs(l_.x) < 1.0 and abs(l_.z) < 1.0 and abs(l_.y * .006) < half: return True
                return False
            amt = {}
            for f_ in C.FINGERS + ('thumb',):
                best = 0.0
                for st in range(0, 17):
                    a_ = st * .05; C.clear_finger(m, side, f_)
                    C.curl_finger(m, side, f_, a_, (20, 35, 25) if f_ == 'thumb' else (55, 70, 45))
                    if hits(f_): break
                    best = a_
                amt[f_] = best; C.clear_finger(m, side, f_)
            S[key] = amt; print('makoto curl', side, amt)
        for f_, a_ in S[key].items():
            C.curl_finger(m, side, f_, a_, (20, 35, 25) if f_ == 'thumb' else (55, 70, 45))

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
    if os.environ.get('SKIP_LM'): print('env.glb: kept')
    else: E.export(f'{OUT}/env.glb', env)
    json.dump(dict(scene='dusk', YF=Hm.YF, ZG=Hm.ZG, cam0=list(CAM), fps=E.FPS, loop=E.LOOP, talk=TALK,
                   mark=[.35, 3.75, 0]), open(f'{OUT}/scene.json', 'w'), indent=1)
    print('EXPORTED')
