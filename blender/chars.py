"""Characters built from the MakeHuman base mesh (MPFB2, CC0 assets) + game_engine rig (Godot-compatible).
Clothes are offset shells of the body that share its skin weights; the head is the photo bust from lib.bust,
parented to the head bone. Poses are given as world-space aim targets per bone chain."""
import sys, math, importlib
sys.path.insert(0, '/home/claude/kf')
import bpy, bmesh, addon_utils
from mathutils import Vector, Matrix, Quaternion
import lib

_mp = {}
def mpfb():
    if not _mp:
        addon_utils.enable('bl_ext.user_default.mpfb', default_set=True)
        b = 'bl_ext.user_default.mpfb.'
        _mp['HS'] = importlib.import_module(b + 'services.humanservice').HumanService
        _mp['TS'] = importlib.import_module(b + 'services.targetservice').TargetService
    return _mp['HS'], _mp['TS']

# MakeHuman age macro: 0 -> 1y, .1875 -> 11y, .5 -> 25y, 1 -> 90y
def age01(years):
    if years <= 25: return .1875 + (years - 11) / 14 * .3125
    return .5 + (years - 25) / 65 * .5

SPEC = {
    'mio':     dict(g=.0, age=20, h=1.60, mus=.42, wt=.42, prop=.6, cup=.45),
    'natsuki': dict(g=.0, age=20, h=1.58, mus=.42, wt=.45, prop=.6, cup=.5),
    'natsuki_s': dict(g=.0, age=20, h=1.58, mus=.42, wt=.45, prop=.6, cup=.5),
    'makoto':  dict(g=.0, age=19, h=1.55, mus=.4, wt=.42, prop=.55, cup=.45),
    'kiryu':   dict(g=1., age=22, h=1.76, mus=.5, wt=.42, prop=.65),
    'taiga':   dict(g=1., age=21, h=1.83, mus=.72, wt=.68, prop=.5),
    'yota':    dict(g=1., age=21, h=1.72, mus=.5, wt=.45, prop=.6),
}

def _region(rig, mesh, bones, thresh=.45):
    """Vertex indices whose summed weight to `bones` exceeds thresh."""
    gi = {g.index: g.name for g in mesh.vertex_groups}
    out = set()
    for v in mesh.data.vertices:
        w = sum(g.weight for g in v.groups if gi.get(g.group) in bones)
        if w >= thresh: out.add(v.index)
    return out

ARM = ['clavicle_l', 'upperarm_l', 'lowerarm_l', 'clavicle_r', 'upperarm_r', 'lowerarm_r']
UPPER = ['upperarm_l', 'upperarm_r', 'clavicle_l', 'clavicle_r']
TORSO = ['spine_01', 'spine_02', 'spine_03']
LEGS = ['pelvis', 'thigh_l', 'calf_l', 'thigh_r', 'calf_r']
FEET = ['foot_l', 'ball_l', 'foot_r', 'ball_r']
HEAD = ['head']

def _shell(name, body, keep, offset, mat, rig, solid=.004, relax=0):
    """Copy of the body restricted to `keep`, pushed out along normals, sharing weights + armature."""
    me = body.data.copy(); ob = bpy.data.objects.new(name, me); lib.link(ob)
    ob.matrix_world = body.matrix_world
    for g in body.vertex_groups: pass
    bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
    kill = [v for v in bm.verts if v.index not in keep]
    bmesh.ops.delete(bm, geom=kill, context='VERTS')
    bm.normal_update()
    # straighten the zig-zag edge left by the vertex selection (hem, cuffs, collar)
    for _ in range(25):
        nb = {}
        for v in bm.verts:
            if v.is_boundary:
                ns = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
                if len(ns) == 2: nb[v] = (ns[0].co + ns[1].co) / 2
        for v, c in nb.items(): v.co = v.co.lerp(c, .5)
    bm.normal_update()
    for v in bm.verts: v.co += v.normal * offset
    for _ in range(relax):   # drape: Laplacian relax that keeps the boundary, so fabric bridges over anatomy
        bmesh.ops.smooth_vert(bm, verts=[v for v in bm.verts if not v.is_boundary], factor=.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.normal_update()
    for v in bm.verts: v.co += v.normal * offset * .3
    bm.to_mesh(me); bm.free()
    if me.shape_keys:
        ob.shape_key_clear()
    for m in list(ob.modifiers): ob.modifiers.remove(m)
    ob.data.materials.clear(); ob.data.materials.append(mat)
    am = ob.modifiers.new('rig', 'ARMATURE'); am.object = rig
    sm = ob.modifiers.new('smooth', 'CORRECTIVE_SMOOTH'); sm.iterations = 6; sm.smooth_type = 'LENGTH_WEIGHTED'
    so = ob.modifiers.new('solid', 'SOLIDIFY'); so.thickness = solid; so.offset = 1
    sd = ob.modifiers.new('sub', 'SUBSURF'); sd.levels = 1; sd.render_levels = 1
    for p in me.polygons: p.use_smooth = True
    ob.parent = rig; ob.matrix_parent_inverse = rig.matrix_world.inverted()
    return ob

def make(key, top, pants, socks, skin=(.78, .58, .47), sleeve='long', loose=1.0, label=None, open_eyes=True, head_key=None, drawn=True):
    HS, TS = mpfb()
    sp = SPEC[key]; label = label or key
    macro = TS.get_default_macro_info_dict()
    macro.update(gender=sp['g'], age=age01(sp['age']), muscle=sp['mus'], weight=sp['wt'], proportions=sp['prop'],
                 height=.5, cupsize=sp.get('cup', .5), firmness=.5)
    macro['race'] = dict(asian=1.0, caucasian=0.0, african=0.0)
    body = HS.create_human(macro_detail_dict=macro)
    body.name = f'{label}_body'
    # proportions: narrower shoulders, smaller hands, a little more neck (these read too heavy under the print)
    from bl_ext.user_default.mpfb.services.locationservice import LocationService as _LS
    troot = _LS.get_mpfb_data('targets')
    fem = sp['g'] < .5
    tweaks = [('torso/measure-shoulder-dist-decr', .8 if fem else .85), ('torso/torso-scale-horiz-decr', .25 if fem else .15),
              ('hands/l-hand-scale-decr', .7 if fem else .55), ('hands/r-hand-scale-decr', .7 if fem else .55),
              ('neck/measure-neck-height-incr', .45 if fem else .25)]
    for side in 'lr':
        tweaks.append((f'arms/{side}-upperarm-shoulder-muscle-decr', .5))
        tweaks.append((f'arms/{side}-upperarm-scale-horiz-decr', .3 if fem else .15))
    import os as _os
    for rel, wgt in tweaks:
        path = f'{troot}/{rel}.target.gz'
        if _os.path.exists(path): TS.load_target(body, path, weight=wgt, name=rel.split('/')[-1])
        else: print('missing target', rel)
    rig = HS.add_builtin_rig(body, 'game_engine'); rig.name = f'{label}_rig'
    # bake shape keys into the mesh so the shells (copies) match the deformed body
    bpy.context.view_layer.objects.active = body
    if body.data.shape_keys:
        body.shape_key_add(name='mix', from_mix=True)
        mix = body.data.shape_keys.key_blocks['mix'].data
        co = [v.co.copy() for v in mix]
        body.shape_key_clear()
        for v, c in zip(body.data.vertices, co): v.co = c
    # drop helper geometry permanently
    gi = {g.name: g.index for g in body.vertex_groups}
    if 'body' in gi:
        bm = bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table()
        dl = body.data.vertices
        kill = [bm.verts[v.index] for v in dl if not any(g.group == gi['body'] and g.weight > .5 for g in v.groups)]
        bmesh.ops.delete(bm, geom=kill, context='VERTS'); bm.to_mesh(body.data); bm.free()
    for m in list(body.modifiers):
        if m.type == 'MASK': body.modifiers.remove(m)
    # uniform scale to target height
    bpy.context.view_layer.update()
    zs = [(body.matrix_world @ v.co).z for v in body.data.vertices]
    k = sp['h'] / (max(zs) - min(zs))
    rig.scale = (k, k, k)
    bpy.context.view_layer.update()
    # regions
    head = _region(rig, body, HEAD, .3)
    torso = _region(rig, body, TORSO + UPPER + ['neck_01'], .35) - head
    neck = _region(rig, body, ['neck_01'], .5)
    arms_lo = _region(rig, body, ['lowerarm_l', 'lowerarm_r'], .5)
    hands = _region(rig, body, ['hand_l', 'hand_r'] + [b for b in rig.data.bones.keys() if b[:-2] in ('index_01', 'index_02', 'index_03', 'middle_01', 'middle_02', 'middle_03', 'pinky_01', 'pinky_02', 'pinky_03', 'ring_01', 'ring_02', 'ring_03', 'thumb_01', 'thumb_02', 'thumb_03')], .3)
    legs = _region(rig, body, LEGS, .35)
    feet = _region(rig, body, FEET, .3)
    V = body.data.vertices
    hem = sp['h'] * .54; waist = hem + .05
    arm_all = _region(rig, body, ARM, .3) - hands
    core = {v.index for v in V if v.index not in head and v.index not in hands and v.index not in feet}
    shirt = {i for i in core if V[i].co.z * k > hem and (sleeve == 'long' or i not in arms_lo)}
    shirt -= {i for i in (_region(rig, body, ['hand_l', 'hand_r'], .08))}
    neck_line = sp['h'] * .838
    shirt = {i for i in shirt if V[i].co.z * k < neck_line}
    pants_r = {i for i in core if V[i].co.z * k < waist and i not in arm_all and i not in _region(rig, body, ['hand_l', 'hand_r', 'lowerarm_l', 'lowerarm_r'], .05)}
    ankle = sp['h'] * .055
    pants_r = {i for i in pants_r if V[i].co.z * k > ankle}
    feet = {v.index for v in V if v.co.z * k <= ankle + .01}
    # skin material on the body
    if drawn:
        skin = lib.face_skin(head_key or key)
    skm = lib.mat_basic(f'{label}_skin', skin, rough=.6, sss=.08)
    body.data.materials.clear(); body.data.materials.append(skm)
    for p in body.data.polygons: p.use_smooth = True
    _shell(f'{label}_shirt', body, shirt, .007 * loose, top, rig, .004, relax=int(6 * loose))
    _shell(f'{label}_pants', body, pants_r, .009, pants, rig, .004, relax=6)
    _shell(f'{label}_socks', body, feet, .008, socks, rig, .003, relax=40)
    # hide body under clothes, and the head (replaced by the photo bust)
    # the drawn head brings its own neck down inside the collar, so the body's neck goes too
    body_neck = {v.index for v in V if v.co.z * k > neck_line - .045 and v.index not in arm_all and v.index not in hands}
    hide = ({i for i in shirt if V[i].co.z * k < neck_line - .03} | pants_r | head | feet | (body_neck if drawn else set()))
    bm = bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in hide if i < len(bm.verts)], context='VERTS')
    bm.to_mesh(body.data); bm.free()
    # photo bust on the head bone
    hk = head_key or key
    bust = lib.bust2(hk, name=label, ext=.075, flare=.035 if fem else .05) if drawn else lib.bust(hk, open_eyes, name=label)
    hsc = 1.0 if drawn else .93
    hb = rig.data.bones['head']
    # bone space: Y along the bone; place neck base of the bust at the head bone's head
    bust.matrix_parent_inverse = Matrix.Identity(4)
    bpy.context.view_layer.update()
    # align: bust local Z -> bone +Y, bust local -Y (face) -> body front (-Y world)
    nb = rig.data.bones['neck_01']
    mw_n = rig.matrix_world @ nb.matrix_local
    base = mw_n.translation.lerp(rig.matrix_world @ nb.tail_local, .25)
    bust.matrix_world = Matrix.Translation(base + Vector((0, .006, -.018))) @ Matrix.Diagonal((hsc, hsc, hsc, 1))
    if drawn:
        # skinned to head + neck_01 so the neck bends instead of the whole head swinging through the collar
        bpy.context.view_layer.update()
        mw = bust.matrix_world.copy()
        bust.data.transform(mw); bust.matrix_world = Matrix.Identity(4)
        hz = (rig.matrix_world @ hb.head_local).z
        gh = bust.vertex_groups.new(name='head'); gn = bust.vertex_groups.new(name='neck_01')
        for v in bust.data.vertices:
            t = min(1, max(0, (v.co.z - (hz - .035)) / .05)); t = t * t * (3 - 2 * t)
            if t > 0: gh.add([v.index], t, 'REPLACE')
            if t < 1: gn.add([v.index], 1 - t, 'REPLACE')
        bust.parent = rig; bust.matrix_parent_inverse = rig.matrix_world.inverted()
        am = bust.modifiers.new('rig', 'ARMATURE'); am.object = rig
        return rig, body
    # photo bust stays rigid with the head bone: re-parent keeping the world transform
    mw = bust.matrix_world.copy()
    bust.parent = rig; bust.parent_type = 'BONE'; bust.parent_bone = 'head'
    bpy.context.view_layer.update()
    bust.matrix_world = mw
    return rig, body

# ---------------------------------------------------------------- posing
def aim(rig, bone, world_target, roll_hint=None):
    """Rotate pose bone so its tail points at world_target (keeps its current roll as well as possible)."""
    pb = rig.pose.bones[bone]
    bpy.context.view_layer.update()
    M = rig.matrix_world @ pb.matrix
    head = M.translation
    y_now = (M.to_3x3() @ Vector((0, 1, 0))).normalized()
    y_new = (Vector(world_target) - head).normalized()
    q = y_now.rotation_difference(y_new)
    R = q.to_matrix().to_4x4()
    newM = Matrix.Translation(head) @ R @ Matrix.Translation(-head) @ M
    pb.matrix = rig.matrix_world.inverted() @ newM
    bpy.context.view_layer.update()

def twist(rig, bone, deg, axis='Y'):
    pb = rig.pose.bones[bone]; pb.rotation_mode = 'XYZ'
    r = list(pb.rotation_euler); i = 'XYZ'.index(axis); r[i] += math.radians(deg); pb.rotation_euler = r
    bpy.context.view_layer.update()

def bone_head(rig, bone):
    bpy.context.view_layer.update()
    return rig.matrix_world @ rig.pose.bones[bone].head

def bone_tail(rig, bone):
    bpy.context.view_layer.update()
    return rig.matrix_world @ rig.pose.bones[bone].tail

def arm_to(rig, side, hand_world, elbow_out=Vector((0, .15, -.3))):
    """Two-bone IK by construction: place elbow on the bend plane, aim upper then lower arm."""
    s = f'_{side}'
    sh = bone_head(rig, 'upperarm' + s)
    L1 = (bone_tail(rig, 'upperarm' + s) - sh).length
    L2 = (bone_tail(rig, 'lowerarm' + s) - bone_head(rig, 'lowerarm' + s)).length
    T = Vector(hand_world); d = T - sh; D = min(d.length, (L1 + L2) * .999); dn = d.normalized()
    a = (L1 * L1 - L2 * L2 + D * D) / (2 * D); hgt = math.sqrt(max(L1 * L1 - a * a, 0))
    pole = (rig.matrix_world.to_3x3() @ Vector(elbow_out))
    pole = (pole - dn * pole.dot(dn)).normalized()
    elbow = sh + dn * a + pole * hgt
    # the elbow never crosses the chest: keep it on its own side of the body's midline (local x), at least 4 cm out
    sx_ = 1 if side == 'l' else -1
    el = rig.matrix_world.inverted() @ elbow
    if sx_ * el.x < .04:
        el.x = sx_ * .04; elbow = rig.matrix_world @ el
    aim(rig, 'upperarm' + s, elbow)
    aim(rig, 'lowerarm' + s, sh + dn * D)

def leg_to(rig, side, ankle_world, knee_fwd=Vector((0, -1, 0))):
    s = f'_{side}'
    hp = bone_head(rig, 'thigh' + s)
    L1 = (bone_tail(rig, 'thigh' + s) - hp).length
    L2 = (bone_tail(rig, 'calf' + s) - bone_head(rig, 'calf' + s)).length
    T = Vector(ankle_world); d = T - hp; D = min(d.length, (L1 + L2) * .999); dn = d.normalized()
    a = (L1 * L1 - L2 * L2 + D * D) / (2 * D); hgt = math.sqrt(max(L1 * L1 - a * a, 0))
    pole = (rig.matrix_world.to_3x3() @ Vector(knee_fwd)); pole = (pole - dn * pole.dot(dn)).normalized()
    knee = hp + dn * a + pole * hgt
    aim(rig, 'thigh' + s, knee); aim(rig, 'calf' + s, hp + dn * D)

def local(rig, v):
    """Character-local offset (x right, -y forward, z up, metres) -> world point."""
    return rig.matrix_world @ (Vector(v) / rig.scale[0]) if False else rig.matrix_world.to_translation() + rig.matrix_world.to_3x3().normalized() @ Vector(v)

def relax_arms(rig):
    for s, sx in (('l', 1), ('r', -1)):
        arm_to(rig, s, local(rig, (sx * .2, -.03, .82 * rig.scale[0] / rig.scale[0])), Vector((sx * .3, .3, 0)))

def rot_world(rig, bone, axis, deg):
    """Rotate a pose bone about a world-space axis through its head."""
    pb = rig.pose.bones[bone]; bpy.context.view_layer.update()
    M = rig.matrix_world @ pb.matrix; h = M.translation
    R = Matrix.Rotation(math.radians(deg), 4, Vector(axis))
    pb.matrix = rig.matrix_world.inverted() @ (Matrix.Translation(h) @ R @ Matrix.Translation(-h) @ M)
    pb.scale = (1, 1, 1)   # the setter's decomposition leaves a little scale on bones whose rest frame is not orthonormal; it compounds
    bpy.context.view_layer.update()

def reset_pose(rig):
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()

# ---------------------------------------------------------------- Tripo characters
TRIPO = {k: f'/home/claude/tripo/{k}_prep.blend' for k in ('natsuki', 'natsuki_s', 'mio', 'kiryu', 'taiga', 'yota', 'makoto')}   # natsuki_s: socks body (indoors)

def _base_human(key):
    """MakeHuman body + game_engine rig at the character's height, unclothed, shape keys baked (weight donor)."""
    HS, TS = mpfb()
    sp = SPEC[key]
    macro = TS.get_default_macro_info_dict()
    macro.update(gender=sp['g'], age=age01(sp['age']), muscle=sp['mus'], weight=sp['wt'], proportions=sp['prop'],
                 height=.5, cupsize=sp.get('cup', .5), firmness=.5)
    macro['race'] = dict(asian=1.0, caucasian=0.0, african=0.0)
    body = HS.create_human(macro_detail_dict=macro)
    rig = HS.add_builtin_rig(body, 'game_engine')
    bpy.context.view_layer.objects.active = body
    if body.data.shape_keys:
        body.shape_key_add(name='mix', from_mix=True)
        co = [v.co.copy() for v in body.data.shape_keys.key_blocks['mix'].data]
        body.shape_key_clear()
        for v, c in zip(body.data.vertices, co): v.co = c
    gi = {g.name: g.index for g in body.vertex_groups}
    if 'body' in gi:
        bm = bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table()
        kill = [bm.verts[v.index] for v in body.data.vertices if not any(g.group == gi['body'] and g.weight > .5 for g in v.groups)]
        bmesh.ops.delete(bm, geom=kill, context='VERTS'); bm.to_mesh(body.data); bm.free()
    for m in list(body.modifiers):
        if m.type == 'MASK': body.modifiers.remove(m)
    bpy.context.view_layer.update()
    zs = [(body.matrix_world @ v.co).z for v in body.data.vertices]
    k = sp['h'] / (max(zs) - min(zs)); rig.scale = (k, k, k)
    bpy.context.view_layer.update()
    return rig, body

def _apply_pose_as_rest(rig, meshes):
    for ob in meshes:
        bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
        for m in list(ob.modifiers):
            if m.type == 'ARMATURE': bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='POSE'); bpy.ops.pose.select_all(action='SELECT'); bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode='OBJECT')

CUT_WEB = False   # only for generations where the sleeve came out fused to the body (free-plan Natsuki)
ARM_CHAIN = ('clavicle', 'upperarm', 'lowerarm', 'hand', 'thumb', 'index', 'middle', 'ring', 'pinky')

def _transfer_weights_gated(donor, target, rig, k=4):
    bones = set(rig.data.bones.keys())
    """Copy skin weights from the MakeHuman donor (posed to match) onto the generated mesh. Nearest-surface alone
    lets a hand hanging beside the jeans grab the thigh, so below the armpit every target vertex is first sorted
    into 'arm' or 'not arm' by the gap between arm and body in the front view, and only searches donor vertices
    of the same kind. Weights are the inverse-distance blend of the k nearest donor vertices."""
    from mathutils.kdtree import KDTree
    import numpy as np
    gname = {g.index: g.name for g in donor.vertex_groups}
    dmw = donor.matrix_world
    dv = []
    for v in donor.data.vertices:
        ws = {gname[g.group]: g.weight for g in v.groups if g.weight > 1e-3 and gname[g.group] in bones}
        if not ws: continue
        top = max(ws, key=ws.get)
        dv.append((dmw @ v.co, ws, top.split('_')[0] in ARM_CHAIN))
    trees = {}
    for kind in (True, False, None):
        sub = [d for d in dv if kind is None or d[2] == kind]
        t = KDTree(len(sub))
        for i, d in enumerate(sub): t.insert(d[0], i)
        t.balance(); trees[kind] = (t, sub)
    tmw = target.matrix_world
    P = np.array([tuple(tmw @ v.co) for v in target.data.vertices])
    # below the armpit, the hanging arms are separate pieces of the surface from the torso and legs:
    # split the mesh there and take the connected pieces that sit where the donor's arms are
    DA = np.array([tuple(d[0]) for d in dv if d[2]])
    armpit = float(np.percentile(DA[:, 2], 97)) - .12
    below = P[:, 2] < armpit
    adj = [[] for _ in P]
    for e in target.data.edges:
        a_, b_ = e.vertices
        if below[a_] and below[b_]: adj[a_].append(b_); adj[b_].append(a_)
    # the imported mesh is split along its UV seams: stitch coincident vertices back together for the walk
    from mathutils.kdtree import KDTree as _KD0
    kd0 = _KD0(len(P))
    for i, q in enumerate(P): kd0.insert(q, i)
    kd0.balance()
    for i, q in enumerate(P):
        if not below[i]: continue
        for _, j, _ in kd0.find_range(q, .0012):
            if j != i and below[j]: adj[i].append(j)
    # the arms touch the body somewhere (hand on the hip, sleeve on the sweater), so split by walking distance
    # over the surface instead: from seeds on the forearms and seeds on the torso/legs, whichever is nearer wins
    import heapq
    def seeds(points, r):
        out = set()
        for q in points:
            for _, j, _ in kd0.find_range(q, r):
                if below[j]: out.add(j)
        return out
    def seg(b_, ts):
        h = rig.matrix_world @ rig.data.bones[b_].head_local; t = rig.matrix_world @ rig.data.bones[b_].tail_local
        return [h.lerp(t, x) for x in ts]
    arm_seed = seeds([q for s_ in 'lr' for q in seg(f'lowerarm_{s_}', (.3, .6, .9)) + seg(f'hand_{s_}', (.5,))], .055)
    arm_seed |= seeds([q for s_ in 'lr' for q in seg(f'upperarm_{s_}', (.55, .75, .95))], .035)
    body_seed = seeds([q for s_ in 'lr' for q in seg(f'thigh_{s_}', (.1, .3, .5, .7, .9)) + seg(f'calf_{s_}', (.2, .5, .8))]
                      + seg('spine_01', (.2, .6)) + seg('pelvis', (.5,)), .115)
    # the whole front and back of the torso (well inside the arms) also counts as body
    sp_z = (rig.matrix_world @ rig.data.bones['spine_01'].head_local).z
    body_seed |= {i for i in range(len(P)) if below[i] and abs(P[i][0]) < .12 and P[i][2] > sp_z - .1}
    print('seeds', len(arm_seed), len(body_seed), 'overlap', len(arm_seed & body_seed))
    arm_seed -= body_seed
    INF = 1e9
    def dijkstra(src):
        d = np.full(len(P), INF); h = []
        for i in src: d[i] = 0; h.append((0.0, i))
        heapq.heapify(h)
        while h:
            du, u = heapq.heappop(h)
            if du > d[u]: continue
            for w_ in adj[u]:
                nd = du + float(np.linalg.norm(P[u] - P[w_]))
                if nd < d[w_]: d[w_] = nd; heapq.heappush(h, (nd, w_))
        return d
    dA = dijkstra(arm_seed); dB = dijkstra(body_seed)
    arm = below & (dA < dB)
    # clean up stray islands: a few rounds of majority vote among surface neighbours
    for _ in range(12):
        new = arm.copy()
        for i in range(len(P)):
            if not below[i] or not adj[i]: continue
            v = sum(1 for j in adj[i] if arm[j]) / len(adj[i])
            if v > .6: new[i] = True
            elif v < .4: new[i] = False
        arm = new
    # whole islands (after the vote) that are tiny compared to their side's arm go to the other label
    lab = -np.ones(len(P), int); n_isl = 0; sizes = []
    for i in range(len(P)):
        if not below[i] or lab[i] >= 0: continue
        st = [i]; lab[i] = n_isl; cnt = 0
        while st:
            u = st.pop(); cnt += 1
            for j in adj[u]:
                if lab[j] < 0 and arm[j] == arm[i]: lab[j] = n_isl; st.append(j)
        sizes.append(cnt); n_isl += 1
    sizes = np.array(sizes)
    for c in np.where(sizes < 400)[0]:
        m = lab == c; arm[m] = ~arm[m]
    print('arm vertices', int(arm.sum()), 'armpit z', round(armpit, 3))
    names = set()
    for d in dv: names |= set(d[1])
    for n in names:
        if n not in target.vertex_groups: target.vertex_groups.new(name=n)
    G = {g.name: g for g in target.vertex_groups}
    W = []
    for i, p in enumerate(P):
        kind = None if p[2] > armpit + .02 else bool(arm[i])
        t, sub = trees[kind]
        acc = {}; tot = 0.0
        for co, j, dist in t.find_n(p, k):
            w = 1.0 / (dist + .004); tot += w
            for n, x in sub[j][1].items(): acc[n] = acc.get(n, 0) + w * x
        W.append({n: x / tot for n, x in acc.items()})
    # smooth the weights along the surface (not across the arm/body gap), so neighbours move together
    nb = [[] for _ in P]
    for e in target.data.edges:
        a_, b_ = e.vertices
        if arm[a_] == arm[b_] or P[a_][2] > armpit + .02: nb[a_].append(b_); nb[b_].append(a_)
    # the import split the surface along its UV seams; the two sides of a seam must carry the same weights
    weld = [[j for _, j, _ in kd0.find_range(q, .0012) if j != i] for i, q in enumerate(P)]
    for i in range(len(P)):
        for j in weld[i]:
            if j not in nb[i] and (arm[i] == arm[j] or P[i][2] > armpit + .02): nb[i].append(j)
    for _ in range(24):
        W2 = []
        for i, w in enumerate(W):
            if not nb[i]: W2.append(w); continue
            acc = {n: x * .5 for n, x in w.items()}
            f = .5 / len(nb[i])
            for j in nb[i]:
                for n, x in W[j].items(): acc[n] = acc.get(n, 0) + x * f
            W2.append(acc)
        W = W2
    W3 = []
    for i, w in enumerate(W):
        grp = [i] + weld[i]; acc = {}
        for j in grp:
            for n, x in W[j].items(): acc[n] = acc.get(n, 0) + x / len(grp)
        W3.append(acc)
    W = W3
    for i, w in enumerate(W):
        tot = sum(w.values())
        for n, x in w.items():
            if x / tot > .01: G[n].add([i], x / tot, 'REPLACE')
    # where the generator fused the sleeve to the side of the sweater, the surface between them would stretch into
    # a sheet when the arm lifts: cut those faces out
    bm = bmesh.new(); bm.from_mesh(target.data); bm.faces.ensure_lookup_table()
    web = [f for f in bm.faces if all(below[v.index] for v in f.verts) and len({bool(arm[v.index]) for v in f.verts}) > 1] if CUT_WEB else []
    bmesh.ops.delete(bm, geom=web, context='FACES_ONLY')
    bm.to_mesh(target.data); bm.free()
    print('cut web faces', len(web))

def make_tripo(key, label=None):
    """Character from Tripo meshes (prepared by tripo/prep_<key>.py), rigged with the same game_engine skeleton as
    the MakeHuman characters so every pose function works unchanged. Returns (rig, body)."""
    label = label or key
    rig, donor = _base_human(key)
    rig.name = f'{label}_rig'
    with bpy.data.libraries.load(TRIPO[key]) as (src, dst):
        dst.objects = [n for n in src.objects if n.startswith(key)]
    parts = {}
    for o in dst.objects:
        lib.link(o); parts[o.name] = o
    body = parts[f'{key}_body']; face = parts[f'{key}_head']; hair = parts.get(f'{key}_hair')   # newer preps bake the face into the head: no hair object
    bpy.context.view_layer.update()
    # match the skeleton to the generated pose: wrists and ankles where the mesh has them
    V = [v.co for v in body.data.vertices]
    for s, sx in (('l', 1), ('r', -1)):
        # the hand: outermost vertices below the sweater cuff (the jeans stop short of it in x)
        Hh = max(c.z for c in V)
        xm = max(sx * c.x for c in V if .35 * Hh < c.z < .65 * Hh)
        hv = [c for c in V if sx * c.x > .8 * xm and .3 * Hh < c.z < .65 * Hh]
        tip = min(c.z for c in hv)
        wz = tip + .15
        band = [c for c in hv if abs(c.z - wz) < .012]
        print('wrist', s, round(tip, 3), tuple(round(x, 3) for x in sum(band, Vector()) / len(band)))
        wrist = sum(band, Vector()) / len(band)
        arm_to(rig, s, wrist, Vector((sx * .3, .3, 0)))
        fv = [c for c in V if sx * c.x > .02 and c.z < .12]
        ank = sum((c for c in fv if c.z > .07), Vector()) / max(1, len([c for c in fv if c.z > .07]))
        leg_to(rig, s, Vector((ank.x, bone_head(rig, f'foot_{s}').y, bone_head(rig, f'foot_{s}').z)))
    bpy.context.view_layer.update()
    # the hand: the MakeHuman hand is longer than the generated one (Kiryu 20.4 cm against 15 cm), so its finger
    # joints fell in the middle of the mesh's fingers and every grip bent the fingers in the wrong places. Turn and
    # scale the hand bone (fingers follow) so the middle fingertip lands on the mesh's fingertip.
    for s in ('l', 'r'):
        e = bone_head(rig, f'lowerarm_{s}'); w = bone_head(rig, f'hand_{s}'); d = (w - e).normalized()
        lat = lambda c: ((c - e) - d * (c - e).dot(d)).length
        pts = [c for c in V if lat(c) < .07 and (c - e).dot(d) > (w - e).dot(d)]
        far = max((c - e).dot(d) for c in pts); tp = [c for c in pts if (c - e).dot(d) > far - .008]
        tip_m = sum(tp, Vector()) / len(tp); tip_r = bone_tail(rig, f'middle_03_{s}')
        a = tip_r - w; b = tip_m - w
        if a.cross(b).length > 1e-6: rot_world(rig, f'hand_{s}', a.cross(b).normalized(), math.degrees(a.angle(b)))
        k = b.length / a.length; rig.pose.bones[f'hand_{s}'].scale = (k, k, k); bpy.context.view_layer.update()
        # the thumb: aim and scale its chain at the mesh's thumb tip, the farthest hand vertex inside a cone around
        # the skeleton's thumb (the transferred weights then follow the mesh's own thumb)
        h1 = bone_head(rig, f'thumb_01_{s}'); t3 = bone_tail(rig, f'thumb_03_{s}'); td = (t3 - h1).normalized()
        hand_v = [c for c in pts if (c - h1).length < .12]
        cone = [c for c in hand_v if (c - h1).length > .02 and (c - h1).normalized().dot(td) > .75]
        if cone:
            far_t = max((c - h1).dot(td) for c in cone); tt = [c for c in cone if (c - h1).dot(td) > far_t - .006]
            tip_t = sum(tt, Vector()) / len(tt); a2 = t3 - h1; b2 = tip_t - h1
            if a2.cross(b2).length > 1e-6: rot_world(rig, f'thumb_01_{s}', a2.cross(b2).normalized(), math.degrees(a2.angle(b2)))
            k2 = b2.length / a2.length; rig.pose.bones[f'thumb_01_{s}'].scale = (k2, k2, k2); bpy.context.view_layer.update()
            print('thumb fit', s, 'mesh', round(b2.length * 100, 1), 'rig', round(a2.length * 100, 1), 'turned', round(math.degrees(a2.angle(b2)), 1))
        print('hand fit', s, 'mesh', round(b.length * 100, 1), 'cm rig', round(a.length * 100, 1), 'cm, turned', round(math.degrees(a.angle(b)), 1), 'deg, err', round((bone_tail(rig, f'middle_03_{s}') - tip_m).length * 100, 2), 'cm')
    _apply_pose_as_rest(rig, [donor])
    _transfer_weights_gated(donor, body, rig)
    hz = bone_head(rig, 'head').z; nz = bone_head(rig, 'neck_01').z
    # one rule for the whole neck, on the head mesh AND the body's collar: by height alone, so the two meshes move
    # together when the neck turns. Below the collar top: spine_03. Up the neck over 7 cm: neck_01. Then head.
    zc = max(v.co.z for v in body.data.vertices)          # the body's cut, just above the collar
    def neck_w(z):
        th = min(1, max(0, (z - (hz - .07)) / .09)); th = th * th * (3 - 2 * th)
        ts = min(1, max(0, (zc + .005 - z) / .03)); ts = ts * ts * (3 - 2 * ts)   # spine below the collar top
        tn = (1 - th) * (1 - ts)
        return th, tn, (1 - th) * ts
    for ob in [o for o in (hair, face) if o is not None]:
        gh = ob.vertex_groups.new(name='head'); gn = ob.vertex_groups.new(name='neck_01'); gs = ob.vertex_groups.new(name='spine_03')
        for v in ob.data.vertices:
            th, tn, tsp = neck_w(v.co.z)
            if th > 0: gh.add([v.index], th, 'REPLACE')
            if tn > 0: gn.add([v.index], tn, 'REPLACE')
            if tsp > 0: gs.add([v.index], tsp, 'REPLACE')
    # the body's top 4 cm (the collar) takes the same rule in place of the transferred weights
    names = {g.name: g for g in body.vertex_groups}
    for nm in ('head', 'neck_01', 'spine_03'):
        if nm not in names: names[nm] = body.vertex_groups.new(name=nm)
    for v in body.data.vertices:
        if v.co.z < zc - .04: continue
        th, tn, tsp = neck_w(v.co.z)
        for g in body.vertex_groups:
            if g.name not in ('head', 'neck_01', 'spine_03'):
                try: g.remove([v.index])
                except RuntimeError: pass
        names['head'].add([v.index], th, 'REPLACE'); names['neck_01'].add([v.index], tn, 'REPLACE'); names['spine_03'].add([v.index], tsp, 'REPLACE')
    for ob in [o for o in (body, hair, face) if o is not None]:
        ob.name = {body: f'{label}_body', hair: f'{label}_hair', face: f'{label}_head'}[ob]
        mw = ob.matrix_world.copy(); ob.parent = rig; ob.matrix_world = mw
        am = ob.modifiers.new('rig', 'ARMATURE'); am.object = rig
    bpy.data.objects.remove(donor)
    return rig, body

# ---------------------------------------------------------------- hands
FINGERS = ('index', 'middle', 'ring', 'pinky')

_PALM_SIGN = {}
def palm_sign(rig, side):
    """+1 if the palm is on the hand bone's +Z side, -1 if on -Z. Measured from where the thumb grows: the thumb
    sits on the palm side of the hand. (On the MakeHuman game_engine rig this is +Z, the opposite of the Blender
    convention; assuming the convention put phones on the back of the hand.)"""
    key = (rig.name, side)
    if key not in _PALM_SIGN:
        bpy.context.view_layer.update()
        R = hand_frame(rig, side).to_3x3().normalized(); hb = hand_frame(rig, side).translation
        t = R.transposed() @ (bone_tail(rig, f'thumb_02_{side}') - hb)
        _PALM_SIGN[key] = 1.0 if t.z > 0 else -1.0
    return _PALM_SIGN[key]

def palm_dir(rig, side):
    """World direction the palm faces."""
    R = hand_frame(rig, side).to_3x3().normalized()
    return (R @ Vector((0, 0, 1))) * palm_sign(rig, side)

def curl_finger(rig, side, finger, amount, degs=(55, 70, 45)):
    """Bend a finger toward the palm by `amount` (0..1) of `degs` per joint, about the world axis that is
    perpendicular to the finger and to the palm normal. Works whatever the finger bones' rest roll is."""
    bpy.context.view_layer.update()
    palm = palm_dir(rig, side)
    for j, deg in zip(('01', '02', '03'), degs):
        pb = rig.pose.bones.get(f'{finger}_{j}_{side}')
        if pb is None: continue
        bpy.context.view_layer.update()
        M = rig.matrix_world @ pb.matrix; fdir = (M.to_3x3() @ Vector((0, 1, 0))).normalized()
        axis = fdir.cross(palm)
        if axis.length < 1e-6: continue
        rot_world(rig, f'{finger}_{j}_{side}', axis.normalized(), deg * amount)

def clear_finger(rig, side, finger):
    for j in ('01', '02', '03'):
        pb = rig.pose.bones[f'{finger}_{j}_{side}']; pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (1, 0, 0, 0); pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()

def grip(rig, side, amount=1.0, thumb=.6):
    """Curl the fingers (0 = open, 1 = closed fist). Rotates each finger joint about its local X."""
    for f in FINGERS: curl_finger(rig, side, f, amount)
    curl_finger(rig, side, 'thumb', amount * thumb, (20, 35, 25))

def grip_phone(rig, side):
    """One-handed phone hold: index and middle lie along the back of the phone, ring and pinky curl under its lower
    edge, the thumb rests along the near edge of the screen."""
    for f, amt in (('index', .3), ('middle', .4), ('ring', .85), ('pinky', 1.0)): curl_finger(rig, side, f, amt)
    curl_finger(rig, side, 'thumb', .35, (20, 35, 25))

def hand_frame(rig, side):
    """World matrix of the hand bone (origin at the wrist; Y along the bone toward the fingers)."""
    bpy.context.view_layer.update()
    return rig.matrix_world @ rig.pose.bones[f'hand_{side}'].matrix

def place_in_hand(ob, rig, side, offset=(0, .07, 0), rot=(0, 0, 0)):
    """Put an object in the palm: offset and rotation are in the hand bone's frame (Y toward the fingers,
    Z out of the back of the hand, X across the palm)."""
    H = hand_frame(rig, side); Hn = Matrix.Translation(H.translation) @ H.to_3x3().normalized().to_4x4()   # the rig's height scale must not leak into the object
    m = Hn @ Matrix.Translation(Vector(offset)) @ __import__('mathutils').Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
    ob.matrix_world = m @ Matrix.Diagonal((*ob.scale, 1))   # keep the object's own size

def phone(name, screen_k, strength):
    """A phone: dark body, the screen a bright plane on its -Y face (the face that lands palm-outward in place_in_hand)."""
    from lib import prim, mat_basic
    body = prim('cube', name, loc=(0, 0, 0), scale=(.037, .004, .078), mat=mat_basic(name + '_body', (.05, .05, .06), .35))
    body.visible_shadow = False
    scr = prim('plane', name + '_scr', loc=(0, -1.02, 0), rot=(math.radians(90), 0, 0), scale=(.9, .92, 1),
               mat=mat_basic(name + '_glow', (.6, .8, 1), .3, emit=screen_k, estr=strength))
    scr.visible_shadow = False
    scr.parent = body   # local to the body, so the cube's scale (0.034, 0.004, 0.072) applies
    return body

def wet(rig, tint=(.45, .45, .5), rough=.3):
    """Rain-soaked: every Tripo material on this character gets darker and shinier (the tint is baked on export)."""
    for ob in rig.children_recursive:
        if ob.type != 'MESH': continue
        for m in ob.data.materials:
            if m is None or not m.use_nodes: continue
            p = m.node_tree.nodes.get('Principled BSDF')
            if p is None: continue
            p.inputs['Roughness'].default_value = rough
            src = p.inputs['Base Color'].links[0].from_node if p.inputs['Base Color'].links else None
            if src is None or src.type != 'TEX_IMAGE': continue
            mix = m.node_tree.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'; mix.inputs['Factor'].default_value = 1.0
            mix.inputs['B'].default_value = (*tint, 1)
            m.node_tree.links.new(src.outputs['Color'], mix.inputs['A']); m.node_tree.links.new(mix.outputs['Result'], p.inputs['Base Color'])

def socks(rig, color=(.86, .86, .83), ankle=.10):
    """Indoors nobody wears shoes: the shoe part of the Tripo body texture (everything below the ankle) is repainted as
    a plain sock, keeping the baked shading. Writes <image>_socks.png next to the Tripo texture."""
    from PIL import Image, ImageDraw
    import numpy as np
    for ob in rig.children_recursive:
        if ob.type != 'MESH' or not ob.name.endswith('_body'): continue
        me = ob.data; uv = me.uv_layers[0]
        for m in ob.data.materials:
            if m is None or not m.use_nodes: continue
            p = m.node_tree.nodes.get('Principled BSDF')
            src = p.inputs['Base Color'].links[0].from_node if p and p.inputs['Base Color'].links else None
            if src is None or src.type != 'TEX_IMAGE': continue
            img = src.image; w, h = img.size
            mask = Image.new('L', (w, h), 0); dr = ImageDraw.Draw(mask)
            n = 0
            for poly in me.polygons:
                if all(me.vertices[vi].co.z < ankle for vi in poly.vertices):
                    pts = [(uv.data[li].uv.x * w, (1 - uv.data[li].uv.y) * h) for li in poly.loop_indices]
                    dr.polygon(pts, fill=255, outline=255); n += 1
            if n == 0: continue
            buf = np.empty(w * h * 4, np.float32); img.pixels.foreach_get(buf); px = buf.reshape(h, w, 4)
            mk = np.asarray(mask, np.float32)[::-1] / 255        # blender rows start at the bottom
            lum = px[..., :3].mean(2, keepdims=True)
            ref = np.median(lum[mk > .5]) if (mk > .5).any() else .5
            sock = np.clip(np.array(color, np.float32) * np.clip(lum / max(ref, 1e-3), .55, 1.12), 0, 1)
            px[..., :3] = px[..., :3] * (1 - mk[..., None]) + sock * mk[..., None]
            name = img.name.rsplit('.', 1)[0] + '_socks'
            im = bpy.data.images.new(name, w, h, alpha=False); im.pixels.foreach_set(px.ravel())
            im.filepath_raw = f'/home/claude/tripo/{name}.png'; im.file_format = 'PNG'; im.save()
            src.image = im
            print(f'socks: {ob.name} {n} shoe polys repainted')

def palm_to(rig, side, target, limit=100.0):
    """Turn the forearm (hand roll) so the palm faces the world point `target` as far as the forearm axis allows.
    `limit` caps the total twist (deg); the default is the anatomical range, a bent arm held in front of the body can
    use more because the shoulder contributes."""
    bpy.context.view_layer.update()
    M = hand_frame(rig, side); R = M.to_3x3().normalized()
    axis = R @ Vector((0, 1, 0)); palm = (R @ Vector((0, 0, 1))) * palm_sign(rig, side)
    want = Vector(target) - M.translation
    palm -= axis * palm.dot(axis); want -= axis * want.dot(axis)
    if palm.length < 1e-6 or want.length < 1e-6: return
    ang = math.degrees(palm.normalized().angle(want.normalized()))
    if palm.cross(want).dot(axis) < 0: ang = -ang
    # a forearm pronates/supinates about 80 deg each way, the wrist adds ~25: beyond that the hand only looks
    # as if it belonged to the other arm. Clamp, and let the pose fall short of the target instead
    ang = max(-limit, min(limit, ang))
    rot_world(rig, f'lowerarm_{side}', axis, ang * .75)
    rot_world(rig, f'hand_{side}', axis, ang * .25)

# ---------------------------------------------------------------- object-first holds
def set_hand_frame(rig, side, y_dir, z_dir):
    """Orient the hand bone directly: Y (toward the fingers) and Z (out of the back of the hand) in world space.
    The forearm is not touched, so call this after arm_to; the wrist joint absorbs the difference."""
    pb = rig.pose.bones[f'hand_{side}']; bpy.context.view_layer.update()
    M = rig.matrix_world @ pb.matrix; h = M.translation
    y = Vector(y_dir).normalized(); z = Vector(z_dir); z = (z - y * z.dot(y)).normalized(); x = y.cross(z)
    R = Matrix(((x.x, y.x, z.x), (x.y, y.y, z.y), (x.z, y.z, z.z))).to_4x4()
    pb.matrix = rig.matrix_world.inverted() @ (Matrix.Translation(h) @ R)
    pb.scale = (1, 1, 1); bpy.context.view_layer.update()

def settle_forearm(rig, side, limit=80.0):
    """Rotate the forearm about its own axis toward the hand's roll (pronation / supination), so the wrist does not
    carry the whole twist. The hand's world orientation is restored by the caller."""
    bpy.context.view_layer.update()
    fa = rig.pose.bones[f'lowerarm_{side}']; hd = rig.pose.bones[f'hand_{side}']
    F = (rig.matrix_world @ fa.matrix).to_3x3().normalized(); H = (rig.matrix_world @ hd.matrix).to_3x3().normalized()
    axis = F @ Vector((0, 1, 0))
    fz = F @ Vector((0, 0, 1)); hz = H @ Vector((0, 0, 1))
    fz -= axis * fz.dot(axis); hz -= axis * hz.dot(axis)
    if fz.length < 1e-6 or hz.length < 1e-6: return
    ang = math.degrees(fz.normalized().angle(hz.normalized()))
    if fz.cross(hz).dot(axis) < 0: ang = -ang
    rot_world(rig, f'lowerarm_{side}', axis, max(-limit, min(limit, ang)))

def finger_tips(rig, side):
    bpy.context.view_layer.update()
    return {f: rig.matrix_world @ rig.pose.bones[f'{f}_03_{side}'].tail for f in FINGERS + ('thumb',)}

_CURL = {}
def hold_phone(rig, side, phone, face_point, hand_target, elbow_out, screen_tilt=0.0):
    """The phone comes first: its back rests on the fingers, its screen faces `face_point`. The hand is then set to
    it: wrist at `hand_target`, palm normal = screen normal, fingers along the phone's long axis, curled so the
    fingertips meet the far long edge. Returns the fingertip-to-screen distances (negative = behind the screen)."""
    arm_to(rig, side, hand_target, elbow_out)
    bpy.context.view_layer.update()
    w = Vector(hand_target)
    n = (Vector(face_point) - w).normalized()                       # screen normal: toward the face
    # the phone's long axis continues the forearm (bottom of the phone toward the elbow): the wrist stays nearly straight
    elbow = bone_head(rig, f'lowerarm_{side}'); fdir = (w - elbow).normalized()
    along = (fdir - n * fdir.dot(n)).normalized()
    if screen_tilt: along = Matrix.Rotation(math.radians(screen_tilt), 4, n.cross(along)) @ along
    # fingers run across the phone (its short axis), from the thumb side to the far edge
    sx = 1 if side == 'l' else -1
    across = along.cross(n) * sx
    # the phone lies ON THE PALM: the back of the hand (+Z) points away from the face, the palm (-Z) toward it, and
    # the phone sits on the palm side with its screen facing the same way the palm does (toward the face)
    ps = palm_sign(rig, side)
    set_hand_frame(rig, side, across, n * ps)          # hand +Z = n*ps  ->  palm (= +Z*ps) faces n
    settle_forearm(rig, side); set_hand_frame(rig, side, across, n * ps)
    # the phone lies on the fingers' first segments: its centre is 2 cm in front of the palm (hand thickness) and
    # 5 cm along the fingers from the wrist, and its near long edge sits at the finger roots, so the curled fingers
    # come up behind its far edge, not in front of the screen
    # measured on this rig: the palm surface is 3.6 cm from the hand bone (the mesh is ~8 cm thick around it), the
    # finger roots ~9 cm along the bone. The phone's back rests on the palm's fingers-side half.
    HW = phone.scale.x; HL = phone.scale.z
    pd = palm_dir(rig, side)   # measured from the thumb, not assumed
    n = pd   # the screen faces the way the palm faces
    centre = w + pd * (.030 + phone.scale.y) + across * .058
    # phone local: X short, Y thickness (screen on -Y), Z long. Build its world basis: -Y -> n, Z -> along, X -> across
    along = (along - n * along.dot(n)).normalized(); across = along.cross(n) * sx
    # a right-handed basis (a left-handed one is decomposed with a negative scale and one axis flips on assignment):
    # Y = -n (screen side), Z = along; X follows as Y x Z. If that X points away from the fingers, flip Z (the
    # phone's top/bottom), which does not matter for the hold.
    Y = -n; Z = along; X = Y.cross(Z)
    if X.dot(across) < 0: Z = -Z; X = Y.cross(Z)
    B = Matrix(((X.x, Y.x, Z.x), (X.y, Y.y, Z.y), (X.z, Y.z, Z.z))).to_4x4()
    if phone.parent is None:   # once parented to the hand bone (for export) it rides along; re-assigning would collapse its scale
        phone.matrix_world = Matrix.Translation(centre) @ B @ Matrix.Diagonal((*phone.scale, 1))
    # curl: each finger's three joints bend until its tip reaches the far edge plane (across = +HW) without
    # crossing the screen plane; a short search per finger
    # curl each finger as far as it can without any joint coming in front of the screen plane, so the fingers wrap
    # the phone's far edge; the curl is applied to all four, the pinky and ring reach furthest round
    key = (rig.name, side)
    for f in FINGERS:
        if key in _CURL and f in _CURL[key]:   # the hand/phone relation is rigid: the curl found once is reused on every frame
            curl_finger(rig, side, f, _CURL[key][f]); continue
        best = 0.0
        def reset_f():
            for j in ('01', '02', '03'):
                pb = rig.pose.bones[f'{f}_{j}_{side}']; pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (1, 0, 0, 0); pb.scale = (1, 1, 1)
        for step in range(0, 21):
            amt = step / 20
            reset_f(); curl_finger(rig, side, f, amt); bpy.context.view_layer.update()
            pts = [rig.matrix_world @ rig.pose.bones[f'{f}_{j}_{side}'].tail for j in ('01', '02', '03')]
            # the phone rests on the fingers: no joint may enter the phone's slab (back face at -thick, screen at +thick)
            thick = phone.scale.y
            # a finger may rise above the phone's back only outside its outline (round the far edge); inside the
            # outline it must stay under the back face
            inside = lambda p: abs((p - centre).dot(across)) < HW - .002 and abs((p - centre).dot(along)) < HL + .004
            # a joint may be anywhere behind the phone, and may rise beside its far edge; it may not enter the slab
            # from behind while under the phone, and never rise above the screen plane
            if any(((p - centre).dot(n) > -thick - .003 and inside(p)) or (p - centre).dot(n) > thick + .002 for p in pts): break
            best = amt
        reset_f(); curl_finger(rig, side, f, best)
        _CURL.setdefault(key, {})[f] = best
    # the thumb rests along the phone's near long edge: uncurled it stands up from the palm, so its base is rotated
    # toward the hand's edge (about the finger direction) until the whole thumb lies below the screen plane
    for j in ('01', '02', '03'):
        pb = rig.pose.bones[f'thumb_{j}_{side}']; pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (1, 0, 0, 0); pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()
    for step in range(0, 25):
        pts = [rig.matrix_world @ rig.pose.bones[f'thumb_{j}_{side}'].tail for j in ('01', '02', '03')]
        if all((p - centre).dot(n) < phone.scale.y - .003 for p in pts): break
        rot_world(rig, f'thumb_01_{side}', across, -5.0 * sx)   # lay it down toward the near edge
    curl_finger(rig, side, 'thumb', .25, (20, 35, 25))
    bpy.context.view_layer.update()
    tips = finger_tips(rig, side)
    return {f: round((t - centre).dot(n), 4) for f, t in tips.items()}   # < -thick: under the phone (good); > +thick: over the screen (bad)

# ---------------------------------------------------------------- a real one-hand phone grip
_GRIP = {}
def _palm_frame(rig, side):
    """Hand frame with z toward the palm (measured): returns (origin, ex, ey, ez) in world."""
    bpy.context.view_layer.update()
    H = hand_frame(rig, side); R = H.to_3x3().normalized(); ps = palm_sign(rig, side)
    ey = R @ Vector((0, 1, 0)); ez = (R @ Vector((0, 0, 1))) * ps; ex = ey.cross(ez)
    return H.translation.copy(), ex, ey, ez

def _seg_dist(p, a, b):
    ab = b - a; t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length

def phone_grip(rig, side, phone, face_point, hand_target, elbow_out, alpha=25.0):
    """Hold a phone the way a person reads one, one-handed. In the hand's own frame (x across the palm toward the
    index side, y toward the fingertips, z out of the palm):
      - the phone's back sits just off the palm and the straight fingers (measured from the mesh, thumb excluded),
        its screen faces out of the palm; its long axis runs across the palm, top end toward the index finger,
        tilted `alpha` deg toward the fingertips
      - the four fingers lie under it and curl up round its far long edge (never into it, never over the screen)
      - the thumb comes over the near long edge and rests its pad on the screen near that edge
    The arm then puts the screen toward `face_point`. Solved once per rig (the grip is rigid in the hand frame)."""
    sx = 1 if side == 'l' else -1
    arm_to(rig, side, hand_target, elbow_out)
    key = (rig.name, side)
    HW, HT, HL = phone.scale.x, phone.scale.y, phone.scale.z   # half width, half thickness, half length
    a = math.radians(alpha)
    u_h = Vector((math.cos(a), math.sin(a), 0.0))      # phone long axis in palm frame
    v_h = Vector((0.0, 0.0, 1.0)).cross(u_h)           # short axis, pointing toward the fingertips side
    if key not in _GRIP:
        # 1. measure the palm/finger surface under the footprint, with straight fingers, thumb excluded
        for f in FINGERS + ('thumb',):
            for j in ('01', '02', '03'):
                pb = rig.pose.bones[f'{f}_{j}_{side}']; pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (1, 0, 0, 0)
        o, ex, ey, ez = _palm_frame(rig, side)
        loc = lambda p: Vector(((p - o).dot(ex), (p - o).dot(ey), (p - o).dot(ez)))
        body = [ob for ob in rig.children_recursive if ob.name.endswith('_body')][0]
        me = body.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
        th = [(bone_head(rig, f'thumb_{j}_{side}'), bone_tail(rig, f'thumb_{j}_{side}')) for j in ('02', '03')]
        others = [(bone_head(rig, b), bone_tail(rig, b)) for b in [f'{f}_{j}_{side}' for f in FINGERS for j in ('01', '02', '03')] + [f'hand_{side}']]
        pts = []
        for v in me.vertices:
            p = body.matrix_world @ v.co
            if (p - o).length > .16: continue
            dt = min(_seg_dist(p, a_, b_) for a_, b_ in th); do = min(_seg_dist(p, a_, b_) for a_, b_ in others)
            if dt < do: continue
            pts.append(loc(p))
        # footprint centre: across the finger bases, the near edge over the palm, the far edge at the middle phalanges
        y_roots = sum(loc(bone_head(rig, f'{f}_01_{side}')).y for f in FINGERS) / 4
        x_mid = sum(loc(bone_head(rig, f'{f}_01_{side}')).x for f in FINGERS) / 4
        c = Vector((x_mid + .03, y_roots + .005, 0.0))
        # fingers reach ~8 cm past their roots: the phone's far long edge goes out to the middle joints, so the last
        # joints can curl round it (measured: index middle joint ~5.5 cm past the root)
        c += v_h * (.058 - HW)
        inside = lambda p, m=0.0: abs((p - c).dot(u_h)) < HL + m and abs((p - c).dot(v_h)) < HW + m
        surf = max(p.z for p in pts if inside(Vector((p.x, p.y, 0.0))))
        c.z = surf + .004 + HT                       # back 4 mm off the skin
        back, screen = c.z - HT, c.z + HT
        # 2. fingers: curl each until the tip has come round the far edge, without entering the phone or the screen
        curls = {}
        for f in FINGERS:
            best, best_s = 0.0, 1e9
            for step in range(0, 26):
                amt = step / 25
                for j in ('01', '02', '03'):
                    pb = rig.pose.bones[f'{f}_{j}_{side}']; pb.rotation_quaternion = (1, 0, 0, 0)
                curl_finger(rig, side, f, amt)
                js = [loc(rig.matrix_world @ rig.pose.bones[f'{f}_{j}_{side}'].tail) for j in ('01', '02', '03')]
                # (the margins must stay below the 4 mm gap between skin and phone, or no finger can bend at all)
                # nothing inside the phone; nothing over the screen's face (beside the phone a finger may rise freely)
                bad = any(inside(Vector((q.x, q.y, 0)), .002) and back - .002 < q.z < screen + .002 for q in js) or any(inside(Vector((q.x, q.y, 0)), -.004) and q.z > screen for q in js)
                if bad: break
                tip = js[-1]
                # the fingertip should end up touching the far long edge from outside, level with the phone's middle
                s = math.hypot((tip - c).dot(v_h) - (HW + .007), tip.z - (back + HT))
                if s < best_s: best, best_s = amt, s
            curls[f] = best
            for j in ('01', '02', '03'):
                rig.pose.bones[f'{f}_{j}_{side}'].rotation_quaternion = (1, 0, 0, 0)
            curl_finger(rig, side, f, best)
        # 3. thumb: swing it down over the near edge (about the palm x axis) and curl, pad onto the screen
        bestT, bestS = (0.0, 0.0), 1e9
        for sw in range(0, 13):
            for cu in range(0, 11):
                for j in ('01', '02', '03'):
                    pb = rig.pose.bones[f'thumb_{j}_{side}']; pb.rotation_quaternion = (1, 0, 0, 0)
                o2, ex2, _, _ = _palm_frame(rig, side)
                rot_world(rig, f'thumb_01_{side}', ex2, -5.0 * sw)
                curl_finger(rig, side, 'thumb', cu / 10, (20, 35, 25))
                js = [loc(rig.matrix_world @ rig.pose.bones[f'thumb_{j}_{side}'].tail) for j in ('01', '02', '03')]
                if any(inside(Vector((q.x, q.y, 0)), .002) and back - .002 < q.z < screen + .002 for q in js): continue
                tip = js[-1]
                near = (tip - c).dot(v_h) + HW            # 0 at the near edge, + toward the middle
                s = abs(tip.z - (screen + .008)) * 3 + abs(near - .018) + (0 if inside(Vector((tip.x, tip.y, 0))) else .05)
                if s < bestS: bestT, bestS = (sw, cu), s
        _GRIP[key] = dict(c=c, curls=curls, thumb=bestT, back=back, screen=screen)
        print('phone_grip solved', key, 'curls', {k: round(v, 2) for k, v in curls.items()}, 'thumb', bestT, 'back z', round(back, 4))
    g = _GRIP[key]
    # 4. orient the hand so the screen (palm direction) faces the face, phone top continuing the forearm
    w = Vector(hand_target); n = (Vector(face_point) - w).normalized()
    elbow = bone_head(rig, f'lowerarm_{side}'); fdir = (w - elbow); fdir = (fdir - n * fdir.dot(n)).normalized()
    # palm-frame x = phone top rotated back by alpha: choose ex so the phone's long axis u continues the forearm
    up_dir = fdir                                    # world direction for u
    ex_w = (Matrix.Rotation(-a, 4, n) @ up_dir)       # u = cos a ex + sin a ey  ->  ex = u rotated by -a about n
    ey_w = n.cross(ex_w)
    ps = palm_sign(rig, side)
    set_hand_frame(rig, side, ey_w, n * ps); settle_forearm(rig, side); set_hand_frame(rig, side, ey_w, n * ps)
    for f in FINGERS:
        for j in ('01', '02', '03'):
            pb = rig.pose.bones[f'{f}_{j}_{side}']; pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (1, 0, 0, 0)
        curl_finger(rig, side, f, g['curls'][f])
    for j in ('01', '02', '03'):
        pb = rig.pose.bones[f'thumb_{j}_{side}']; pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (1, 0, 0, 0)
    o, ex, ey, ez = _palm_frame(rig, side)
    rot_world(rig, f'thumb_01_{side}', ex, -5.0 * g['thumb'][0]); curl_finger(rig, side, 'thumb', g['thumb'][1] / 10, (20, 35, 25))
    o, ex, ey, ez = _palm_frame(rig, side)
    c = g['c']; cw = o + ex * c.x + ey * c.y + ez * c.z
    u = ex * u_h.x + ey * u_h.y; v = ez.cross(u)
    if phone.parent is None:
        Y = -ez; Z = u; X = Y.cross(Z)               # phone: -Y = screen = palm side; Z = long axis
        B = Matrix(((X.x, Y.x, Z.x), (X.y, Y.y, Z.y), (X.z, Y.z, Z.z))).to_4x4()
        phone.matrix_world = Matrix.Translation(cw) @ B @ Matrix.Diagonal((*phone.scale, 1))
    bpy.context.view_layer.update()
    return g

def phone_grip2(rig, side, phone, face_point, hand_target, elbow_out):
    """One-handed reading grip, built from the hand: the fingers take a natural curl (index least, pinky most), the
    phone's back is laid on the pads of their middle segments (a plane fitted through them, 8 mm off the bone toward
    the palm = skin), its far long edge just inside the fingertip joints so the tips hook round it, its bottom end on
    the pinky; the thumb lies along the near long edge with its tip on the screen. Then the arm turns the whole hand
    so the screen faces `face_point`. Solved once per rig in the hand's own frame."""
    arm_to(rig, side, hand_target, elbow_out)
    key = (rig.name, side, 'g2')
    curls = {'index': .42, 'middle': .5, 'ring': .58, 'pinky': .66}
    def pose_fingers():
        for f in FINGERS + ('thumb',):
            for j in ('01', '02', '03'):
                pb = rig.pose.bones[f'{f}_{j}_{side}']; pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (1, 0, 0, 0)
        for f, a in curls.items(): curl_finger(rig, side, f, a)
    HW, HT, HL = phone.scale.x, phone.scale.y, phone.scale.z
    if key not in _GRIP:
        pose_fingers()
        o, ex, ey, ez = _palm_frame(rig, side)
        loc = lambda p: Vector(((p - o).dot(ex), (p - o).dot(ey), (p - o).dot(ez)))
        pads = []
        for f in ('index', 'middle', 'ring'):
            a_, b_ = bone_head(rig, f'{f}_02_{side}'), bone_tail(rig, f'{f}_02_{side}')
            pads.append(loc((a_ + b_) / 2))
        tips = [loc(bone_head(rig, f'{f}_03_{side}')) for f in ('index', 'middle', 'ring')]
        # plane through the three pads; its normal points out of the palm side (+z)
        nrm = (pads[1] - pads[0]).cross(pads[2] - pads[0]).normalized()
        if nrm.z < 0: nrm = -nrm
        # the fingers' pads face the phone: skin 8 mm from the bone line, toward +nrm
        pad_c = sum(pads, Vector()) / 3 + nrm * .008
        # long axis: along the line of finger pads (index -> ring), projected into the plane
        u = (pads[0] - pads[2]); u = (u - nrm * u.dot(nrm)).normalized()
        v = nrm.cross(u)                                    # short axis
        if v.dot(sum(tips, Vector()) / 3 - pad_c) < 0: v = -v    # v points toward the fingertips side
        # far long edge just inside the tip joints, so the last segments hook round it
        tip_v = sum((t - pad_c).dot(v) for t in tips) / 3
        c = pad_c + nrm * HT + v * (tip_v - .006 - HW)
        # slide along u so the phone's bottom end sits by the pinky and the top stands out past the index
        pink = loc(bone_head(rig, f'pinky_02_{side}'))
        c += u * ((pink - c).dot(u) + HL - .025)
        # each finger: the most curl (up to twice its natural amount) with no joint inside the phone or over its
        # screen; tips are allowed to stand up beside the far edge
        inside = lambda p, m: abs((p - c).dot(u)) < HL + m and abs((p - c).dot(v)) < HW + m
        fc = {}
        for f in FINGERS:
            best = 0.0
            for step in range(0, 31):
                amt = step / 30 * min(1.0, curls[f] * 2)
                for j in ('01', '02', '03'):
                    pb = rig.pose.bones[f'{f}_{j}_{side}']; pb.rotation_quaternion = (1, 0, 0, 0)
                curl_finger(rig, side, f, amt)
                js = [loc(rig.matrix_world @ rig.pose.bones[f'{f}_{j}_{side}'].tail) for j in ('01', '02', '03')]
                if any(inside(q, .001) and (q - c).dot(nrm) > -HT - .006 for q in js): break
                best = amt
            fc[f] = best
        _GRIP[key] = dict(c=c, u=u, v=v, n=nrm, fc=fc)
        print('phone_grip2 solved', key, 'n', [round(x, 2) for x in nrm], 'curls', {k: round(x, 2) for k, x in fc.items()})
    g = _GRIP[key]
    # orient the hand: the phone's screen normal (g.n in the palm frame) must point at the face, and the phone's long
    # axis should rise away from the hand (its top away from the wrist), as when reading
    w = Vector(hand_target); want_n = (Vector(face_point) - w).normalized()
    elbow = bone_head(rig, f'lowerarm_{side}'); fdir = (w - elbow); fdir = (fdir - want_n * fdir.dot(want_n)).normalized()
    # current palm frame -> world rotation that takes (g.n, g.u) to (want_n, fdir)
    o, ex, ey, ez = _palm_frame(rig, side)
    P = Matrix((ex, ey, ez)).transposed()                  # palm-frame -> world (columns)
    n_w = P @ g['n']; u_w = P @ g['u']
    def basis(a, b):
        a = a.normalized(); b = (b - a * b.dot(a)).normalized(); return Matrix((a, b, a.cross(b))).transposed()
    Rw = basis(want_n, fdir) @ basis(n_w, u_w).transposed()
    H = hand_frame(rig, side).to_3x3().normalized()
    newH = Rw @ H
    set_hand_frame(rig, side, newH @ Vector((0, 1, 0)), newH @ Vector((0, 0, 1)))
    settle_forearm(rig, side); set_hand_frame(rig, side, newH @ Vector((0, 1, 0)), newH @ Vector((0, 0, 1)))
    pose_fingers()
    for f in FINGERS:
        for j in ('01', '02', '03'):
            pb = rig.pose.bones[f'{f}_{j}_{side}']; pb.rotation_quaternion = (1, 0, 0, 0)
        curl_finger(rig, side, f, g['fc'][f])
    # thumb: lay it along the near long edge, tip onto the screen near that edge (searched once)
    o, ex, ey, ez = _palm_frame(rig, side)
    P = Matrix((ex, ey, ez)).transposed()
    c_w = o + P @ g['c']; n_w = P @ g['n']; u_w = P @ g['u']; v_w = P @ g['v']
    tkey = key + ('thumb',)
    if tkey not in _GRIP:
        best, bs = (0, 0, 0), 1e9
        for sw in range(-10, 11):
            for tw in range(-8, 9):
                for cu in range(0, 9, 2):
                    for j in ('01', '02', '03'):
                        pb = rig.pose.bones[f'thumb_{j}_{side}']; pb.rotation_quaternion = (1, 0, 0, 0)
                    o2, ex2, ey2, ez2 = _palm_frame(rig, side)
                    rot_world(rig, f'thumb_01_{side}', ex2, 6.0 * sw); rot_world(rig, f'thumb_01_{side}', ey2, 6.0 * tw)
                    curl_finger(rig, side, 'thumb', cu / 8, (20, 35, 25))
                    js = [rig.matrix_world @ rig.pose.bones[f'thumb_{j}_{side}'].tail for j in ('01', '02', '03')]
                    inside = lambda p, m: abs((p - c_w).dot(u_w)) < HL + m and abs((p - c_w).dot(v_w)) < HW + m
                    if any(inside(p, .002) and (p - c_w).dot(n_w) > -HT - .003 for p in js): continue   # not in it, not over the screen
                    tip = js[-1]
                    target = c_w - v_w * (HW + .009) + n_w * HT          # pad against the near long edge, level with the screen
                    s = (tip - target).length
                    if s < bs: best, bs = (sw, tw, cu), s
        _GRIP[tkey] = best; print('thumb', best, 'err cm', round(bs * 100, 1))
    sw, tw, cu = _GRIP[tkey]
    for j in ('01', '02', '03'):
        pb = rig.pose.bones[f'thumb_{j}_{side}']; pb.rotation_quaternion = (1, 0, 0, 0)
    o2, ex2, ey2, ez2 = _palm_frame(rig, side)
    rot_world(rig, f'thumb_01_{side}', ex2, 6.0 * sw); rot_world(rig, f'thumb_01_{side}', ey2, 6.0 * tw)
    curl_finger(rig, side, 'thumb', cu / 8, (20, 35, 25))
    if phone.parent is None:
        Y = -n_w; Z = u_w; X = Y.cross(Z)
        B = Matrix(((X.x, Y.x, Z.x), (X.y, Y.y, Z.y), (X.z, Y.z, Z.z))).to_4x4()
        phone.matrix_world = Matrix.Translation(c_w) @ B @ Matrix.Diagonal((*phone.scale, 1))
    bpy.context.view_layer.update()

def phone_grip3(rig, side, phone, face_point, hand_target, elbow_out):
    """One-hand reading grip, laid out from the reference photos (docs/参考写真):
      - the phone's short axis runs along the fingers: its near long edge lies over the top of the palm (just short of
        the finger roots), its far long edge at the fingers' second joints, so the fingertips peek round it
      - the fingers are nearly straight under the phone's back; only the last segments hook the far edge
      - the thumb lies along the near long edge, pad against the side, tip just over the screen's edge
      - the phone's bottom end sits on the heel of the hand, the top stands out past the index finger
    Then the arm turns the hand so the screen faces `face_point`, the phone upright as seen from there."""
    arm_to(rig, side, hand_target, elbow_out)
    key = (rig.name, side, 'g3')
    HW, HT, HL = phone.scale.x, phone.scale.y, phone.scale.z
    def clear(fs):
        for f in fs:
            for j in ('01', '02', '03'):
                pb = rig.pose.bones[f'{f}_{j}_{side}']; pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (1, 0, 0, 0)
    if key not in _GRIP:
        clear(FINGERS + ('thumb',))
        for f in FINGERS: curl_finger(rig, side, f, .1)
        o, ex, ey, ez = _palm_frame(rig, side)
        loc = lambda p: Vector(((p - o).dot(ex), (p - o).dot(ey), (p - o).dot(ez)))
        roots = [loc(bone_head(rig, f'{f}_01_{side}')) for f in FINGERS]
        y_root = sum(r.y for r in roots) / 4
        y_far = sum(loc(bone_head(rig, f'{f}_02_{side}')).y for f in ('index', 'middle', 'ring')) / 3 + .012
        x_mid = sum(r.x for r in roots) / 4
        # long axis u across the palm (perpendicular to the fingers), short axis v along the fingers
        u = Vector((1, 0, 0)); v = Vector((0, 1, 0))
        thumb_side = 1 if loc(bone_head(rig, f'thumb_01_{side}')).x > x_mid else -1
        u = u * thumb_side                                  # u points from the pinky side toward the thumb/index side (phone top)
        c = Vector((roots[3].x + thumb_side * (HL - .012), y_far - HW, 0.0))   # the bottom end lies over the pinky, the top stands out past the index
        # rest the back on the skin under the footprint (thumb excluded)
        body = [ob for ob in rig.children_recursive if ob.name.endswith('_body')][0]
        me = body.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
        th = [(bone_head(rig, f'thumb_{j}_{side}'), bone_tail(rig, f'thumb_{j}_{side}')) for j in ('01', '02', '03')]
        others = [(bone_head(rig, b), bone_tail(rig, b)) for b in [f'{f}_{j}_{side}' for f in FINGERS for j in ('01', '02', '03')] + [f'hand_{side}']]
        zs = []
        for vv in me.vertices:
            p = body.matrix_world @ vv.co
            if (p - o).length > .17: continue
            q = loc(p)
            if abs((q - c).dot(u)) > HL or abs((q - c).dot(v)) > HW: continue
            if min(_seg_dist(p, a_, b_) for a_, b_ in th) < min(_seg_dist(p, a_, b_) for a_, b_ in others): continue
            zs.append(q.z)
        zs.sort(); surf = zs[int(len(zs) * .97)] if zs else .02    # ignore stray high points
        c.z = surf + .002 + HT
        back, screen = c.z - HT, c.z + HT
        inside = lambda q, m: abs((q - c).dot(u)) < HL + m and abs((q - c).dot(v)) < HW + m
        # fingers: curl until the tip hooks the far edge (tip just beyond it, level with the phone), never into it
        fc = {}
        for f in FINGERS:
            best, bs = 0.1, 1e9
            for step in range(0, 31):
                amt = step / 30 * .9
                clear((f,)); curl_finger(rig, side, f, amt)
                js = [loc(rig.matrix_world @ rig.pose.bones[f'{f}_{j}_{side}'].tail) for j in ('01', '02', '03')]
                if any(inside(q, .001) and back - .002 < q.z < screen + .001 for q in js): break
                if any(inside(q, -.006) and q.z > screen for q in js): break
                tip = js[-1]
                s = math.hypot((tip - c).dot(v) - (HW + .006), tip.z - (screen - .001))
                if s < bs: best, bs = amt, s
            fc[f] = best; clear((f,)); curl_finger(rig, side, f, best)
        # thumb: aim the whole thumb along the near long edge toward the phone's top, its pad against the side and
        # the tip just over the screen's edge (a few aiming passes of the root joint, then the tip joints a little)
        clear(('thumb',))
        h0 = loc(bone_head(rig, f'thumb_01_{side}'))
        L = sum((bone_tail(rig, f'thumb_0{j}_{side}') - bone_head(rig, f'thumb_0{j}_{side}')).length for j in (1, 2, 3))
        P0 = Matrix((ex, ey, ez)).transposed()
        along = max(0.0, L * L - ((h0 - c).dot(v) + HW) ** 2 - (h0.z - screen) ** 2) ** .5
        T = c - v * (HW + .009) + u * ((h0 - c).dot(u) + along) + Vector((0, 0, screen - c.z - .004))
        for _ in range(4):
            hw = bone_head(rig, f'thumb_01_{side}'); tw = bone_tail(rig, f'thumb_03_{side}'); Tw = o + P0 @ T
            a_, b_ = tw - hw, Tw - hw
            if a_.cross(b_).length < 1e-6: break
            rot_world(rig, f'thumb_01_{side}', a_.cross(b_).normalized(), math.degrees(a_.angle(b_)))
        curl_finger(rig, side, 'thumb', .15, (20, 35, 25))
        js = [loc(rig.matrix_world @ rig.pose.bones[f'thumb_{j}_{side}'].tail) for j in ('01', '02', '03')]
        bs = (js[-1] - T).length
        best = [rig.pose.bones[f'thumb_0{j}_{side}'].rotation_quaternion.copy() for j in (1, 2, 3)]
        _GRIP[key] = dict(c=c, u=u, v=v, fc=fc, thumb=best)
        print('phone_grip3 solved', {k: round(x, 2) for k, x in fc.items()}, 'thumb err', round(bs * 100, 1), 'cm')
    g = _GRIP[key]
    # turn the hand: screen (+z of the palm frame) toward the face, phone top (u) upright as seen from the face
    w = Vector(hand_target); want_n = (Vector(face_point) - w).normalized()
    up = Vector((0, 0, 1)); want_u = (up - want_n * up.dot(want_n)).normalized()
    o, ex, ey, ez = _palm_frame(rig, side)
    P = Matrix((ex, ey, ez)).transposed()
    def basis(a, b):
        a = a.normalized(); b = (b - a * b.dot(a)).normalized(); return Matrix((a, b, a.cross(b))).transposed()
    Rw = basis(want_n, want_u) @ basis(ez, P @ g['u']).transposed()
    H = hand_frame(rig, side).to_3x3().normalized(); newH = Rw @ H
    set_hand_frame(rig, side, newH @ Vector((0, 1, 0)), newH @ Vector((0, 0, 1)))
    settle_forearm(rig, side); set_hand_frame(rig, side, newH @ Vector((0, 1, 0)), newH @ Vector((0, 0, 1)))
    clear(FINGERS + ('thumb',))
    for f in FINGERS: curl_finger(rig, side, f, g['fc'][f])
    for j, q in zip((1, 2, 3), g['thumb']):
        pb = rig.pose.bones[f'thumb_0{j}_{side}']; pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = q
    bpy.context.view_layer.update()
    o, ex, ey, ez = _palm_frame(rig, side); P = Matrix((ex, ey, ez)).transposed()
    cw = o + P @ g['c']; uw = P @ g['u']
    if phone.parent is None:
        Y = -ez; Z = uw; X = Y.cross(Z)
        B = Matrix(((X.x, Y.x, Z.x), (X.y, Y.y, Z.y), (X.z, Y.z, Z.z))).to_4x4()
        phone.matrix_world = Matrix.Translation(cw) @ B @ Matrix.Diagonal((*phone.scale, 1))
    bpy.context.view_layer.update()
