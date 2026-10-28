import bpy, sys, math
sys.path.insert(0,'/home/claude/kf')
import lib
f,tag,cz,sc,rot=sys.argv[sys.argv.index('--')+1:][:5]; cz=float(cz); sc=float(sc); rot=float(rot)
lib.reset()
bpy.ops.import_scene.gltf(filepath=f)
o=[o for o in bpy.data.objects if o.type=='MESH'][0]
o.rotation_euler.z+=math.radians(rot)
for m in o.data.materials:
    nt=m.node_tree; N=nt.nodes
    bsdf=[n for n in N if n.type=='BSDF_PRINCIPLED'][0]
    src=bsdf.inputs['Base Color'].links[0].from_node
    em=N.new('ShaderNodeEmission'); nt.links.new(src.outputs[0], em.inputs[0])
    nt.links.new(em.outputs[0], N['Material Output'].inputs[0])
s=bpy.context.scene; s.view_settings.view_transform='Standard'
for nm,ang in (('f',0),('s',90)):
    a=math.radians(ang)
    cam=lib.camera((3*math.sin(a),-3*math.cos(a),cz),(0,0,cz)); cam.data.type='ORTHO'; cam.data.ortho_scale=sc
    lib.render(f'/home/claude/tripo/{tag}_o{nm}.png',samples=2,res=(1024,1024))
