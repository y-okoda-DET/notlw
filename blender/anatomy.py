"""Body-structure check of the exported characters (run before every set of check images):
    python3 anatomy.py [glb ...]          (default: every character glb of both scenes)
At rest: the toes and the chin must point the same way as the skeleton's front (catches a body or head on backwards).
Over the loop (every 4th frame): elbows and knees bend only the anatomical way, the forearm bone itself rolls little
(the twist bone does the turning, gradually toward the wrist), and the twist stays within what a forearm can turn.
Prints one line per check and NG lines for failures; the last line is ANATOMY_OK or ANATOMY_NG <count>."""
import sys, os, math, glob
import bpy
from mathutils import Vector

A = '/home/claude/rules/assets'
files = [a for a in sys.argv[1:] if a.endswith('.glb')] or \
    [f'{A}/{k}.glb' for k in ('natsuki', 'kiryu', 'taiga')] + [f'{A}/dusk/{k}.glb' for k in ('natsuki', 'kiryu', 'taiga', 'makoto')]
ROLL_MAX = 45      # deg the forearm bone may roll about its own axis (the elbow end barely turns in a real arm)
TWIST_MAX = 110    # deg the twist bone may turn (pronation + supination range, with a little give)
BEND_TOL = .05     # how far (as a cosine) a bent elbow or knee may go the wrong way before it is called reversed
ng = 0

def NG(msg):
    global ng; ng += 1; print('  NG', msg)

def hd(a, b): return Vector((a.x - b.x, a.y - b.y)).length   # horizontal distance

def horiz(v):
    v = Vector((v.x, v.y, 0)); return v.normalized() if v.length > 1e-6 else v

for path in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o.find_armature() == rig]
    name = os.path.relpath(path, A)
    print(name)
    sc = bpy.context.scene
    act = rig.animation_data.action if rig.animation_data else None
    # ---- rest: skeleton front vs the mesh's toes and chin
    rig.data.pose_position = 'REST'; bpy.context.view_layer.update()
    mw = rig.matrix_world
    def bh(b): return mw @ rig.data.bones[b].head_local
    fwd = horiz((bh('ball_l') - bh('foot_l')) + (bh('ball_r') - bh('foot_r')))
    # judged on the mesh itself (a fitted joint can sit a few cm off): the shoe's sole reaches forward of the
    # shin above it, and the drawn face sits forward of the head's middle. Both must agree with the skeleton.
    allp = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    z0 = min(p.z for p in allp)
    for side in ('l', 'r'):
        fx = bh(f'foot_{side}')
        near = [p for p in allp if hd(p, fx) < .16]
        sole = [p for p in near if p.z < z0 + .03]; shin = [p for p in near if z0 + .14 < p.z < z0 + .20]
        if not sole or not shin: NG(f'toes {side}: no shoe or shin found'); continue
        d = ((sum(sole, Vector()) / len(sole)) - (sum(shin, Vector()) / len(shin))).dot(fwd)
        print(f'  toes {side}: the sole reaches {d * 100:+.1f} cm forward of the shin')
        if d < .015: NG(f'toes {side} do not point to the skeleton\'s front (body on backwards?)')
    nz = bh('neck_01').z; fp = []
    for o in meshes:
        mi = {i for i, m in enumerate(o.data.materials) if m and m.name.endswith('_face')}
        for poly in o.data.polygons:
            if poly.material_index in mi: fp.append(o.matrix_world @ poly.center)
    if fp:
        c = sum(fp, Vector()) / len(fp)
        head = [p for p in allp if p.z > nz + .05 and hd(p, bh('head')) < .2 and abs(p.z - c.z) < .06]
        if not head: print('  face at', tuple(round(x, 2) for x in c), 'neck z %.2f head joint' % nz, tuple(round(x, 2) for x in bh('head'))); NG('no head vertices around the face'); continue
        hc = sum(head, Vector()) / len(head)
        d = (c - hc).dot(fwd)
        print(f'  face: {d * 100:+.1f} cm forward of the middle of the head')
        if d < .02: NG('the drawn face is not on the front of the head (head on backwards?)')
    else: NG('no drawn face found (material *_face)')
    # ---- the loop: joints
    rig.data.pose_position = 'POSE'
    if not act: print('  (no animation)'); continue
    f0, f1 = map(int, act.frame_range)
    rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
    worst = {}
    def keep(k, val, fr):
        if k not in worst or abs(val) > abs(worst[k][0]): worst[k] = (val, fr)
    for fr in range(f0, f1 + 1, 4):
        sc.frame_set(fr)
        P = {pb.name: pb.matrix.copy() for pb in rig.pose.bones}
        for side in ('l', 'r'):
            for up, lo, sign, label in ((f'upperarm_{side}', f'lowerarm_{side}', 1, 'elbow'), (f'thigh_{side}', f'calf_{side}', -1, 'knee')):
                if up not in P or lo not in P: continue
                # the front of the limb at rest (the skeleton's front, square to the bone), carried by the upper bone
                ud0 = rest[up].to_3x3() @ Vector((0, 1, 0)); a0 = Vector((0, -1, 0)); a0 = (a0 - ud0 * a0.dot(ud0)).normalized()
                R = P[up].to_3x3().normalized() @ rest[up].to_3x3().normalized().inverted()
                a = R @ a0; ud = P[up].to_3x3().normalized() @ Vector((0, 1, 0)); ld = P[lo].to_3x3().normalized() @ Vector((0, 1, 0))
                bend = math.degrees(ud.angle(ld))
                if bend > 15:
                    s = sign * ld.dot(a)   # elbows fold toward the front of the arm, knees toward the back of the leg
                    keep(f'{label} {side} wrong-way', min(0, s), fr)
                    if s < -BEND_TOL: keep(f'{label} {side} REVERSED', s, fr)
            # forearm: roll of the forearm bone about its own axis relative to the upper arm, and the twist bone's turn
            fa = f'lowerarm_{side}'; ua = f'upperarm_{side}'; tw = f'lowerarm_twist_{side}'
            if fa in P:
                Lrel = (rest[ua].inverted() @ rest[fa]).to_3x3().normalized().inverted() @ (P[ua].inverted() @ P[fa]).to_3x3().normalized()
                q = Lrel.to_quaternion(); twist_y = 2 * math.degrees(math.atan2(q.y, q.w))
                twist_y = (twist_y + 180) % 360 - 180
                keep(f'forearm bone roll {side}', twist_y, fr)
            if tw in rig.pose.bones:
                q = rig.pose.bones[tw].rotation_quaternion; a_ = (2 * math.degrees(math.atan2(q.y, q.w)) + 180) % 360 - 180
                keep(f'forearm twist {side}', a_, fr)
    for k in sorted(worst):
        v, fr = worst[k]
        if 'wrong-way' in k: print(f'  {k}: worst {v:+.2f} (frame {fr})'); continue
        if 'REVERSED' in k: NG(f'{k} (cos {v:+.2f}, frame {fr})'); continue
        print(f'  {k}: max {v:+.0f} deg (frame {fr})')
        if 'bone roll' in k and abs(v) > ROLL_MAX: NG(f'{k}: the forearm turns as one piece ({v:+.0f} deg)')
        if 'forearm twist' in k and abs(v) > TWIST_MAX: NG(f'{k}: beyond a forearm\'s range ({v:+.0f} deg)')
    if not any(k.startswith('forearm twist') for k in worst): print('  (no forearm twist bones)')
print('ANATOMY_OK' if ng == 0 else f'ANATOMY_NG {ng}')
