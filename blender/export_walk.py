"""第2章から：人の歩き（試作92）. Mixamo's walk, stairs and turns (ユーザーが渡した FBX, 段階2/mixamo/, not in git)
put on the four make_tripo rigs: the legs, the hips and the spine come from Mixamo, the arms and the head stay ours
(export_t20.pose: the phone in the right hand, its torch ahead), so the people walk with their phones out.

Retargeting: for each mapped bone, the change of its world rotation from Mixamo's rest (a T-pose, legs straight) is
put on our bone's rest (the same idea for both skeletons: straight legs, facing -Y). The hips' movement is scaled by
the hip heights; for the stairs the climb itself (the straight line from the first frame to the last) is taken out
and handed to Godot, which moves the body along the path (walk.json: metres per second, the rise per cycle).

Out: assets/dusk/<k>_walk.glb (rig + the skinned stub, one action per clip, named <rig>_<clip>) and walk.json.
Run: python3 export_walk.py (MIXAMO=<folder with the FBX>)"""
import sys, os, math, json, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P
import bpy
from mathutils import Vector, Quaternion, Matrix
import lib, chars as C
import export_godot as E
import export_t20 as T

SRC = os.environ.get('MIXAMO', '/mnt/project-files/段階2/mixamo')
OUT = f'{P.RULES}/assets/dusk'
# clip: (file, loop, take the climb out)
CLIPS = {'walk': ('Walking_1.fbx', True, False), 'up': ('Walking_Up_The_Stairs.fbx', True, True),
         'down': ('Descending_Stairs.fbx', True, True), 'turnl': ('Left_Turn.fbx', False, False),
         'turnr': ('Right_Turn.fbx', False, False)}
MAP = {'Hips': 'pelvis', 'Spine': 'spine_01', 'Spine1': 'spine_02', 'Spine2': 'spine_03',
       'LeftUpLeg': 'thigh_l', 'LeftLeg': 'calf_l', 'LeftFoot': 'foot_l', 'LeftToeBase': 'ball_l',
       'RightUpLeg': 'thigh_r', 'RightLeg': 'calf_r', 'RightFoot': 'foot_r', 'RightToeBase': 'ball_r'}
SLOW = 0.85    # a little slower than Mixamo's: a dark house, phones out (ユーザーに説明した「速さを落として」)

def rot_of(M):
    return M.to_3x3().normalized().to_quaternion()

def read_clip(path):
    """Mixamo world data per frame: {bone: delta world rotation from rest}, hips world position; and the rest."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
    f0, f1 = [int(x) for x in arm.animation_data.action.frame_range]
    sc = bpy.context.scene
    W = arm.matrix_world
    rest = {b: rot_of(W @ arm.data.bones['mixamorig:' + b].matrix_local) for b in MAP}
    hip0 = W @ arm.data.bones['mixamorig:Hips'].head_local
    frames = []
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        d = {b: rot_of(W @ arm.pose.bones['mixamorig:' + b].matrix) @ rest[b].inverted() for b in MAP}
        hp = W @ arm.pose.bones['mixamorig:Hips'].head
        feet = [W @ arm.pose.bones['mixamorig:' + s + 'Foot'].head for s in ('Left', 'Right')]
        frames.append({'d': d, 'hip': hp.copy(), 'feet': [v.copy() for v in feet]})
    return {'frames': frames, 'hip0': hip0.copy(), 'fps': sc.render.fps}

def ground_speed(clip):
    """In place: how fast the planted foot slides back (m/s, Mixamo size)."""
    fr = clip['frames']; fps = clip['fps']; v = []
    for s in range(2):
        zs = [f['feet'][s].z for f in fr]; lo = min(zs)
        for i in range(1, len(fr)):
            if fr[i]['feet'][s].z < lo + .03 and fr[i - 1]['feet'][s].z < lo + .03:
                dy = fr[i]['feet'][s].y - fr[i - 1]['feet'][s].y
                v.append(dy * fps)   # forward is -Y: the planted foot moves +Y
    return sum(v) / max(1, len(v))

def sample(clip, t):
    """clip at time t (s), linear between frames"""
    fr = clip['frames']; x = t * clip['fps']
    i = min(int(x), len(fr) - 2); a = x - i
    A, B = fr[i], fr[i + 1]
    return {'d': {b: A['d'][b].slerp(B['d'][b], a) for b in MAP}, 'hip': A['hip'].lerp(B['hip'], a)}

def put(rig, key, clip, t, k_size, trend):
    s = sample(clip, t)
    n = len(clip['frames']) - 1; T_ = n / clip['fps']
    hip = s['hip'] - clip['hip0']
    if trend is not None: hip = hip - trend * (t / T_)
    Rw = rig.matrix_world.to_3x3().normalized().to_quaternion()
    for b, ob in MAP.items():   # parents first (MAP is in hierarchy order)
        pb = rig.pose.bones[ob]
        bpy.context.view_layer.update()
        rest_w = rot_of(rig.matrix_world @ rig.data.bones[ob].matrix_local)
        tgt_w = s['d'][b] @ rest_w
        head = (rig.matrix_world @ pb.matrix).translation
        if ob == 'pelvis': head = rig.matrix_world @ rig.data.bones[ob].head_local + hip * k_size
        Mw = Matrix.Translation(head) @ tgt_w.to_matrix().to_4x4()
        pb.matrix = rig.matrix_world.inverted() @ Mw
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()
    T.pose(key, rig, t)

def bake(rig, key, name, clip, loop, k_size, trend):
    n = len(clip['frames']) - 1
    dur = n / clip['fps']
    out_n = max(2, round(dur / SLOW * E.FPS))
    rig.animation_data_create()
    act = bpy.data.actions.new(f'{rig.name}_{name}'); rig.animation_data.action = act
    prev = {}
    for f in range(out_n + 1):
        t = dur * f / out_n
        C.reset_pose(rig); put(rig, key, clip, t, k_size, trend); C.apply_twist(rig)
        for pb in rig.pose.bones:
            q = pb.rotation_quaternion.copy()
            if pb.name in prev and q.dot(prev[pb.name]) < 0: q = -q; pb.rotation_quaternion = q
            prev[pb.name] = q
            pb.keyframe_insert('rotation_quaternion', frame=f + 1)
        rig.pose.bones['pelvis'].keyframe_insert('location', frame=f + 1)
    act.use_fake_user = True
    return act, out_n / E.FPS

if __name__ == '__main__':
    clips = {k: read_clip(f'{SRC}/{v[0]}') for k, v in CLIPS.items()}
    info = {}
    for k, c in clips.items():
        n = len(c['frames']) - 1; T_ = n / c['fps']
        tr = c['frames'][-1]['hip'] - c['frames'][0]['hip']
        info[k] = {'dur': T_, 'trend': tr, 'speed': ground_speed(c) if k == 'walk' else -tr.y / T_}
        print('CLIP', k, 'frames', n + 1, 'dur %.2f' % T_, 'trend', tuple(round(x, 3) for x in tr), 'speed %.3f' % info[k]['speed'])
    rigs = T.build()
    E_nodeform = []
    for o in bpy.data.objects:   # sampling reads bones only (export_godot.bake_action)
        if o.type == 'MESH':
            for md in o.modifiers:
                if md.show_viewport: md.show_viewport = False; E_nodeform.append(md)
    out = {}
    for key, rig in rigs.items():
        hip_h = (rig.matrix_world @ rig.data.bones['pelvis'].head_local).z
        k_size = hip_h / clips['walk']['hip0'].z
        acts = {}
        for name, (fn, loop, detrend) in CLIPS.items():
            act, dur = bake(rig, key, name, clips[name], loop, k_size, info[name]['trend'] if detrend else None)
            acts[name] = act
            tr = info[name]['trend'] * k_size
            out.setdefault(key, {})[name] = {'anim': act.name, 'dur': dur, 'loop': loop,
                'speed': info[name]['speed'] * k_size * SLOW,                       # metres per second along the path
                'fwd': -tr.y, 'rise': tr.z}                                         # per cycle (stairs)
            print('BAKED', key, name, 'dur %.2f' % dur, out[key][name])
        rig.animation_data.action = acts['walk']
        me = bpy.data.meshes.new(f'{key}_walkstub'); me.from_pydata([(0, 0, 0), (.001, 0, 0), (0, .001, 0)], [], [(0, 1, 2)])
        stub = bpy.data.objects.new(f'{key}_walkstub', me); bpy.context.scene.collection.objects.link(stub)
        stub.parent = rig; vg = stub.vertex_groups.new(name='pelvis'); vg.add([0, 1, 2], 1.0, 'REPLACE')
        md = stub.modifiers.new('arm', 'ARMATURE'); md.object = rig
        # only this rig's actions go in its file: the rigs share bone names, so 'ACTIONS' would take every rig's
        bpy.ops.object.select_all(action='DESELECT')
        for o in (rig, stub): o.select_set(True)
        bpy.ops.export_scene.gltf(filepath=f'{OUT}/{key}_walk.glb', export_format='GLB', use_selection=True, export_apply=True,
                                  export_animations=True, export_animation_mode='ACTIONS', export_yup=True,
                                  export_force_sampling=True, export_def_bones=False)
        rig.animation_data.action = None
        for a in acts.values(): bpy.data.actions.remove(a)
    json.dump(out, open(f'{OUT}/walk.json', 'w'), indent=1)
    print('EXPORTED walk')
