import sys; sys.path.insert(0,'/home/claude/kf')
import lib, bpy, math
lib.reset()
xs={'mio':-0.6,'natsuki':-0.2,'kiryu':0.2,'taiga':0.6}
for k,x in xs.items():
    h=lib.bust(k); h.location=(x,0,0); h.rotation_euler=(0,0,math.radians(-25))
lib.area('key',(-1.2,-1.6,.6),(0,0,.1),60,k=4300,size=(.8,.8))
lib.area('rim',(1.2,1.2,.8),(0,0,.1),40,k=6500,size=(.5,.5))
c=lib.camera((0,-2.6,.15),(0,0,.12),lens=55)
lib.render('/home/claude/kf/out/t_head.png',samples=32,res=(1280,540))
