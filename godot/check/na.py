import sys, bpy, math
sys.path.insert(0,'/home/claude/kf')
import export_dusk as X, chars as C, lib
from mathutils import Vector
X.build(); S=X.S; n=S['n']
C.reset_pose(n); X.pose_natsuki(n, 1.0); bpy.context.view_layer.update()
sh,el,w=[C.bone_head(n,b) for b in ('upperarm_l','lowerarm_l','hand_l')]
print('NA elbow angle', round(math.degrees((sh-el).angle(w-el))), 'elbow out of body (cm)', round((el-C.bone_head(n,'spine_02')).dot(X.E.axis_local(n,(1,0,0)))*100))
keep=set(o.name for o in n.children_recursive)|{n.name}
for o in bpy.data.objects:
    if o.type in ('MESH','CURVE') and o.name not in keep: o.hide_render=True
lv=X.E.axis_local(n,(1,0,0)); fw=X.E.axis_local(n,(0,-1,0))
for nm,p in (('top',el+fw*.5+lv*.25+Vector((0,0,.7))),('side',el+lv*.8+fw*.2+Vector((0,0,.1))),('back',el-fw*.7+lv*.4+Vector((0,0,.3)))):
    lib.camera(tuple(p),tuple(el),lens=40); lib.render(f'/home/claude/work/na_{nm}.png',samples=8,res=(400,400))
