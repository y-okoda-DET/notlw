import sys; sys.path.insert(0,'/home/claude/kf')
import bpy, math, lib, chars as C
from mathutils import Vector
from lib import prim, mat_basic
lib.reset()
r,b=C.make_tripo('kiryu'); kl=lambda v: C.local(r,v)
C.arm_to(r,'r',kl((-.04,-.3,1.22)),Vector((-.3,.2,-.4))); C.arm_to(r,'l',kl((.2,-.02,.84)),Vector((.3,.3,0)))
ph=prim('cube','kphone',scale=(.034,.004,.072),mat=mat_basic('kph',(.08,.08,.09),.3))
bpy.context.view_layer.update()
hf=C.hand_frame(r,'r'); p=hf.translation.copy()
lib.area('key',(p.x-.6,p.y-1.0,p.z+.9),tuple(p),40,k=5000,size=(1.0,1.0))
lib.area('fill',(p.x+.8,p.y-.6,p.z+.3),tuple(p),15,k=5000,size=(1.0,1.0))
for i,(amt,off,rot) in enumerate(((.8,(0,.055,-.016),(90,0,0)),(.8,(0,.055,-.016),(90,0,0)),(.65,(0,.05,-.014),(90,10,0)),(.8,(.005,.06,-.02),(90,0,0)))):
    for f in C.FINGERS+('thumb',):
        for j in ('01','02','03'):
            pb=r.pose.bones.get(f'{f}_{j}_r'); pb.rotation_mode='XYZ'; pb.rotation_euler=(0,0,0)
    C.grip(r,'r',amt)
    C.place_in_hand(ph,r,'r',offset=off,rot=rot); bpy.context.view_layer.update()
    cams=[((p.x-.3,p.y-.5,p.z+.35)),((p.x+.1,p.y-.55,p.z+.1)),((p.x-.3,p.y-.5,p.z+.35)),((p.x-.45,p.y-.3,p.z-.1))]
    lib.camera(cams[i],(p.x,p.y-.03,p.z),lens=60); lib.render(f'/home/claude/tripo/grip_{i}.png',samples=12,res=(500,500))
