import bpy, sys, math
sys.path.insert(0,'/home/claude/kf')
import lib
bpy.ops.wm.open_mainfile(filepath='/home/claude/tripo/natsuki_s_prep.blend')
s=bpy.context.scene
for o in list(bpy.data.objects):
    if o.type in ('CAMERA','LIGHT'): bpy.data.objects.remove(o)
if s.world is None: s.world=bpy.data.worlds.new('w')
s.world.use_nodes=True; s.world.node_tree.nodes['Background'].inputs[1].default_value=.25
s.view_settings.view_transform='AgX'
lib.area('key',(-1.2,-2.2,2.2),(0,0,1.30),260,k=5000,size=(1.5,1.5)); lib.area('fill',(1.5,-1.5,1.5),(0,0,1.30),90,k=5000,size=(2,2)); lib.area('back',(0,2.5,2),(0,0,1.30),120,k=5000,size=(2,2))
for name,(ang,z,tz,lens) in {'front':(0,1.45,1.40,60),'q':(35,1.45,1.40,60),'feet':(30,.35,.12,60)}.items():
    a=math.radians(ang)
    lib.camera((1.1*math.sin(a),-1.1*math.cos(a),z),(0,0,tz),lens=lens)
    lib.render(f'/home/claude/tripo/ps_{name}.png',samples=16,res=(500,600))
lib.camera((0,-4.2,.85),(0,0,.8),lens=45)
lib.render('/home/claude/tripo/ps_full.png',samples=16,res=(500,900))
