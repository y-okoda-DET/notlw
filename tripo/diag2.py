import bpy, sys
sys.path.insert(0,'/home/claude/kf')
import lib
bpy.ops.wm.open_mainfile(filepath='/home/claude/tripo/makoto_prep.blend')
s=bpy.context.scene
if s.world is None: s.world=bpy.data.worlds.new('w')
s.world.use_nodes=True; s.world.node_tree.nodes['Background'].inputs[1].default_value=.25
lib.area('key',(-1.2,-2.2,2.2),(0,0,1.45),260,k=5000,size=(1.5,1.5)); lib.area('fill',(1.5,-1.5,1.5),(0,0,1.45),90,k=5000,size=(2,2)); lib.area('side',(2,0,1.6),(0,0,1.4),200,k=5000,size=(1.5,1.5))
H=bpy.data.objects['makoto_hair']; F=bpy.data.objects['makoto_head']; B=bpy.data.objects['makoto_body']
hz=1.32; B.hide_render=True
for n,(hh,hf) in {'f_side':(1,0),'h_side':(0,1),'f_front':(1,0)}.items():
    H.hide_render=bool(hh); F.hide_render=bool(hf)
    if 'side' in n: lib.camera((.7,-.05,hz+.03),(0,0,hz-.02),lens=70)
    else: lib.camera((0,-.6,hz+.03),(0,0,hz-.02),lens=70)
    lib.render(f'/home/claude/tripo/dg2_{n}.png',samples=12,res=(500,500))
