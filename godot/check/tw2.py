import sys, bpy, math
sys.path.insert(0,'/home/claude/kf')
import shot, chars as C, export_godot as E
from mathutils import Vector
shot.build(); tg=shot.S['t']
C.reset_pose(tg); E.pose_taiga(tg, 9.9)
n=E.axis_local(tg,(0,-1,0)); n.z=0; n.normalize(); ax=E.axis_local(tg,(1,0,0)); ax.z=0; ax.normalize()
for s,sx in (('l',1),('r',-1)):
    w=C.bone_head(tg,f'hand_{s}').copy()
    for tilt in (.18,.5,1.0,2.0):
        up=(Vector((0,0,1))+ax*(sx*tilt)).normalized(); pz=n*C.palm_sign(tg,s)
        row=[]
        for a in (0,30,60,90,120):
            r=math.radians(a); C.arm_to(tg,s,w,Vector((sx*math.sin(r),.1,-math.cos(r)))); C.set_hand_frame(tg,s,up,pz); row.append(round(C.forearm_twist(tg,s)))
        print('TW2',s,tilt,row)
