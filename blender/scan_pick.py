"""Where in a scan's texture is what a preview shows: python3 scan_pick.py -- <glb> <view 0|1|2> x,y [x,y ...]
The views are those of the preview renders (800x600; cameras as in scan_look.py). Prints the texel
(from the top-left, as scan_paint.py boxes take it) under each preview pixel."""
import bpy, sys
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
bpy.ops.wm.read_factory_settings(use_empty=True)
a=sys.argv[sys.argv.index('--')+1:]
bpy.ops.import_scene.gltf(filepath=a[0])
ob=[o for o in bpy.context.scene.objects if o.type=='MESH'][0]
sc=bpy.context.scene; sc.render.resolution_x=800; sc.render.resolution_y=600
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); sc.collection.objects.link(cam)
p=[(0,-.6,.4),(0,0,.8),(.5,.35,.25)][int(a[1])]; cam.location=p; cam.rotation_euler=(Vector((0,0,.05))-Vector(p)).to_track_quat('-Z','Y').to_euler()
bpy.context.view_layer.update()
dg=bpy.context.evaluated_depsgraph_get()
TW,TH=[n.image.size for n in ob.active_material.node_tree.nodes if n.type=='TEX_IMAGE'][0]
fr=[cam.matrix_world @ v for v in cam.data.view_frame(scene=sc)]  # tr, br, bl, tl
for (px,py) in [tuple(map(int,q.split(','))) for q in a[2:]]:
    u=px/800; v=py/600
    top=fr[3].lerp(fr[0],u); bot=fr[2].lerp(fr[1],u); pt=top.lerp(bot,v)
    d=(pt-cam.location).normalized()
    hit,loc,nor,fi,o,m=sc.ray_cast(dg,cam.location,d)
    if not hit: print(px,py,'miss'); continue
    me=ob.data; poly=me.polygons[fi]; uvl=me.uv_layers.active.data
    # nearest corner's uv is enough to locate
    best=min(poly.loop_indices,key=lambda li:(me.vertices[me.loops[li].vertex_index].co-loc).length)
    uv=uvl[best].uv; print(px,py,'tex', int(uv[0]*TW), int((1-uv[1])*TH))
