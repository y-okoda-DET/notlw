import bpy, sys
sys.path.insert(0,'/home/claude/kf')
import lib
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='/home/claude/rules/assets/kiryu.glb')
rig=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
print('ACTIONS',[a.name for a in bpy.data.actions][:6], 'active', rig.animation_data.action.name if rig.animation_data and rig.animation_data.action else None)
for a in bpy.data.actions:
    if a.name.startswith('kiryu_rig'): rig.animation_data.action=a
bpy.context.scene.frame_set(48)
ph=[o for o in bpy.data.objects if o.name.startswith('kphone')]
print('PHONES',[(o.name,o.parent.name if o.parent else None,o.parent_bone, tuple(round(x,2) for x in o.matrix_world.translation)) for o in ph])
hb=rig.matrix_world@rig.pose.bones['hand_r'].head
print('HAND', tuple(round(x,2) for x in hb), 'head', tuple(round(x,2) for x in rig.matrix_world@rig.pose.bones['head'].head))
s=bpy.context.scene
if s.world is None: s.world=bpy.data.worlds.new('w')
s.world.use_nodes=True; s.world.node_tree.nodes['Background'].inputs[1].default_value=1
c=ph[0].matrix_world.translation
lib.camera(tuple(c+Vector((0,-.5,.1))),tuple(c),lens=50); lib.render('/home/claude/work/glbk_a.png',samples=4,res=(400,400))
lib.camera(tuple(c+Vector((-.5,0,.1))),tuple(c),lens=50); lib.render('/home/claude/work/glbk_b.png',samples=4,res=(400,400))
