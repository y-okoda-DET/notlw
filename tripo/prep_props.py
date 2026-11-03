"""段階2: Tripo の小道具（車・シカの首・キツネ・キジ）を、家と外に置ける重さにする。
python3 tripo/prep_props.py [car,deer,...]
入力：$WORK/tripo/<名前>.glb（Tripo の書き出し。約200万三角形、4K の画像3枚）
出力：tripo/<名前>_prop.glb（三角形を TARGET まで減らし、色と法線の画像を SIZE に縮め、metallicRoughness は捨てる）
      $WORK/tripo/<名前>_views.png（正面・左・後ろ・右の4方向。頭が2つ、穴、つぶれがないかを見る）
寸法は Tripo の元のまま（底が0、高さ約1）。置くときの大きさは使う側（furnish.py など）で決める。"""
import os, sys, math
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'blender')); import paths as P
import bpy
from mathutils import Vector

TARGET = {'car': 60000, 'deer': 24000, 'fox': 20000, 'pheasant': 20000}
SIZE = {'car': 2048, 'deer': 1024, 'fox': 1024, 'pheasant': 1024}
SRC = f'{P.WORK}/tripo'

def prep(n):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f'{SRC}/{n}.glb')
    ms = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in ms: o.select_set(True)
    bpy.context.view_layer.objects.active = ms[0]
    if len(ms) > 1: bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    for e in [e for e in bpy.context.scene.objects if e != o]: bpy.data.objects.remove(e)
    o.parent = None
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    t0 = sum(len(p.vertices) - 2 for p in o.data.polygons)
    md = o.modifiers.new('dec', 'DECIMATE'); md.ratio = min(1.0, TARGET[n] / max(1, t0))
    bpy.ops.object.modifier_apply(modifier='dec')
    t1 = sum(len(p.vertices) - 2 for p in o.data.polygons)
    for p in o.data.polygons: p.use_smooth = True
    o.name = f'prop_{n}'
    m = o.data.materials[0]; m.name = f'prop_{n}'
    nt = m.node_tree; bsdf = next(x for x in nt.nodes if x.type == 'BSDF_PRINCIPLED')
    # metallic/roughness from Tripo is noise on a stuffed animal or a white car's paint: fixed values instead
    for sock in ('Metallic', 'Roughness'):
        for l in list(bsdf.inputs[sock].links): nt.links.remove(l)
    bsdf.inputs['Metallic'].default_value = 0.0
    bsdf.inputs['Roughness'].default_value = .45 if n == 'car' else .8
    for x in [x for x in nt.nodes if x.type == 'TEX_IMAGE']:
        if not x.outputs[0].links: nt.nodes.remove(x); continue
        img = x.image
        if img.size[0] > SIZE[n]: img.scale(SIZE[n], SIZE[n])
    for img in [i for i in bpy.data.images if i.users == 0]: bpy.data.images.remove(img)
    out = f'{P.TRIPO}/{n}_prop.glb'
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=False, export_image_format='JPEG',
                              export_jpeg_quality=88, export_apply=True)
    print('PROP', n, 'tris', t0, '->', t1, 'size', os.path.getsize(out) // 1024, 'KB', flush=True)
    return o

def views(n, o):
    s = bpy.context.scene; s.render.engine = 'CYCLES'; s.cycles.samples = 24; s.cycles.device = 'CPU'
    s.render.resolution_x = s.render.resolution_y = 420; s.view_settings.view_transform = 'Standard'
    w = bpy.data.worlds.new('w'); s.world = w; w.use_nodes = True; w.node_tree.nodes['Background'].inputs[1].default_value = 1.0
    lo = Vector([min(v.co[i] for v in o.data.vertices) for i in range(3)]); hi = Vector([max(v.co[i] for v in o.data.vertices) for i in range(3)])
    c = (lo + hi) / 2; r = (hi - lo).length * .5
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); s.collection.objects.link(cam); s.camera = cam
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = r * 2.1
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN')); s.collection.objects.link(sun)
    sun.data.energy = 2.5; sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    files = []
    # glTF: the model's front is +Y in Blender after import (glTF +Z); left = its left side, as the views were drawn
    for k, (lab, ang) in enumerate((('front', 0), ('left', 90), ('back', 180), ('right', 270))):
        a = math.radians(ang)
        d = Vector((math.sin(a), -math.cos(a), 0)) if False else Vector((-math.sin(a), -math.cos(a), 0))
        cam.location = c - d * r * 4 + Vector((0, 0, r * .25))
        cam.rotation_euler = (d * 1.0 + Vector((0, 0, -.06))).to_track_quat('-Z', 'Y').to_euler()
        f = f'{SRC}/{n}_{lab}.png'; s.render.filepath = f; bpy.ops.render.render(write_still=True); files.append(f)
    return files

if __name__ == '__main__':
    names = sys.argv[-1].split(',') if len(sys.argv) > 1 and not sys.argv[-1].endswith('.py') else list(TARGET)
    from PIL import Image
    for n in names:
        o = prep(n)
        fs = views(n, o)
        S = Image.new('RGB', (420 * 4, 420), (255, 255, 255))
        for i, f in enumerate(fs): S.paste(Image.open(f).convert('RGB'), (420 * i, 0))
        S.save(f'{SRC}/{n}_views.png')
    print('PROPS_DONE')
