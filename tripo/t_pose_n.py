import sys; sys.path.insert(0,'/home/claude/kf')
import bpy, lib, chars as C
from mathutils import Vector
lib.reset(); r,b=C.make_tripo('natsuki'); nl=lambda v: C.local(r,v)
C.arm_to(r, 'l', nl((.05, -.17, .98)), Vector((.1, .3, -.5))); C.arm_to(r, 'r', nl((-.05, -.17, .98)), Vector((-.1, .3, -.5)))
bpy.context.view_layer.update()
lib.area('key',(-1.2,-2.2,2.2),(0,0,1.0),300,k=5000,size=(1.5,1.5))
lib.camera((-.8,-2.2,1.3),(0,0,1.0),lens=50); lib.render('/home/claude/tripo/n_hold.png',samples=12,res=(500,600))
