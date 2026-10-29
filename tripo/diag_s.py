import bpy, sys, math
sys.path.insert(0,'/home/claude/kf')
import lib
bpy.ops.wm.open_mainfile(filepath='/home/claude/tripo/natsuki_s_prep.blend')
s=bpy.context.scene
if s.world is None: s.world=bpy.data.worlds.new('w')
s.world.use_nodes=True; s.world.node_tree.nodes['Background'].inputs[1].default_value=.25
lib.area('key',(-1.2,-2.2,2.2),(0,0,1.45),260,k=5000,size=(1.5,1.5)); lib.area('fill',(1.5,-1.5,1.5),(0,0,1.45),90,k=5000,size=(2,2))
H=bpy.data.objects['natsuki_s_hair']; F=bpy.data.objects['natsuki_s_head']; B=bpy.data.objects['natsuki_s_body']
hz=1.32
for n,(hh,hf,hb) in {'all':(0,0,0),'noface':(0,1,0),'nohair':(1,0,0),'nobody':(0,0,1)}.items():
    H.hide_render=bool(hh); F.hide_render=bool(hf); B.hide_render=bool(hb)
    lib.camera((.3,-.55,hz+.05),(0,0,hz-.02),lens=70); lib.render(f'/home/claude/tripo/dgs_{n}.png',samples=12,res=(500,500))
