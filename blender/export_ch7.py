"""第7章「去年の夏」（2026-11-19）：澪の体と動き、陽太の腕。これまで澪は腕（export_mio_arms.py）しか出ていなかった。
この章だけ、澪が人として見える（夕方の玄関で扉を開ける。飲み会）。

出す物（assets/dusk/、体と動きは4人と同じ作り）：
  mio.glb        体と頭（make_tripo('mio')、靴下）。立って息をしている 20 秒の輪
  mio_walk.glb   歩く・階段・向きを変える（export_walk.py と同じ動き）
  mio_talk.glb   立つ・話す・考える ほか（export_talk.py と同じ作り。Godot では check/ch7_lib.gd が mio_talk.res にする）
  ch7.json       歩く速さ（main.gd の WALKJ に ch7.gd が足す）、動きの長さ
  ../faces/mio_open|closed|talk.jpg  顔（無ければ tripo/mio_headtex_*.png から）
陽太の腕（props/yota_arm_l|r.glb）は export_mio_arms.py を WHO=yota で回す（そちらに書いた）。

Run: python3 export_ch7.py（MIXAMO=<FBX のあるフォルダ>、CLIPS=idle,talk_a で動きを絞れる）"""
import sys, os, json, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P
import bpy
from mathutils import Vector
import lib, chars as C
import export_godot as E
import export_walk as W
import export_talk as TK

OUT = f'{P.RULES}/assets/dusk'
SRC = W.SRC
# 話す側の動き：export_talk.py の名前のまま。届いたら足す物（無ければ飛ばす）：驚く、笑う
TALK = {'idle': 'Standing_Idle.fbx', 'talk_a': 'Talking_A.fbx', 'think': 'Thinking.fbx', 'sit_a': 'Sitting_Talking_A.fbx', 'sit_b': 'Sitting_Talking_B.fbx',
        'startle': 'Surprised.fbx', 'react': 'Reacting.fbx', 'laugh': 'Laughing.fbx',
        'sit_idle': 'Sitting_Idle.fbx', 'sit_laugh': 'Sitting_Laughing.fbx'}
# 2026-11-19 ユーザーの Mixamo 4：飲み会の4人（桐生・大河・夏希）にこの章だけの動きを足す。export_talk.py（4人の talk.glb、全章が使う）は
# 触らず、<名前>_c7.glb に別に書く（Godot では check/ch7_lib.gd が <名前>_c7.res にし、ch7.gd が "c7" の名前で足す）。
#   PEOPLE=1 python3 export_ch7.py
PEOPLE = {'sit_idle': 'Sitting_Idle.fbx', 'sit_laugh': 'Sitting_Laughing.fbx', 'sit': 'Sitting.fbx', 'drink': 'Drinking.fbx',
          'point': 'Angry_Point.fbx', 'startle': 'Surprised.fbx', 'react': 'Reacting.fbx', 'laugh': 'Laughing.fbx'}

def people():
    import export_t20 as T20
    clips = {k: TK.read_clip(f'{SRC}/{v}') for k, v in PEOPLE.items() if os.path.exists(f'{SRC}/{v}')}
    for k, c in clips.items(): print('CLIP', k, 'frames', len(c['frames']), 'fps', c['fps'], flush=True)
    hip_ref = W.read_clip(f'{SRC}/Walking_1.fbx')['hip0'].z
    rigs = T20.build()
    for o in bpy.data.objects:
        if o.type == 'MESH':
            for md in o.modifiers: md.show_viewport = False
    out = {}
    for key, rig in rigs.items():
        if key not in ('kiryu', 'taiga', 'natsuki'): continue
        C.reset_pose(rig); bpy.context.view_layer.update()
        k_size = (rig.matrix_world @ rig.data.bones['pelvis'].head_local).z / hip_ref
        acts = {}
        for name, clip in clips.items():
            align = {}
            for b, ob in TK.ARMS.items():
                ours = (TK.rot_of(rig.matrix_world @ rig.data.bones[ob].matrix_local) @ Vector((0, 1, 0))).normalized()
                align[b] = ours.rotation_difference(clip['rest_dir'][b])
            act, dur = TK.bake(rig, name, clip, k_size, align)
            acts[name] = act; out.setdefault(key, {})[name] = {'anim': act.name, 'dur': dur}
            print('BAKED', key, name, 'dur %.2f' % dur, flush=True)
        rig.animation_data.action = acts[next(iter(acts))]
        me = bpy.data.meshes.new(f'{key}_c7stub'); me.from_pydata([(0, 0, 0), (.001, 0, 0), (0, .001, 0)], [], [(0, 1, 2)])
        stub = bpy.data.objects.new(f'{key}_c7stub', me); bpy.context.scene.collection.objects.link(stub)
        stub.parent = rig; vg = stub.vertex_groups.new(name='pelvis'); vg.add([0, 1, 2], 1.0, 'REPLACE')
        md = stub.modifiers.new('arm', 'ARMATURE'); md.object = rig
        bpy.ops.object.select_all(action='DESELECT')
        for o in (rig, stub): o.select_set(True)
        bpy.ops.export_scene.gltf(filepath=f'{OUT}/{key}_c7.glb', export_format='GLB', use_selection=True, export_apply=True,
                                  export_animations=True, export_animation_mode='ACTIONS', export_yup=True,
                                  export_force_sampling=True, export_def_bones=False)
        rig.animation_data.action = None
        for a in acts.values(): bpy.data.actions.remove(a)
    json.dump(out, open(f'{OUT}/ch7_people.json', 'w'), indent=1)
    print('EXPORTED ch7 people')

def pose_idle(rig, t):
    kl = lambda v: C.local(rig, v)
    C.arm_to(rig, 'l', kl((.2, -.03, .80)), Vector((.3, .3, 0))); C.arm_to(rig, 'r', kl((-.2, -.03, .80)), Vector((-.3, .3, 0)))
    C.grip(rig, 'l', .3); C.grip(rig, 'r', .3)
    E.idle(rig, t, 11.0, breath=.26, amp=.9, rate=1.0)

def pose_walk(key, rig, t):
    # export_walk.py puts the 20:00 arms (the phone held up) on the walking legs; hers hang, and swing a little with the step
    import math
    kl = lambda v: C.local(rig, v)
    sw = .05 * math.sin(t * 2 * math.pi / 1.1)
    C.arm_to(rig, 'l', kl((.2, -.03 - sw, .80)), Vector((.3, .3, 0))); C.arm_to(rig, 'r', kl((-.2, -.03 + sw, .80)), Vector((-.3, .3, 0)))
    C.grip(rig, 'l', .3); C.grip(rig, 'r', .3)

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    if os.environ.get('PEOPLE'): people(); sys.exit(0)
    W.T.pose = pose_walk
    only = os.environ.get('CLIPS')
    walk = {k: W.read_clip(f'{SRC}/{v[0]}') for k, v in W.CLIPS.items()}
    info = {}
    for k, c in walk.items():
        n = len(c['frames']) - 1; T_ = n / c['fps']
        tr = c['frames'][-1]['hip'] - c['frames'][0]['hip']
        info[k] = {'dur': T_, 'trend': tr, 'speed': W.ground_speed(c) if k == 'walk' else -tr.y / T_}
    talk = {}
    for k, v in TALK.items():
        if only and k not in only.split(','): continue
        if not os.path.exists(f'{SRC}/{v}'): print('NO CLIP', k, v); continue
        talk[k] = TK.read_clip(f'{SRC}/{v}')
    hip_ref = walk['walk']['hip0'].z

    lib.reset()
    rig = C.make_tripo('mio')[0]; C.socks(rig)
    rig.location = (0, 0, 0); rig.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    # the body, standing
    if not os.environ.get('SKIP_BODY'):
        E.simplify_materials()
        C.reset_pose(rig)
        E.bake_action(rig, lambda t: pose_idle(rig, t))
        E.export(f'{OUT}/mio.glb', E.descendants(rig))
        rig.animation_data.action = None
        print('EXPORTED mio body')

    for o in bpy.data.objects:
        if o.type == 'MESH':
            for md in o.modifiers: md.show_viewport = False
    hip_h = (rig.matrix_world @ rig.data.bones['pelvis'].head_local).z
    k_size = hip_h / hip_ref
    out = {'walk': {}, 'talk': {}}

    def write(name, acts, first):
        rig.animation_data.action = acts[first]
        me = bpy.data.meshes.new(f'mio_{name}stub'); me.from_pydata([(0, 0, 0), (.001, 0, 0), (0, .001, 0)], [], [(0, 1, 2)])
        stub = bpy.data.objects.new(f'mio_{name}stub', me); bpy.context.scene.collection.objects.link(stub)
        stub.parent = rig; vg = stub.vertex_groups.new(name='pelvis'); vg.add([0, 1, 2], 1.0, 'REPLACE')
        md = stub.modifiers.new('arm', 'ARMATURE'); md.object = rig
        bpy.ops.object.select_all(action='DESELECT')
        for o in (rig, stub): o.select_set(True)
        bpy.ops.export_scene.gltf(filepath=f'{OUT}/mio_{name}.glb', export_format='GLB', use_selection=True, export_apply=True,
                                  export_animations=True, export_animation_mode='ACTIONS', export_yup=True,
                                  export_force_sampling=True, export_def_bones=False)
        rig.animation_data.action = None
        for a in acts.values(): bpy.data.actions.remove(a)
        bpy.data.objects.remove(stub)

    acts = {}
    for name, (fn, loop, detrend) in W.CLIPS.items():
        act, dur = W.bake(rig, 'mio', name, walk[name], loop, k_size, info[name]['trend'] if detrend else None)
        acts[name] = act
        tr = info[name]['trend'] * k_size
        out['walk'][name] = {'anim': act.name, 'dur': dur, 'loop': loop, 'speed': info[name]['speed'] * k_size * W.SLOW, 'fwd': -tr.y, 'rise': tr.z}
        print('BAKED mio', name, 'dur %.2f' % dur, flush=True)
    write('walk', acts, 'walk')

    acts = {}
    for name, clip in talk.items():
        align = {}
        for b, ob in TK.ARMS.items():
            ours = (TK.rot_of(rig.matrix_world @ rig.data.bones[ob].matrix_local) @ Vector((0, 1, 0))).normalized()
            align[b] = ours.rotation_difference(clip['rest_dir'][b])
        act, dur = TK.bake(rig, name, clip, k_size, align)
        acts[name] = act
        out['talk'][name] = {'anim': act.name, 'dur': dur}
        print('BAKED mio', name, 'dur %.2f' % dur, flush=True)
    if acts: write('talk', acts, next(iter(acts)))
    json.dump(out, open(f'{OUT}/ch7.json', 'w'), indent=1)

    # her face's three pictures, where the four's are
    fd = f'{P.RULES}/assets/faces'; os.makedirs(fd, exist_ok=True)
    for st in ('open', 'closed', 'talk'):
        if not any(os.path.exists(f'{fd}/mio_{st}.{e}') for e in ('jpg', 'png')):
            src = f'{P.TRIPO}/mio_headtex_{st}.png'
            if os.path.exists(src): shutil.copy(src, f'{fd}/mio_{st}.png'); print('face', st)
    print('EXPORTED ch7')
