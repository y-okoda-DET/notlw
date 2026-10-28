import sys; sys.path.insert(0,'/home/claude/kf')
import bpy, math, lib, chars as C
from mathutils import Vector
lib.reset()
r,b=C.make_tripo('natsuki')
bpy.context.view_layer.update()
lib.area('key',(-1.2,-2.2,2.2),(0,0,1.0),300,k=5000,size=(1.5,1.5)); lib.area('fill',(1.5,-1.5,1.5),(0,0,1.0),100,k=5000,size=(2,2))
lib.camera((0,-4.2,.85),(0,0,.8),lens=45); lib.render('/home/claude/tripo/r_rest.png',samples=12,res=(500,900))
# a pose like the game: hand raised to the glass, head turned
C.arm_to(r,'l',C.local(r,(.1,-.35,1.42)),Vector((.25,.2,-.4)))
C.arm_to(r,'r',C.local(r,(-.15,-.15,1.0)),Vector((-.3,.2,-.4)))
C.rot_world(r,'head',(0,0,1),25); C.rot_world(r,'neck_01',(1,0,0),10); C.rot_world(r,'spine_02',(1,0,0),-6)
bpy.context.view_layer.update()
lib.render('/home/claude/tripo/r_pose.png',samples=12,res=(500,900))
lib.camera((-1.6,-2.6,1.3),(0,0,1.0),lens=50); lib.render('/home/claude/tripo/r_pose_q.png',samples=12,res=(600,900))
