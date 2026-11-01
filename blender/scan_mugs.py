"""The two mugs (s07) with what is left in them: python3 scan_mugs.py -- <prepped.glb> <out.glb>
The scan's inner bottoms have holes you would see through from above (the mugs sit below eye level on the stair);
the drink left in each covers them and says the crew stopped for a while: coffee in the white one, hojicha in the
green one. Prints MUGS_OK."""
import bpy, bmesh, sys, math, numpy as np
a = sys.argv[sys.argv.index('--') + 1:]
inp, out = a[0], a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=inp)
ob = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
for o in bpy.context.selected_objects: o.select_set(False)
bpy.context.view_layer.objects.active = ob; ob.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True); ob.parent = None
P = np.array([v.co[:] for v in ob.data.vertices])
from scipy.cluster.vq import kmeans2
c, lab = kmeans2(P[:, :2], 2, minit='++', seed=1)
# which is the white one: the brighter baked colour
img = [n.image for n in ob.active_material.node_tree.nodes if n.type == 'TEX_IMAGE'][0]
W, H = img.size; px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[:, :, :3]
uv = ob.data.uv_layers.active.data
lum = np.zeros(2); cnt = np.zeros(2)
for p in list(ob.data.polygons)[::7]:
    li = p.loop_indices[0]; u, v = uv[li].uv
    k = lab[p.vertices[0]]; lum[k] += px[min(H - 1, int(v * H)), min(W - 1, int(u * W))].mean(); cnt[k] += 1
white = int(np.argmax(lum / cnt))
def mat(name, col, rough):
    m = bpy.data.materials.new(name); m.use_nodes = True; pb = m.node_tree.nodes['Principled BSDF']
    pb.inputs['Base Color'].default_value = (*col, 1); pb.inputs['Roughness'].default_value = rough; return m
DRINK = {white: mat('mug_coffee', (.07, .04, .025), .08), 1 - white: mat('mug_hojicha', (.30, .17, .07), .08)}
for k in (0, 1):
    Q = P[lab == k]; zt = Q[:, 2].max(); zl = zt * .72          # two-thirds full, left to go cold
    rim = Q[Q[:, 2] > zt - .008][:, :2]                           # the rim is a circle: fit it (the handle is lower)
    Am = np.c_[rim, np.ones(len(rim))]; D, E, F = np.linalg.lstsq(Am, -(rim ** 2).sum(1), rcond=None)[0]
    cen = np.array([-D / 2, -E / 2]); rr = math.sqrt(cen @ cen - F)
    r = rr - .007                                                 # the glaze wall's thickness and the taper below the rim
    me = bpy.data.meshes.new('drink'); bm = bmesh.new()
    vs = [bm.verts.new((cen[0] + r * math.cos(j / 40 * math.tau), cen[1] + r * math.sin(j / 40 * math.tau), zl)) for j in range(40)]
    bm.faces.new(vs); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new('drink', me); bpy.context.scene.collection.objects.link(o); me.materials.append(DRINK[k])
    o.select_set(True)
    print('mug', k, 'white' if k == white else 'green', 'centre', np.round(cen, 3), 'rim z', round(zt, 3), 'drink r', round(r, 3))
bpy.context.view_layer.objects.active = ob; ob.select_set(True)
bpy.ops.object.join()
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True)
print('MUGS_OK', out)
