import sys, bpy, math
sys.path.insert(0,'/home/claude/kf')
import shot, chars as C, export_godot as E, lib, hall as Hm
from mathutils import Vector
shot.build(); S=shot.S; tg=S['t']
def setup(D, lean):
    tg.location.y = Hm.YF - D; tg.rotation_euler.x = math.radians(lean); bpy.context.view_layer.update()
    C.reset_pose(tg); E.pose_taiga(tg, 8.0); bpy.context.view_layer.update()
    for s in 'lr':
        sh=C.bone_head(tg,f'upperarm_{s}'); w=C.bone_head(tg,f'hand_{s}')
        L=(C.bone_tail(tg,f'upperarm_{s}')-sh).length+(C.bone_tail(tg,f'lowerarm_{s}')-C.bone_head(tg,f'lowerarm_{s}')).length
        el=C.bone_head(tg,f'lowerarm_{s}')
        print('TD',D,lean,s,'reach',round((w-sh).length/L,2),'wrist z',round(w.z,2),'eye z',round(C.bone_head(tg,'head').z+.07,2),'elbow below wrist',round((w.z-el.z)*100),'cm', 'wrist y-door', round((w.y-Hm.YF)*100,1))
for D in (.85,.95,1.05):
    for lean in (14,18):
        setup(D,lean)
D=float(sys.argv[-2]); lean=float(sys.argv[-1]); setup(D,lean)
body=[o for o in tg.children_recursive if o.name.endswith('_body')][0]
me=body.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
print('TD max skin y past door (cm)', round((max((body.matrix_world@v.co).y for v in me.vertices)-Hm.YF)*100,1))
h=C.bone_head(tg,'spine_03'); x=tg.location.x
for nm,p in (('side',Vector((x-2.4,h.y,1.2))),('back',Vector((x+.3,h.y-2.6,1.5))),('q',Vector((x-1.1,h.y-1.5,1.5)))):
    lib.camera(tuple(p),(x,h.y+.1,1.15),lens=35); lib.render(f'/home/claude/kf/td_{nm}.png',samples=16,res=(500,600))
