# カメラごとに描く。flat=1 で物の色だけの画（材質ごとの割合を測るため、平たくなる画にも使う）
import bpy, json, sys, os, math
from mathutils import Vector
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import build as B
a = sys.argv[sys.argv.index('--') + 1:]
names = a[0].split(','); out = a[1]; samples = int(a[2]) if len(a) > 2 else 48; pct = int(a[3]) if len(a) > 3 else 50
flat = len(a) > 4 and a[4] == 'flat'
CAMS = json.load(open(os.path.join(HERE, 'cameras.json')))
B.build(sun='--sun' in sys.argv)
sc = bpy.context.scene; groups = json.loads(sc['groups'])
LYT_TOP = json.load(open(os.path.join(HERE, 'layout.json')))['table']['h']
if os.environ.get('NOTEBOOK_OPEN'):   # 書く手のときだけ：帳面を手前に引いて開く
    nx_, ny_, na_ = [float(v) for v in os.environ['NOTEBOOK_OPEN'].split(',')]
    for on in ('notebook', 'notebook_pages'):
        if on in bpy.data.objects: bpy.data.objects.remove(bpy.data.objects[on])
    pm = bpy.data.materials.new('page'); pb_ = pm.node_tree.nodes['Principled BSDF']; pb_.inputs['Base Color'].default_value = (0.80, 0.79, 0.75, 1); pb_.inputs['Roughness'].default_value = 0.9
    for k_, sx_ in enumerate((-1, 1)):
        bpy.ops.mesh.primitive_cube_add(size=1); pg = bpy.context.object; pg.name = f'open_page_{k_}'
        pg.scale = (0.148, 0.21, 0.004); pg.rotation_euler = (0, sx_ * 0.035, math.radians(na_))
        off = Vector((sx_ * 0.075, 0, 0)); off.rotate(__import__('mathutils').Euler((0, 0, math.radians(na_))))
        pg.location = (nx_ + off.x, ny_ + off.y, LYT_TOP + 0.004)
        PT_ = os.path.join(HERE, 'tex', 'page_L.png' if sx_ > 0 else 'page_R.png')   # 聞き手の側（北）から読む向き：左右も上下も反対（notebook_tex.py）
        if os.path.exists(PT_):
            mp_ = bpy.data.materials.new(f'page_{k_}'); nt_ = mp_.node_tree; pb2 = nt_.nodes['Principled BSDF']; pb2.inputs['Roughness'].default_value = 0.9
            tc_ = nt_.nodes.new('ShaderNodeTexCoord'); mpn = nt_.nodes.new('ShaderNodeMapping'); mpn.inputs['Location'].default_value = (1, 1, 0); mpn.inputs['Scale'].default_value = (-1, -1, 1)
            ti_ = nt_.nodes.new('ShaderNodeTexImage'); ti_.image = bpy.data.images.load(PT_)
            nt_.links.new(tc_.outputs['Generated'], mpn.inputs['Vector']); nt_.links.new(mpn.outputs['Vector'], ti_.inputs['Vector']); nt_.links.new(ti_.outputs['Color'], pb2.inputs['Base Color'])
            mp_['flat'] = (0.80, 0.79, 0.75); pg.data.materials.append(mp_)
        else: pg.data.materials.append(pm)
if os.environ.get('KIKITE'):   # 聞き手（Tripo＋骨＋正座）に差し替える
    for on in list(groups.get('people', [])):
        if on in bpy.data.objects: bpy.data.objects.remove(bpy.data.objects[on])
    with bpy.data.libraries.load(os.environ['KIKITE']) as (src, dst):
        dst.objects = [n for n in src.objects if n.startswith('kikite')]
    groups['people'] = []
    for o in dst.objects:
        sc.collection.objects.link(o); groups['people'].append(o.name)
if os.environ.get('MIO'):   # 澪（ゲームの Tripo の体＋骨＋正座、南の座布団）に差し替える
    for on in list(groups.get('mio', [])):
        if on in bpy.data.objects: bpy.data.objects.remove(bpy.data.objects[on])
    with bpy.data.libraries.load(os.environ['MIO']) as (src, dst):
        dst.objects = [n for n in src.objects if n.startswith('mio')]
    groups['mio'] = []
    for o in dst.objects:
        sc.collection.objects.link(o); groups['mio'].append(o.name)
sc.cycles.samples = samples; sc.render.resolution_x = 1920; sc.render.resolution_y = 1080; sc.render.resolution_percentage = pct
if flat:
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'; sc.view_settings.exposure = 0; sc.cycles.samples = 8; sc.cycles.use_denoising = False
    for o in bpy.data.objects:
        if o.type == 'LIGHT': o.hide_render = True
    sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0
    for m in bpy.data.materials:
        col = m.get('flat'); nt = m.node_tree
        if col is None: continue
        em = nt.nodes.new('ShaderNodeEmission'); em.inputs['Color'].default_value = (*col, 1)
        nt.links.new(em.outputs[0], nt.nodes['Material Output'].inputs['Surface'])
if flat:
    srgb = lambda c: [ (12.92*x if x <= 0.0031308 else 1.055*x**(1/2.4)-0.055) for x in c ]
    json.dump({m.name: srgb(m['flat']) for m in bpy.data.materials if m.get('flat') is not None}, open(os.path.join(out, 'flat_colors.json'), 'w'))
bpy.ops.object.camera_add(); cam = bpy.context.object; sc.camera = cam
for n in names:
    c = CAMS[n]
    for o in bpy.data.objects: o.hide_render = False if o.type != 'LIGHT' or not flat else True
    for g in c.get('hide', []):
        for on in groups.get(g, []): bpy.data.objects[on].hide_render = True
    cam.location = c['loc']; cam.data.lens = c['lens']; cam.data.shift_y = c.get('shift_y', 0.0)   # 水平のまま、枠だけ上下にずらす（小津の水平を守る）
    d = Vector(c['at']) - Vector(c['loc']); cam.rotation_mode = 'QUATERNION'; cam.rotation_quaternion = d.to_track_quat('-Z', 'Y')
    if c.get('roll'): cam.rotation_quaternion = cam.rotation_quaternion @ __import__('mathutils').Quaternion((0, 0, 1), math.radians(c['roll']))
    sc.render.filepath = os.path.join(out, n + ('_flat' if flat else '') + '.png')
    bpy.ops.render.render(write_still=True); print('== DONE', n)
