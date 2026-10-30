import sys, bpy, math
sys.path.insert(0,'/home/claude/kf')
import export_dusk as X, chars as C, lib
from mathutils import Vector
X.build(); S=X.S; n=S['n']
C.reset_pose(n); X.pose_natsuki(n, 8.3); bpy.context.view_layer.update()
sh,el,w=[C.bone_head(n,b) for b in ('upperarm_l','lowerarm_l','hand_l')]
print('NA elbow angle', round(math.degrees((sh-el).angle(w-el))), 'elbow out of body (cm)', round((el-C.bone_head(n,'spine_02')).dot(X.E.axis_local(n,(1,0,0)))*100))
keep=set(o.name for o in n.children_recursive)|{n.name}
for o in bpy.data.objects:
    if o.type in ('MESH','CURVE') and o.name not in keep: o.hide_render=True
lv=X.E.axis_local(n,(1,0,0)); fw=X.E.axis_local(n,(0,-1,0))
nk=C.bone_head(n,'neck_01')
for nm,p in (('game',Vector((0.71,3.28,1.55))),('game2',Vector((0.6,3.4,1.45)))):
    lib.camera(tuple(p),tuple(nk),lens=50); lib.render(f'/home/claude/kf/na_{nm}.png',samples=8,res=(400,400))
