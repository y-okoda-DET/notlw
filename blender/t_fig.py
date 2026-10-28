import sys; sys.path.insert(0,'/home/claude/kf')
import lib, door as D, bpy, math
lib.reset(); M=D.mats()
hold = dict(lel=(.19, -.06, 1.13), lwr=(.08, -.2, 1.0), lha=(.03, -.23, .97), rel=(-.19, -.06, 1.13), rwr=(-.08, -.2, 1.0), rha=(-.03, -.23, .97))
lib.figure('natsuki', top=M['knit'], pants=M['denim'], feet=M['sock'], skin=(.78,.58,.47), female=True, s=.96, loc=(-.35,0,0), yaw=-10, pose=hold)
lib.figure('kiryu', top=M['plaid'], pants=M['olive'], feet=M['sockd'], skin=(.76,.57,.45), s=1.04, loc=(.35,0,0), yaw=10)
lib.area('k',(-1.5,-2,2),(0,0,1),300,k=4500,size=(1,1)); lib.area('f',(1.5,-2,1),(0,0,1),120,k=6000,size=(1,1))
lib.camera((0,-3.4,1.1),(0,0,.95),lens=50)
lib.render('/home/claude/kf/out/t_fig.png',samples=16,res=(900,700))
