"""Repaint the printing on a flat-ish scan (snack bags) from above, where the UV islands of the bake would cut a word
into pieces:
    python3 scan_relabel.py -- top   <prepped.glb> <top.png> [px=2048]
        an orthographic top view of the scan's own colour (no light), and <top.json> with the square it covers
    python3 scan_relabel.py -- apply <prepped.glb> <top.png> <edit.png> <mask.png> <out.glb>
        project <edit.png> from above onto every face that looks up (normal z > .35) where <mask.png> is white, keep
        the rest; baked back onto the scan's own UVs. Prints RELABEL_OK."""
import bpy, sys, json, math, numpy as np
from mathutils import Vector
a = sys.argv[sys.argv.index('--') + 1:]
mode, inp = a[0], a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=inp)
ob = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
for o in bpy.context.selected_objects: o.select_set(False)
bpy.context.view_layer.objects.active = ob; ob.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True); ob.parent = None
P = np.array([v.co[:] for v in ob.data.vertices])
mt = ob.active_material; N = mt.node_tree.nodes; L = mt.node_tree.links
tex = [n for n in N if n.type == 'TEX_IMAGE'][0]
sc = bpy.context.scene; sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'
sc.view_settings.view_transform = 'Standard'

if mode == 'top':
    out = a[2]; PX = int(a[3]) if len(a) > 3 else 2048
    c = (P.min(0) + P.max(0)) / 2; side = float(max(P.max(0)[:2] - P.min(0)[:2])) * 1.04
    ext = [float(c[0] - side / 2), float(c[1] - side / 2), float(c[0] + side / 2), float(c[1] + side / 2)]
    em = N.new('ShaderNodeEmission'); L.new(tex.outputs[0], em.inputs[0])
    L.new(em.outputs[0], N['Material Output'].inputs[0])
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True; w.node_tree.nodes['Background'].inputs[1].default_value = 0
    sc.cycles.samples = 4; sc.render.resolution_x = sc.render.resolution_y = PX; sc.render.film_transparent = True
    cam = bpy.data.objects.new('c', bpy.data.cameras.new('c')); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = side; cam.location = (c[0], c[1], 2); cam.rotation_euler = (0, 0, 0)
    sc.render.filepath = out; bpy.ops.render.render(write_still=True)
    json.dump(dict(ext=ext, px=PX), open(out.replace('.png', '.json'), 'w'))
    print('TOP_OK', out, ext)
    sys.exit(0)

top, edit, mask, out = a[2], a[3], a[4], a[5]
ext = json.load(open(top.replace('.png', '.json')))['ext']
src_img = tex.image.copy(); src_img.name = 'orig'
tex.image = src_img
W, H = tex.image.size
target = bpy.data.images.new('relabel', W, H)
def img_node(path, srgb=True):
    n = N.new('ShaderNodeTexImage'); n.image = bpy.data.images.load(path); n.extension = 'CLIP'
    if not srgb: n.image.colorspace_settings.name = 'Non-Color'
    return n
geo = N.new('ShaderNodeNewGeometry')
sep = N.new('ShaderNodeSeparateXYZ'); L.new(geo.outputs['Position'], sep.inputs[0])
def lin(inp_sock, lo, hi):
    m = N.new('ShaderNodeMapRange'); L.new(inp_sock, m.inputs[0]); m.inputs[1].default_value = lo; m.inputs[2].default_value = hi
    m.inputs[3].default_value = 0; m.inputs[4].default_value = 1; m.clamp = False; return m.outputs[0]
comb = N.new('ShaderNodeCombineXYZ'); L.new(lin(sep.outputs[0], ext[0], ext[2]), comb.inputs[0]); L.new(lin(sep.outputs[1], ext[1], ext[3]), comb.inputs[1])
e = img_node(edit); m = img_node(mask, False)
for n in (e, m): L.new(comb.outputs[0], n.inputs[0])
nz = N.new('ShaderNodeSeparateXYZ'); L.new(geo.outputs['True Normal'], nz.inputs[0])
up = N.new('ShaderNodeMath'); up.operation = 'GREATER_THAN'; up.inputs[1].default_value = .35; L.new(nz.outputs[2], up.inputs[0])
fac = N.new('ShaderNodeMath'); fac.operation = 'MULTIPLY'; L.new(up.outputs[0], fac.inputs[0]); L.new(m.outputs[0], fac.inputs[1])
mix = N.new('ShaderNodeMix'); mix.data_type = 'RGBA'
L.new(fac.outputs[0], mix.inputs['Factor']); L.new(tex.outputs[0], mix.inputs[6]); L.new(e.outputs[0], mix.inputs[7])
em = N.new('ShaderNodeEmission'); L.new(mix.outputs[2], em.inputs[0]); L.new(em.outputs[0], N['Material Output'].inputs[0])
tn = N.new('ShaderNodeTexImage'); tn.image = target; N.active = tn
sc.cycles.samples = 1; sc.render.bake.margin = 6
bpy.ops.object.bake(type='EMIT')
target.filepath_raw = out.replace('.glb', '.png'); target.file_format = 'PNG'; target.save()
# rebuild a plain material on the result (load the saved file: the exporter writes the image it read)
for n in list(N):
    if n.name not in ('Principled BSDF', 'Material Output'): N.remove(n)
fin = N.new('ShaderNodeTexImage'); fin.image = bpy.data.images.load(out.replace('.glb', '.png'))
L.new(fin.outputs[0], N['Principled BSDF'].inputs['Base Color'])
L.new(N['Principled BSDF'].outputs[0], N['Material Output'].inputs[0])
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True)
print('RELABEL_OK', out)
