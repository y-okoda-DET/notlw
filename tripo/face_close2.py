import bpy, sys, math
sys.path.insert(0,'/home/claude/kf')
import lib
bpy.ops.wm.open_mainfile(filepath='/home/claude/tripo/natsuki_prep.blend')
s=bpy.context.scene
if s.world is None: s.world=bpy.data.worlds.new('w')
s.world.use_nodes=True; s.world.node_tree.nodes['Background'].inputs[1].default_value=.25
s.view_settings.view_transform='AgX'
lib.area('key',(-1.2,-2.2,2.2),(0,0,1.45),260,k=5000,size=(1.5,1.5)); lib.area('fill',(1.5,-1.5,1.5),(0,0,1.45),90,k=5000,size=(2,2))
bpy.data.objects['natsuki_head'].hide_render=True
for n,a in (('h',0),):
    a=math.radians(a)
    lib.camera((.55*math.sin(a),-.55*math.cos(a),1.45),(0,0,1.44),lens=70)
    lib.render(f'/home/claude/tripo/fc_{n}.png',samples=16,res=(500,500))
