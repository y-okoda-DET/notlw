import sys; sys.path.insert(0,'/home/claude/kf')
import bpy, math, lib, door as D, chars as C
lib.reset(); M=D.mats()
for i,k in enumerate(['natsuki','kiryu','taiga','mio','makoto']):
    h=lib.bust2(k); h.location=(-1.0+i*.5,0,0); h.rotation_euler=(0,0,math.radians(-28))
r,b=C.make('kiryu',M['plaid'],M['olive'],M['sockd'],skin=(.86,.68,.55)); r.location=(.0,.9,-1.25); C.relax_arms(r)
lib.area('key',(-1.4,-2.2,.9),(0,0,0),220,k=4300,size=(1.2,1.2)); lib.area('rim',(1.5,1.5,1.0),(0,0,0),120,k=6500,size=(.6,.6))
lib.camera((0,-3.1,.05),(0,0,-.05),lens=40)
lib.render('/home/claude/kf/out/t_drawn.png',samples=24,res=(1600,700))
