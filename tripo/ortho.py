import bpy, sys, math
sys.path.insert(0,'/home/claude/kf')
import lib
from mathutils import Vector
f,tag,cz,sc=sys.argv[sys.argv.index('--')+1:][:4]; cz=float(cz); sc=float(sc)
lib.reset()
bpy.ops.import_scene.gltf(filepath=f)
o=[o for o in bpy.data.objects if o.type=='MESH'][0]
for m in o.data.materials:
    nt=m.node_tree; N=nt.nodes
    tex=[n for n in N if n.type=='TEX_IMAGE']
    bsdf=[n for n in N if n.type=='BSDF_PRINCIPLED'][0]
    src=bsdf.inputs['Base Color'].links[0].from_node if bsdf.inputs['Base Color'].links else None
    em=N.new('ShaderNodeEmission'); nt.links.new(src.outputs[0], em.inputs[0])
    nt.links.new(em.outputs[0], N['Material Output'].inputs[0])
    print('basecolor tex', src.image.name if src and src.type=='TEX_IMAGE' else src)
s=bpy.context.scene; s.view_settings.view_transform='Standard'
cam=lib.camera((0,-3,cz),(0,0,cz)); cam.data.type='ORTHO'; cam.data.ortho_scale=sc
lib.render(f'/home/claude/tripo/{tag}_ortho.png',samples=4,res=(1024,1024))
