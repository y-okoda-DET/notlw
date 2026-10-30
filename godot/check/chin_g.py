import bpy, sys
sys.path.insert(0,'/home/claude/kf')
import lib
from mathutils import Vector
src, out, objname = sys.argv[-3], sys.argv[-2], sys.argv[-1]
if src.endswith('.glb'):
    bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=src)
    obs=[o for o in bpy.data.objects if o.type=='MESH']
else:
    bpy.ops.wm.open_mainfile(filepath=src)
    for o in list(bpy.data.objects):
        if o.type in ('CAMERA','LIGHT'): bpy.data.objects.remove(o)
    obs=[o for o in bpy.data.objects if o.type=='MESH' and objname in o.name]
    for o in bpy.data.objects:
        if o.type=='MESH' and o not in obs: o.hide_render=True
bpy.context.view_layer.update()
import os
if os.environ.get("GREY"):
    g=bpy.data.materials.new("g")
    for o in obs:
        o.data.materials.clear(); o.data.materials.append(g)
pts=[o.matrix_world@Vector(c) for o in obs for c in o.bound_box]
lo=Vector((min(p.x for p in pts),min(p.y for p in pts),min(p.z for p in pts))); hi=Vector((max(p.x for p in pts),max(p.y for p in pts),max(p.z for p in pts)))
if not src.endswith('.glb'): lo.z=hi.z-.3   # head only
c=(lo+hi)/2; d=max(hi-lo)*2.6
s=bpy.context.scene
if s.world is None: s.world=bpy.data.worlds.new('w')
s.world.use_nodes=True; s.world.node_tree.nodes['Background'].inputs[1].default_value=.8
s.view_settings.view_transform='Standard'
# find forward: glb from Tripo is Y-up converted; front is -Y in Blender
for nm,off in (('side',Vector((d,0,0))),('q',Vector((d*.6,-d*.8,0)))):
    lib.camera(tuple(c+off),tuple(c),lens=50); lib.render(f'{out}_{nm}.png',samples=8,res=(360,360))
