"""A flat woven mat from a Scaniverse glb: python3 scan_mat.py -- <in.glb> <out.glb> [tex_px]
The mat is ~1 cm thick and lies on the floor, so cutting the scan's mesh by height leaves holes all over it (see
scan_prep.py's 'mat' mode). Instead: find the mat by colour (it differs from the floor's wood), fit a rectangle to it,
lay a fine grid there and bake the scan's colour onto the grid from above; the texels that look like the floor
become transparent (the fringe keeps its own shape). A solidify gives it its thickness. Prints MAT_OK."""
import bpy, sys, math, numpy as np
from mathutils import Vector, Matrix
a = sys.argv[sys.argv.index('--') + 1:]
inp, out = a[0], a[1]; PX = int(a[2]) if len(a) > 2 else 2048
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=inp)
src = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
for o in bpy.context.selected_objects: o.select_set(False)
bpy.context.view_layer.objects.active = src; src.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True); src.parent = None
me = src.data; P = np.array([v.co[:] for v in me.vertices])
img = [n.image for n in src.active_material.node_tree.nodes if n.type == 'TEX_IMAGE'][0]
W, H = img.size; px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[:, :, :3]
cx, cy = np.median(P[:, 0]), np.median(P[:, 1])
mid = P[np.hypot(P[:, 0] - cx, P[:, 1] - cy) < .45]
h, e = np.histogram(mid[:, 2], bins=200); fz = (e[h.argmax()] + e[h.argmax() + 1]) / 2
fl = mid[np.abs(mid[:, 2] - fz) < .01]
c, *_ = np.linalg.lstsq(np.c_[fl[:, 0], fl[:, 1], np.ones(len(fl))], fl[:, 2], rcond=None)
T = Vector((-c[0], -c[1], 1)).normalized().rotation_difference(Vector((0, 0, 1))).to_matrix().to_4x4()
me.transform(T); P = np.array([v.co[:] for v in me.vertices])
z0 = np.median(P[np.abs(P[:, 2] - np.median(P[:, 2])) < .01][:, 2])
# face colours and positions
uv = me.uv_layers.active.data
fc = np.array([P[list(p.vertices)].mean(0) for p in me.polygons])
cols = np.array([np.mean([px[min(H - 1, int(uv[li].uv[1] * H)), min(W - 1, int(uv[li].uv[0] * W))] for li in p.loop_indices], 0) for p in me.polygons])
rr = np.hypot(fc[:, 0] - cx, fc[:, 1] - cy)
flo = cols[(rr > .45) & (rr < .7) & (np.abs(fc[:, 2] - z0) < .004)]
mu = np.median(flo, 0); sd = np.median(np.abs(flo - mu), 0) * 1.48 + .01
dist = lambda cc: np.sqrt((((cc - mu) / sd) ** 2).sum(-1))
matf = fc[(dist(cols) > 4.0) & (rr < .5) & (fc[:, 2] > z0 - .004)]
# rectangle: principal axes of the mat faces, 1st..99th percentile extents
m0 = matf[:, :2].mean(0); U, S, Vt = np.linalg.svd(matf[:, :2] - m0, full_matrices=False)
ax = Vt[0]; ang = math.atan2(ax[1], ax[0])
loc = (matf[:, :2] - m0) @ Vt.T
lo, hi = np.percentile(loc, .5, 0) - .01, np.percentile(loc, 99.5, 0) + .01
ctr = m0 + ((lo + hi) / 2) @ Vt; size = hi - lo
top = np.percentile(matf[:, 2], 60)
print('mat cm', np.round(size * 100, 1), 'angle', round(math.degrees(ang), 1), 'top above floor mm', round((top - z0) * 1000, 1))
bpy.ops.mesh.primitive_grid_add(x_subdivisions=96, y_subdivisions=72, size=1, location=(ctr[0], ctr[1], top))
g = bpy.context.active_object; g.name = 'mat'
g.scale = (size[0], size[1], 1); g.rotation_euler.z = ang
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
new = bpy.data.images.new('mat_tex', PX, int(PX * size[1] / size[0]) // 4 * 4, alpha=True)
mat = bpy.data.materials.new('scanmat'); mat.use_nodes = True; N = mat.node_tree.nodes
t = N.new('ShaderNodeTexImage'); t.image = new; N.active = t
L = mat.node_tree.links; L.new(t.outputs[0], N['Principled BSDF'].inputs['Base Color']); rd = N.new('ShaderNodeMath'); rd.operation = 'ROUND'; L.new(t.outputs[1], rd.inputs[0]); L.new(rd.outputs[0], N['Principled BSDF'].inputs['Alpha'])   # round: glTF alpha MASK (cut-out), not blended
N['Principled BSDF'].inputs['Roughness'].default_value = .95
try: mat.blend_method = 'CLIP'
except Exception: pass
g.data.materials.append(mat)
sc = bpy.context.scene; sc.render.engine = 'CYCLES'; sc.cycles.samples = 1
b = sc.render.bake; b.use_pass_direct = False; b.use_pass_indirect = False; b.use_pass_color = True
b.use_selected_to_active = True; b.cage_extrusion = .03; b.max_ray_distance = .06; b.margin = 2
for o in bpy.context.selected_objects: o.select_set(False)
src.select_set(True); g.select_set(True); bpy.context.view_layer.objects.active = g
bpy.ops.object.bake(type='DIFFUSE')
pix = np.array(new.pixels[:], dtype=np.float32).reshape(new.size[1], new.size[0], 4)
# what is mat and what is floor: the height of the surface each texel sees (the mat stands 3-5 mm proud of the floor),
# helped by colour for the fringe that lies flat. Height: the source's emission becomes its z (in cm above the floor)
hz = bpy.data.images.new('hz', new.size[0], new.size[1], float_buffer=True)
t.image = hz
sm = bpy.data.materials.new('hzsrc'); sm.use_nodes = True; N2 = sm.node_tree.nodes; L2 = sm.node_tree.links
for n in list(N2): N2.remove(n)
gg = N2.new('ShaderNodeNewGeometry'); sx = N2.new('ShaderNodeSeparateXYZ'); mth = N2.new('ShaderNodeMath'); mth.operation = 'MULTIPLY_ADD'
mth.inputs[1].default_value = 100.0; mth.inputs[2].default_value = -100.0 * z0
em = N2.new('ShaderNodeEmission'); oo = N2.new('ShaderNodeOutputMaterial')
L2.new(gg.outputs['Position'], sx.inputs[0]); L2.new(sx.outputs[2], mth.inputs[0]); L2.new(mth.outputs[0], em.inputs['Strength']); L2.new(em.outputs[0], oo.inputs[0])
src.data.materials[0] = sm
bpy.ops.object.bake(type='EMIT')
zc = np.array(hz.pixels[:], dtype=np.float32).reshape(new.size[1], new.size[0], 4)[:, :, 0]   # cm above the floor
t.image = new
import cv2
d = cv2.GaussianBlur(dist(pix[:, :, :3]).astype(np.float32), (0, 0), 3)
zb = cv2.GaussianBlur(zc, (0, 0), 4)
alpha = (zb > .03).astype(np.uint8)   # the floor around reads exactly 0; anything raised is mat or fringe
alpha = cv2.morphologyEx(alpha, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
n_, lab, st, _ = cv2.connectedComponentsWithStats(alpha, 8)   # the mat (with its fringe) is the big piece
big = 1 + np.argmax(st[1:, cv2.CC_STAT_AREA])
body = cv2.morphologyEx((lab == big).astype(np.uint8), cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
cs, _ = cv2.findContours(body, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE); body = np.zeros_like(body); cv2.drawContours(body, cs, -1, 1, -1)   # no holes inside it
pix[:, :, 3] = body
cv2.imwrite(out.replace('.glb', '_z.png'), np.flipud(np.clip(zc * 300, 0, 255)).astype(np.uint8))
print('opaque', round(float(pix[:, :, 3].mean()), 3))
new.pixels[:] = pix.ravel(); new.filepath_raw = out.replace('.glb', '.png'); new.file_format = 'PNG'; new.save()
bpy.data.objects.remove(src)
m = g.modifiers.new('thick', 'SOLIDIFY'); m.thickness = top - z0; m.offset = -1
bpy.ops.object.modifier_apply(modifier='thick')
g.data.transform(Matrix.Translation(Vector((-ctr[0], -ctr[1], -z0)))); g.data.transform(Matrix.Rotation(-ang, 4, 'Z'))   # centred, long side along x, on z = 0
for o in bpy.context.selected_objects: o.select_set(False)
g.select_set(True); bpy.context.view_layer.objects.active = g
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True)
print('MAT_OK', out)
