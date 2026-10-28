import sys; sys.path.insert(0,'/home/claude/kf')
import bpy, math, lib, chars as C
from mathutils import Vector
lib.reset()
R={}
for k,x in (('kiryu',-.5),('taiga',.5)):
    r,b=C.make_tripo(k); r.location.x=x; R[k]=r
bpy.context.view_layer.update()
lib.area('key',(-1.2,-2.6,2.4),(0,0,1.0),400,k=5000,size=(1.5,1.5)); lib.area('fill',(1.5,-1.5,1.5),(0,0,1.0),120,k=5000,size=(2,2))
lib.camera((0,-4.6,1.0),(0,0,.95),lens=40); lib.render('/home/claude/tripo/kt_rest.png',samples=12,res=(800,700))
for k,r in R.items():
    C.arm_to(r,'l',C.local(r,(.12,-.33,1.5)),Vector((.25,.2,-.4))); C.arm_to(r,'r',C.local(r,(-.05,-.3,1.1)),Vector((-.3,.2,-.4)))
    C.rot_world(r,'head',(0,0,1),25); C.rot_world(r,'neck_01',(1,0,0),12)
bpy.context.view_layer.update()
lib.camera((-1.8,-3.4,1.4),(0,0,1.05),lens=40); lib.render('/home/claude/tripo/kt_pose.png',samples=12,res=(800,700))
