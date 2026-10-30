import sys, bpy, math
sys.path.insert(0,'/home/claude/kf')
import shot, chars as C, export_godot as E
from mathutils import Vector
shot.build(); tg=shot.S['t']
orig=C.arm_hand
def spy(rig, side, wrist, y, z, sx, **kw):
    r=orig(rig, side, wrist, y, z, sx, **kw); print('TW', side, 'chosen drop', r[2], 'twist', round(r[0]), 'after settle', round(C.forearm_twist(rig, side))); return r
C.arm_hand=spy
C.reset_pose(tg); E.pose_taiga(tg, 9.9)
for s in 'lr':
    for a in (0,30,60,90,120,150):
        r=math.radians(a); sx=1 if s=='l' else -1
        C.arm_to(tg,s,C.bone_head(tg,f'hand_{s}'),Vector((sx*math.sin(r),.1,-math.cos(r))))
        print('TWP',s,a,round(C.forearm_twist(tg,s)))
