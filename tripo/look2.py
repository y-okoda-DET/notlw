import bpy, sys, math
sys.path.insert(0,'/home/claude/kf')
import lib
f,tag=sys.argv[sys.argv.index('--')+1:][:2]
lib.reset()
bpy.ops.import_scene.gltf(filepath=f)
o=[o for o in bpy.data.objects if o.type=='MESH'][0]
from mathutils import Vector
bb=[o.matrix_world@Vector(c) for c in o.bound_box]; mn=[min(v[i] for v in bb) for i in range(3)]; mx=[max(v[i] for v in bb) for i in range(3)]
print('BB',mn,mx,len(o.data.vertices))
h=mx[2]-mn[2]; cz=mn[2]+h*.5
lib.area('key',(-1.2,-2.2,2),(0,0,cz),220*h*h,k=5000,size=(1.5,1.5)); lib.area('fill',(1.5,1.5,1),(0,0,cz),120*h*h,k=5000,size=(2,2))
for name,ang in [('front',0),('left',90),('back',180),('right',-90)]:
    a=math.radians(ang); d=2.6*h
    lib.camera((d*math.sin(a),-d*math.cos(a),cz),(0,0,cz),lens=55)
    lib.render(f'/home/claude/tripo/{tag}_{name}.png',samples=12,res=(400,700))
for name,ang in [('hf',0),('hb',180),('hs',90)]:
    a=math.radians(ang); d=.9*h; hz=mn[2]+h*.9
    lib.camera((d*math.sin(a),-d*math.cos(a),hz),(0,0,hz),lens=80)
    lib.render(f'/home/claude/tripo/{tag}_{name}.png',samples=12,res=(400,400))
