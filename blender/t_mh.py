import sys; sys.path.insert(0,'/home/claude/kf')
import bpy, math, lib, door as D, chars as C
from mathutils import Vector
lib.reset(); M = D.mats()
r1, b1 = C.make('natsuki', M['knit'], M['denim'], M['sock'], skin=(.78,.58,.47), loose=1.6)
r1.location = (-.4, 0, 0)
r2, b2 = C.make('kiryu', M['plaid'], M['olive'], M['sockd'], skin=(.76,.57,.45))
r2.location = (.4, 0, 0)
bpy.context.view_layer.update()
for r in (r1, r2): C.relax_arms(r)
lib.area('k',(-1.5,-2,2),(0,0,1),300,k=4500,size=(1,1)); lib.area('f',(1.5,-2,1),(0,0,1),120,k=6000,size=(1,1))
lib.camera((0,-3.6,1.1),(0,0,.95),lens=50)
lib.render('/home/claude/kf/out/t_mh.png',samples=16,res=(900,700))
