"""第6章：警察官の体（godot/props/police_body.glb）から頭を切り、ユーザーの頭と帽子（police_head）を載せられる体にする
→ godot/props/police_body_nohead.glb。Run: python3.13 tripo/police_nohead.py"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'blender')); import paths as P
import bpy, bmesh
CUT = float(os.environ.get('CUT', '.868'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=f'{P.RULES}/props/police_body.glb')
o = [x for x in bpy.context.scene.objects if x.type == 'MESH'][0]
bpy.context.view_layer.objects.active = o; o.select_set(True); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bm = bmesh.new(); bm.from_mesh(o.data)
# the head and the neck above the collar: everything above the chin within 9 cm (model units .05) of the neck's axis
top = max(v.co.z for v in bm.verts)
kill = [v for v in bm.verts if v.co.z > CUT * top and (v.co.x ** 2 + v.co.y ** 2) ** .5 < .075 * top]
bmesh.ops.delete(bm, geom=kill, context='VERTS'); bm.to_mesh(o.data); bm.free()
print('NOHEAD cut', len(kill), 'top', round(top, 3))
bpy.ops.export_scene.gltf(filepath=f'{P.RULES}/props/police_body_nohead.glb', export_format='GLB', use_selection=False, export_image_format='JPEG', export_jpeg_quality=88, export_apply=True)
