import bpy
bpy.ops.wm.open_mainfile(filepath='/home/claude/work/rec/recorder.blend')
for o in list(bpy.data.objects):
    if o.name != 'recorder_tripo': bpy.data.objects.remove(o)
bpy.ops.export_scene.gltf(filepath='/home/claude/work/exp/recorder.glb', export_format='GLB', export_yup=True, export_image_format='AUTO')
print('OUT', len(bpy.data.objects['recorder_tripo'].data.vertices), [im.size[:] for im in bpy.data.images])
