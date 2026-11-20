# 証言の部屋の二人を「骨つき」の GLB にする（2026-11-20、インタビューを作り直すスレッド）。
# pose2glb.py は形を焼き込んだ動かない GLB だった（紙芝居の原因：人が動かない）。こちらは骨と肌のつながりを残し、
# 形（聞き手：seiza・pinch・stroke・write、澪：lap・fist）を1コマの動きとして入れる。ゲームの側（scripts/interview.gd）が
# 形と形の間をつなぎ、息・首・ペン・拳を骨に足す。
#   python3 rig2glb.py -- kikite <seiza.blend> <形の json の入ったフォルダ> <out.glb>
#   python3 rig2glb.py -- mio <mio_seiza.blend> - <out.glb>
# 形の json は dump.py（同じフォルダ）が各 blend から書く：python3 dump.py -- kikite_<形>.blend kikite kikite_<形>.json
import bpy, sys, json, math, os
from mathutils import Matrix, Vector
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..'))
a = sys.argv[sys.argv.index('--') + 1:]
KEY, SRC, FORMS_DIR, OUT = a
bpy.ops.wm.open_mainfile(filepath=SRC)
rig = bpy.data.objects[KEY + '_rig']
sc = bpy.context.scene

def key_pose(name, basis):
    """one action, one key, every bone: the form `name`"""
    act = bpy.data.actions.new(name)
    rig.animation_data_create()
    rig.animation_data.action = act
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.matrix_basis = Matrix(basis[pb.name])
        for p in ('location', 'rotation_quaternion', 'scale'): pb.keyframe_insert(p, frame=1)
    tr = rig.animation_data.nla_tracks.new(); tr.name = name
    st = tr.strips.new(name, 1, act); st.action_frame_end = 2
    rig.animation_data.action = None
    return act

FORMS = {}
if KEY == 'kikite':
    for f in ('seiza', 'pinch', 'stroke', 'write'):
        FORMS[f] = json.load(open(os.path.join(FORMS_DIR, f'kikite_{f}.json')))['bones']
    # the pencil lives only in the write form's file: bring it over (its place is where the writing hand holds it)
    wb = os.path.join(os.path.dirname(SRC), 'kikite_write.blend')
    with bpy.data.libraries.load(wb, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n.startswith('kikite_pencil')]
    for o in dst.objects: sc.collection.objects.link(o)
else:
    lap = {pb.name: [list(r) for r in pb.matrix_basis] for pb in rig.pose.bones}
    FORMS['lap'] = lap
    # fist: from her lap, every finger closes ~45° more at each joint, the thumb a little (証言の答えが嘘のとき、膝の上で握る)
    hm = bpy.data.objects[KEY + '_hands']
    import numpy as np
    bpy.context.view_layer.update()
    P = np.array([tuple(hm.matrix_world @ v.co) for v in hm.data.vertices])
    def tip(b): bpy.context.view_layer.update(); return rig.matrix_world @ rig.pose.bones[b].tail
    def rot_world(bone, axis, deg):
        pb = rig.pose.bones[bone]; bpy.context.view_layer.update()
        M = rig.matrix_world @ pb.matrix; h = M.translation
        R = Matrix.Rotation(math.radians(deg), 4, Vector(axis))
        pb.matrix = rig.matrix_world.inverted() @ (Matrix.Translation(h) @ R @ Matrix.Translation(-h) @ M); pb.scale = (1, 1, 1)
        bpy.context.view_layer.update()
    for s in ('l', 'r'):
        for fg in ('index', 'middle', 'ring', 'pinky', 'thumb'):
            k = 45.0 if fg != 'thumb' else 22.0
            for j in ('01', '02', '03'):
                if fg == 'thumb' and j == '01': continue
                b = f'{fg}_{j}_{s}'
                pb = rig.pose.bones[b]; M = rig.matrix_world @ pb.matrix
                # the bend axis: the bone's own x (the game_engine rig bends fingers about local x); the sign that brings
                # the finger tip toward the wrist's palm side is taken by trying both
                wrist = rig.matrix_world @ rig.pose.bones[f'hand_{s}'].head
                best = None
                for lv in (Vector((1, 0, 0)), Vector((0, 0, 1))):
                    ax = (M.to_3x3() @ lv).normalized()
                    for sg in (1, -1):
                        keep = pb.matrix.copy()
                        rot_world(b, ax, sg * k); d = (tip(f'{fg}_03_{s}') - wrist).length
                        pb.matrix = keep; bpy.context.view_layer.update()
                        if best is None or d < best[0]: best = (d, sg, ax)
                rot_world(b, best[2], best[1] * k)
    FORMS['fist'] = {pb.name: [list(r) for r in pb.matrix_basis] for pb in rig.pose.bones}
    for pb in rig.pose.bones: pb.matrix_basis = Matrix(lap[pb.name])

# the meshes: in the rest pose, the hands' smoothing applied (the game smooths nothing), the glasses' curves made mesh
rig.data.pose_position = 'REST'; bpy.context.view_layer.update()
for o in list(bpy.data.objects):
    if o.type == 'CURVE' and o.name.startswith(KEY):
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
        bpy.ops.object.convert(target='MESH')
for o in list(bpy.data.objects):
    if o.type != 'MESH' or not o.name.startswith(KEY): continue
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        if m.type == 'CORRECTIVE_SMOOTH': o.modifiers.remove(m)
    for m in list(o.modifiers):
        if m.type == 'SUBSURF':
            m.levels = min(m.levels, 1)
            bpy.ops.object.modifier_move_to_index(modifier=m.name, index=0)
            bpy.ops.object.modifier_apply(modifier=m.name)
import export_godot as E
for o in list(bpy.data.objects):
    if o.type == 'MESH' and o.name.startswith(KEY) and any(m is not None and not E.is_simple(m) for m in o.data.materials):
        print('BAKE', o.name); E.bake_object(o, 2048, normal=True)
for im in bpy.data.images:
    if im.size[0] > 2048: im.scale(2048, int(im.size[1] * 2048 / im.size[0]))
rig.data.pose_position = 'POSE'
for o in list(bpy.data.objects):
    if not o.name.startswith(KEY): bpy.data.objects.remove(o)
for n, b in FORMS.items(): key_pose(n, b)
for pb in rig.pose.bones: pb.matrix_basis = Matrix(FORMS['seiza' if KEY == 'kikite' else 'lap'][pb.name])
bpy.context.view_layer.update()
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=False, export_apply=False, export_yup=True,
    export_image_format='AUTO', export_animations=True, export_animation_mode='NLA_TRACKS', export_skins=True,
    export_def_bones=False, export_optimize_animation_size=False, export_force_sampling=True)
print('OUT', OUT, list(FORMS))
