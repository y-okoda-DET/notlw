import sys; sys.path.insert(0,'/home/claude/kf')
import bpy, math, lib, door as D, chars as C
from mathutils import Vector
lib.reset(); M=D.mats()
specs=[('natsuki',M['knit'],M['denim'],M['sock'],-.6),('kiryu',M['plaid'],M['olive'],M['sockd'],.1),('taiga',M['tee'],M['track'],M['sockd'],.85)]
for k,t,p,s,x in specs:
    r,b=C.make(k,t,p,s,sleeve='short' if k=='taiga' else 'long'); r.location=(x,0,0); r.rotation_euler.z=math.radians(-20 if x<0 else 15)
    bpy.context.view_layer.update(); C.relax_arms(r)
lib.area('key',(-1.5,-2.5,2.2),(0,0,1.2),500,k=4300,size=(1.2,1.2)); lib.area('rim',(1.8,1.5,2),(0,0,1.2),250,k=6500,size=(.8,.8)); lib.area('fill',(0,-3,1),(0,0,1.2),80,k=5000,size=(2,2))
lib.camera((0,-4.3,1.25),(0,0,1.0),lens=40)
lib.render('/home/claude/kf/out/t_drawn2.png',samples=24,res=(1600,1000))
lib.camera((0,-1.3,1.5),(.1,0,1.45),lens=50)
lib.render('/home/claude/kf/out/t_drawn2_close.png',samples=24,res=(1000,800))
