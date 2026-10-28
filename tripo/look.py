import bpy, sys, math
sys.path.insert(0,'/home/claude/kf')
import lib
from mathutils import Vector
f=sys.argv[sys.argv.index('--')+1]; tag=sys.argv[sys.argv.index('--')+2]
lib.reset()
bpy.ops.import_scene.gltf(filepath=f)
o=[o for o in bpy.data.objects if o.type=='MESH'][0]
lib.area('key',(-1.2,-2.2,1.8),(0,0,.5),220,k=5000,size=(1.5,1.5)); lib.area('fill',(1.5,-1.5,1),(0,0,.5),90,k=5000,size=(2,2)); lib.area('back',(0,2.5,1.5),(0,0,.5),120,k=5000,size=(2,2))
w=bpy.context.scene.world; w.node_tree.nodes['Background'].inputs[1].default_value=.3
for i,(name,ang) in enumerate([('front',0),('left',90),('back',180),('right',-90),('q',35)]):
    a=math.radians(ang); d=2.6
    lib.camera((math.sin(a)*-d*0+ -math.sin(a)*d*0 + d*math.sin(a), -d*math.cos(a), .55),(0,0,.5),lens=55)
    lib.render(f'/home/claude/tripo/{tag}_{name}.png',samples=16,res=(500,700))
