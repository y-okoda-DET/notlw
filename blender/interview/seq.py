# 決めたカメラワークを、本物の二人の部屋で一つの流れとして描く。python seq.py -- <shot> <outdir> [samples] [pct]
# 1秒 12 コマ。止まった画は1枚だけ描いて、つなぐときに伸ばす（hold）。
import bpy, json, sys, os, math
from mathutils import Vector, Quaternion
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import build as B
a = sys.argv[sys.argv.index('--') + 1:]
shot, out = a[0], a[1]; samples = int(a[2]) if len(a) > 2 else 12; pct = int(a[3]) if len(a) > 3 else 40
from cuts import *
if shot == 'list': print(' '.join(SHOTS)); sys.exit(0)
B.build(sun=True); sc = bpy.context.scene; groups = json.loads(sc['groups'])
for env, pre, grp in (('KIKITE', 'kikite', 'people'), ('MIO', 'mio', 'mio')):
    if not os.environ.get(env): continue
    for on in list(groups.get(grp, [])):
        if on in bpy.data.objects: bpy.data.objects.remove(bpy.data.objects[on])
    with bpy.data.libraries.load(os.environ[env]) as (src, dst):
        dst.objects = [n for n in src.objects if n.startswith(pre)]
    groups[grp] = []
    for o in dst.objects: sc.collection.objects.link(o); groups[grp].append(o.name)
sc.cycles.samples = samples; sc.render.resolution_x = 1920; sc.render.resolution_y = 1080; sc.render.resolution_percentage = pct
bpy.ops.object.camera_add(); cm = bpy.context.object; sc.camera = cm
od = os.path.join(out, shot); os.makedirs(od, exist_ok=True); meta = []
for i, f in enumerate(SHOTS[shot]):
    for o in bpy.data.objects:
        if o.type != 'LIGHT': o.hide_render = False
    for g in f.get('hide', ()):
        for on in groups.get(g, []):
            if on in bpy.data.objects: bpy.data.objects[on].hide_render = True
    cm.location = f['loc']; cm.data.lens = f['lens']; cm.data.shift_y = f.get('shift_y', 0.0)
    q = (Vector(f['at']) - Vector(f['loc'])).to_track_quat('-Z', 'Y')
    if f.get('roll'): q = q @ Quaternion((0, 0, 1), math.radians(f['roll']))
    cm.rotation_mode = 'QUATERNION'; cm.rotation_quaternion = q
    cm.data.dof.use_dof = 'dof' in f
    if 'dof' in f: cm.data.dof.focus_distance = f['dof']; cm.data.dof.aperture_fstop = f['fstop']
    if f.get('flat') and not sc.get('flat_done'):   # 平たくなる：光と影を抜いて、物の色だけ（render_cams.py の flat と同じ）
        sc['flat_done'] = 1
        sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'; sc.view_settings.exposure = 0; sc.cycles.use_denoising = False
        for o in bpy.data.objects:
            if o.type == 'LIGHT': o.hide_render = True
        sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0
        for m in bpy.data.materials:
            col = m.get('flat'); nt = m.node_tree
            if col is None or nt is None: continue
            em = nt.nodes.new('ShaderNodeEmission'); em.inputs['Color'].default_value = (*col, 1)
            nt.links.new(em.outputs[0], nt.nodes['Material Output'].inputs['Surface'])
    if f.get('flat'):
        for o in bpy.data.objects:
            if o.type == 'LIGHT': o.hide_render = True
    if 'sway' in f:   # 葉の影の揺れ（sway.py と同じ動き）
        lv = bpy.data.objects['tree_leaves']; lv.rotation_mode = 'XYZ'; lv0 = lv.get('base', None)
        if lv0 is None: lv['base'] = list(lv.location); lv0 = lv['base']
        t = 2 * math.pi * f['sway']; lv.rotation_euler = (0.02 * math.sin(t), 0.035 * math.sin(t + 0.7), 0.0)
        lv.location = Vector(lv0) + Vector((0.03 * math.sin(t + 1.3), 0, 0))
    sc.render.filepath = os.path.join(od, f'{i:03d}.png'); bpy.ops.render.render(write_still=True)
    meta.append(dict(hold=f.get('hold', 1), blur=f.get('blur', 0), n5=f.get('n5'), post=f.get('post')))
json.dump(meta, open(os.path.join(od, 'meta.json'), 'w')); print('== DONE', shot, len(meta))
