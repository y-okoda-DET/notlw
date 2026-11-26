import sys, numpy as np, bpy
from PIL import Image, ImageDraw
glb, tex, out = sys.argv[1:4]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
im = np.asarray(Image.open(tex).convert('RGB'), np.float32) / 255
H, W = im.shape[:2]
def cls(c):
    mx = c.max(); mn = c.min(); sat = (mx - mn) / (mx + 1e-4)
    if sat < 0.10 and mx > 0.62: return 's'          # sweater
    if sat > 0.16 and c[0] > c[1] > c[2] and mx > 0.45 and sat < 0.55: return 'k'   # skin
    if mx < 0.42 and sat < 0.2: return 'p'           # trousers
    return 'o'
bodies = [o for o in bpy.data.objects if o.type == 'MESH' and any(m and 'body' in m.name for m in o.data.materials)]
print('bodies', [o.name for o in bodies])
new = im.copy()
band = Image.new('L', (W, H), 0); dr = ImageDraw.Draw(band)
for ob in bodies:
    me = ob.data; uv = me.uv_layers.active
    pc = []
    for p in me.polygons:
        us = np.array([uv.data[li].uv[:] for li in p.loop_indices]).mean(0)
        x = int(np.clip(us[0], 0, 0.9999) * W); y = int(np.clip(1 - us[1], 0, 0.9999) * H)
        pc.append(cls(im[y, x]))
    # mesh neighbours (by vertex): sweater faces within 2 rings of skin or trousers are the rib
    vf = {}
    for p in me.polygons:
        for v in p.vertices: vf.setdefault(v, []).append(p.index)
    edge = set(p.index for p in me.polygons if pc[p.index] in 'kp')
    ring = set(edge)
    for _ in range(2):
        nxt = set()
        for i in ring:
            for v in me.polygons[i].vertices: nxt.update(vf[v])
        ring |= nxt
    n = 0
    for p in me.polygons:
        if p.index in ring and pc[p.index] == 's' and p.index not in edge:
            pts = [(uv.data[li].uv[0] * W, (1 - uv.data[li].uv[1]) * H) for li in p.loop_indices]
            dr.polygon(pts, fill=255, outline=255); n += 1
    print(ob.name, 'polys', len(pc), 'sweater', pc.count('s'), 'skin', pc.count('k'), 'trousers', pc.count('p'), 'rib', n)
mx = im.max(2); mn = im.min(2); sat = (mx - mn) / (mx + 1e-4)
sw = (sat < 0.10) & (mx > 0.62)
new[sw] = im[sw] * np.array([0.58, 0.62, 0.74], np.float32)
bm = (np.asarray(band, np.float32) / 255)[..., None] * sw[..., None]
new = new * (1 - 0.35 * bm)
Image.fromarray((np.clip(new, 0, 1) * 255).astype(np.uint8)).save(out)
Image.fromarray((bm[..., 0] * 255).astype(np.uint8)).resize((1024, 1024)).save(out.replace('.png', '_rib.png'))
