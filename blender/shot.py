"""第2章 23:00 — 扉の前の沈黙. A 10 s shot from Mio's eye-line, slowly pushing toward the door.
Everything per frame is a function of t (seconds), so any frame can be rendered alone.
  python3 shot.py -- <outdir> <first> <last> <spp> <pct> [step]
Beats:
  0.0  rain, generator-fed fresnel breathing, Natsuki's palm on the slit glass, Kiryu reading his phone
  3.0  three knocks (her hand lifts and taps); Taiga presses his back into the door
  4.5  Kiryu looks up at the door ... and back down at 7.0
  6.0  her phone lights her fingers from below as she types against the glass
  8.2  lightning: one white-blue pulse through the slit, the fresnel dips with the generator
  10.0 end
"""
import sys, math, random
import os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P   # all paths: paths.env
import bpy
from mathutils import Vector, Matrix
import lib, door as D, hall as Hm, chars as C, house4 as H4, stage as St
from lib import prim, mat_basic, kelvin

FPS = 12
DUR = 10.0
CAM0 = Vector((-.3, 1.0, 1.52)); CAM1 = Vector((-.15, 1.95, 1.5))   # v4 house: the walkway beside the stair, toward the door
TGT0 = CAM0 + Vector((.75, 4.1, -.77)); TGT1 = CAM1 + Vector((.55, 4.0, -1.3))

def ease(x): x = max(0, min(1, x)); return x * x * (3 - 2 * x)
def pulse(t, t0, w): return math.exp(-((t - t0) / w) ** 2)

S = {}

# the user's scans in the genkan (scan_prep.py / scan_mat.py / scan_paint.py made them; 受け取ったスキャン一覧.md)
# name: (x, y, z rotation deg). Kept off Taiga's 23:00 spot (St.TAIGA_N, on the genkan floor) and the umbrella stand.
# rz turns each pair's toes toward the door (+Y): the scans lie at 140-150 deg (heel -> toe, measured per shoe), so
# 90 - that, plus a few degrees of the way people leave shoes. The mat is up on the hall floor, past the step.
GENKAN_SCANS = {'genkan_mat': (.2, 4.55, 0), 'genkan_shoe1': (-.28, 5.14, 90 - 139.6 + 2), 'genkan_shoe2': (-.36, 5.78, 90 - 150.6 - 3),
                'genkan_shoe3': (.46, 5.84, 90 - 141.2 + 1)}
# the rest of the scans (2026-11-01): name: (x, y, z, z rotation deg).
# The umbrellas where the box stand was (the genkan's west corner); the slippers on the mat at the step, toes into the
# house (the scan lies heel -> toe at ~130 deg); the backpack on the hall floor against the east wall by the step.
# The crew's break on the up-stair's 2nd tread (top z = 2 * F2 / 13): the snacks on the wall side, the mugs on the open
# side, a roll of packing tape on the 3rd tread. The living room has no furniture and is out of both shots.
STEP = H4.F2 / H4.NSTEP
MORE_SCANS = {'genkan_umbrella': (St.HALL[0] + .2, 5.15, Hm.ZG + .002, 0),
              'hall_slippers': (.42, 4.70, .005, -90 - 130),
              'hall_backpack': (.93, 4.66, 0, 0),
              'stair_snacks': (.86, 3.355, 2 * STEP, 8),
              'stair_mugs': (.48, 3.36, 2 * STEP, -20)}
def _import_scan(d, n, x, y, z, rz):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(d, n + '.glb'))
    for o in set(bpy.data.objects) - before:
        if o.type != 'MESH': continue
        o.name = 'scan_' + n; o.parent = None
        o.location = (x, y, z); o.rotation_euler = (0, 0, math.radians(rz))

def scans_genkan():
    d = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'scans')
    if not os.path.exists(os.path.join(d, 'genkan_mat.glb')): return False
    for n, (x, y, rz) in GENKAN_SCANS.items():
        _import_scan(d, n, x, y, .001 if n == 'genkan_mat' else Hm.ZG + .004, rz)   # the mat on the hall floor (z 0), shoes on the genkan
    for n, (x, y, z, rz) in MORE_SCANS.items():
        if os.path.exists(os.path.join(d, n + '.glb')): _import_scan(d, n, x, y, z, rz)
    return True

def _clear_mat():
    m = mat_basic('tape_clear', (.85, .66, .32), .12)
    m.node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value = .45; m.surface_render_method = 'BLENDED'
    return m

def tape_roll(name, r_out, r_core, width, tape_mat, core_mat, clear_mat=None, seg=40):
    """A roll of tape with its cardboard core and the hole through it (sizes from the user's scan s10: 10 cm across,
    5 cm wide, a 7.6 cm core). Axis Z, origin at the centre (like door.cyl_between). clear_mat: a thin outer layer
    for packing tape, whose last wrap you see through."""
    import bmesh
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    def ring(r0, r1, w, mi):
        vs = []
        for z in (-w / 2, w / 2):
            for r in (r0, r1):
                vs.append([bm.verts.new((r * math.cos(j / seg * math.tau), r * math.sin(j / seg * math.tau), z)) for j in range(seg)])
        ib, ob, it, ot = vs
        for j in range(seg):
            k = (j + 1) % seg
            for qi, q in enumerate(((ob[j], ob[k], ot[k], ot[j]), (it[j], it[k], ib[k], ib[j]), (ot[j], ot[k], it[k], it[j]), (ib[j], ib[k], ob[k], ob[j]))):
                f = bm.faces.new(q); f.material_index = mi; f.smooth = qi < 2   # the walls round, the flat sides flat
    ring(r_core - .0035, r_core, width * 1.01, 1)
    ring(r_core, r_out - (.0012 if clear_mat else 0), width, 0)
    if clear_mat: ring(r_out - .0012, r_out, width * .995, 2)
    bm.to_mesh(me); bm.free()
    for m in (tape_mat, core_mat) + ((clear_mat,) if clear_mat else ()): me.materials.append(m)
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    return o

def genkan_props4(M, shoes=4, umbrellas=6):
    """Shoes on the genkan floor and the umbrella stand in its west corner (the v4 genkan, X -.8..1.2, Y 4.9..6.3)."""
    import random as R
    R.seed(9)
    shoe = [mat_basic('shoe0', (.08, .08, .09), .6), mat_basic('shoe1', (.72, .7, .66), .7), mat_basic('shoe2', (.25, .19, .13), .6),
            mat_basic('shoe3', (.1, .12, .2), .6), mat_basic('shoe4', (.55, .3, .25), .6)]
    if scans_genkan():
        pass   # the user's scans (assets/scans) take the place of the box shoes
    else:
        for i in range(shoes):
            for d in (-.06, .06):
                o = prim('cube', 'shoe', loc=(-.45 + i * .22 + d, 5.2 + (i % 2) * .3, Hm.ZG + .045), scale=(.045, .13, .04), mat=shoe[i])
                o.rotation_euler.z = R.uniform(-.3, .3)
    ux, uy = St.HALL[0] + .2, 5.15
    # packing tape left on the stair with the snacks (the roll's size from the scan s10)
    tp = tape_roll('scan_tape_pack', .049, .040, .036, mat_basic('tape_pack', (.62, .42, .10), .2), mat_basic('tape_core', (.55, .42, .28), .8),
                   _clear_mat())
    tp.location = (.62, 3.12, 3 * STEP + .018); tp.rotation_euler.z = .4
    if os.path.exists(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'scans', 'genkan_umbrella.glb')):
        return   # the scanned stand and umbrellas take the place of the box ones
    prim('cylinder', 'ustand', loc=(ux, uy, Hm.ZG + .22), vertices=16, radius=.09, depth=.44, mat=M['black'])
    for i in range(umbrellas):
        a = i / umbrellas * math.tau
        D.cyl_between('umb', (ux + math.cos(a) * .04, uy + math.sin(a) * .04, Hm.ZG + .05), (ux + math.cos(a) * .1, uy + math.sin(a) * .1, Hm.ZG + .95), .03, M['umb'], 8)
        D.cyl_between('uh', (ux + math.cos(a) * .1, uy + math.sin(a) * .1, Hm.ZG + .95), (ux + math.cos(a) * .12, uy + math.sin(a) * .12, Hm.ZG + 1.06), .009, M['white'], 6)

def build():
    lib.reset()
    M = D.mats()
    H4.build_house4(M, floors=('1F', '2F')); H4.prune(St.GI_BOX)
    genkan_props4(M, shoes=4, umbrellas=6)
    S['fres'] = D.fresnel(St.FRESNEL, 2.0, (*St.MARK, 0), M, energy=520, size=30)
    tx, ty = St.TRIPOD_N
    D.tripod((tx, ty), math.radians(205), M)
    lib.spot('camtop_led', (tx + .02, ty - .08, 1.62), (tx + .95, ty - 2.75, 1.2), 6, k=5600, size=70, blend=.6, radius=.02)
    Hm.tape_mark(*St.MARK, CAM0[:2], 'tape_natsuki.png')
    cu = bpy.data.curves.new('cable', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = .007
    spl = cu.splines.new('BEZIER'); fx, fy = St.FRESNEL; pts = [(fx, fy, .01), (fx + .25, fy - .3, .008), (fx + .05, fy - .65, .008), (-.62, fy - .4, .008), (-.74, fy - .2, .008)]   # to the living room, under its door
    spl.bezier_points.add(len(pts) - 1)
    for bp, p in zip(spl.bezier_points, pts): bp.co = p; bp.handle_left_type = bp.handle_right_type = 'AUTO'
    co = bpy.data.objects.new('cable', cu); lib.link(co); co.data.materials.append(M['rubber'])
    ab = prim('cube', 'applebox', loc=(*St.APPLEBOX, .1), rot=(0, 0, .3), scale=(.25, .15, .1), mat=M['agari']); lib.uv_box(ab, 1.25)
    bx, by, bz = St.SHOECAB_TOP; bz += .12; dt = Vector((St.DOOR_C, St.YF - .1, 1.2))   # on the shoe cabinet, aimed at the door
    pnl = prim('cube', 'blue_panel', loc=(bx, by, bz), scale=(.13, .02, .1), mat=M['black'])
    d = (dt - Vector((bx, by, bz))); pnl.rotation_euler = d.to_track_quat('-Y', 'Z').to_euler()
    S['blue'] = lib.area('blue_door', tuple(Vector((bx, by, bz)) + d.normalized() * .03), tuple(dt), 7, color=(.4, .56, 1.0), size=(.24, .18), spread=75)   # v4: 4 -> 7, wider: Taiga at the door read as a black cut-out
    S['slit_x'] = sum(St.SLIT_X) / 2; Y = St.YF
    # ---- outside: porch, rain, Natsuki herself (seen only through the slit)
    porch = prim('cube', 'porch', loc=(St.DOOR_C, Y + .9, Hm.ZG - .03), scale=(1.4, .9, .03), mat=M['floor']); lib.uv_box(porch, .87)
    S['sky'] = lib.area('rain_sky', (S['slit_x'] - .5, Y + 1.4, 2.2), (S['slit_x'], Y + .2, 1.1), 6, k=14000, size=(.8, .8))
    S['bolt'] = lib.area('lightning', (S['slit_x'] + .4, Y + 2.5, 2.2), (S['slit_x'], Y, 1.1), 0, k=16000, size=(1.5, 1.5))
    wet = mat_basic('wetknit', (.09, .09, .1), .3)
    nk = C.make_tripo('natsuki')   # Tripo-generated body and head (see tripo/prep_natsuki.py)
    S['n'] = nk[0]; nk[0].location = (S['slit_x'] - .12, Y + .26, Hm.ZG); nk[0].rotation_euler.z = 0   # facing the door, the knocking left hand at the slit (試作17 had her back to it, the arms reaching behind)
    C.wet(nk[0], (.42, .44, .5), .28)   # she has been standing in the rain
    # her phone
    S['nphone'] = C.phone('nphone', kelvin(9000), 7)
    S['nphone_l'] = lib.point('nphone_light', (0, 0, 0), 2.0, k=9000, radius=.02)
    # rain streaks outside (instanced as one mesh so it's cheap to move)
    random.seed(4); verts = []; faces = []
    for i in range(160):
        x = random.uniform(St.DOOR_C - 1.4, St.DOOR_C + 1.4); y = random.uniform(Y + .3, Y + 3.0); z = random.uniform(-.2, 2.8)
        b = len(verts); w = .0018
        verts += [(x - w, y, z), (x + w, y, z), (x + w - .01, y - .015, z - .28), (x - w - .01, y - .015, z - .28)]
        faces.append((b, b + 1, b + 2, b + 3))
    rain = lib.mesh_obj('rain', verts, faces); rain.data.materials.append(mat_basic('rain', (.7, .8, 1), .2, emit=(.55, .68, 1), estr=.35))
    rain.visible_shadow = False; S['rain'] = rain
    # ---- inside
    S['k'] = C.make_tripo('kiryu')[0]
    S['k'].location = (*St.KIRYU_N, 0); S['k'].rotation_euler.z = math.radians(-14)
    S['t'] = C.make_tripo('taiga')[0]
    S['t'].location = (*St.TAIGA_N, Hm.ZG); S['t'].rotation_euler = (math.radians(16), 0, math.radians(176))   # facing the door, the whole body leaning in, hands on it (export_godot.pose_taiga)
    S['kphone'] = C.phone('kphone', kelvin(8500), 5)
    S['kphone_l'] = lib.spot('kiryu_phone_light', (0, 0, 0), (0, 0, 1), 2.2, k=8000, size=70, blend=.8, radius=.035)
    import house4_ext as HX; HX.build_ext4(M, with_trees=False, time='night')   # the outside (外観スレッド); only the slit and the rain show it at 23:00
    lib.haze(((St.HALL[0], -.2, -.2), (St.HALL[1], St.YF, 2.45)), density=.06, aniso=0)
    S['cam'] = lib.camera(tuple(CAM0), tuple(TGT0), lens=18)
    bpy.context.view_layer.update()

def at(t):
    """Set the whole scene to time t (seconds)."""
    Y = Hm.YF; sx = S['slit_x']
    # camera: slow push, a breath of handheld drift
    u = ease(t / DUR)
    cp = CAM0.lerp(CAM1, u) + Vector((math.sin(t * .9) * .006, 0, math.sin(t * 1.3 + 1) * .005))
    tg = TGT0.lerp(TGT1, u)
    S['cam'].location = cp; S['cam'].rotation_euler = (tg - cp).to_track_quat('-Z', 'Y').to_euler()
    S['cam'].data.lens = 18 + 3 * u
    # fresnel on a generator: slow breathing + the dip at the lightning
    dip = 1 - .55 * pulse(t, 8.35, .12) - .25 * pulse(t, 8.6, .08)
    S['fres'].data.energy = 520 * (1 + .03 * math.sin(t * 6.1) + .02 * math.sin(t * 17.3)) * dip
    S['bolt'].data.energy = 900 * (pulse(t, 8.2, .035) + .6 * pulse(t, 8.32, .03) + .25 * pulse(t, 8.5, .05))
    # rain falls (wraps every 0.25 s)
    S['rain'].location.z = -((t * 7.5) % 1.0) * .9
    # ---- Natsuki outside
    n = S['n']; C.reset_pose(n)
    knock = 0.0
    for k0 in (3.0, 3.35, 3.7):
        knock = max(knock, pulse(t, k0, .07))
    palm_up = 1.5 + .0
    hx = sx + .0; hy = Y + .03
    if t < 2.7 or t > 4.2:
        hand = Vector((hx, hy + .01, 1.32))
    else:
        hand = Vector((hx, hy + .05 - .05 * knock, 1.42))
    C.arm_to(n, 'l', hand, Vector((.25, .2, -.4)))
    C.rot_world(n, 'neck_01', (1, 0, 0), -8)
    C.grip(n, 'l', .15)
    # the phone in a reading grip, its screen toward her face (試作18: it faced away from her, the door way)
    eyes = C.bone_head(n, 'head') + Vector((0, -.08, .05))
    C.phone_grip3(n, 'r', S['nphone'], eyes, Vector((sx - .17, Y + .14, 1.02 + .02 * math.sin(t * 3))), Vector((-.3, .2, -.4)))
    bpy.context.view_layer.update()
    S['nphone_l'].location = S['nphone'].matrix_world.translation + S['nphone'].matrix_world.to_quaternion() @ Vector((0, -.04, 0))
    # ---- Kiryu: phone, looks up at the knock, back down
    k = S['k']; C.reset_pose(k)
    kl = lambda v: C.local(k, v)
    C.arm_to(k, 'l', kl((.2, -.02, .84)), Vector((.3, .3, 0)))
    look_up = ease((t - 4.5) / .5) * (1 - ease((t - 7.0) / .8))
    C.rot_world(k, 'neck_01', k.matrix_world.to_3x3().normalized() @ Vector((1, 0, 0)), -16 + 22 * look_up)
    C.rot_world(k, 'head', (0, 0, 1), 10 * look_up)
    C.grip(k, 'l', .3)
    eyes = C.bone_head(k, 'head') + C.local(k, (0, -.08, .05)) - C.local(k, (0, 0, 0))
    C.phone_grip3(k, 'r', S['kphone'], eyes, kl((-.03, -.29, 1.33)), Vector((-.3, .3, -.5)))
    head = C.bone_head(k, 'head') + Vector((0, 0, .1))
    S['kphone_l'].location = S['kphone'].matrix_world.translation + S['kphone'].matrix_world.to_quaternion() @ Vector((0, -.03, 0))
    S['kphone_l'].rotation_euler = (head - S['kphone_l'].location).to_track_quat('-Z', 'Y').to_euler()
    # ---- Taiga: back to the door, hands behind; flinches into it at the knocks
    tg_ = S['t']; C.reset_pose(tg_)
    tl = lambda v: C.local(tg_, v)
    press = ease((t - 3.0) / .3) * (1 - .4 * ease((t - 5.5) / 1.5))
    C.rot_world(tg_, 'spine_01', tg_.matrix_world.to_3x3().normalized() @ Vector((1, 0, 0)), 5 * press)
    C.arm_to(tg_, 'l', tl((.1, .16, .95)), Vector((.3, .4, 0)))
    C.arm_to(tg_, 'r', tl((-.1, .16, .95)), Vector((-.3, .4, 0)))
    C.rot_world(tg_, 'head', (0, 0, 1), 20 + 8 * press)
    bpy.context.view_layer.update()

if __name__ == '__main__':
    a = sys.argv[sys.argv.index('--') + 1:]
    out, f0, f1, spp, pct = a[0], int(a[1]), int(a[2]), int(a[3]), int(a[4])
    step = int(a[5]) if len(a) > 5 else 1
    import os; os.makedirs(out, exist_ok=True)
    build()
    s = bpy.context.scene
    s.view_settings.exposure = .8
    s.view_settings.look = 'AgX - Medium High Contrast'
    for f in range(f0, f1 + 1, step):
        p = f'{out}/f{f:04d}.png'
        if os.path.exists(p): continue
        at(f / FPS)
        lib.render(p, samples=spp, pct=pct)
