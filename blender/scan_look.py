"""Three preview renders of a scan glb: python3 scan_look.py <glb> <out prefix>  (writes <prefix>_0/1/2.png, 800x600)"""
import bpy, sys, math
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=sys.argv[1])
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.samples=8; w=bpy.data.worlds.new('w'); sc.world=w; w.use_nodes=True; w.node_tree.nodes['Background'].inputs[1].default_value=1.0
sc.render.resolution_x=800; sc.render.resolution_y=600
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); sc.collection.objects.link(cam); sc.camera=cam
for i,(p) in enumerate([(0,-.6,.4),(0,0,.8),(.5,.35,.25)]):
    cam.location=p; cam.rotation_euler=(Vector((0,0,.05))-Vector(p)).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=sys.argv[2]+f'_{i}.png'; bpy.ops.render.render(write_still=True)
