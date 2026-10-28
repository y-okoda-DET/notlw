import sys; sys.path.insert(0,'/home/claude/kf')
import bpy, lib, door as D, chars as C
lib.reset(); M = D.mats()
for key in ('natsuki','kiryu'):
    r,b = C.make(key, M['knit'], M['denim'], M['sock'])
    bpy.context.view_layer.update()
    for nm in ('shirt','pants'):
        o = bpy.data.objects[f'{key}_{nm}']
        zs=[(o.matrix_world @ v.co).z for v in o.data.vertices]
        print(key, nm, round(min(zs),3), round(max(zs),3), 'rigscale', round(r.scale[0],3))
    zs=[(b.matrix_world @ v.co).z for v in b.data.vertices]; print(key,'body', round(min(zs),3), round(max(zs),3))
    for o in list(bpy.data.objects): bpy.data.objects.remove(o)
