"""Export the 23:00 hallway to Godot.
  env.glb        hall, props, rain, outside porch (static)
  <name>.glb     each character: rig + shells + bust + held phone, with one looping action "loop" (20 s)
  lights.json    every light (Godot rebuilds them; Blender watts are converted there)
Materials are flattened to what glTF carries: base-colour image (tints baked into the file), roughness,
emission. Anything else (box projection, vertex-colour mixes, procedurals) is baked to an image."""
import sys, os, math, json, random
sys.path.insert(0, '/home/claude/kf')
import bpy, numpy as np
from mathutils import Vector, Matrix
import lib, shot, chars as C, hall as Hm

OUT = '/home/claude/rules/assets'
TEXOUT = '/home/claude/kf/export_tex'
os.makedirs(OUT, exist_ok=True); os.makedirs(TEXOUT, exist_ok=True)
FPS = 24; LOOP = 20.0

# ------------------------------------------------------------------ materials
def principled(m):
    return m.node_tree.nodes.get('Principled BSDF') if m and m.use_nodes else None

def is_simple(m):
    """True when the material is (image ->) Base Color on UV, or a flat colour."""
    p = principled(m)
    if p is None: return False
    for n in m.node_tree.nodes:
        if n.type in ('TEX_NOISE', 'TEX_WAVE', 'VERTEX_COLOR', 'NEW_GEOMETRY', 'VECT_TRANSFORM', 'MAP_RANGE'): return False
        if n.type == 'TEX_COORD':
            for l in n.outputs['Object'].links: return False
            for l in n.outputs['Generated'].links: return False
        if n.type == 'TEX_IMAGE' and n.projection == 'BOX': return False
    return True

def flatten_tint(m):
    """image -> Mix(MULTIPLY, tint) -> Base Color  becomes  tinted image -> Base Color. Mapping scale moves into UVs later."""
    nt = m.node_tree; N = nt.nodes; p = principled(m)
    mix = next((n for n in N if n.type == 'MIX' and n.data_type == 'RGBA'), None)
    img = next((n for n in N if n.type == 'TEX_IMAGE'), None)
    if img is None: return
    tint = (1, 1, 1)
    if mix is not None:
        tint = tuple(mix.inputs['B'].default_value[:3])
    if any(abs(t - 1) > 1e-3 for t in tint):
        src = img.image; w, h = src.size
        px = np.array(src.pixels[:], dtype=np.float32).reshape(h, w, 4)
        px[..., :3] *= np.array(tint, dtype=np.float32)
        px = np.clip(px, 0, 1)
        name = f'{m.name}_tinted'
        im = bpy.data.images.new(name, w, h, alpha=False); im.pixels.foreach_set(px.ravel())
        im.filepath_raw = f'{TEXOUT}/{name}.png'; im.file_format = 'PNG'; im.save()
        img.image = im
    nt.links.new(img.outputs['Color'], p.inputs['Base Color'])
    for n in list(N):
        if n.type in ('MIX', 'BUMP'): N.remove(n)

def bake_object(o, size=1024):
    """Bake the object's base colour (diffuse, colour pass only) into a fresh UV layout."""
    me = o.data
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    uv = me.uv_layers.new(name='bake'); me.uv_layers.active = uv
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=.01)
    bpy.ops.object.mode_set(mode='OBJECT')
    img = bpy.data.images.new(f'{o.name}_bake', size, size, alpha=False)
    for m in me.materials:
        if m is None: continue
        n = m.node_tree.nodes.new('ShaderNodeTexImage'); n.image = img; n.name = '_bake_target'
        m.node_tree.nodes.active = n
    s = bpy.context.scene; s.render.engine = 'CYCLES'; s.cycles.samples = 4
    s.render.bake.use_pass_direct = False; s.render.bake.use_pass_indirect = False; s.render.bake.use_pass_color = True
    s.render.bake.margin = 6
    bpy.ops.object.bake(type='DIFFUSE')
    img.filepath_raw = f'{TEXOUT}/{o.name}_bake.png'; img.file_format = 'PNG'; img.save()
    rough = .8
    for m in me.materials:
        if m and principled(m): rough = principled(m).inputs['Roughness'].default_value
    nm = bpy.data.materials.new(f'{o.name}_baked'); nm.use_nodes = True
    p = nm.node_tree.nodes['Principled BSDF']; p.inputs['Roughness'].default_value = rough
    t = nm.node_tree.nodes.new('ShaderNodeTexImage'); t.image = img
    uvn = nm.node_tree.nodes.new('ShaderNodeUVMap'); uvn.uv_map = 'bake'
    nm.node_tree.links.new(uvn.outputs[0], t.inputs[0]); nm.node_tree.links.new(t.outputs[0], p.inputs['Base Color'])
    me.materials.clear(); me.materials.append(nm)
    # keep only the bake UV so glTF TEXCOORD_0 is the right one
    for u in list(me.uv_layers):
        if u.name != 'bake': me.uv_layers.remove(u)

def simplify_materials():
    for m in bpy.data.materials:
        if m.use_nodes and is_simple(m): flatten_tint(m)
    todo = []
    for o in bpy.data.objects:
        if o.type != 'MESH': continue
        if any(m is not None and not is_simple(m) for m in o.data.materials): todo.append(o)
    for o in todo:
        # apply non-armature modifiers first so the bake matches the exported shape
        bake_object(o, 2048 if o.name.endswith('_head') else 1024)
    return todo

# ------------------------------------------------------------------ baked bounce light
NO_LM = ('door_', 'doorglass', 'rain', 'slitglass', 'fres_lens', 'recled', 'nphone', 'kphone', 'phone_glow', 'lcd', 'cable', 'ledface', 'fresnel', 'barndoor', 'yoke', 'cscol', 'csleg')

def bake_bounce(env_objs, size=2048, samples=256):
    """Join the static set into one mesh, give it a second UV ('lm'), and bake the indirect diffuse light
    (no albedo) that Cycles computes from the scene's lights. Godot adds albedo * lightmap as emission."""
    statics = [o for o in env_objs if o.type == 'MESH' and not o.name.startswith(NO_LM)]
    bpy.ops.object.select_all(action='DESELECT')
    for o in statics: o.select_set(True)
    bpy.context.view_layer.objects.active = statics[0]
    bpy.ops.object.convert(target='MESH')                  # apply modifiers (auto smooth etc.)
    for o in statics:                                      # first UV layer of every object becomes 'UVMap'
        if len(o.data.uv_layers) == 0: o.data.uv_layers.new(name='UVMap')
        o.data.uv_layers[0].name = 'UVMap'
        while len(o.data.uv_layers) > 1: o.data.uv_layers.remove(o.data.uv_layers[1])
    bpy.ops.object.join()
    j = bpy.context.view_layer.objects.active; j.name = 'env_static'
    me = j.data
    lm = me.uv_layers.new(name='lm'); me.uv_layers.active = lm
    me.uv_layers['UVMap'].active_render = True
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=.004)
    bpy.ops.object.mode_set(mode='OBJECT')
    img = bpy.data.images.new('lightmap', size, size, alpha=False, float_buffer=True)
    for m in me.materials:
        if m is None: continue
        n = m.node_tree.nodes.new('ShaderNodeTexImage'); n.image = img; n.name = '_lm'
        uvn = m.node_tree.nodes.new('ShaderNodeUVMap'); uvn.uv_map = 'lm'; m.node_tree.links.new(uvn.outputs[0], n.inputs[0])
        m.node_tree.nodes.active = n
    s = bpy.context.scene; s.render.engine = 'CYCLES'; s.cycles.samples = samples
    s.cycles.max_bounces = 6; s.cycles.diffuse_bounces = 4
    b = s.render.bake; b.use_pass_direct = False; b.use_pass_indirect = True; b.use_pass_color = False; b.margin = 8
    bpy.ops.object.select_all(action='DESELECT'); j.select_set(True); bpy.context.view_layer.objects.active = j
    import time; t = time.time()
    if os.environ.get('SKIP_LM'):   # only the people changed: the lightmap on disk still matches this set (same mesh -> same 'lm' UVs)
        print('lightmap: kept the one on disk')
    else:
        bpy.ops.object.bake(type='DIFFUSE')
        print('lightmap baked in', round(time.time() - t), 's')
        img.filepath_raw = f'{OUT}/lightmap.exr'; img.file_format = 'OPEN_EXR'
        img.save()
    for m in me.materials:
        if m is None: continue
        for n in [n for n in m.node_tree.nodes if n.name == '_lm' or (n.type == 'UVMAP' and n.uv_map == 'lm')]: m.node_tree.nodes.remove(n)
    return j

# ------------------------------------------------------------------ lights
def dump_lights():
    L = []
    for o in [o for o in bpy.data.objects if o.type == 'LIGHT']:
        d = o.data; mw = o.matrix_world
        fwd = (mw.to_3x3() @ Vector((0, 0, -1))).normalized()
        e = dict(name=o.name, type=d.type, pos=list(mw.translation), dir=list(fwd), watts=d.energy, color=list(d.color))
        if d.type == 'SPOT': e.update(angle=math.degrees(d.spot_size) / 2, blend=d.spot_blend, radius=d.shadow_soft_size)
        if d.type == 'AREA': e.update(size=[d.size, d.size_y], spread=math.degrees(d.spread))
        if d.type == 'POINT': e.update(radius=d.shadow_soft_size)
        if d.type == 'SUN': e.update(angle=math.degrees(d.angle))
        e['parent'] = o.parent.name if o.parent else None
        e['parent_bone'] = o.parent_bone if o.parent and o.parent_type == 'BONE' else None
        L.append(e)
    json.dump(L, open(f'{OUT}/lights.json', 'w'), indent=1)
    for o in [o for o in bpy.data.objects if o.type == 'LIGHT']: bpy.data.objects.remove(o)

# ------------------------------------------------------------------ animation
# Everything that runs all the time is built from whole cycles of the 20 s loop, so the loop has no seam
# (the old noise was not periodic: at 20 s every head jumped back to where it was at 0 s).
def _cyc(f):
    return max(1, round(f * LOOP)) / LOOP          # nearest frequency (Hz) with whole cycles in the loop

def wob(t, f, ph=0.0):
    return math.sin(t * _cyc(f) * math.tau + ph)

def noise1(t, seed, rate=1.0):
    """smooth 1-D drift from three sines, each a whole number of cycles per loop"""
    w = lambda radps: _cyc(radps * rate / math.tau) * math.tau
    return (math.sin(t * w(.37) + seed) * .5 + math.sin(t * w(.91) + seed * 2.1) * .3 + math.sin(t * w(1.73) + seed * 3.7) * .2)

def snap(t, t0, dur=.09):
    """a pose change that starts at t0: fast, but eased in and out (no one-frame jerk). Min 0.3 s."""
    dur = max(dur, .3)
    x = min(1, max(0, (t - t0) / dur))
    return x * x * x * (x * (x * 6 - 15) + 10)

def ease(x): x = max(0, min(1, x)); return x * x * (3 - 2 * x)

KNOCKS = (6.0, 6.28, 6.56, 11.0, 11.2, 11.4, 11.6)

def axis_local(rig, v): return (rig.matrix_world.to_3x3().normalized() @ Vector(v))

def idle(rig, t, seed, breath=.24, amp=1.0, rate=1.0):
    """breathing, weight shift, small head drift: always on, for everyone"""
    C.rot_world(rig, 'spine_02', axis_local(rig, (1, 0, 0)), -1.1 * amp * wob(t, breath, seed))
    C.rot_world(rig, 'pelvis', axis_local(rig, (0, 1, 0)), 1.4 * amp * noise1(t, seed, .25 * rate))
    C.rot_world(rig, 'neck_01', axis_local(rig, (0, 0, 1)), 2.0 * amp * noise1(t, seed + 5, .6 * rate))
    C.rot_world(rig, 'head', axis_local(rig, (1, 0, 0)), 1.5 * amp * noise1(t, seed + 9, .8 * rate))

def hit(t, t0, rise=.06, fall=.35):
    """a jolt: fast eased rise, slower decay"""
    if t < t0: return 0.0
    x = (t - t0) / rise
    return (x * x * (3 - 2 * x)) if x < 1 else math.exp(-(t - t0 - rise) / fall)

def jolts(t, fall=.35):
    return min(1.0, sum(hit(t, k, fall=fall) for k in KNOCKS))

def pose_kiryu(k, t):
    kl = lambda v: C.local(k, v)
    # reading his phone. The first series of knocks: he hears it but only lifts his head a beat after it ends, slowly,
    # and goes back to the phone; the second series brings his head up at once and it stays up
    look = snap(t, 7.3, .9) * (1 - snap(t, 10.0, 1.2)) + snap(t, 11.0, .35)
    look = min(1.0, look)
    j = jolts(t) * (t > 10.9)
    C.arm_to(k, 'l', kl((.2, -.02, .84)), Vector((.3, .3, 0)))
    C.rot_world(k, 'neck_01', axis_local(k, (1, 0, 0)), 18 - 30 * look - 3 * j)
    C.rot_world(k, 'head', (0, 0, 1), 22 * look)
    C.rot_world(k, 'spine_03', axis_local(k, (1, 0, 0)), -2 * j)
    # the phone first, the hand to it (chars.hold_phone): screen toward his eyes, fingers behind it, measured
    eyes = C.bone_head(k, 'head') + C.local(k, (0, -.08, .05)) - C.local(k, (0, 0, 0))
    C.phone_grip3(k, 'r', shot.S['kphone'], eyes, kl((-.02, -.3 + .04 * look, 1.22 - .14 * look + .01 * noise1(t, 3))), Vector((-.3, .3, -.5)))
    C.grip(k, 'l', .3)   # fingers wrap the phone's back, thumb lies along the screen edge
    idle(k, t, 1.0, breath=.21, amp=1 - .7 * look, rate=.8)

TAIGA_WRIST = .095   # the wrists' plane, this far in front of the door's line (palms flat on the door)

def pose_taiga(tg, t):
    """Pushing the door shut, laid out from the reference photos: the whole body a diagonal (feet back, leaning in,
    set in shot.build), palms flat on the door at eye height, fingers up and spread, hands wider than the shoulders,
    arms almost straight with the elbows down, head turned over his left shoulder toward the hall. The first knock
    goes straight into his arms; every knock jolts him; the second series makes him lean harder."""
    press = snap(t, 6.0, .3) * (1 - ease((t - 16.5) / 3.0)) + .6 * snap(t, 11.0, .3) * (1 - ease((t - 17.0) / 3.0))
    press = min(1.0, press)
    j = jolts(t, .25)
    C.rot_world(tg, 'spine_01', axis_local(tg, (1, 0, 0)), -3 * press + 3 * j)
    C.rot_world(tg, 'spine_03', axis_local(tg, (1, 0, 0)), -3 * press)
    C.rot_world(tg, 'neck_01', (0, 0, 1), 26 + 6 * press + 2 * j)
    C.rot_world(tg, 'head', (0, 0, 1), 36 + 8 * press + 4 * j)
    C.rot_world(tg, 'neck_01', axis_local(tg, (1, 0, 0)), 6 * press)
    idle(tg, t, 2.0, breath=.31 + .2 * press, amp=1 + .8 * press, rate=1.25)
    o = tg.matrix_world.translation
    n = axis_local(tg, (0, -1, 0)); n.z = 0; n.normalize()          # toward the door
    ax = axis_local(tg, (1, 0, 0)); ax.z = 0; ax.normalize()
    door = Hm.YF - TAIGA_WRIST                                        # the wrists' plane (world y)
    eye_z = C.bone_head(tg, 'head').z + .07
    lean = math.degrees(tg.rotation_euler.x)                           # the feet stay flat on the floor
    for s_ in ('l', 'r'): C.rot_world(tg, f'foot_{s_}', ax, -lean)
    for side, sx in (('l', 1), ('r', -1)):
        w = o + ax * (sx * .33) + Vector((0, 0, eye_z - .09 + .015 * press - .008 * sx * noise1(t, 2, .4) - o.z))
        w += n * ((door - w.y) / n.y - .004 * j)
        C.arm_to(tg, side, w, Vector((sx * .12, .1, -1.0)))
        up = (Vector((0, 0, 1)) + ax * (sx * .18)).normalized()
        pz = n * C.palm_sign(tg, side)
        C.set_hand_frame(tg, side, up, pz); C.settle_forearm(tg, side); C.set_hand_frame(tg, side, up, pz)
        C.grip(tg, side, .0, thumb=.0)
        for f, a in (('index', -6), ('middle', 0), ('ring', 5), ('pinky', 11)):
            C.rot_world(tg, f'{f}_01_{side}', n, sx * a)

def pose_natsuki(n, t, sx, Y):
    knock = max(math.exp(-((t - k) / .05) ** 2) for k in KNOCKS)
    up = snap(t, 5.6, .35) * (1 - snap(t, 12.2, .6))
    hand = Vector((sx, Y + .01 + .05 * up - .06 * knock * up, 1.32 + .1 * up))
    C.arm_to(n, 'l', hand, Vector((.25, .2, -.4)))
    C.arm_to(n, 'r', Vector((sx + .1, Y + .14, 1.02 + .02 * wob(t, .5))), Vector((-.3, .2, -.4)))
    C.rot_world(n, 'neck_01', (1, 0, 0), 8 + 6 * up)
    C.grip(n, 'r', .8); C.grip(n, 'l', .15 + .5 * knock * up)
    idle(n, t, 3.0, breath=.36 + .15 * up, amp=1.3, rate=1.1)

def bake_action(rig, fn):
    rig.animation_data_create()
    act = bpy.data.actions.new(f'{rig.name}_loop'); rig.animation_data.action = act
    n = int(LOOP * FPS)
    prev = {}
    for f in range(n + 1):
        t = f / FPS
        C.reset_pose(rig); fn(t)
        for pb in rig.pose.bones:
            # keep each bone's quaternion on the same hemisphere as the previous frame: a sign flip between two keys
            # would interpolate through zero (the mesh blows up to infinity in the exported animation)
            q = pb.rotation_quaternion.copy()
            if pb.name in prev and q.dot(prev[pb.name]) < 0: q = -q; pb.rotation_quaternion = q
            prev[pb.name] = q
            pb.keyframe_insert('rotation_quaternion', frame=f + 1)
    # linear between keys; the snaps already live in the sampled data
    try:
        curves = act.fcurves
    except AttributeError:
        curves = [fc for l in act.layers for s in l.strips for cb in s.channelbags for fc in cb.fcurves]
    for fc in curves:
        for kp in fc.keyframe_points: kp.interpolation = 'LINEAR'
    bpy.context.scene.frame_start = 1; bpy.context.scene.frame_end = n + 1
    return act

# ------------------------------------------------------------------ export
def export(path, objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True,
                              export_animations=True, export_animation_mode='ACTIVE_ACTIONS', export_yup=True,
                              export_image_format='AUTO', export_force_sampling=True, export_def_bones=False)

def descendants(o):
    out = [o]
    for c in o.children: out += descendants(c)
    return out

if __name__ == '__main__':
    shot.build()
    S = shot.S
    shot.at(0.0)
    for name in ('haze', 'cam'):
        for o in [o for o in bpy.data.objects if o.name.startswith(name)]: bpy.data.objects.remove(o)
    # held phones follow the hand bones
    for ph, rig, side in ((S['kphone'], S['k'], 'r'), (S['nphone'], S['n'], 'r')):
        mw = ph.matrix_world.copy(); ph.parent = rig; ph.parent_type = 'BONE'; ph.parent_bone = f'hand_{side}'
        bpy.context.view_layer.update(); ph.matrix_world = mw
    baked = simplify_materials()
    print('baked', [o.name for o in baked])
    _chars = set()
    for r in (S['k'], S['t'], S['n']): _chars |= set(descendants(r))
    bake_bounce([o for o in bpy.data.objects if o not in _chars])
    dump_lights()
    sx, Y = S['slit_x'], Hm.YF
    rigs = {'kiryu': (S['k'], lambda t: pose_kiryu(S['k'], t)), 'taiga': (S['t'], lambda t: pose_taiga(S['t'], t)),
            'natsuki': (S['n'], lambda t: pose_natsuki(S['n'], t, sx, Y))}
    for name, (rig, fn) in rigs.items():
        bake_action(rig, fn)
    # place phones again at frame 1 pose
    for name, (rig, fn) in rigs.items():
        export(f'{OUT}/{name}.glb', descendants(rig))
    char_objs = set()
    for name, (rig, fn) in rigs.items(): char_objs |= set(descendants(rig))
    env = [o for o in bpy.data.objects if o not in char_objs and o.type in ('MESH', 'CURVE', 'EMPTY')]
    if os.environ.get('SKIP_LM'): print('env.glb: kept')
    else: export(f'{OUT}/env.glb', env)
    import shutil
    os.makedirs(f'{OUT}/faces', exist_ok=True)
    for k in ('natsuki', 'kiryu', 'taiga', 'makoto'):
        for st in ('open', 'closed', 'talk'):
            src = f'{lib.FACES_S}/{k}_{st}.png'
            if k == 'natsuki' and st == 'talk': src = f'{lib.FACES_S}/natsuki_talk_open.png'
            if k in C.TRIPO: src = f'/home/claude/tripo/{k}_{st}.png'   # tinted to the Tripo skin
            ht = f'/home/claude/tripo/{k}_headtex_{st}.png'
            if os.path.exists(ht):   # face baked into the head texture: ship the whole head texture per state, at 2048
                from PIL import Image as _PI
                _PI.open(ht).convert('RGB').resize((2048, 2048), _PI.LANCZOS).save(f'{OUT}/faces/{k}_{st}.jpg', quality=92)
                if os.path.exists(f'{OUT}/faces/{k}_{st}.png'): os.remove(f'{OUT}/faces/{k}_{st}.png')
                continue
            shutil.copy(src, f'{OUT}/faces/{k}_{st}.png')
    json.dump(dict(slit_x=sx, YF=Y, ZG=Hm.ZG, cam0=list(shot.CAM0), fps=FPS, loop=LOOP, knocks=KNOCKS,
                   mark=[.35, 3.75, 0]), open(f'{OUT}/scene.json', 'w'), indent=1)
    print('EXPORTED')
