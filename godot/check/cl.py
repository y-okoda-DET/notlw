import sys, bpy
sys.path.insert(0,'/home/claude/kf')
import shot, chars as C, export_godot as E
from mathutils import Vector
shot.build(); tg=shot.S['t']
C.reset_pose(tg); n=E.axis_local(tg,(0,-1,0)); n.z=0; n.normalize()
a={s:C.bone_head(tg,f'upperarm_{s}').z for s in 'lr'}
for s_, sx_ in (('l', 1), ('r', -1)): C.rot_world(tg, f'clavicle_{s_}', n, -sx_ * 7)
print('CL', {s: round((C.bone_head(tg,f'upperarm_{s}').z-a[s])*100,2) for s in 'lr'})
