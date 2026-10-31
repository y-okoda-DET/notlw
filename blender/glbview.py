# import an exported character glb, go to a frame, render closeups. args: glb frame tx,ty,tz cx,cy,cz[;...] out
import bpy, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P   # all paths: paths.env
import lib
a=sys.argv[sys.argv.index('--')+1:]
glb,frame,T,cams,out=a[0],int(a[1]),tuple(map(float,a[2].split(','))),a[3],a[4]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
s=bpy.context.scene; s.frame_set(frame)
if os.environ.get('REST'):
    for o in bpy.data.objects:
        if o.type=='ARMATURE': o.data.pose_position='REST'
w=bpy.data.worlds.new('w'); s.world=w; w.use_nodes=True; w.node_tree.nodes['Background'].inputs[1].default_value=.7
s.view_settings.view_transform='Standard'; lib.area('key',(T[0]-1.5,T[1]-2,T[2]+1.5),T,250,k=5000,size=(2,2)); lib.area('fill',(T[0]+1.5,T[1]-1,T[2]),T,120,k=5000,size=(2,2)); lib.area('top',(T[0],T[1]+1.5,T[2]+2),T,120,k=5000,size=(2,2)); s.render.engine='CYCLES'
import os
if os.environ.get('CLAY'):
    cm=bpy.data.materials.new('clay'); cm.use_nodes=True
    for o in bpy.data.objects:
        if o.type=='MESH':
            for i in range(len(o.material_slots)): o.material_slots[i].material=cm
if os.environ.get('NONRM'):
    for m in bpy.data.materials:
        if m.use_nodes:
            for n in list(m.node_tree.nodes):
                if n.type=='NORMAL_MAP': m.node_tree.nodes.remove(n)
for i,c in enumerate(cams.split(';')):
    c=tuple(map(float,c.split(',')))
    lib.camera(c,T,lens=int(os.environ.get("LENS","60")))
    lib.render(f'{out}_{i}.png',samples=8,res=(500,500))
