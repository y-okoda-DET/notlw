import bpy, sys
sys.path.insert(0,'/home/claude/kf')
import lib
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='/home/claude/rules/assets/dusk/natsuki.glb')
rig=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
bpy.context.scene.frame_set(200)
nk=rig.matrix_world@rig.pose.bones['neck_01'].head
print('GN neck', [round(x,2) for x in nk], [o.name for o in bpy.data.objects if o.type=='MESH'])
s=bpy.context.scene
if s.world is None: s.world=bpy.data.worlds.new('w')
s.world.use_nodes=True; s.world.node_tree.nodes['Background'].inputs[1].default_value=1
for nm,p in (('a',Vector((0.71,3.28,1.55))),('b',nk+Vector((.5,-.3,.1))),('c',nk+Vector((.3,.5,.1)))):
    lib.camera(tuple(p),tuple(nk),lens=50); lib.render(f'/home/claude/kf/gn_{nm}.png',samples=4,res=(400,400))
