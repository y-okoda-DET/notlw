import sys, bpy, math, json
sys.path.insert(0,'/home/claude/kf')
import shot, chars as C, export_godot as E, lib, hall as Hm
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view as w2c
shot.build(); S=shot.S; tg=S['t']
D=float(sys.argv[-2]); lean=float(sys.argv[-1])
tg.location.y = Hm.YF - D; tg.rotation_euler.x = math.radians(lean); bpy.context.view_layer.update()
C.reset_pose(tg); E.pose_taiga(tg, 8.0); bpy.context.view_layer.update()
print('TV up axis', [round(x,2) for x in tg.matrix_world.to_3x3().normalized().col[2]], 'head', [round(x,2) for x in C.bone_head(tg,'head')], 'pelvis', [round(x,2) for x in C.bone_head(tg,'pelvis')] if 'pelvis' in tg.pose.bones else '')
keep=set(o.name for o in tg.children_recursive)|{tg.name}
for o in bpy.data.objects:
    if o.type in ('MESH','CURVE') and o.name not in keep: o.hide_render=True
    if o.type=='LIGHT': o.hide_render=True
for ob in tg.children_recursive:
    if ob.type=='MESH':
        for m in ob.data.materials:
            nt=m.node_tree; em=nt.nodes.new('ShaderNodeEmission'); em.inputs[0].default_value=(.9,.6,.5,1); nt.links.new(em.outputs[0], nt.nodes['Material Output'].inputs[0])
bpy.context.scene.view_settings.view_transform='Standard'
bones=['upperarm','lowerarm','hand']
out={}
x=tg.location.x; yc=tg.location.y+.3
for nm,p in (('side',Vector((x-3.0,yc,1.0))),('back',Vector((x,yc-3.2,1.2)))):
    lib.camera(tuple(p),(x,yc,.95),lens=35); lib.render(f'/home/claude/work/tv_{nm}.png',samples=4,res=(450,600))
    cam=bpy.context.scene.camera
    out[nm]={s:[tuple(w2c(bpy.context.scene,cam,q))[:2] for q in [C.bone_head(tg,f'upperarm_{s}'),C.bone_head(tg,f'lowerarm_{s}'),C.bone_head(tg,f'hand_{s}'),C.bone_tail(tg,f'middle_03_{s}')]] for s in 'lr'}
    out[nm]['door']=[tuple(w2c(bpy.context.scene,cam,Vector((x,Hm.YF,z))))[:2] for z in (0,2.2)]
json.dump(out,open('/home/claude/work/tv.json','w'))
