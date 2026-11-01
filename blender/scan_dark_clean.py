"""A dark object scanned on a wooden floor (the black slippers, s04): python3 scan_dark_clean.py -- <prepped.glb> <out.glb>
- the floor that stayed stuck to the soles (warped boards higher than the cut) comes off: low faces in the wood's colour
- what is much lighter than the cloth round it is the maker's name printed on the side ('...MEDICAL'): painted out with the
  black around it. Prints CLEAN_OK."""
import bpy, bmesh, sys, numpy as np, cv2
a = sys.argv[sys.argv.index('--') + 1:]
inp, out = a[0], a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=inp)
ob = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
for o in bpy.context.selected_objects: o.select_set(False)
bpy.context.view_layer.objects.active = ob; ob.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True); ob.parent = None
tn = [n for n in ob.active_material.node_tree.nodes if n.type == 'TEX_IMAGE'][0]; img = tn.image
W, H = img.size; px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
me = ob.data; uv = me.uv_layers.active.data
bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
uvl = bm.loops.layers.uv.active
kill = []
for f in bm.faces:
    if max(v.co.z for v in f.verts) > .03: continue
    c = np.mean([px[min(H - 1, int(l[uvl].uv.y * H)), min(W - 1, int(l[uvl].uv.x * W)), :3] for l in f.loops], 0)
    if c.mean() > .09 or (c[0] - c[2] > .015 and c.mean() > .05): kill.append(f)   # the black cloth and sole are darker than any floor
bmesh.ops.delete(bm, geom=kill, context='FACES_ONLY')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
bm.to_mesh(me); bm.free()
print('floor faces removed', len(kill))
rgb = (np.clip(px[::-1, :, :3], 0, 1) ** (1 / 2.2) * 255).astype(np.uint8)   # image rows are bottom-up in Blender
lum = rgb.mean(2)
used = rgb.max(2) > 3
bg = cv2.medianBlur(lum.astype(np.uint8), 41).astype(np.float32)
grey = (rgb.max(2).astype(int) - rgb.min(2)) < 28
m = ((lum - bg > 35) & grey & used).astype(np.uint8) * 255   # printed letters: much lighter than the cloth round them, and grey
m = cv2.dilate(m, np.ones((5, 5), np.uint8))
fix = cv2.inpaint(rgb, m, 7, cv2.INPAINT_TELEA)
print('light texels painted', int((m > 0).sum()))
lin = (fix.astype(np.float32) / 255) ** 2.2
px[:, :, :3] = lin[::-1]
img.pixels[:] = px.ravel()
img.filepath_raw = out.replace('.glb', '.png'); img.file_format = 'PNG'; img.save()
tn.image = bpy.data.images.load(out.replace('.glb', '.png'))   # the exporter writes the image it read: load the saved one
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True)
print('CLEAN_OK', out)
