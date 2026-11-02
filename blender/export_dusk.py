"""第1章 夕方 for the Godot prototype: the same hallway with the front door open onto the sunset,
Natsuki standing on the mark she has just taped, Kiryu framing her behind the camera, Taiga in the doorway
with an apple box. Exported like the 23:00 scene (env.glb + one glb per character + lights.json + lightmap)
into assets/dusk/."""
import sys, os, math, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P   # all paths: paths.env
import bpy
from mathutils import Vector
import lib, door as D, hall as Hm, chars as C, house4 as H4, stage as St
import export_godot as E
from lib import prim, mat_basic, kelvin
import shot
CAM = tuple(shot.CAM0)

E.OUT = OUT = f'{P.RULES}/assets/dusk'
os.makedirs(OUT, exist_ok=True)
S = {}

def face(rig, target_xy):
    p = rig.location; dx, dy = target_xy[0] - p.x, target_xy[1] - p.y
    rig.rotation_euler.z = math.atan2(dx, -dy)

def build():
    lib.reset()
    s = bpy.context.scene
    M = D.mats()
    A = H4.build_house4(M, floors=('1F', '2F')); H4.prune(St.GI_BOX)
    A['doors']['front'].rotation_euler.z = math.radians(105)   # open onto the sunset (Japanese front doors swing out)
    S['boxes'] = H4.colliders()
    shot.genkan_props4(M, shoes=5, umbrellas=5)
    Y = St.YF; DC = St.DOOR_C
    porch = prim('cube', 'porch', loc=(DC, Y + 1.0, Hm.ZG - .03), scale=(1.6, 1.0, .03), mat=M['floor']); lib.uv_box(porch, .87)
    import house4_ext as HX; HX.build_ext4(M, with_trees=True)   # the outside through the open door (外観スレッド)
    sky = bpy.data.materials.new('sunset'); sky.use_nodes = True; N = sky.node_tree.nodes; L = sky.node_tree.links
    p = N['Principled BSDF']; t = N.new('ShaderNodeTexImage'); t.image = lib.img(lib.tex_path('sunset'))
    L.new(t.outputs[0], p.inputs['Base Color']); L.new(t.outputs[0], p.inputs['Emission Color']); p.inputs['Emission Strength'].default_value = 2.2
    p.inputs['Base Color'].default_value = (0, 0, 0, 1)
    bd = prim('plane', 'sunset_backdrop', loc=(DC + .14, Y + 9, 1.6), rot=(math.pi / 2, 0, 0), scale=(8, 8 * 876 / 1358, 1), mat=sky)
    bd.visible_shadow = False
    bpy.data.objects.remove(bd)   # v4: the exterior's sky ring (外観スレッド, r 28 m) is the backdrop; the sheet stood inside the wood and shaded the front
    S['sun'] = lib.sun('sun', (0, 0, 0), 14, k=2200, angle=.8)
    S['sun'].rotation_euler = Vector((.3, -.95, -.25)).to_track_quat('-Z', 'Y').to_euler()
    w = s.world.node_tree.nodes['Background']; w.inputs[0].default_value = (*kelvin(3400), 1); w.inputs[1].default_value = .35
    lib.area('door_sky', (DC, Y + .25, 1.1), (DC - .16, 3.5, .7), 30, k=4200, size=(.8, 2.1), spread=120)
    if os.environ.get('EXT'):   # the look comparison: the whole outside of the house, the sky ring replaces the backdrop
        import house; house.build_exterior(M)
        k_ = 20 / 9   # the sunset sheet pushed back to 20 m (same size seen from the hall), out of the outside views' way
    D.fresnel(St.FRESNEL, 2.0, (*St.MARK, 0), M, energy=160, size=30)
    D.tripod(St.TRIPOD_D, math.radians(205), M)
    Hm.tape_mark(*St.MARK, CAM[:2], 'tape_natsuki.png')
    ab = prim('cube', 'applebox', loc=(*St.APPLEBOX, .1), rot=(0, 0, .3), scale=(.25, .15, .1), mat=M['agari']); lib.uv_box(ab, 1.25)
    # the reflector is held by Makoto (the new member helps: she holds things, lights hands), no stand
    # people
    n = C.make_tripo('natsuki_s', label='natsuki')[0]; n.location = (*St.NATSUKI_D, 0);   # indoors: the socks body
    for ob in n.children_recursive: ob.name = ob.name.replace('natsuki_s_', 'natsuki_')
    n.location = (*St.NATSUKI_D, 0); face(n, CAM[:2]); n.rotation_euler.z += math.radians(-10)
    k = C.make_tripo('kiryu')[0]; k.location = (*St.KIRYU_D, 0); k.rotation_euler.z = math.radians(205 - 180 + 8)   # squarely behind the camera, which points at yaw 205
    t = C.make_tripo('taiga')[0]; t.location = (*St.TAIGA_D, Hm.ZG); face(t, (DC - .56, 3.0))
    m = C.make_tripo('makoto')[0]; C.socks(m); m.location = (*St.MAKOTO_D, 0); face(m, St.NATSUKI_D)
    bpy.context.view_layer.update()
    # the reflector, held as in the reference photos: in front of her belly, its face toward Natsuki's face (so it
    # leans back toward Makoto by the angle up to that face), hands at the side edges low down, elbows bent at her sides
    nface = Vector((St.NATSUKI_D[0], St.NATSUKI_D[1] - .02, 1.5))
    ctr = C.local(m, (0, -.21, 0)); ctr.z = (C.bone_head(m, 'upperarm_l').z + C.bone_head(m, 'upperarm_r').z) / 2 - .1   # wrists at elbow height, forearms forward
    rf = prim('cube', 'reflector', loc=tuple(ctr), scale=(.2, .006, .2), mat=mat_basic('refl', (.9, .9, .88), .7))
    rf.rotation_euler = (nface - ctr).to_track_quat('-Y', 'Z').to_euler(); bpy.context.view_layer.update()
    lib.area('reflector_bounce', tuple(ctr + (nface - ctr).normalized() * .03), tuple(nface), 9, k=3000, size=(.4, .4), spread=150)
    print('reflector at', tuple(round(x, 2) for x in ctr), 'leans back', round(math.degrees(math.asin((nface - ctr).normalized().z)), 1), 'deg')
    # she grips the board by its side edges: wrists just outside each edge, palms toward the centre, fingers curling round
    # the board faces Natsuki along its local -Y (scale .006 -> 1 unit = 6 mm); Makoto stands on the +Y (back) side.
    # Board local +X points away from her (toward -x world), so her LEFT hand takes the board's +X edge.
    # Wrists 2 cm outside each edge and 8 cm behind the board, a little below centre; palms face the board's centre
    S['rf_l'] = rf.matrix_world @ Vector((1.07, 6, -.45)); S['rf_r'] = rf.matrix_world @ Vector((-1.07, 6, -.45))
    S['rf_lf'] = rf.matrix_world @ Vector((0, 0, -.45)); S['rf_rf'] = S['rf_lf']; S['rf'] = rf; S['rf_M'] = rf.matrix_world.copy()
    S.update(n=n, k=k, t=t, m=m)
    bpy.context.view_layer.update()
    roll = shot.tape_roll('taperoll', .058, .040, .05, mat_basic('tapeyel', (.95, .62, .04), .45), mat_basic('tapecore', (.55, .42, .28), .8))   # a 115 mm roll of gaffer tape on its 3-inch core (the hole her fingers go through), saturated so it reads through the print
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

def taiga_lights():
    # Taiga in the doorway, against the sky: what the eye sees, not the meter (ユーザー：目には HDR 的に見える).
    # A fill from the hall side (the sunlit genkan floor and the walls throw light back at him) so his face and
    # clothes read, and a rim from the sky behind him over the shoulders. Godot lights only Taiga with these;
    # made after the bounce bake, so they never reach the walls.
    tc = St.TAIGA_D
    lib.area('taiga_fill', (tc[0] - .25, tc[1] - 1.5, .55), (tc[0], tc[1], Hm.ZG + 1.2), 6, k=3300, size=(.8, .8), spread=150)
    lib.area('taiga_rim', (tc[0] + .1, tc[1] + .9, 2.0), (tc[0], tc[1], Hm.ZG + 1.5), 6, k=4800, size=(1.0, .4), spread=120)
    bpy.context.view_layer.update()   # dump_lights reads matrix_world: new objects are at the origin until updated

TALK = ((2.0, 4.6), (9.0, 10.4), (14.5, 16.8))   # Natsuki says something to Mio

def pose_natsuki(n, t):
    nl = lambda v: C.local(n, v)
    tilt = E.noise1(t, 4.0, .5)
    # arms down, the tape roll hanging from the fingers of the right hand at the thigh; the left hand rests on her hip
    laugh = sum(E.snap(t, a, .35) * (1 - E.snap(t, b, .5)) for a, b in TALK)
    C.arm_to(n, 'r', nl((-.23, -.07 + .01 * tilt, .79 + .01 * laugh)), Vector((-.35, .3, 0)))
    C.arm_to(n, 'l', nl((.245, -.04, .80 + .01 * laugh)), Vector((.08, .3, 0))); C.palm_to(n, 'l', nl((.6, -.05, .80)), limit=35)   # a small roll only: turning the forearm further wrung the puffy sleeve into a step at the elbow   # hanging relaxed: the generated puffy sleeve dents and tears when the elbow is bent hard (hand on hip)
    C.palm_to(n, 'r', nl((-.6, -.07, .79)))   # palm inward toward the thigh, the roll hangs below
    C.grip(n, 'r', .85); C.grip(n, 'l', .25)
    C.rot_world(n, 'head', (0, 0, 1), 8 + 6 * tilt)
    C.rot_world(n, 'neck_01', E.axis_local(n, (0, 1, 0)), 5 * laugh)
    C.rot_world(n, 'spine_03', E.axis_local(n, (1, 0, 0)), -3 * laugh)
    E.idle(n, t, 3.0, breath=.28, amp=1.0, rate=1.1)

def pose_kiryu(k, t):
    kl = lambda v: C.local(k, v)
    # framing her on the camera's flip-out screen; looks up over it twice
    up = E.snap(t, 6.5, .45) * (1 - E.snap(t, 8.6, .5)) + E.snap(t, 15.2, .45) * (1 - E.snap(t, 17.0, .5))
    # his hands are on the camera on the tripod (cx, cy): the right rests on top of the body, palm down; the left holds
    # the body's left side at his left, palm in, the elbow out by his side (not in front of his stomach)
    cx, cy = St.TRIPOD_D
    lv = E.axis_local(k, (1, 0, 0)); lv.z = 0; lv.normalize()
    C.arm_to(k, 'r', Vector((cx - .03, cy + .07, 1.575)), Vector((-.35, .2, -.3))); C.palm_to(k, 'r', Vector((cx - .03, cy + .07, 1.2)))
    C.grip(k, 'r', .25, thumb=.2)
    # 試作19b（ユーザーの選択）：the left arm hangs at his side. Raised to the camera's side, the shirt under it folded
    # inside out (7 ways tried: NOTES.md). The right hand alone works the camera.
    C.arm_to(k, 'l', kl((.24, .03, .84)), E.axis_local(k, (.2, 1, 0))); C.palm_to(k, 'l', kl((0, .03, .84)))
    C.grip(k, 'l', .2, thumb=.15)
    C.rot_world(k, 'neck_01', E.axis_local(k, (1, 0, 0)), 14 - 16 * up)
    E.idle(k, t, 1.0, breath=.21, amp=.8, rate=.8)

def pose_taiga(tg, t):
    tl = lambda v: C.local(tg, v)
    C.arm_to(tg, 'l', tl((.28, -.3, .99)), Vector((.4, .3, -.2)))   # hands outside the box's sides (half width .25): at .2 the forearms sank into it
    C.arm_to(tg, 'r', tl((-.28, -.3, .99)), Vector((-.4, .3, -.2)))
    C.rot_world(tg, 'spine_01', E.axis_local(tg, (1, 0, 0)), -4)
    C.rot_world(tg, 'head', (0, 0, 1), -10 + 25 * E.snap(t, 11.0, .5) * (1 - E.snap(t, 13.5, .5)))
    C.grip(tg, 'l', .35); C.grip(tg, 'r', .35)
    E.idle(tg, t, 2.0, breath=.31, amp=1.1, rate=1.25)

def pose_makoto(m, t):
    # holding the reflector on Natsuki with both hands; the board stays still, so the body breathes under fixed hands
    E.idle(m, t, 7.0, breath=.26, amp=.7, rate=1.05)
    look = E.snap(t, 3.2, .5) * (1 - E.snap(t, 5.0, .6)) + E.snap(t, 12.0, .5) * (1 - E.snap(t, 13.6, .6))   # glances at Kiryu
    # the whole turn on the neck bone: the head's own share bent the lower face behind the upper (the mouth lagged up to
    # 4.5 cm at this angle, 試作18 「顔の下半身と上半身で歪み」); the neck between the collar and the jaw takes the twist
    C.rot_world(m, 'neck_01', (0, 0, 1), -8 + 30 * look)
    # each hand holds a side edge as in the photo (a box held by its sides): palm facing in against the edge, fingers
    # up along it, the edge in the crotch of the hand: the thumb on the face toward her (the back face), the fingers
    # round the other side and their tips curling onto the front a little
    RM = S["rf_M"]; R = RM.to_3x3().normalized()   # the board stays its own object (export_godot.NO_LM): Godot turns it with her when she talks
    bx = R @ Vector((1, 0, 0)); f = -(R @ Vector((0, 1, 0))); ub = R @ Vector((0, 0, 1))
    for side, sx in (('l', 1), ('r', -1)):
        # 試作18 「レフ板をちゃんと持てていない」: the fingers stood up beside the edge without touching it. Now the way a
        # board is carried in front of the body: the fingers behind it (on her side) reaching in from the edge, the
        # palm against its back face, the thumb over the edge onto the front face
        out = bx * sx
        edge = RM @ Vector((sx * 1.0, 0, -.25))
        back = -f * (.006 + .009)          # half the board's thickness plus the fingers' own half-thickness
        wrist = edge + out * .02 + back + -f * .012   # 2 cm outside: at 5 cm the thumb could not reach the front face (2.2 cm off it) and the open hand showed when she turned (試作34)
        C.arm_to(m, side, wrist, Vector((sx * .15, .3, -.8)))      # elbows down at her sides
        pz = f * C.palm_sign(m, side)                              # palm toward the board (the board is in front of the hand)
        fing = (-out * .9 + ub * .25).normalized()                  # fingers reach in from the edge, a little upward
        C.set_hand_frame(m, side, fing, pz); C.settle_forearm(m, side); C.set_hand_frame(m, side, fing, pz)
        key = ('mk_curl2', side)
        if key not in S:
            Mi = RM.inverted()
            def depth(f_):   # how far the finger's middle and tip sit behind the back face (m; negative = through it)
                pb2 = m.pose.bones[f'{f_}_02_{side}']; pb3 = m.pose.bones[f'{f_}_03_{side}']
                return min((Mi @ (m.matrix_world @ q)).y * .006 for q in (pb2.head, pb3.tail))
            amt = {}
            for f_ in C.FINGERS:   # curl each finger toward the palm until it lies on the back face
                best = 0.0
                for st in range(0, 13):
                    a_ = st * .04; C.clear_finger(m, side, f_); C.curl_finger(m, side, f_, a_, (40, 50, 30))
                    if depth(f_) < .006 + .007: break
                    best = a_
                amt[f_] = best; C.clear_finger(m, side, f_)
            for f_, a_ in amt.items(): C.curl_finger(m, side, f_, a_, (40, 50, 30))
            C.clear_finger(m, side, 'thumb')
            T = edge - out * .07 + f * (.006 + .007) + ub * .02     # the thumb tip on the front face, 7 cm in from the edge (aimed 3 cm in, the thumb overshot and stood 4 cm off the face)
            for _ in range(5):
                h_ = C.bone_head(m, f'thumb_01_{side}'); t_ = C.bone_tail(m, f'thumb_03_{side}')
                a1, b1 = t_ - h_, T - h_
                if a1.cross(b1).length < 1e-6: break
                C.rot_world(m, f'thumb_01_{side}', a1.cross(b1).normalized(), math.degrees(a1.angle(b1)))
            amt['thumb_q'] = [m.pose.bones[f'thumb_0{j}_{side}'].rotation_quaternion.copy() for j in (1, 2, 3)]
            amt['thumb_err_cm'] = round((C.bone_tail(m, f'thumb_03_{side}') - T).length * 100, 1)
            amt['finger_gap_cm'] = {f_: round((depth(f_) - .006) * 100, 1) for f_ in C.FINGERS}
            S[key] = amt; print('makoto grip', side, {k_: v_ for k_, v_ in amt.items() if k_ != 'thumb_q'})
        for f_, a_ in S[key].items():
            if f_ in C.FINGERS: C.curl_finger(m, side, f_, a_, (40, 50, 30))
        for j, q in zip((1, 2, 3), S[key]['thumb_q']):
            pb = m.pose.bones[f'thumb_0{j}_{side}']; pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = q
        bpy.context.view_layer.update()

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
    taiga_lights()
    E.dump_lights()
    rigs = {'kiryu': (S['k'], lambda t: pose_kiryu(S['k'], t)), 'taiga': (S['t'], lambda t: pose_taiga(S['t'], t)),
            'natsuki': (S['n'], lambda t: pose_natsuki(S['n'], t)), 'makoto': (S['m'], lambda t: pose_makoto(S['m'], t))}
    for name, (rig, fn) in rigs.items(): E.bake_action(rig, fn)
    for name, (rig, fn) in rigs.items(): E.export(f'{OUT}/{name}.glb', E.descendants(rig))
    env = [o for o in bpy.data.objects if o not in chars and o.type in ('MESH', 'CURVE', 'EMPTY')]
    if os.environ.get('SKIP_LM') and not os.environ.get('ENV'): print('env.glb: kept')   # ENV=1: props moved (the lightmap may lag)
    else: E.export(f'{OUT}/env.glb', env)
    # lme: the baked bounce (Godot default 1.5); the narrow v4 hall printed its walls paper white at 1.5
    json.dump(dict(scene='dusk', YF=Hm.YF, ZG=Hm.ZG, cam0=list(CAM), fps=E.FPS, loop=E.LOOP, talk=TALK,
                   **St.scene_json('dusk', S['boxes']), lme=.7), open(f'{OUT}/scene.json', 'w'), indent=1)
    print('EXPORTED')
