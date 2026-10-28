"""第2章 23:00 — 扉の前の沈黙.  build(style) where style in main / doll / print."""
import sys, math, random
sys.path.insert(0, '/home/claude/kf')
import bpy
from mathutils import Vector
import lib
from lib import prim, mat_basic, mat_image, tex_path, wood_proc, noise_proc, kelvin

W, Z1, ZG, YG, H = .9, 6.3, -.18, 4.45, 2.45   # half width, front wall y, genkan floor z, genkan start y, ceiling
random.seed(11)

def mats():
    M = {}
    M['log'] = mat_image('log', tex_path('log'), rough=.7, bump=.3, coords='UV', tint=(.5, .44, .38),
                         fallback=wood_proc((.56, .37, .2), (.24, .13, .06), scale=5, stretch=(1, 1, 7), axis='Z'))
    M['chink'] = mat_image('chink', tex_path('chinking'), rough=.95, coords='UV', bump=.4,
                           fallback=noise_proc((.62, .58, .52), (.42, .39, .35), 60, .2))
    M['floor'] = mat_image('floor', tex_path('floor'), rough=.5, coords='UV', tint=(.7, .62, .55),
                           fallback=wood_proc((.48, .32, .18), (.2, .12, .06), scale=7, stretch=(1, 1, 9), axis='Y', bumpv=.15))
    M['ceil'] = mat_image('ceil', tex_path('floor'), rough=.8, coords='UV', tint=(.7, .65, .6),
                          fallback=wood_proc((.4, .27, .15), (.17, .1, .05), scale=7, stretch=(1, 1, 9), axis='Y'))
    M['tile'] = mat_image('tile', tex_path('tile'), rough=.45, coords='UV', bump=.1,
                          fallback=noise_proc((.42, .42, .4), (.25, .25, .25), 30, .1))
    M['door'] = mat_image('door', tex_path('door'), rough=.6, coords='UV',
                          fallback=wood_proc((.26, .16, .09), (.1, .06, .03), scale=6, stretch=(1, 1, 8), axis='Z'))
    M['framewood'] = mat_image('framewood', tex_path('door'), rough=.6, coords='Object', scale=(2, 2), tint=(1.3, 1.2, 1.1))
    M['agari'] = mat_image('agari', tex_path('log'), rough=.45, coords='UV', bump=.1, tint=(1.05, .95, .85), fallback=wood_proc((.72, .52, .31), (.42, .27, .13), scale=6, stretch=(1, 1, 9), axis='X'))
    M['metal'] = mat_basic('metal', (.08, .08, .085), .35, .5, metal=.8)
    M['chrome'] = mat_basic('chrome', (.55, .55, .56), .2, .5, metal=1)
    M['black'] = mat_basic('black', (.02, .02, .022), .5)
    M['rubber'] = mat_basic('rubber', (.015, .015, .015), .8)
    M['glass'] = mat_basic('glass', (.8, .85, .9), .35)
    g = M['glass'].node_tree.nodes['Principled BSDF']; g.inputs['Transmission Weight'].default_value = 1; g.inputs['Roughness'].default_value = .3
    M['led'] = mat_basic('ledface', (1, 1, 1), .4, emit=kelvin(5600), estr=12)
    M['rec'] = mat_basic('rec', (1, .05, .03), .4, emit=(1, .04, .02), estr=60)
    M['umb'] = mat_basic('umb', (.85, .9, .92), .15)
    u = M['umb'].node_tree.nodes['Principled BSDF']; u.inputs['Transmission Weight'].default_value = .85; u.inputs['Alpha'].default_value = .7
    M['phone'] = mat_basic('phone', (.6, .8, 1), .3, emit=kelvin(9000), estr=25)
    # clothes
    M['knit'] = mat_image('knit', tex_path('knit'), rough=.95, coords='Object', scale=(5, 5), bump=.3, tint=(.55, .55, .58),
                          fallback=noise_proc((.42, .42, .43), (.3, .3, .31), 300, .3))
    M['denim'] = mat_image('denim', tex_path('denim'), rough=.9, coords='Object', scale=(4, 4),
                           fallback=noise_proc((.12, .16, .26), (.06, .08, .14), 250, .2))
    M['plaid'] = mat_image('plaid', tex_path('plaid'), rough=.95, coords='Object', scale=(3, 3),
                           fallback=noise_proc((.2, .26, .2), (.08, .1, .08), 30, .1))
    M['tee'] = mat_basic('tee', (.05, .05, .055), .9)
    M['olive'] = mat_basic('olive', (.18, .19, .12), .85)
    M['white'] = mat_basic('white', (.75, .74, .72), .85)
    M['track'] = mat_basic('track', (.04, .05, .09), .6)
    M['sock'] = mat_basic('sock', (.6, .6, .6), .9)
    M['sockd'] = mat_basic('sockd', (.12, .12, .12), .9)
    M['corduroy'] = mat_image('cord', tex_path('corduroy'), rough=.9, coords='Object', scale=(3, 3), fallback=noise_proc((.5, .36, .08), (.3, .2, .04), 200, .2))
    return M

def cyl_between(name, a, b, r, mat, seg=14):
    a, b = Vector(a), Vector(b); d = b - a
    o = prim('cylinder', name, loc=(a + b) / 2, vertices=seg, radius=r, depth=d.length, mat=mat)
    o.rotation_euler = d.to_track_quat('Z', 'Y').to_euler(); lib.smooth(o, 50)
    return o

def logs_along(axis, fixed, lo, hi, holes, M, inward, cut=None):
    """Stack of logs; holes = list of (a,b,z0,z1) along the wall axis."""
    z = ZG + .09
    i = 0
    top_ = H + .1 if cut is None else cut
    while z < top_:
        segs = [(lo, hi)]
        for (ha, hb, z0, z1) in holes:
            if z + .11 > z0 and z - .11 < z1:
                ns = []
                for a, b in segs:
                    if hb <= a or ha >= b: ns.append((a, b))
                    else:
                        if ha > a: ns.append((a, ha))
                        if hb < b: ns.append((hb, b))
                segs = ns
        for a, b in segs:
            if b - a < .04: continue
            if axis == 'Y': p0, p1 = (fixed - inward * .03, a, z), (fixed - inward * .03, b, z)
            else: p0, p1 = (a, fixed - inward * .03, z), (b, fixed - inward * .03, z)
            o = cyl_between(f'log{axis}{i}', p0, p1, .118 + random.uniform(-.006, .006), M['log'], seg=20)
            lib.uv_cyl(o, 1.25)
            i += 1
        z += .226
    # chinking backing, with the openings cut out
    rects = [(lo, hi, ZG, top_ - .06)]
    for (ha, hb, z0, z1) in holes:
        nr = []
        for (a, b, c, d) in rects:
            if hb <= a or ha >= b: nr.append((a, b, c, d)); continue
            if ha > a: nr.append((a, ha, c, d))
            if hb < b: nr.append((hb, b, c, d))
            nr.append((max(a, ha), min(b, hb), z1, d))
            if z0 > c: nr.append((max(a, ha), min(b, hb), c, z0))
        rects = nr
    for (a, b, c, d) in rects:
        if b - a < .01 or d - c < .01: continue
        if axis == 'Y':
            o = prim('plane', 'chinkY', loc=(fixed + inward * .06, (a + b) / 2, (c + d) / 2), rot=(0, math.pi / 2, 0), scale=((d - c) / 2, (b - a) / 2, 1), mat=M['chink'])
        else:
            o = prim('plane', 'chinkX', loc=((a + b) / 2, fixed + inward * .06, (c + d) / 2), rot=(math.pi / 2, 0, 0), scale=((b - a) / 2, (d - c) / 2, 1), mat=M['chink'])
        lib.uv_box(o, .9)

def boards(name, x0, x1, y0, y1, z, w, M, mat, along='Y', thick=.03):
    n = int(round((x1 - x0) / w)) if along == 'Y' else int(round((y1 - y0) / w))
    for i in range(n):
        if along == 'Y':
            cx = x0 + (i + .5) * w; o = prim('cube', f'{name}{i}', loc=(cx, (y0 + y1) / 2, z), scale=(w / 2 - .002, (y1 - y0) / 2, thick / 2), mat=mat)
        else:
            cy = y0 + (i + .5) * w; o = prim('cube', f'{name}{i}', loc=((x0 + x1) / 2, cy, z), scale=((x1 - x0) / 2, w / 2 - .002, thick / 2), mat=mat)
        # per-board UV offset handled by object coords; add slight tone variation via scale of z
        o.rotation_euler.z = random.uniform(-.002, .002)

def fresnel(base, head_h, aim, M, energy=260, k=3200, size=24):
    """C-stand with a small tungsten fresnel; the light it throws is the scene's key."""
    bx, by = base
    for kk in range(3):
        a = kk / 3 * math.tau + .4
        cyl_between('csleg', (bx, by, .52), (bx + math.cos(a) * .38, by + math.sin(a) * .38, .02), .011, M['metal'], 8)
    cyl_between('cscol', (bx, by, .02), (bx, by, head_h), .016, M['metal'], 10)
    hp = Vector((bx, by, head_h + .12)); d = (Vector(aim) - hp).normalized()
    cyl_between('yoke', (bx, by, head_h), hp, .01, M['metal'], 6)
    body_ = cyl_between('fresnel', hp - d * .14, hp + d * .1, .085, M['black'], 18)
    lensm = mat_basic('fres_lens', (1, .9, .7), .3, emit=kelvin(k), estr=30)
    lens_ = cyl_between('fres_lens', hp + d * .1, hp + d * .105, .07, lensm, 18); lens_.visible_shadow = False
    for kk in range(4):   # barn doors
        a = kk / 4 * math.tau
        x, y = _perp(d)
        off = (x * math.cos(a) + y * math.sin(a)) * .095
        bd = prim('cube', 'barndoor', loc=hp + d * .16 + off, scale=(.09, .002, .05), mat=M['black'])
        bd.rotation_euler = (d.to_track_quat('Y', 'Z')).to_euler()
    return lib.spot('fresnel_key', tuple(hp + d * .12), aim, energy, k=k, size=size, blend=.18, radius=.05)

def _perp(d):
    up = Vector((0, 0, 1)) if abs(d.z) < .95 else Vector((0, 1, 0))
    x = d.cross(up).normalized(); return x, d.cross(x).normalized()

def cstand(base, head_h, M):
    """Film C-stand with a small LED panel aimed at the ceiling."""
    bx, by = base
    for k in range(3):
        a = k / 3 * math.tau + .4
        cyl_between('csleg', (bx, by, .52), (bx + math.cos(a) * .38, by + math.sin(a) * .38, .02), .011, M['metal'], 8)
    cyl_between('cscol', (bx, by, .02), (bx, by, head_h), .016, M['metal'], 10)
    cyl_between('csarm', (bx, by, head_h - .05), (bx - .25, by + .15, head_h + .05), .011, M['metal'], 8)
    p = prim('cube', 'ledpanel', loc=(bx - .28, by + .17, head_h + .1), scale=(.16, .025, .16), mat=M['black'])
    p.rotation_euler = (math.radians(-60), 0, math.radians(-30))
    face = prim('plane', 'ledface', loc=(0, 0, 0), scale=(.145, .145, 1), mat=M['led'])
    face.parent = p; face.location = (0, -1.05, 0); face.rotation_euler = (math.radians(90), 0, 0)
    face.scale = (.145 / .16, .145 / .16, 1)
    face.visible_shadow = False
    return p

def tripod(loc, yaw, M):
    x, y = loc
    for k in range(3):
        a = k / 3 * math.tau + yaw
        cyl_between('tpleg', (x, y, 1.32), (x + math.cos(a) * .28, y + math.sin(a) * .28, .0), .011, M['metal'], 8)
    cyl_between('tpcol', (x, y, 1.3), (x, y, 1.42), .02, M['metal'], 8)
    body = prim('cube', 'cam', loc=(x, y, 1.5), scale=(.055, .11, .06), mat=M['black']); body.rotation_euler.z = yaw
    lens = cyl_between('lens', (x, y, 1.5), (x - math.sin(yaw) * .17, y + math.cos(yaw) * .17, 1.5), .042, M['rubber'], 16)
    lcd = prim('cube', 'lcd', loc=(x - .07, y, 1.51), scale=(.004, .045, .035), mat=mat_basic('lcd', (.02, .03, .03), .2, emit=(.25, .3, .35), estr=.6))
    lcd.rotation_euler.z = yaw + .9
    led = prim('uv_sphere', 'recled', loc=(x + .03, y + .06, 1.565), radius=.006, mat=M['rec'])
    r = lib.point('rec_light', (x + .03, y + .075, 1.57), .25, color=(1, .03, .01), radius=.004)
    return body

def build(style='main'):
    s = lib.reset()
    M = mats()
    # --- shell
    logs_along('Y', -W, -.4, Z1, [(4.75, 5.55, ZG, 2.02)] if False else [], M, -1)          # left wall solid
    logs_along('Y', W, -.4, Z1, [(.8, 2.3, ZG, 2.05)], M, 1)                                 # right wall: opening to the living room
    logs_along('X', Z1, -W, W, [(-.46, .46, ZG, 2.0)], M, 1)                                 # front wall with the door
    if style != 'doll':
        logs_along('X', -.4, -W, W, [], M, -1)
    fl = prim('cube', 'floor', loc=(0, (YG - .4) / 2, -.015), scale=(W + .1, (YG + .4) / 2, .015), mat=M['floor']); lib.uv_box(fl, .87)
    gk = prim('cube', 'genkan', loc=(0, (YG + Z1) / 2, ZG - .02), scale=(W + .1, (Z1 - YG) / 2, .02), mat=M['tile']); lib.uv_box(gk, 1.2)
    ag = prim('cube', 'agarikamachi', loc=(0, YG - .05, -.09), scale=(W, .07, .105), mat=M['agari']); lib.uv_box(ag, 1.25)
    if style != 'doll':
        ce = prim('cube', 'ceiling', loc=(0, (Z1 - .4) / 2, H + .015), scale=(W + .1, (Z1 + .4) / 2, .015), mat=M['ceil']); lib.uv_box(ce, .87)
        for yb in (.6, 2.3, 4.0, 5.7):
            b = cyl_between('beam', (-W - .05, yb, H - .1), (W + .05, yb, H - .1), .1, M['log'], 16); lib.uv_cyl(b, 1.25)
    # living room beyond the opening: dark, only a couch edge catching light
    lf = prim('cube', 'lr_floor', loc=(2.4, 1.5, -.01), scale=(1.5, 2.5, .01), mat=M['floor']); lib.uv_box(lf, .87)
    prim('cube', 'couch', loc=(2.2, 1.6, .25), scale=(.45, .9, .25), mat=M['corduroy'])
    # --- door with slit window
    dmat = M['door']
    prim('cube', 'door_l', loc=(-.29, Z1 - .02, .91), scale=(.15, .025, 1.09), mat=dmat)
    prim('cube', 'door_r', loc=(.24, Z1 - .02, .91), scale=(.2, .025, 1.09), mat=dmat)
    prim('cube', 'door_t', loc=(-.075, Z1 - .02, 1.87), scale=(.065, .025, .13), mat=dmat)
    prim('cube', 'door_b', loc=(-.075, Z1 - .02, .25), scale=(.065, .025, .43), mat=dmat)
    gl = prim('plane', 'slitglass', loc=(-.075, Z1 - .02, 1.1), rot=(math.pi / 2, 0, 0), scale=(.065, .64, 1), mat=M['glass'])
    gl.visible_shadow = False
    for x in (-.47, .47): prim('cube', 'jamb', loc=(x, Z1 - .04, .91), scale=(.035, .09, 1.1), mat=M['framewood'])
    prim('cube', 'lintel', loc=(0, Z1 - .04, 2.04), scale=(.5, .09, .04), mat=M['framewood'])
    for o in bpy.data.objects:
        if o.name.startswith('door_'): lib.uv_box(o, 1.0, rot90=False, offset=(0, 0))
    lever = prim('cube', 'lever', loc=(.36, Z1 - .07, .98), scale=(.06, .012, .01), mat=M['chrome'])
    # her hand on the glass, outside, and the phone she holds up
    M['nskin'] = mat_basic('nskin', (.7, .5, .42), .5, sss=.2)
    hand = prim('cube', 'hand_palm', loc=(-.07, Z1 + .02, 1.22), scale=(.04, .008, .05), mat=M['nskin'])
    for i, dx in enumerate((-.03, -.01, .01, .03)):
        prim('cube', f'finger{i}', loc=(-.07 + dx, Z1 + .02, 1.3 + (.01 if i in (1, 2) else 0)), scale=(.008, .008, .035), mat=M['nskin'])
    prim('cube', 'thumb', loc=(-.12, Z1 + .02, 1.2), rot=(0, .6, 0), scale=(.008, .008, .03), mat=M['nskin'])
    ph = prim('plane', 'phone_glow', loc=(-.02, Z1 + .35, 1.05), rot=(math.pi / 2, 0, 0), scale=(.04, .07, 1), mat=M['phone'])
    ph.visible_shadow = False
    sp = lib.spot('phone_light', (-.04, Z1 + .4, 1.12), (.1, 3.1, .9), 40, k=9500, size=60, blend=.3, radius=.03)
    lib.area('rain_sky', (0, Z1 + 1.2, 1.0), (0, Z1, 1.0), 2, k=12000, size=(.6, 1.8))
    # --- genkan props: four pairs of shoes (hers is gone), slippers, six umbrellas
    shoe = [mat_basic('shoe0', (.08, .08, .09), .6), mat_basic('shoe1', (.72, .7, .66), .7), mat_basic('shoe2', (.25, .19, .13), .6), mat_basic('shoe3', (.1, .12, .2), .6)]
    for i in range(4):
        for d in (-.06, .06):
            o = prim('cube', 'shoe', loc=(-.6 + i * .2 + d, 5.0 + (i % 2) * .35, ZG + .045), scale=(.045, .13, .04), mat=shoe[i])
            o.rotation_euler.z = random.uniform(-.25, .25)
    prim('cylinder', 'ustand', loc=(.68, 6.05, ZG + .22), vertices=16, radius=.09, depth=.44, mat=M['black'])
    for i in range(6):
        a = i / 6 * math.tau
        u = cyl_between('umb', (.68 + math.cos(a) * .04, 6.05 + math.sin(a) * .04, ZG + .05), (.68 + math.cos(a) * .1, 6.05 + math.sin(a) * .1, ZG + .95), .03, M['umb'], 8)
        cyl_between('uh', (.68 + math.cos(a) * .1, 6.05 + math.sin(a) * .1, ZG + .95), (.68 + math.cos(a) * .12, 6.05 + math.sin(a) * .12, ZG + 1.06), .009, M['white'], 6)
    for i in range(3):
        for d in (-.06, .06):
            prim('cube', 'slipper', loc=(.45 + d, 2.9 - i * .32, .015), scale=(.045, .12, .015), mat=mat_basic('slip', (.3, .33, .37), .8))
    # --- film gear left on the set
    fresnel((.66, 3.0), 2.0, (-.12, 4.25, 0), M, energy=520, size=34)
    tp = tripod((-.6, 4.35), math.radians(200), M)   # the fixed camera, watching the hallway (ch.11 tape)
    cu = bpy.data.curves.new('cable', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = .007
    spl = cu.splines.new('BEZIER'); pts = [(.66, 3.1, .01), (.35, 3.3, .008), (.1, 3.0, .008), (.5, 2.4, .008), (1.6, 1.8, .008)]
    spl.bezier_points.add(len(pts) - 1)
    for bp, p in zip(spl.bezier_points, pts): bp.co = p; bp.handle_left_type = bp.handle_right_type = 'AUTO'
    co = bpy.data.objects.new('cable', cu); lib.link(co); co.data.materials.append(M['rubber'])
    ab = prim('cube', 'applebox', loc=(.6, 4.1, .1), rot=(0, 0, .25), scale=(.25, .15, .1), mat=M['agari']); lib.uv_box(ab, 1.25)
    # the empty mark: gaffer-tape X with her name, where Natsuki was supposed to stand for tonight's shot
    def tapeX(name, x, y, z, png):
        tm = mat_image(f'tape_{name}', f'/home/claude/kf/{png}', rough=.6, bump=0)
        for r in (.6, -.6):
            o = prim('plane', 'tape', loc=(x, y, z + .0035), rot=(0, 0, r), scale=(.13, .026, 1), mat=tm)
    tapeX('n', -.08, 3.95, 0, 'tape_natsuki.png')
    # --- people
    P = {}
    hands_back = dict(lel=(.2, .1, 1.12), lwr=(.12, .16, .95), lha=(.08, .17, .9), rel=(-.2, .1, 1.12), rwr=(-.12, .16, .95), rha=(-.08, .17, .9))
    pockets = dict(lel=(.22, .03, 1.13), lwr=(.19, -.04, .93), lha=(.17, -.03, .86), rel=(-.22, .03, 1.13), rwr=(-.19, -.04, .93), rha=(-.17, -.03, .86))
    P['taiga'] = lib.figure('taiga', top=M['tee'], pants=M['track'], feet=M['sockd'], skin=(.74, .55, .43), sleeve='short', s=1.07, wide=1.1,
                            loc=(.36, Z1 - .22, ZG), yaw=-14, head_yaw=-24, head_pitch=4, pose=dict(hands_back, lean=(0, .05, 0)))
    P['kiryu'] = lib.figure('kiryu', top=M['plaid'], pants=M['olive'], feet=M['sockd'], skin=(.76, .57, .45), s=1.04,
                            loc=(-.42, 4.95, ZG), yaw=26, head_yaw=-4, head_pitch=-4, pose=pockets)

    return P

def cam_main():
    bpy.context.scene.view_settings.exposure = 1.0
    return lib.camera((.4, 2.0, 1.55), (-.25, 5.2, .75), lens=18)

if __name__ == '__main__':
    style = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else 'main'
    out = sys.argv[sys.argv.index('--') + 2] if '--' in sys.argv else '/home/claude/kf/out/door_test.png'
    spp = int(sys.argv[sys.argv.index('--') + 3]) if '--' in sys.argv else 24
    pct = int(sys.argv[sys.argv.index('--') + 4]) if '--' in sys.argv else 50
    build(style); cam_main()
    lib.render(out, samples=spp, pct=pct)
