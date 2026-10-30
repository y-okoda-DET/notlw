import bpy, sys
sys.path.insert(0,'/home/claude/kf')
import lib
bpy.ops.wm.open_mainfile(filepath='/home/claude/tripo/makoto_prep.blend')
s=bpy.context.scene
for o in list(bpy.data.objects):
    if o.type in ('CAMERA','LIGHT'): bpy.data.objects.remove(o)
print('OBJS',[o.name for o in bpy.data.objects])
for o in bpy.data.objects:
    if o.type=='MESH':
        for m in o.data.materials:
            nt=m.node_tree; em=nt.nodes.new('ShaderNodeEmission'); em.inputs[0].default_value=((.2,.4,1,1) if 'body' in o.name else (1,.3,.2,1)); nt.links.new(em.outputs[0], nt.nodes['Material Output'].inputs[0])
hz=1.33
lib.camera((.7,-.05,hz+.02),(0,0,hz-.02),lens=70); lib.render('/home/claude/tripo/v4h_side.png',samples=2,res=(450,450))
lib.camera((.45,.5,hz+.1),(0,0,hz-.02),lens=70); lib.render('/home/claude/tripo/v4h_back.png',samples=2,res=(450,450))
