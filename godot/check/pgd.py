import sys, bpy, math
sys.path.insert(0,'/home/claude/kf')
import shot, chars as C, export_godot as E, lib
from mathutils import Vector
shot.build(); S=shot.S; k=S['k']; kl=lambda v: C.local(k, v)
C._GRIP.clear(); C.reset_pose(k); C.rot_world(k, 'neck_01', E.axis_local(k, (1, 0, 0)), 18)
face = C.bone_head(k,'head') + C.local(k,(0,-.08,.05)) - C.local(k,(0,0,0))
ph=S['kphone']; ph.parent=None
g=C.phone_grip3(k, 'r', ph, face, kl((-.02,-.3,1.22)), Vector((-.3,.3,-.5)))
o,ex,ey,ez=C._palm_frame(k,'r'); M=ph.matrix_world; c=M.translation; n=-(M.to_3x3().col[1]).normalized()
print('CHK screen toward face', round(n.dot((face-c).normalized()),2), ' screen = palm side', round(n.dot(ez),2))
from bpy_extras.object_utils import world_to_camera_view as w2c
import json
for ob in k.children_recursive:
    if ob.type=='MESH':
        for m in ob.data.materials:
            nt=m.node_tree; em=nt.nodes.new('ShaderNodeEmission'); em.inputs[0].default_value=(.9,.6,.5,1); nt.links.new(em.outputs[0], nt.nodes['Material Output'].inputs[0])
bpy.context.scene.view_settings.view_transform='Standard'
for ob in bpy.data.objects:
    if ob.name.startswith('kphone'): ob.hide_render=True
M=ph.matrix_world; c=M.translation; n=-(M.to_3x3().col[1]).normalized()
corn=[M@Vector((sx,0,sz)) for sx,sz in ((-1,-1),(1,-1),(1,1),(-1,1))]   # unit cube scaled
top=M@Vector((0,0,1))
pts={'corners':corn,'top':[top]}
for f in C.FINGERS+('thumb',):
    pts[f]=[C.bone_head(k,f'{f}_01_r')]+[C.bone_tail(k,f'{f}_0{j}_r') for j in (1,2,3)]
out={}
for nm,p in (('screen',c+n*.4),('back',c-n*.4),('eye',C.bone_head(k,'head')+Vector((0,0,.08)))):
    cam=lib.camera(tuple(p),tuple(c),lens=45); lib.render(f'/home/claude/work/pgd_{nm}.png',samples=4,res=(500,500))
    camo=bpy.context.scene.camera
    out[nm]={key:[tuple(w2c(bpy.context.scene,camo,q))[:3] for q in v] for key,v in pts.items()}
json.dump(out,open('/home/claude/work/pgd.json','w'))
