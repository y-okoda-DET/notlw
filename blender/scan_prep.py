"""Turn a Scaniverse glb (object + the floor it stood on, 8K atlas) into a game prop:
    python3 scan_prep.py <in.glb> <out.glb> <mode> [tex_px] [faces]
mode: 'shoes' (cut by height above the floor) or 'mat' (cut by colour: the floor's wood vs the mat, fringe kept).
Steps: level the floor plane and cut it away, keep the islands in the middle, close the holes (scan gaps, shoe
openings, the cut edge at the floor), decimate, new UVs, and bake the scan's colour onto them (selected-to-active, so
the filled holes take the colour of the surface next to them). The 8K atlas, mostly floor, becomes one small texture.
Prints SCAN_OK. Logos are painted out afterwards on the baked texture (scan_paint.py)."""
import bpy, bmesh, sys, math, numpy as np
from mathutils import Vector, Matrix
a = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
inp, out, mode = a[0], a[1], a[2]
PX = int(a[3]) if len(a) > 3 else 2048
FACES = int(a[4]) if len(a) > 4 else 40000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=inp)
src = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
for o in bpy.context.selected_objects: o.select_set(False)
bpy.context.view_layer.objects.active = src; src.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
src.parent = None
me = src.data
P = np.array([v.co[:] for v in me.vertices])
img = [n.image for n in src.active_material.node_tree.nodes if n.type == 'TEX_IMAGE'][0]
W, H = img.size; px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[:, :, :3]

# the floor: most populated height near the middle; a plane fitted to it
cx, cy = np.median(P[:, 0]), np.median(P[:, 1])
r = np.hypot(P[:, 0] - cx, P[:, 1] - cy)
mid = P[r < .45]
h, e = np.histogram(mid[:, 2], bins=200); fz = (e[h.argmax()] + e[h.argmax() + 1]) / 2
fl = mid[np.abs(mid[:, 2] - fz) < .01]
A = np.c_[fl[:, 0], fl[:, 1], np.ones(len(fl))]; c, *_ = np.linalg.lstsq(A, fl[:, 2], rcond=None)
hgt = P[:, 2] - (c[0] * P[:, 0] + c[1] * P[:, 1] + c[2])
print('floor z', round(fz, 4), 'tilt', np.round(c[:2], 4))

# each face's colour (mean of its corners' texels)
uv = me.uv_layers.active.data
def face_col(poly):
    s = np.zeros(3)
    for li in poly.loop_indices:
        u, v = uv[li].uv; s += px[min(H - 1, max(0, int(v * H))), min(W - 1, max(0, int(u * W)))]
    return s / poly.loop_total
fh = np.array([hgt[list(p.vertices)].min() for p in me.polygons])
fc = np.array([P[list(p.vertices)].mean(0) for p in me.polygons])
if mode == 'shoes':
    keepf = fh > .004
else:   # the mat: faces that differ in colour from the floor (sampled in a ring away from the middle), not below it
    cols = np.array([face_col(p) for p in me.polygons])
    rr = np.hypot(fc[:, 0] - cx, fc[:, 1] - cy)
    flo = cols[(np.abs(fh) < .003) & (rr > .45) & (rr < .7)]
    mu = np.median(flo, 0); sd = np.median(np.abs(flo - mu), 0) * 1.48 + .01
    d = np.sqrt((((cols - mu) / sd) ** 2).sum(1))
    keepf = ((d > 4.0) | (fh > .004)) & (fh > -.005) & (rr < .5)
    print('floor colour', np.round(mu, 3), 'kept faces', int(keepf.sum()))
bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[f for f in bm.faces if not keepf[f.index]], context='FACES_ONLY')
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=.0004)   # the scan is split along its UV seams: weld it, or every seam is a 'hole'
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
# islands near the middle (drop the far walls, the skirting board, loose bits)
seen = set(); isl = []
for v in bm.verts:
    if v in seen: continue
    st = [v]; comp = []; seen.add(v)
    while st:
        u = st.pop(); comp.append(u)
        for ed in u.link_edges:
            w = ed.other_vert(u)
            if w not in seen: seen.add(w); st.append(w)
    isl.append(comp)
isl.sort(key=len, reverse=True)
big = len(isl[0])
good = [k for k in isl if len(k) > max(200, big * .02) and np.hypot(np.mean([u.co.x for u in k]) - cx, np.mean([u.co.y for u in k]) - cy) < .4]
print('islands', [len(k) for k in isl[:8]], 'kept', [len(k) for k in good])
gs = set(u for k in good for u in k)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v not in gs], context='VERTS')
# close every hole: the shoe openings, scan gaps, the cut along the floor
edges = [ed for ed in bm.edges if ed.is_boundary]
res = bmesh.ops.holes_fill(bm, edges=edges, sides=0)
bmesh.ops.triangulate(bm, faces=res['faces'])
print('holes filled', len(res['faces']))
dst_me = bpy.data.meshes.new('scan'); bm.to_mesh(dst_me); bm.free(); dst_me.validate()
dst = bpy.data.objects.new('scan', dst_me); bpy.context.scene.collection.objects.link(dst)

# level, sit on z = 0, centre (both the bake source and the result move together)
n = Vector((-c[0], -c[1], 1)).normalized(); T = n.rotation_difference(Vector((0, 0, 1))).to_matrix().to_4x4()
for o in (src, dst): o.data.transform(T)
Q = np.array([v.co[:] for v in dst_me.vertices])
T2 = Matrix.Translation(Vector((-(Q[:, 0].min() + Q[:, 0].max()) / 2, -(Q[:, 1].min() + Q[:, 1].max()) / 2, -np.percentile(Q[:, 2], .5))))
for o in (src, dst): o.data.transform(T2)
if mode == 'mat':   # flat underside: nothing below the floor
    for v in dst_me.vertices: v.co.z = max(v.co.z, 0.0)

# decimate, smooth shading, new UVs
bpy.context.view_layer.objects.active = dst
for o in bpy.context.selected_objects: o.select_set(False)
dst.select_set(True)
if len(dst_me.polygons) > FACES:
    m = dst.modifiers.new('dec', 'DECIMATE'); m.ratio = FACES / len(dst_me.polygons)
    bpy.ops.object.modifier_apply(modifier='dec')
for p in dst_me.polygons: p.use_smooth = True
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=.004)
bpy.ops.object.mode_set(mode='OBJECT')

# bake the scan's colour onto the new UVs
new = bpy.data.images.new('scan_tex', PX, PX)
mat = bpy.data.materials.new('scan'); mat.use_nodes = True; N = mat.node_tree.nodes
t = N.new('ShaderNodeTexImage'); t.image = new; N.active = t
mat.node_tree.links.new(t.outputs[0], N['Principled BSDF'].inputs['Base Color'])
N['Principled BSDF'].inputs['Roughness'].default_value = .8
dst_me.materials.clear(); dst_me.materials.append(mat)
sc = bpy.context.scene; sc.render.engine = 'CYCLES'; sc.cycles.samples = 1; sc.cycles.device = 'CPU'
b = sc.render.bake; b.use_pass_direct = False; b.use_pass_indirect = False; b.use_pass_color = True
b.use_selected_to_active = True; b.cage_extrusion = .006; b.max_ray_distance = .03; b.margin = 6
src.select_set(True); dst.select_set(True); bpy.context.view_layer.objects.active = dst
bpy.ops.object.bake(type='DIFFUSE')
new.filepath_raw = out.replace('.glb', '.png'); new.file_format = 'PNG'; new.save()
bpy.data.objects.remove(src)
Q = np.array([v.co[:] for v in dst_me.vertices])
print('size cm', np.round((Q.max(0) - Q.min(0)) * 100, 1), 'faces', len(dst_me.polygons))
for o in bpy.context.selected_objects: o.select_set(False)
dst.select_set(True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True)
print('SCAN_OK', out)
