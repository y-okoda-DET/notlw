import sys; sys.path.insert(0,'/home/claude/kf')
import bpy, math, lib, chars as C
from mathutils import Vector
lib.reset()
r,b=C.make_tripo('natsuki')
lib.area('key',(-1.2,-2.2,2.2),(0,0,1.0),300,k=5000,size=(1.5,1.5)); lib.area('fill',(1.5,-1.5,1.5),(0,0,1.0),100,k=5000,size=(2,2))
nl=lambda v: C.local(r,v)
C.arm_to(r,'l',nl((.04,-.24,1.0)),Vector((.3,.1,-.4))); C.arm_to(r,'r',nl((-.04,-.24,1.0)),Vector((-.3,.1,-.4)))
bpy.context.view_layer.update()
lib.camera((-.9,-1.6,1.3),(0,0,1.05),lens=50); lib.render(sys.argv[-1],samples=12,res=(600,700))
