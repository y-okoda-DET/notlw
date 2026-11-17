"""2026-11-14（ユーザー「居間、みんな内側を向いて会話している感じに。スマホは持たない」）：21時の居間と地下の窓の、立つ・座る・
しゃがむ・話す動き。ユーザーが渡した Mixamo の FBX（段階2/mixamo/、git に入れない）を、make_tripo の4人の体に全身で載せる。

export_walk.py と同じ考え（各骨の世界での回転の、Mixamo の休みの姿勢からの変化を、こちらの骨の休みの姿勢に載せる）。ただ腕は
二つの休みの姿勢が違う（Mixamo は T、こちらは腕を下ろした形）ので、先にこちらの腕の骨を Mixamo の休みの向きにそろえてから載せる。
指はこちらのまま（軽く曲げた手）。腰の動きは腰の高さの比で縮める（座る・しゃがむの下がりもそのまま）。

Out: assets/dusk/<k>_talk.glb（体の骨と小さな印。1本の動きが1つの action、名前は <rig>_<clip>）と talk.json（長さ）。
Run: python3 export_talk.py（MIXAMO=<FBX のあるフォルダ>）"""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P
import bpy
from mathutils import Vector, Matrix
import chars as C
import export_godot as E
import export_t20 as T
import export_walk as W

SRC = W.SRC
OUT = W.OUT
# clip: file. 話す4本は Mixamo の Talking 1〜4（届いた順の名前ではないので A〜D）、座って話す2本、立つ、考える、言い合う、しゃがむ
CLIPS = {'talk_a': 'Talking_A.fbx', 'talk_b': 'Talking_B.fbx', 'talk_c': 'Talking_C.fbx', 'talk_d': 'Talking_D.fbx',
         'sit_a': 'Sitting_Talking_A.fbx', 'sit_b': 'Sitting_Talking_B.fbx', 'idle': 'Standing_Idle.fbx',
         'think': 'Thinking.fbx', 'argue': 'Standing_Arguing.fbx', 'crouch': 'Crouching_Idle.fbx',
         # 2026-11-17 第5章（真琴が夏希の横にひざをつく、勝手口の手形に手を重ねる）：Mixamo の Kneel（10.8 秒、30fps）を二つに切る。
         # kneel＝立ちから下りて片ひざをついたまま（1.7〜6.2 秒。Godot では繰り返さず、最後の形で止める）、kneel_up＝そこから立つ（6.2〜8.0 秒）
         'kneel': ('Kneel.fbx', 1.7, 6.2), 'kneel_up': ('Kneel.fbx', 6.2, 8.0)}
MAX_DUR = 24.0   # 座って話す2本は40秒を超える：前の24秒だけ（ループの継ぎ目は Godot で短く重ねる）
ARMS = {'LeftShoulder': 'clavicle_l', 'LeftArm': 'upperarm_l', 'LeftForeArm': 'lowerarm_l', 'LeftHand': 'hand_l',
        'RightShoulder': 'clavicle_r', 'RightArm': 'upperarm_r', 'RightForeArm': 'lowerarm_r', 'RightHand': 'hand_r'}
HEAD = {'Neck': 'neck_01', 'Head': 'head'}
MAP = dict(W.MAP); MAP.update(HEAD); MAP.update(ARMS)   # hierarchy order: legs and spine, then the neck, then the arms

def rot_of(M):
    return M.to_3x3().normalized().to_quaternion()

def read_clip(path, part=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
    f0, f1 = [int(x) for x in arm.animation_data.action.frame_range]
    sc = bpy.context.scene; Wm = arm.matrix_world
    f1 = min(f1, f0 + int(MAX_DUR * sc.render.fps))
    if part: f0, f1 = f0 + round(part[0] * sc.render.fps), min(f1, f0 + round(part[1] * sc.render.fps))
    rest = {b: rot_of(Wm @ arm.data.bones['mixamorig:' + b].matrix_local) for b in MAP}
    hip0 = Wm @ arm.data.bones['mixamorig:Hips'].head_local   # the rest's hips (a part of a clip moves from there too)
    frames = []
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        d = {b: rot_of(Wm @ arm.pose.bones['mixamorig:' + b].matrix) @ rest[b].inverted() for b in MAP}
        frames.append({'d': d, 'hip': (Wm @ arm.pose.bones['mixamorig:Hips'].head).copy()})
    return {'frames': frames, 'hip0': hip0.copy(), 'fps': sc.render.fps,
            'rest_dir': {b: (rest[b] @ Vector((0, 1, 0))).normalized() for b in ARMS}}

def sample(clip, t):
    fr = clip['frames']; x = t * clip['fps']
    i = min(int(x), len(fr) - 2); a = x - i
    A, B = fr[i], fr[i + 1]
    return {'d': {b: A['d'][b].slerp(B['d'][b], a) for b in MAP}, 'hip': A['hip'].lerp(B['hip'], a)}

def put(rig, clip, t, k_size, align):
    s = sample(clip, t)
    hip = s['hip'] - clip['hip0']
    for b, ob in MAP.items():   # parents first
        pb = rig.pose.bones[ob]
        bpy.context.view_layer.update()
        rest_w = rot_of(rig.matrix_world @ rig.data.bones[ob].matrix_local)
        if b in align: rest_w = align[b] @ rest_w
        tgt_w = s['d'][b] @ rest_w
        head = (rig.matrix_world @ pb.matrix).translation
        if ob == 'pelvis': head = rig.matrix_world @ rig.data.bones[ob].head_local + hip * k_size
        pb.matrix = rig.matrix_world.inverted() @ (Matrix.Translation(head) @ tgt_w.to_matrix().to_4x4())
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()

def bake(rig, name, clip, k_size, align):
    n = len(clip['frames']) - 1
    dur = n / clip['fps']
    out_n = max(2, round(dur * E.FPS))
    rig.animation_data_create()
    act = bpy.data.actions.new(f'{rig.name}_{name}'); rig.animation_data.action = act
    keyed = [b for b in MAP.values()] + [b for b in rig.pose.bones.keys() if 'twist' in b]
    prev = {}
    for f in range(out_n + 1):
        t = dur * f / out_n
        C.reset_pose(rig); put(rig, clip, t, k_size, align); C.apply_twist(rig)
        for bn in keyed:
            pb = rig.pose.bones[bn]
            q = pb.rotation_quaternion.copy()
            if bn in prev and q.dot(prev[bn]) < 0: q = -q; pb.rotation_quaternion = q
            prev[bn] = q
            pb.keyframe_insert('rotation_quaternion', frame=f + 1)
        rig.pose.bones['pelvis'].keyframe_insert('location', frame=f + 1)
    act.use_fake_user = True
    return act, out_n / E.FPS

if __name__ == '__main__':
    only = os.environ.get('CLIPS')
    clips = {k: (read_clip(f'{SRC}/{v}') if isinstance(v, str) else read_clip(f'{SRC}/{v[0]}', v[1:]))
             for k, v in CLIPS.items() if not only or k in only.split(',')}
    who = os.environ.get('WHO')   # e.g. WHO=makoto: only her glb is written (a quick try; build.sh writes all four)
    for k, c in clips.items(): print('CLIP', k, 'frames', len(c['frames']), flush=True)
    hip_ref = W.read_clip(f'{SRC}/Walking_1.fbx')['hip0'].z   # the size of Mixamo's body (the same for every clip); before build (it clears the scene)
    rigs = T.build()
    for o in bpy.data.objects:
        if o.type == 'MESH':
            for md in o.modifiers: md.show_viewport = False
    out = {}
    for key, rig in rigs.items():
        if who and key not in who.split(','): continue
        C.reset_pose(rig); bpy.context.view_layer.update()
        hip_h = (rig.matrix_world @ rig.data.bones['pelvis'].head_local).z
        k_size = hip_h / hip_ref
        acts = {}
        for name, clip in clips.items():
            align = {}
            for b, ob in ARMS.items():
                ours = (rot_of(rig.matrix_world @ rig.data.bones[ob].matrix_local) @ Vector((0, 1, 0))).normalized()
                align[b] = ours.rotation_difference(clip['rest_dir'][b])
            act, dur = bake(rig, name, clip, k_size, align)
            acts[name] = act
            out.setdefault(key, {})[name] = {'anim': act.name, 'dur': dur}
            print('BAKED', key, name, 'dur %.2f' % dur, flush=True)
        rig.animation_data.action = acts[next(iter(acts))]
        me = bpy.data.meshes.new(f'{key}_talkstub'); me.from_pydata([(0, 0, 0), (.001, 0, 0), (0, .001, 0)], [], [(0, 1, 2)])
        stub = bpy.data.objects.new(f'{key}_talkstub', me); bpy.context.scene.collection.objects.link(stub)
        stub.parent = rig; vg = stub.vertex_groups.new(name='pelvis'); vg.add([0, 1, 2], 1.0, 'REPLACE')
        md = stub.modifiers.new('arm', 'ARMATURE'); md.object = rig
        bpy.ops.object.select_all(action='DESELECT')
        for o in (rig, stub): o.select_set(True)
        bpy.ops.export_scene.gltf(filepath=f'{OUT}/{key}_talk.glb', export_format='GLB', use_selection=True, export_apply=True,
                                  export_animations=True, export_animation_mode='ACTIONS', export_yup=True,
                                  export_force_sampling=True, export_def_bones=False)
        rig.animation_data.action = None
        for a in acts.values(): bpy.data.actions.remove(a)
    if not who: json.dump(out, open(f'{OUT}/talk.json', 'w'), indent=1)
    print('EXPORTED talk')
