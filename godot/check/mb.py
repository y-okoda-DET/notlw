import sys, bpy, math, json
sys.path.insert(0,'/home/claude/kf')
import export_dusk as X, chars as C, lib
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view as w2c
X.build(); S=X.S; m=S['m']; rf=S['rf']
C.reset_pose(m); X.pose_makoto(m, 1.0); bpy.context.view_layer.update()
# penetration: skin verts inside the board slab
body=[o for o in m.children_recursive if o.name.endswith('_body')][0]
me=body.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
Mi=rf.matrix_world.inverted(); ins=0; BY={}
for v in me.vertices:
    q=Mi@(body.matrix_world@v.co)
    if abs(q.x)<1 and abs(q.z)<1 and abs(q.y)<1:
        ins+=1; g=max(v.groups,key=lambda g:g.weight) if v.groups else None
        nm=body.vertex_groups[g.group].name if g else '?'; BY[nm]=BY.get(nm,0)+1
print('MB skin verts inside the board', ins, sorted(BY.items(),key=lambda x:-x[1])[:8])
for s in 'lr':
    sh=C.bone_head(m,f'upperarm_{s}'); el=C.bone_head(m,f'lowerarm_{s}'); w=C.bone_head(m,f'hand_{s}')
    a=(sh-el).angle(w-el); print('MB', s, 'elbow angle', round(math.degrees(a)), 'elbow below shoulder', round((sh.z-el.z)*100), 'cm', 'wrist z', round(w.z,2))
keep=set(o.name for o in m.children_recursive)|{m.name,'reflector'}
for o in bpy.data.objects:
    if o.type in ('MESH','CURVE') and o.name not in keep: o.hide_render=True
    if o.type=='LIGHT': o.hide_render=True
for ob in list(m.children_recursive)+[rf]:
    if ob.type=='MESH':
        for mt in ob.data.materials:
            nt=mt.node_tree; em=nt.nodes.new('ShaderNodeEmission'); em.inputs[0].default_value=((.9,.6,.5,1) if ob!=rf else (.3,.5,.9,1)); nt.links.new(em.outputs[0], nt.nodes['Material Output'].inputs[0])
bpy.context.scene.view_settings.view_transform='Standard'
c=rf.matrix_world.translation; f=-(rf.matrix_world.to_3x3().col[1]).normalized(); fh=Vector((f.x,f.y,0)).normalized(); sd=fh.cross(Vector((0,0,1)))
R=rf.matrix_world.to_3x3().normalized(); bx=R@Vector((1,0,0)); ub=R@Vector((0,0,1))
hr=C.bone_head(m,'hand_r')+ub*.05; hl=C.bone_head(m,'hand_l')+ub*.05
views=(('r_out',hr-bx*.4+f*.05,hr),('r_front',hr+f*.4-bx*.05,hr),('r_her',hr-f*.4+Vector((0,0,.1)),hr),('l_out',hl+bx*.4+f*.05,hl),('l_front',hl+f*.4,hl),('l_her',hl-f*.4+Vector((0,0,.1)),hl))
views2=(('front',c+fh*1.6+Vector((0,0,.2))),('side',c+sd*1.6+Vector((0,0,.1))),('eye',C.bone_head(m,'head')+Vector((0,0,.08))-fh*.05),('back3q',c-fh*1.3+sd*.7+Vector((0,0,.5))))
for nm,p,tg_ in views:
    lib.camera(tuple(p),tuple(tg_),lens=35); lib.render(f'/home/claude/kf/mb_{nm}.png',samples=4,res=(400,400))
