"""試作297（赤字 #15「ここの夏希、もういっそのことがっつりゾンビみたいに歩かせるってのはどう？前に手をダランと垂らすのはやりすぎ？
mixamoにモーションありそう」）: 第4章の階段の下から来る夏希の歩きを、ユーザーが落とした Mixamo の Not So Scary Zombie Pack
（段階2/mixamo/zombie_pack/、git には入れない）の歩きにする。

export_walk.py と同じ移し方（Mixamo の休みの形からの、骨ごとの世界の回りの変わりを、こちらの骨の休みの形に乗せる）だが、腕・首・頭も
Mixamo から取る（ふつうの歩きは腕と頭がこちらの物：スマホを持つ形）。前へ進むぶんは抜いて、Godot が道に沿って動かす。

  zwalk  … walking.fbx      腕をだらりと前に垂らした、足を引きずる歩き
  zwalk2 … walking (2).fbx  両腕を前に上げた、昔の映画のゾンビの歩き

Out: assets/dusk/natsuki_zwalk.glb（natsuki の骨と、動き2つ）と zwalk.json（1秒に進むメートル、Mixamo の大きさをこちらに直した物）
Run: python3 export_zwalk.py (MIXAMO_Z=<zombie_pack のフォルダ>)"""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P
import bpy
import export_walk as W
import export_t20 as T
import export_godot as E
import chars as C

SRC = os.environ.get('MIXAMO_Z', '/mnt/project-files/段階2/mixamo/zombie_pack')
OUT = f'{P.RULES}/assets/dusk'
CLIPS = {'zwalk': 'walking.fbx', 'zwalk2': 'walking (2).fbx'}
W.MAP.update({'Neck': 'neck_01', 'Head': 'head',
              'LeftShoulder': 'clavicle_l', 'LeftArm': 'upperarm_l', 'LeftForeArm': 'lowerarm_l', 'LeftHand': 'hand_l',
              'RightShoulder': 'clavicle_r', 'RightArm': 'upperarm_r', 'RightForeArm': 'lowerarm_r', 'RightHand': 'hand_r'})
W.SLOW = 1.0
T.pose = lambda key, rig, t: None   # the arms and the head are the clip's (no phone: its battery went hours ago)

if __name__ == '__main__':
    if not all(os.path.exists(f'{SRC}/{f}') for f in CLIPS.values()):
        print('ZWALK: no zombie pack in', SRC, '(skipped)'); sys.exit(0)
    clips = {k: W.read_clip(f'{SRC}/{f}') for k, f in CLIPS.items()}
    rigs = T.build()
    for o in bpy.data.objects:
        if o.type == 'MESH':
            for md in o.modifiers: md.show_viewport = False
    rig = rigs['natsuki']; key = 'natsuki'
    hip_h = (rig.matrix_world @ rig.data.bones['pelvis'].head_local).z
    out = {}; acts = {}
    for name, c in clips.items():
        n = len(c['frames']) - 1; dur0 = n / c['fps']
        tr = c['frames'][-1]['hip'] - c['frames'][0]['hip']
        k_size = hip_h / c['hip0'].z
        act, dur = W.bake(rig, key, name, c, True, k_size, tr)
        acts[name] = act
        out[name] = {'anim': act.name, 'dur': dur, 'speed': -tr.y / dur0 * k_size}
        print('ZWALK', name, out[name])
    rig.animation_data.action = acts['zwalk']
    me = bpy.data.meshes.new('natsuki_zwalkstub'); me.from_pydata([(0, 0, 0), (.001, 0, 0), (0, .001, 0)], [], [(0, 1, 2)])
    stub = bpy.data.objects.new('natsuki_zwalkstub', me); bpy.context.scene.collection.objects.link(stub)
    stub.parent = rig; vg = stub.vertex_groups.new(name='pelvis'); vg.add([0, 1, 2], 1.0, 'REPLACE')
    md = stub.modifiers.new('arm', 'ARMATURE'); md.object = rig
    bpy.ops.object.select_all(action='DESELECT')
    for o in (rig, stub): o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=f'{OUT}/natsuki_zwalk.glb', export_format='GLB', use_selection=True, export_apply=True,
                              export_animations=True, export_animation_mode='ACTIONS', export_yup=True,
                              export_force_sampling=True, export_def_bones=False)
    json.dump(out, open(f'{OUT}/zwalk.json', 'w'), indent=1)
    print('EXPORTED zwalk')
