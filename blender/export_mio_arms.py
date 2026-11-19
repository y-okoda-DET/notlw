"""2026-11-18 第6章（ユーザー「粗いところを直そう。パーフェクトに」）：澪の手と袖。箱と筒で作っていた手を、澪本人の体
（tripo/mio_prep.blend、make_tripo('mio')）の前腕と手に替える。骨は前腕・手・指だけ残す。

左右を別の glb にする（godot/props/mio_arm_l.glb, mio_arm_r.glb）。向きは ch6.gd の手の決まりに合わせてある：
原点＝手首、指先が -Z、手のひらが -Y、前腕（袖）が +Z（Blender では 指先 +Y、手のひら -Z）。
Run: python3.13 blender/export_mio_arms.py"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P
import bpy, bmesh
from mathutils import Vector, Matrix
import chars as C

OUT = f'{P.RULES}/props'
WHO = os.environ.get('WHO', 'mio')   # 第7章：WHO=yota で陽太の腕（props/yota_arm_l|r.glb）
KEEP = ('lowerarm', 'hand', 'thumb', 'index', 'middle', 'ring', 'pinky')
TEX = 2048

def run(side):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rig, body = C.make_tripo(WHO)
    for o in list(bpy.data.objects):
        if o not in (rig, body): bpy.data.objects.remove(o)
    bpy.context.view_layer.update()
    gi = {g.index: g.name for g in body.vertex_groups}
    mine = lambda n: n.endswith('_' + side) and n.startswith(KEEP)
    up = f'upperarm_{side}'
    # the forearm and the hand, and the lower third of the upper arm (so that the sleeve's open end is far up it)
    elbow = C.bone_head(rig, f'lowerarm_{side}'); sh = C.bone_head(rig, up); ud = (elbow - sh); ul = ud.length; ud.normalize()
    keep = set()
    for v in body.data.vertices:
        w = sum(g.weight for g in v.groups if mine(gi[g.group]))
        wu = sum(g.weight for g in v.groups if gi[g.group] == up)
        if w > .5: keep.add(v.index)
        elif w + wu > .5 and ((body.matrix_world @ v.co) - sh).dot(ud) > ul * .55: keep.add(v.index)
    bm = bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keep], context='VERTS')
    bm.to_mesh(body.data); bm.free()
    # what is left of the upper arm moves with the forearm (one piece from the elbow up: the elbow is out of the picture)
    lo = body.vertex_groups[f'lowerarm_{side}']
    for v in body.data.vertices:
        add = 0.0
        for g in list(v.groups):
            if not mine(gi[g.group]): add += g.weight; body.vertex_groups[g.group].remove([v.index])
        if add > 0: lo.add([v.index], add, 'ADD')
    for g in list(body.vertex_groups):
        if not mine(g.name): body.vertex_groups.remove(g)
    # the bones: the forearm is the root
    bpy.context.view_layer.objects.active = rig; bpy.ops.object.mode_set(mode='EDIT')
    for eb in list(rig.data.edit_bones):
        if not mine(eb.name): rig.data.edit_bones.remove(eb)
    bpy.ops.object.mode_set(mode='OBJECT')
    # ch6.gd's frame: the wrist at the origin, the fingers to +Y, the palm to -Z (Blender) = -Z and -Y in Godot
    bpy.context.view_layer.update()
    w = C.bone_head(rig, f'hand_{side}'); tip = C.bone_tail(rig, f'middle_03_{side}')
    y = (w - elbow).normalized()                       # along the forearm, to the hand
    palm = C.palm_dir(rig, side); z = -(palm - y * palm.dot(y)).normalized(); x = y.cross(z).normalized()
    R = Matrix((x, y, z)).to_4x4()                     # rows: world -> the hand's frame
    M = R @ Matrix.Translation(-w)
    rig.matrix_world = M @ rig.matrix_world
    bpy.context.view_layer.update()
    for img in bpy.data.images:
        if img.size[0] > TEX: img.scale(TEX, TEX * img.size[1] // img.size[0])
    rig.name = f'{WHO}_arm_{side}'; body.name = f'{WHO}_arm_{side}_mesh'
    print('ARM', side, 'verts', len(body.data.vertices), 'bones', len(rig.data.bones), 'forearm', round((w - elbow).length, 3),
          'hand', round((tip - w).length, 3), 'images', [(i.name, tuple(i.size)) for i in bpy.data.images])
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); body.select_set(True)
    bpy.ops.export_scene.gltf(filepath=f'{OUT}/{WHO}_arm_{side}.glb', export_format='GLB', use_selection=True, export_apply=False,
                              export_animations=False, export_yup=True, export_image_format='JPEG', export_jpeg_quality=90,
                              export_def_bones=False, export_skins=True)

for s in ('l', 'r'): run(s)
