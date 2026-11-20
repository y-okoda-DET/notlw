# 組んだ人物（骨＋正座の形）を、形を焼き込んだ動かない GLB にする。python pose2glb.py -- <in.blend> <prefix> <out.glb>
import bpy, sys
sys.path.insert(0, '/home/user/notlw/blender'); sys.argv_ = sys.argv
a = sys.argv[sys.argv.index('--') + 1:]; src, pre, out = a
bpy.ops.wm.open_mainfile(filepath=src)
dg = bpy.context.evaluated_depsgraph_get(); keep = []
for o in list(bpy.data.objects):
    if not o.name.startswith(pre) or o.type not in ('MESH', 'CURVE'): continue
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    n = bpy.data.objects.new(o.name + '_posed', me); n.matrix_world = o.matrix_world.copy(); bpy.context.scene.collection.objects.link(n); keep.append(n)
for o in list(bpy.data.objects):
    if o not in keep: bpy.data.objects.remove(o)
for n in keep: n.name = n.name[:-6]
import export_godot as E   # 手続きの材質（聞き手の手の年相応の肌など）は色の画像に焼く（ゲームの書き出しと同じ）
for n in keep:
    if any(m is not None and not E.is_simple(m) for m in n.data.materials): print('BAKE', n.name); E.bake_object(n, 2048, normal=True)   # 手の肌のしわ・筋・血管の凹凸も（2026-11-19）
for im in bpy.data.images:
    if im.size[0] > 2048: im.scale(2048, int(im.size[1] * 2048 / im.size[0]))
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=False, export_apply=True, export_yup=True, export_image_format='AUTO')
print('OUT', out, [ (n.name, len(n.data.vertices)) for n in keep])
