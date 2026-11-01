"""Paint real brand marks out of a prepared scan (scan_prep.py output):
    python3 scan_paint.py -- <in.glb> <out.glb> <rule>
Bakes the height of every texel (Geometry Position Z) onto the scan's own UVs, builds a mask by colour and height,
and fills the masked texels from their surroundings (OpenCV inpaint). Rules:
  bright_upper : light letters on a dark upper (shoe 1): bright texels above the sole (z > ZMIN), small blobs only
  red_stripes  : the red stripes on grey suede (shoe 2): reddish texels, pulled to the suede's own grey
Writes <out>.png (texture), <out>_mask.png (what was painted) and the glb. Prints PAINT_OK."""
import bpy, sys, numpy as np, cv2
a = sys.argv[sys.argv.index('--') + 1:]
inp, out, rule = a[0], a[1], a[2]
ZMIN = float(a[3]) if len(a) > 3 else .035
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=inp)
ob = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
mat = ob.active_material; N = mat.node_tree.nodes
tex = [n for n in N if n.type == 'TEX_IMAGE'][0]; img = tex.image
W, H = img.size
col = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
# bake height: a temporary material with z as emission, into a float image
hz = bpy.data.images.new('hz', W, H, float_buffer=True)
m2 = bpy.data.materials.new('hz'); m2.use_nodes = True; N2 = m2.node_tree.nodes; L2 = m2.node_tree.links
for n in list(N2): N2.remove(n)
g = N2.new('ShaderNodeNewGeometry'); s = N2.new('ShaderNodeSeparateXYZ'); e = N2.new('ShaderNodeEmission'); o_ = N2.new('ShaderNodeOutputMaterial')
L2.new(g.outputs['Position'], s.inputs[0]); L2.new(s.outputs[2], e.inputs['Strength']); L2.new(e.outputs[0], o_.inputs[0])
t2 = N2.new('ShaderNodeTexImage'); t2.image = hz; N2.active = t2
ob.data.materials[0] = m2
sc = bpy.context.scene; sc.render.engine = 'CYCLES'; sc.cycles.samples = 1; sc.render.bake.margin = 4
for o in bpy.context.selected_objects: o.select_set(False)
ob.select_set(True); bpy.context.view_layer.objects.active = ob
bpy.ops.object.bake(type='EMIT')
z = np.array(hz.pixels[:], dtype=np.float32).reshape(H, W, 4)[:, :, 0]
ob.data.materials[0] = mat
rgb = col[:, :, :3]
srgb = (np.clip(rgb, 0, 1) * 255).astype(np.uint8)   # a byte image: its pixels are the stored sRGB values
hsv = cv2.cvtColor(srgb, cv2.COLOR_RGB2HSV)
filled = (col[:, :, 3] > 0)
if rule == 'bright_upper':
    m = (hsv[:, :, 2] > 95) & (z > ZMIN) & filled
    n, lab, st, _ = cv2.connectedComponentsWithStats(m.astype(np.uint8), 8)
    small = np.zeros_like(m)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] < W * H * .004: small |= lab == i
    m = small
elif rule == 'red_stripes':
    hue = hsv[:, :, 0].astype(int); sat = hsv[:, :, 1]
    m = ((hue < 12) | (hue > 165)) & (sat > 50) & (hsv[:, :, 2] > 90) & filled   # pink, not the dark brown gum or the gaps
elif rule.startswith('boxes:'):   # boxes:x0,y0,x1,y1,b;... in texture pixels from the top-left (as an image viewer shows it)
    V = np.flipud(hsv[:, :, 2]).astype(int); mt = np.zeros((H, W), bool)
    for spec in rule[6:].split(';'):
        x0, y0, x1, y1, pol = spec.split(','); x0, y0, x1, y1 = map(int, (x0, y0, x1, y1))
        box = V[y0:y1, x0:x1]; med = np.median(box)
        mt[y0:y1, x0:x1] = True if pol == 'a' else (box > med + 25) if pol == 'b' else (box < med - 25)   # letters lighter / darker than what they are printed on; 'a': the whole box (embossed)
    m = np.flipud(mt) & filled
else:
    raise SystemExit('unknown rule ' + rule)
mask = cv2.dilate(m.astype(np.uint8) * 255, np.ones((5, 5), np.uint8))
print('masked texels', int((mask > 0).sum()))
bgr = cv2.cvtColor(srgb, cv2.COLOR_RGB2BGR)
# the atlas's empty black between islands would bleed into the fill: spread the islands' colours into it first
empty = (srgb.max(2) < 4).astype(np.uint8) * 255
if empty.any(): bgr = cv2.inpaint(bgr, empty, 3, cv2.INPAINT_TELEA)
if rule == 'red_recolor':   # (unused: the ring picked up the dark gaps) recolour, keep the leather's own shading: the stripes take the suede's colour and brightness
    lab = cv2.cvtColor(bgr, cv2.COLOR_BGR2LAB).astype(np.float32)
    ring = (cv2.dilate(mask, np.ones((25, 25), np.uint8)) > 0) & (mask == 0) & filled & (hsv[:, :, 1] < 90)
    ref = np.median(lab[ring], 0); mk = mask > 0
    Ls = lab[mk][:, 0]; lab[mk, 0] = (Ls - Ls.mean()) * .6 + ref[0]; lab[mk, 1] = ref[1]; lab[mk, 2] = ref[2]
    soft = cv2.GaussianBlur(mask, (0, 0), 2).astype(np.float32)[:, :, None] / 255
    new = cv2.cvtColor(np.clip(lab, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR)
    res = (new * soft + bgr * (1 - soft)).astype(np.uint8)
    print('suede ref Lab', np.round(ref, 1))
else:
    res = cv2.inpaint(bgr, mask, 9, cv2.INPAINT_TELEA)
cv2.imwrite(out.replace('.glb', '_mask.png'), np.flipud(mask))
res[empty > 0] = 0   # keep the gaps black (unused texels)
res_rgb = cv2.cvtColor(res, cv2.COLOR_BGR2RGB).astype(np.float32) / 255
col[:, :, :3] = res_rgb
img.pixels[:] = col.ravel()
img.filepath_raw = out.replace('.glb', '.png'); img.file_format = 'PNG'; img.save()
tex.image = bpy.data.images.load(out.replace('.glb', '.png'))   # the exporter writes the imported (packed) bytes, not edited pixels
for o in bpy.context.selected_objects: o.select_set(False)
ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True)
print('PAINT_OK', out)
