import bpy, sys
sys.path.insert(0,'/home/claude/kf')
import lib
bpy.ops.wm.open_mainfile(filepath='/home/claude/tripo/kiryu_prep.blend')
s=bpy.context.scene
if s.world is None: s.world=bpy.data.worlds.new('w')
s.world.use_nodes=True; s.world.node_tree.nodes['Background'].inputs[1].default_value=.25
lib.area('key',(-1.2,-2.2,2.2),(0,0,1.45),260,k=5000,size=(1.5,1.5)); lib.area('fill',(1.5,-1.5,1.5),(0,0,1.45),90,k=5000,size=(2,2))
H=bpy.data.objects['kiryu_hair']; F=bpy.data.objects['kiryu_head']
hz=1.60
for n,(hh,hf) in {'both':(0,0),'noF':(0,1),'noB':(1,0)}.items():
    H.hide_render=bool(hh); F.hide_render=bool(hf)
    lib.camera((.32,-.32,hz-.14),(.02,-.06,hz-.07),lens=110)
    lib.render(f'/home/claude/tripo/jaw2_{n}.png',samples=16,res=(500,500))
