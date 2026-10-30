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
for f in C.FINGERS+('thumb',):
    t=C.bone_tail(k,f'{f}_03_r'); print('CHK', f, 'tip height over screen (cm)', round(((t-c).dot(n)-ph.scale.y)*100,1))
# render: flat colours, 3 views: palm side (looking at the screen), back of the hand, from his eyes
for ob in k.children_recursive:
    if ob.type=='MESH':
        for m in ob.data.materials:
            nt=m.node_tree; em=nt.nodes.new('ShaderNodeEmission'); em.inputs[0].default_value=(.9,.6,.5,1); nt.links.new(em.outputs[0], nt.nodes['Material Output'].inputs[0])
scr=bpy.data.objects['kphone_scr']; nt=scr.data.materials[0].node_tree; em=nt.nodes.new('ShaderNodeEmission'); em.inputs[0].default_value=(.2,.4,1,1); nt.links.new(em.outputs[0], nt.nodes['Material Output'].inputs[0])
nt=ph.data.materials[0].node_tree; em=nt.nodes.new('ShaderNodeEmission'); em.inputs[0].default_value=(.1,.1,.1,1); nt.links.new(em.outputs[0], nt.nodes['Material Output'].inputs[0])
bpy.context.scene.view_settings.view_transform='Standard'
side=(M.to_3x3().col[0]).normalized()
for nm,p in (('screen',c+n*.4),('back',c-n*.4),('edge',c+side*.3+n*.12),('eye',C.bone_head(k,'head')+Vector((0,0,.08)))):
    lib.camera(tuple(p),tuple(c),lens=45); lib.render(f'/home/claude/work/pg_{nm}.png',samples=4,res=(400,400))
