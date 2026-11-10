"""段階2: the rest of the house, so the whole of it can be walked (the study, the upstairs rooms, the cellar), and the
things the night changes in it (the boards over the windows, the generator's cord up the cellar stair).
Plan coordinates (house4: x east, y back), as furnish.py. build(M) makes it all and returns collider boxes.

Whose room is whose (企画書「間取り」, kept to what the story needs):
  寝室1 (SW, over the living room)   澪と夏希: two beds, their bags; the window looks south over the porch side
  (2F and the cellar, what is in them: see the note at upstairs() below)
  寝室2 (NW)                          桐生と大河: two beds, the camera cases, the make-up kit's empty foam
  寝室3 (SE, over the study)          真琴: she lies down here at 3:30 with a headache (the CO comes up the stair)
  洗面・浴室 (NE)                     a tiled bathroom with a deep tub, the washbasin, a washing machine
  書斎 (和室, 1F SE)                  the owner's room: tatami, a writing desk, his hunting trophies
  地下                                 the generator in the NE corner under the small window (its exhaust hose goes out of
                                       it), fuel cans, the bare bulb, shelves of the owner's things, the barred door
"""
import math, random
import bpy
from mathutils import Vector
import lib, house4 as H4, cloth, lived
from lib import prim, mat_basic, mat_image, tex_path
import furnish as F
from furnish import box, cyl, legs, collide

X, Y = H4.X, H4.Y
F2, ZB, H1, H2 = H4.F2, H4.ZB, H4.H1, H4.H2

def mats(M):
    F.mats(M)
    if 'tatami' in M: return
    M['tatami'] = mat_image('tatami', tex_path('ph/tatami_face_diff'), rough=.85, coords='UV', bump=.1, tint=(.95, .95, .9),
                            fallback=lib.noise_proc((.55, .52, .34), (.42, .4, .25), 120, .1))
    M['tatamiedge'] = mat_basic('tatamiedge', (.06, .07, .06), .7)
    M['concrete'] = mat_image('concrete', tex_path('ph/concrete_wall_006_diff'), rough=.9, coords='UV', bump=.1, tint=(1.05, 1.05, 1.05),
                              fallback=lib.noise_proc((.36, .35, .33), (.24, .23, .22), 25, .15))
    M['cfloor'] = mat_image('cfloor', tex_path('ph/concrete_floor_worn_001_diff'), rough=.8, coords='UV', bump=.05, tint=(1.1, 1.1, 1.1))
    M['bedding'] = mat_basic('bedding', (.72, .72, .68), .9)
    M['blanket'] = mat_image('blanket', tex_path('plaid'), rough=.95, coords='UV', bump=.05, tint=(.5, .6, .7))
    M['blanket2'] = mat_image('blanket2', tex_path('knit'), rough=.95, coords='UV', bump=.1, tint=(.75, .5, .4))
    M['bagnavy'] = mat_basic('bagnavy', (.05, .07, .13), .7)
    M['bagred'] = mat_basic('bagred', (.45, .07, .05), .7)
    M['bagolive'] = mat_basic('bagolive', (.16, .17, .1), .8)
    M['case'] = mat_basic('case', (.05, .05, .05), .45)
    M['foam'] = mat_basic('foam', (.12, .12, .12), .95)
    M['bathtile'] = mat_image('bathtile', tex_path('tile'), rough=.3, coords='UV', bump=.05, tint=(.85, .9, .9))
    M['enamel'] = mat_basic('enamel', (.82, .83, .82), .15)
    M['mirror'] = mat_basic('mirror', (.7, .72, .74), .03, metal=1)
    M['towel'] = mat_basic('towel', (.6, .7, .72), .95)
    M['genred'] = mat_basic('genred', (.55, .08, .04), .45)
    M['genyel'] = mat_basic('genyel', (.75, .52, .05), .45)
    M['canred'] = mat_basic('canred', (.5, .07, .04), .5)
    M['hose'] = mat_basic('hose', (.12, .12, .11), .6, metal=.3)
    M['cord'] = mat_basic('cord', (.85, .32, .03), .5)       # an orange outdoor extension cord: reads through the print
    M['sheet'] = mat_basic('sheet', (.6, .58, .52), .95)
    M['bulb'] = mat_basic('bulb', (1, .9, .7), .3, emit=lib.kelvin(2600), estr=10)
    M['board'] = mat_image('board', tex_path('ph/raw_plank_wall_diff'), rough=.8, coords='UV', bump=.1)
    M['nail'] = mat_basic('nail', (.3, .3, .3), .4, metal=1)
    M['scroll'] = mat_basic('scroll', (.78, .74, .62), .9)
    M['ink'] = mat_basic('ink', (.04, .04, .04), .8)

# ---------------------------------------------------------------- 書斎（和室） plan x 6..10, y 0..3.6
def study(M):
    # tatami over the whole room (six mats and a half-mat strip), a little raised: the room is entered by the fusuma
    for (x0, y0, x1, y1) in ((6.06, .06, 7.84, .94), (6.06, .94, 7.84, 1.82), (7.84, .06, 9.94, 1.0), (7.84, 1.0, 9.94, 1.94),
                             (6.06, 1.82, 7.84, 2.7), (6.06, 2.7, 7.84, 3.54), (7.84, 1.94, 9.94, 2.74), (7.84, 2.74, 9.94, 3.54)):
        box('tatami', x0 + .004, y0 + .004, x1 - .004, y1 - .004, 0, .03, M['tatami'], .9)
        for (a, b, c, d) in ((x0, y0, x1, y0 + .03), (x0, y1 - .03, x1, y1)) if (x1 - x0) > (y1 - y0) else ((x0, y0, x0 + .03, y1), (x1 - .03, y0, x1, y1)):
            box('tatamiedge', a, b, c, d, 0, .031, M['tatamiedge'])
    # tokonoma in the north-east corner: a raised board, a hanging scroll
    box('study_toko', 8.9, 2.75, 9.94, 3.54, .03, .15, M['walnut'], col=True)
    box('study_tokopost', 8.86, 2.72, 8.94, 2.8, 0, H1, M['walnut'])
    box('study_scroll', 9.3, 3.5, 9.6, 3.53, .75, 1.9, M['scroll'])
    box('study_scrollrod', 9.27, 3.49, 9.63, 3.535, .73, .76, M['ink'])
    for i, z in enumerate((1.7, 1.55, 1.4, 1.25, 1.1)):   # brush strokes: a column of ink
        box('study_ink', 9.43 + .01 * math.sin(i * 1.7), 3.528, 9.47, 3.532, z - .06, z, M['ink'])
    # the owner's writing desk under the east window, a cushion before it, his ashtray and papers
    box('study_desk', 9.25, 1.15, 9.85, 2.45, .33, .37, M['walnut'])
    legs('study_deskleg', 9.25, 1.15, 9.85, 2.45, .33, .06, M['walnut'], inset=.02)
    collide(9.25, 1.15, 9.85, 2.45, 0, .38)
    import furnish as F
    if not F.tripo_prop('zabuton', (X(8.85), Y(1.75), .03), .15, .5, name='study_zabuton'):   # the user's Tripo cushion
        box('study_zabuton', 8.6, 1.5, 9.1, 2.0, .03, .1, M['cushion'])
    cyl('study_ashtray', 9.6, 1.4, .37, .4, .06, M['iron'])
    for i, (x, y, a) in enumerate(((9.55, 1.95, .2), (9.5, 2.1, -.1))):
        prim('plane', 'study_paper', loc=(X(x), Y(y), .371 + i * .001), rot=(0, 0, a), scale=(.12, .17, 1), mat=M['screen'])
    # a glass-fronted cabinet on the south wall: the stuffed birds and a fox
    # hollow (it was one solid block, and what stood inside it could not be seen through the glass)
    collide(6.4, .1, 8.0, .55, 0, 1.75)
    box('study_cab', 6.4, .1, 8.0, .12, 0, 1.75, M['walnut'])          # back
    box('study_cab', 6.4, .1, 6.44, .55, 0, 1.75, M['walnut']); box('study_cab', 7.96, .1, 8.0, .55, 0, 1.75, M['walnut'])
    box('study_cab', 6.4, .1, 8.0, .55, 0, .1, M['walnut']); box('study_cab', 6.4, .1, 8.0, .55, 1.71, 1.75, M['walnut'])
    # no glass in front: in Godot the pane read as an opaque board and hid the fox and the pheasant (試作45)
    # the Tripo fox on the bottom shelf in profile and the cock pheasant on the middle one (the built birds only without them)
    fox = F.tripo_prop('fox', (X(7.2), Y(.33), .25), math.radians(90), .72, name='study_fox')
    if fox: box('study_foxbase', 6.83, .19, 7.57, .47, .22, .25, M['walnut'])   # one board under the whole fox (ユーザー)
    phe = F.tripo_prop('pheasant', (X(7.2), Y(.33), .92), 0.0, .6, name='study_pheasant')
    birds = () if (fox and phe) else ((6.8, .25), (7.5, .25), (6.9, .95), (7.6, .95))
    for (x, z) in birds:
        lib.tube('study_bird', [(X(x), Y(.3), z + .05), (X(x + .06), Y(.33), z + .14), (X(x + .1), Y(.38), z + .22)], [(.05, .04), (.04, .035), (.02, .02)], M['fur'], seg=10)
    for z in (.2, .9, 1.4):
        box('study_shelf', 6.42, .12, 7.98, .53, z, z + .02, M['walnut'])
    if not fox: lib.tube('study_fox', [(X(7.0), Y(.33), 1.44), (X(7.3), Y(.33), 1.5), (X(7.55), Y(.35), 1.56), (X(7.65), Y(.42), 1.62)], [(.07, .06), (.08, .07), (.05, .05), (.025, .025)], M['fur'], seg=12)
    # antlers mounted all along the west (hall) wall over the fusuma: the owner's hunting, in rows
    for i in range(5):
        y = .4 + i * .65
        if 1.5 < y < 2.55: continue
        cx = X(6.06) + .01; cy = Y(y); z = 2.05
        prim('cylinder', 'study_plaque', loc=(cx + .01, cy, z), rot=(0, math.pi / 2, 0), scale=(.09, .12, .012), mat=M['door'], vertices=16)
        for s in (-1, 1):
            lib.tube('study_antler', [(cx + .03, cy + s * .03, z + .02), (cx + .14, cy + s * .12, z + .12), (cx + .18, cy + s * .2, z + .24), (cx + .16, cy + s * .24, z + .34)], [.014, .011, .008, .005], M['antler'], seg=6)
    # a ceiling lamp, off
    cyl('study_lampcord', 8.0, 1.8, 1.95, H1, .006, M['plastic'], 6)
    cyl('lampshade_lamp_study', 8.0, 1.8, 1.8, 1.97, .24, M['shade_off'], 24)

# ---------------------------------------------------------------- what the crew light the house with after 20:00
def night_lights(M):
    """Battery and flame, the crew's and the house's emergency things: a camping lantern on the living room's low table
    (where they sit out the night), candles on the kitchen counter, Makoto's phone by her bed. Their glow is a
    lampshade_<light> (times.py decides when each is lit)."""
    if 'lanternglow' not in M: M['lanternglow'] = mat_basic('lanternglow', (.95, .9, .8), .4, emit=lib.kelvin(3300), estr=4)
    if 'flame' not in M:
        M['flame'] = mat_basic('flame', (1, .7, .3), .4, emit=lib.kelvin(1800), estr=8)
        M['wax'] = mat_basic('wax', (.85, .82, .74), .5)
        M['phonescr'] = mat_basic('phonescr', (.6, .75, 1), .3, emit=lib.kelvin(8000), estr=3)
    # the owner's battery LED bars inside the study cabinet, under the two upper shelves (ユーザー「書斎の棚は光を足す」,
    # 試作45: through the print the fox and the pheasant were black). Battery, so they burn on through the outage
    if 'cabled' not in M: M['cabled'] = mat_basic('cabled', (.95, .93, .88), .4, emit=lib.kelvin(4300), estr=4)
    box('lampshade_cab_led', 6.5, .44, 7.9, .47, 1.385, 1.398, M['cabled'])
    box('lampshade_cab_led2', 6.5, .44, 7.9, .47, .885, .898, M['cabled'])
    x, y, z = 1.85, 1.6, .4
    cyl('lantern_base', x, y, z, z + .05, .055, M['plastic'], 16)
    cyl('lampshade_lantern_living', x, y, z + .05, z + .2, .045, M['lanternglow'], 16)
    cyl('lantern_top', x, y, z + .2, z + .24, .055, M['plastic'], 16)
    lib.tube('lantern_handle', [(X(x) - .04, Y(y), z + .24), (X(x), Y(y), z + .3), (X(x) + .04, Y(y), z + .24)], [.004] * 3, M['steel'], seg=6, sub=3)
    # the crew's lanterns upstairs, on the landing, in the kitchen (times.crew_lanterns: lit from 23:00). crew_*: out of the
    # lightmap and hidden before 23:00 (times.STATE crew)
    import times as TM
    for n, (x, y, z) in TM.P_CREW.items():
        cyl(f'crew_{n}_base', x, y, z, z + .05, .055, M['plastic'], 16)
        cyl(f'lampshade_{n}', x, y, z + .05, z + .2, .045, M['lanternglow'], 16).visible_shadow = False
        cyl(f'crew_{n}_top', x, y, z + .2, z + .24, .055, M['plastic'], 16)
        lib.tube(f'crew_{n}_handle', [(X(x) - .04, Y(y), z + .24), (X(x), Y(y), z + .3), (X(x) + .04, Y(y), z + .24)], [.004] * 3, M['steel'], seg=6, sub=3)
    for n, (x, y, z) in TM.P_CANDLES.items():   # three candles on a saucer, as on the north counter
        for (dx, dy, h) in ((-.06, 0, .14), (.06, -.07, .1), (0, .08, .17)):
            cyl(f'crew_{n}_wax', x + dx, y + dy, z + .006, z + .006 + h, .012, M['wax'], 10)
            prim('uv_sphere', f'lampshade_{n}', loc=(X(x + dx), Y(y + dy), z + .006 + h + .012), scale=(.006, .006, .013), mat=M['flame'], segments=8, ring_count=6)
        cyl(f'crew_{n}_saucer', x, y, z, z + .006, .09, M['fridge'], 16)
    for i, (cx, cy, h) in enumerate(((8.7, 7.62, .14), (8.82, 7.55, .1), (8.76, 7.7, .17))):
        cyl('candle', cx, cy, .862, .862 + h, .012, M['wax'], 10)
        prim('uv_sphere', 'lampshade_candle_kitchen', loc=(X(cx), Y(cy), .862 + h + .012), scale=(.006, .006, .013), mat=M['flame'], segments=8, ring_count=6)
    cyl('candle_saucer', 8.76, 7.62, .862, .868, .09, M['fridge'], 16)
    o = prim('cube', 'phone_makoto', loc=(X(9.62), Y(1.72), F2 + .62), rot=(0, 0, .3), scale=(.035, .072, .004), mat=M['plastic'])   # on her nightstand
    prim('plane', 'lampshade_phone_makoto', loc=(X(9.62), Y(1.72), F2 + .625), rot=(0, 0, .3), scale=(.032, .068, 1), mat=M['phonescr'])

# ---------------------------------------------------------------- 2F and the cellar: what is lived in (段階2, 2026-11-05)
# Two layers in every room (2026-11-04 the owner's life left after the cleaning; 2026-11-05 the crew's night over it):
# the owner's things are old and put away (his iron beds, his chest, his futons, the pale squares where his pictures
# hung, the curtains the sun has faded); the crew's are new and strewn (bags open on the floor, rolled sleeping bags,
# a crate of supplies with the cassette stove, cup noodles and gas, flashlights, drinking water), and they write on
# what they brought, on tape (lived2_tex.py). Cloth falls by the cloth simulation (cloth.py). Tripo's cloth (the user's,
# 画像生成とTripo_4回目) replaces the stand-ins when it comes: hoodie, duffel, sleepsack, futon, sleepbag.
from mathutils import Matrix, Vector as V3

def mats2(M):
    if 'sbag' in M: return
    M['sbag'] = mat_basic('sbag', (.78, .3, .06), .55)          # the crew's sleeping bags: orange nylon
    M['sbag_in'] = mat_basic('sbag_in', (.05, .07, .16), .7)     # their navy lining
    M['hoodie'] = mat_basic('hoodie', (.32, .32, .33), .95)
    M['curtain'] = mat_image('curtain', tex_path('knit'), rough=.95, coords='UV', bump=.05, tint=(.78, .72, .6))
    M['futon'] = mat_basic('futon', (.78, .74, .64), .95)
    M['mattress'] = mat_basic('mattress', (.6, .58, .53), .95)   # an old sheet: not the paper's white through the print
    M['coat'] = mat_basic('coat', (.2, .17, .14), .9)
    M['refl'] = mat_basic('refl', (.04, .04, .045), .6)
    M['futon2'] = mat_image('futon2', tex_path('plaid'), rough=.95, coords='UV', bump=.03, tint=(.85, .62, .55))
    M['stove'] = mat_basic('stove', (.75, .74, .7), .35)
    M['stovetop'] = mat_basic('stovetop', (.08, .08, .08), .5, metal=.3)
    M['gascan'] = mat_basic('gascan', (.85, .45, .08), .35)
    M['cup'] = mat_basic('cup', (.86, .84, .78), .5)
    M['cupband'] = mat_basic('cupband', (.62, .1, .07), .5)
    M['pet'] = mat_basic('pet', (.72, .8, .84), .1)
    M['petcap'] = mat_basic('petcap', (.1, .25, .6), .4)
    M['polyw'] = mat_basic('polyw', (.84, .84, .8), .45)
    M['polyb'] = mat_basic('polyb', (.08, .22, .55), .4)
    M['cbox'] = mat_basic('cbox', (.55, .42, .26), .9)
    M['dust'] = mat_basic('dust', (.46, .45, .41), .95)   # .66 burnt white near the bulb through the print (試作52)

def tape(M, n, at, normal, w, up=(0, 0, 1), name=None):
    """A strip of tape with writing on it (lived2_tex.py crew_<n>), w metres long, centred at world `at` on a surface
    facing `normal`; the writing's top toward `up` (projected on the surface), read from in front of it."""
    k = f'crew_{n}'
    if k not in M: M[k] = mat_image(k, tex_path(k), rough=.6, bump=0)
    im = next(x for x in M[k].node_tree.nodes if x.type == 'TEX_IMAGE').image
    h = w * im.size[1] / im.size[0]
    nz = V3(normal).normalized(); u = V3(up); u = (u - nz * u.dot(nz)).normalized()
    r = u.cross(nz).normalized()   # the reader's right, looking at the face
    R = Matrix((r, u, nz)).transposed().to_4x4()
    o = prim('plane', name or f'tape_{n}', loc=V3(at) + nz * .0015, mat=M[k])
    o.rotation_mode = 'XYZ'; o.rotation_euler = R.to_euler(); o.scale = (w / 2, h / 2, 1)
    return o

def apply_bevel(o, width, seg=3):
    bv = o.modifiers.new('bv', 'BEVEL'); bv.width = width; bv.segments = seg
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier='bv')
    return o

DIRS = {'w': (-1, 0), 'e': (1, 0), 'n': (0, 1), 's': (0, -1)}   # plan directions
def bed(M, cx, cy, head='w', blanket=None, rumpled=0.0, name='bed', z=0.0, seed=1):
    """The owner's old iron bed (Poly Haven old_bed_frame: the rental kept his beds), a thin mattress, a pillow, and a
    blanket dropped on it by the cloth simulation; slept in (rumpled > 0), it is shoved back toward the foot."""
    hd = DIRS[head]
    rz = {'w': math.pi / 2, 'e': -math.pi / 2, 'n': math.pi, 's': 0.0}[head]
    fr = lived.phm('old_bed_frame', cx, cy, z, rz=rz, name=f'{name}_frame')
    lx = head in 'we'
    hx, hy = (.94, .42) if lx else (.42, .94)
    collide(cx - hx - .04, cy - hy - .04, cx + hx + .04, cy + hy + .04, z, z + .66)
    mt = apply_bevel(box(f'{name}_mattress', cx - hx, cy - hy, cx + hx, cy + hy, z + .49, z + .64, M['mattress']), .035)
    px, py = cx + hd[0] * .7, cy + hd[1] * .7
    pl = prim('cube', f'{name}_pillow', loc=(X(px), Y(py), z + .69), rot=(0, 0, rz + .05 * (seed % 3 - 1)), scale=(.29, .17, .075), mat=M['bedding'])
    bpy.ops.object.select_all(action='DESELECT'); pl.select_set(True); bpy.context.view_layer.objects.active = pl
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    sb = pl.modifiers.new('sb', 'SUBSURF'); sb.levels = 3; bpy.ops.object.modifier_apply(modifier='sb')
    for c in pl.data.vertices:   # a pillow: full in the middle, thin at its edges, a dent where a head was
        c.co.z *= (1.0 - .45 * (abs(c.co.x) / .29) ** 4) * (1.0 - .35 * (abs(c.co.y) / .17) ** 4)
        if c.co.z > 0: c.co.z -= .025 * math.exp(-(c.co.x ** 2 + c.co.y ** 2) / .012) * (seed % 2)
    pl.data.update()
    # the blanket: across the bed and hanging down its sides; a slept-in one bunched toward the foot
    L = 1.55 - .25 * rumpled; Wd = 1.45
    off = .2 + .35 * rumpled
    bx, by = cx - hd[0] * off, cy - hd[1] * off
    size = (L, Wd) if lx else (Wd, L)
    push = None
    if rumpled: push = (-hd[0] * .45 * rumpled, hd[1] * .45 * rumpled)   # toward the foot (world Y is plan -y)
    cloth.drop(f'{name}_blanket', (X(bx), Y(by)), size, z + .95, blanket or M['blanket'], [mt, pl, fr], res=.03, frames=80,
               rumple=.12 + .15 * rumpled, seed=seed, floor=z, push=push, bend=.15)
    return mt

def hardcase(M, name, x0, y0, x1, y1, z, h, open_lid=False):
    """A crew's hard equipment case (試作52: a plain box read as a stand-in): rounded body, the lid's seam a dark band
    round it, two latches and a fold-down handle on the front (plan y0 side), ribs on the lid."""
    o = box(name, x0, y0, x1, y1, z, z + h, M['case'], col=True); apply_bevel(o, .015, 3)
    hz = z + h * .72
    box(f'{name}_seam', x0 - .004, y0 - .004, x1 + .004, y1 + .004, hz - .006, hz + .006, M['plastic'])
    w = x1 - x0
    for fx in (.22, .78):
        lx = x0 + w * fx
        box(f'{name}_latch', lx - .03, y0 - .016, lx + .03, y0, hz - .045, hz + .025, M['steel'])
    box(f'{name}_hinge', (x0 + x1) / 2 - .07, y0 - .02, (x0 + x1) / 2 + .07, y0, z + h * .45, z + h * .45 + .025, M['plastic'])
    lib.tube(f'{name}_handle', [(X((x0 + x1) / 2 - .06), Y(y0 - .012), z + h * .47), (X((x0 + x1) / 2 - .05), Y(y0 - .03), z + h * .3),
                                (X((x0 + x1) / 2 + .05), Y(y0 - .03), z + h * .3), (X((x0 + x1) / 2 + .06), Y(y0 - .012), z + h * .47)],
             [.009] * 4, M['plastic'], seg=6, sub=2)
    for k in range(3):   # ribs across the lid
        rx = x0 + w * (.25 + .25 * k)
        box(f'{name}_rib', rx - .012, y0 + .03, rx + .012, y1 - .03, z + h, z + h + .008, M['case'])
    return o

def bag(M, x, y, w, d, h, mat, name='bag', rot=0.0, z=0.0, tag=None):
    o = prim('cube', name, loc=(X(x), Y(y), z + h / 2), rot=(0, 0, rot), scale=(w / 2, d / 2, h / 2), mat=mat)
    bv = o.modifiers.new('bv', 'BEVEL'); bv.width = min(w, d, h) * .3; bv.segments = 3
    lib.tube(f'{name}_handle', [(X(x) - w * .25, Y(y), z + h), (X(x), Y(y), z + h + .08), (X(x) + w * .25, Y(y), z + h)], [.01] * 3, M['plastic'], seg=6, sub=3)
    collide(x - w / 2, y - d / 2, x + w / 2, y + d / 2, z, z + h)
    if tag: tape(M, tag, (X(x) + .1 * math.cos(rot), Y(y) + .1 * math.sin(rot), z + h), (0, 0, 1), .12, up=(-math.sin(rot), math.cos(rot), 0), name=f'{name}_tape')
    return o

def duffel(M, x, y, z, rot, mat, name, tag=None):
    if F.tripo_prop('duffel', (X(x), Y(y), z), rot, .62, name=name):
        collide(x - .3, y - .3, x + .3, y + .3, z, z + .3); return
    bag(M, x, y, .6, .32, .3, mat, name, rot, z, tag)

def sleeproll(M, x, y, z, rot, name):
    """A sleeping bag rolled in its stuff sack, lying on its side (Tripo sleepsack, or a built one)."""
    if F.tripo_prop('sleepsack', (X(x), Y(y), z), rot, .5, name=name): return
    o = prim('cylinder', name, loc=(X(x), Y(y), z + .12), rot=(math.pi / 2, 0, rot), scale=(.12, .12, .2), mat=M['sbag'], vertices=18)
    apply_bevel(o, .04)
    e = (math.cos(rot + math.pi / 2), math.sin(rot + math.pi / 2))   # the sack's axis (world)
    prim('cylinder', f'{name}_cord', loc=(X(x) + e[0] * .205, Y(y) + e[1] * .205, z + .12), rot=(math.pi / 2, 0, rot), scale=(.03, .03, .012), mat=M['plastic'], vertices=10)

def stove(M, x, y, z, rot=0.0, name='cstove'):
    """A cassette stove (built: the shape is simple and known), its can in, the lid down, a pot of nothing on it."""
    c, s = math.cos(rot), math.sin(rot)
    def at(dx, dy, dz): return (X(x) + dx * c - dy * s, Y(y) + dx * s + dy * c, z + dz)
    b = prim('cube', name, loc=at(0, 0, .045), rot=(0, 0, rot), scale=(.17, .145, .045), mat=M['stove']); apply_bevel(b, .012)
    prim('cube', f'{name}_top', loc=at(.02, 0, .091), rot=(0, 0, rot), scale=(.13, .13, .002), mat=M['stovetop'])
    prim('cylinder', f'{name}_burner', loc=at(.02, 0, .097), scale=(.045, .045, .006), mat=M['stovetop'], vertices=20)
    for k in range(4):
        a = rot + k * math.pi / 2 + math.pi / 4
        prim('cube', f'{name}_trivet', loc=(at(.02, 0, .1)[0] + .075 * math.cos(a), at(.02, 0, .1)[1] + .075 * math.sin(a), z + .1),
             rot=(0, 0, a), scale=(.03, .004, .008), mat=M['stovetop'])
    prim('cube', f'{name}_lid', loc=at(-.13, 0, .06), rot=(0, 0, rot), scale=(.035, .13, .025), mat=M['stove'])
    prim('cylinder', f'{name}_knob', loc=at(.17, -.08, .045), rot=(0, math.pi / 2, rot), scale=(.018, .018, .012), mat=M['plastic'], vertices=12)

def gascan(M, x, y, z, rot=0.0, name='gascan', lying=True):
    if lying: o = prim('cylinder', name, loc=(X(x), Y(y), z + .034), rot=(math.pi / 2, 0, rot), scale=(.034, .034, .095), mat=M['gascan'], vertices=14)
    else: o = prim('cylinder', name, loc=(X(x), Y(y), z + .095), scale=(.034, .034, .095), mat=M['gascan'], vertices=14)
    return o

def cupnoodle(M, x, y, z, name='cup'):
    o = prim('cone', name, loc=(X(x), Y(y), z + .05), scale=(.048, .048, .05), mat=M['cup'], vertices=16, radius1=.86, radius2=1.0, depth=2)
    prim('cylinder', f'{name}_band', loc=(X(x), Y(y), z + .06), scale=(.0465, .0465, .014), mat=M['cupband'], vertices=16)
    prim('cylinder', f'{name}_lid', loc=(X(x), Y(y), z + .1), scale=(.049, .049, .002), mat=M['cup'], vertices=16)

def pet(M, x, y, z, name='pet', lying=False, rot=0.0):
    if lying:
        prim('cylinder', name, loc=(X(x), Y(y), z + .05), rot=(math.pi / 2, 0, rot), scale=(.05, .05, .14), mat=M['pet'], vertices=14)
    else:
        prim('cylinder', name, loc=(X(x), Y(y), z + .14), scale=(.05, .05, .14), mat=M['pet'], vertices=14)
        prim('cylinder', f'{name}_cap', loc=(X(x), Y(y), z + .3), scale=(.016, .016, .02), mat=M['petcap'], vertices=10)

def polytank(M, x, y, z, rot=0.0, name='polytank', tag='water'):
    """The crew's 20 L water tank: white, a blue cap and its spout on top, tape on its front."""
    o = prim('cube', name, loc=(X(x), Y(y), z + .2), rot=(0, 0, rot), scale=(.15, .1, .2), mat=M['polyw']); apply_bevel(o, .03)
    c, s = math.cos(rot), math.sin(rot)
    prim('cylinder', f'{name}_cap', loc=(X(x) - .08 * c, Y(y) - .08 * s, z + .42), scale=(.03, .03, .02), mat=M['polyb'], vertices=14)
    lib.tube(f'{name}_handle', [(X(x) + .02 * c, Y(y) + .02 * s, z + .4), (X(x) + .07 * c, Y(y) + .07 * s, z + .45), (X(x) + .12 * c, Y(y) + .12 * s, z + .4)], [.012] * 3, M['polyw'], seg=6, sub=3)
    collide(x - .16, y - .16, x + .16, y + .16, z, z + .45)
    if tag: tape(M, tag, (X(x) + .101 * s, Y(y) - .101 * c, z + .24), (s, -c, 0), .14, name=f'{name}_tape')   # on its front (local -y)

def curtain(M, ax, fixed, inward, a, b, z0, z1, name):
    """The owner's faded curtains, a panel gathered at each side of a window on a thin rod. ax 'X': a window along plan
    x in the wall at plan y = fixed; inward: +1 when the room is toward +plan (y or x)."""
    d = .17    # off the wall's line: in front of the casing
    rodz = z1 + .1
    for k, (p, q) in enumerate(((a - .2, a + .22), (b - .22, b + .2))):
        mid = (p + q) / 2
        if ax == 'X':
            c = (X(mid), Y(fixed + inward * d)); rot = (math.pi / 2, 0, 0)
        else:
            c = (X(fixed + inward * d), Y(mid)); rot = (math.pi / 2, 0, math.pi / 2)
        h = rodz - z0
        cloth.drop(f'{name}_{k}', c, (q - p, h), z0 + h / 2, M['curtain'], (), rot=rot, res=.03, frames=50, slack=1.0, rumple=.0,
                   seed=k, pin=rodz - .02, pleat=(.035, .11), bend=.3, stiff=12.0, thick=.004)
    if ax == 'X':
        lib.tube(f'{name}_rod', [(X(a - .3), Y(fixed + inward * d), rodz), (X(b + .3), Y(fixed + inward * d), rodz)], [.008] * 2, M['steel'], seg=8, sub=1)
    else:
        lib.tube(f'{name}_rod', [(X(fixed + inward * d), Y(a - .3), rodz), (X(fixed + inward * d), Y(b + .3), rodz)], [.008] * 2, M['steel'], seg=8, sub=1)

def upstairs(M):
    z = F2
    mats2(M)
    import lived; lived.mats(M)
    # the owner's curtains on every bedroom window, pulled aside
    s0, s1 = H4.SILL2, H4.SILL2 + H4.WH2
    for (ax, fx, inw, a, b, nm) in (('X', 0, 1, .8, 2.2, 'cur1s'), ('Y', 0, 1, 1.2, 2.6, 'cur1w'), ('X', 8, -1, 1.2, 2.8, 'cur2n'),
                                    ('Y', 0, 1, 5.4, 6.8, 'cur2w'), ('X', 0, 1, 6.6, 8.0, 'cur3s'), ('Y', 10, -1, 1.2, 2.6, 'cur3e')):
        curtain(M, ax, fx, inw, a, b, s0 - .1, s1 + .05, nm)

    # 寝室1 (x 0..4, y 0..4.2): Mio and Natsuki. Natsuki's bed slept on and left (she went out); her hoodie on it, her
    # duffel open on the floor; Mio's bed made, her bag shut by it; their rolled sleeping bags at the foot (unused: the
    # beds were there)
    bed(M, 1.1, .62, 'w', M['blanket'], rumpled=.8, name='bed1a', z=z, seed=11)
    bed(M, 1.1, 3.62, 'w', M['blanket2'], rumpled=0.0, name='bed1b', z=z, seed=12)
    lived.phm('painted_wooden_nightstand', .38, 2.1, z, rz=math.pi / 2, name='bed1_table')   # under the west window's sill
    collide(.12, 1.84, .64, 2.36, z, z + .62)
    if not F.tripo_prop('hoodie', (X(1.25), Y(.6), z + .64), .5, .5, name='natsuki_hoodie'):
        cloth.drop('natsuki_hoodie', (X(1.3), Y(.62)), (.55, .5), z + .9, M['hoodie'], [bpy.data.objects['bed1a_mattress']],
                   res=.025, frames=40, rumple=.12, seed=5, bend=.2, thick=.006)
    duffel(M, 2.75, .55, z, .25, M['bagred'], 'bag_natsuki', 'natsuki')
    bag(M, 2.55, 3.85, .55, .3, .35, M['bagnavy'], 'bag_mio', -.1, z)
    for i, (x, y) in enumerate(((2.35, 1.6), (2.35, 1.9))):
        sleeproll(M, x, y, z, 0.0, f'sleepsack1_{i}')
    lived.ghost_frames(M, 'Y', 4, -1, [(.9, 1.35, z + 1.3, z + 1.62), (1.5, 1.8, z + 1.36, z + 1.74)])

    # 寝室2 (x 0..4, y 4.2..8): Kiryu and Taiga; the camera and light cases, the crew's crate of supplies on the floor
    # (the cassette stove, gas, cup noodles, water), the owner's chest of drawers against the wall to the landing with
    # the make-up kit on it
    bed(M, 1.1, 4.85, 'w', M['blanket'], rumpled=.3, name='bed2a', z=z, seed=21)
    bed(M, 1.1, 7.35, 'w', M['blanket'], rumpled=.9, name='bed2b', z=z, seed=22)
    lived.phm('vintage_wooden_drawer_01', 4.0 - .07 - .34, 5.25, z, rz=-math.pi / 2, s=.62, name='bed2_chest')
    collide(3.3, 4.7, 3.93, 5.8, z, z + .68)
    zc = z + 1.09 * .62
    box('makeup_box', 3.4, 4.85, 3.8, 5.15, zc, zc + .2, M['bagolive'])
    tape(M, 'makeup', (X(3.6), Y(4.85) + .0, zc + .1), (0, 1, 0), .16)
    for i in range(4):
        cyl('makeup_bottle', 3.45 + i * .09, 5.35, zc, zc + .1 + .03 * (i % 2), .022, M['canred'] if i % 2 else M['plastic'], 10)
    hardcase(M, 'case_cam', 2.25, 4.42, 2.95, 4.87, z, .32)
    tape(M, 'cam', (X(2.95) + .008, Y(4.645), z + .14), (1, 0, 0), .2)
    hardcase(M, 'case_light', 2.5, 7.4, 3.6, 7.85, z, .22)
    tape(M, 'light', (X(3.6) + .008, Y(7.625), z + .09), (1, 0, 0), .12)
    # the crew's crate of supplies by the west wall between the beds, with the stove on a box beside it
    cr = lived.phm('plastic_crate_02', 2.55, 6.05, z, rz=.08, name='crew_crate')
    collide(2.28, 5.82, 2.82, 6.28, z, z + .26)
    tape(M, 'crate', (X(2.55) + .0, Y(5.84), z + .17), (0, 1, 0), .15)
    for i in range(3): gascan(M, 2.42 + i * .075, 6.08, z + .02, 0.0, f'gascan_{i}')
    for i in range(3): cupnoodle(M, 2.66, 5.98 + i * .0, z + .02 + i * .1, f'cup_{i}')
    cb = lived.phm('cardboard_box_01', 2.55, 6.7, z, rz=1.57, name='crew_box')
    collide(2.28, 6.48, 2.82, 6.92, z, z + .34)
    stove(M, 2.55, 6.7, z + .34, .1)
    pet(M, 2.95, 6.45, z, 'pet_0'); pet(M, 3.05, 6.5, z, 'pet_1'); pet(M, 2.98, 6.62, z, 'pet_2', lying=True, rot=.6)
    duffel(M, 1.0, 6.15, z, -.15, M['bagolive'], 'bag_taiga', 'taiga')
    sleeproll(M, 2.3, 5.4, z, .3, 'sleepsack2_0')
    lived.phm('pastic_torch_6v', 2.85, 4.75, z + .34, rz=.4, name='torch_kiryu')

    # 寝室3 (x 6..10, y 0..4.2): Makoto. The owner's futons out of the closet, stacked by the wall; her bag; her phone and
    # a flashlight on the nightstand
    bed(M, 8.9, .72, 'e', M['blanket2'], rumpled=.35, name='bed3', z=z, seed=31)
    lived.phm('painted_wooden_nightstand', 9.62, 1.62, z, rz=-math.pi / 2, name='bed3_table')
    collide(9.36, 1.36, 9.88, 1.88, z, z + .62)
    cyl('bed3_cup', 9.75, 1.45, z + .616, z + .7, .035, M['fridge'], 12)
    lived.phm('small_plastic_torch', 9.52, 1.5, z + .616, rz=1.2, name='torch_makoto')
    if not F.tripo_prop('futon', (X(6.95), Y(3.7), z), 0.0, .95, name='futon_stack'):
        for i, (dx, h, m) in enumerate(((0, .14, 'futon'), (.02, .14, 'futon'), (-.03, .12, 'futon2'))):
            o = box('futon_stack', 6.3 + dx, 3.4, 7.6 + dx, 4.08, z + i * .14, z + i * .14 + h, M[m]); apply_bevel(o, .05)
    collide(6.25, 3.35, 7.65, 4.1, z, z + .42)
    bag(M, 7.3, .5, .5, .3, .34, M['bagnavy'], 'bag_makoto', .5, z)
    # the owner's chair by the east window, her jacket thrown over its back; her reflector in its round bag against
    # the wall (she holds it open in the first chapter)
    ch = lived.phm('painted_wooden_chair_01', 9.45, 3.1, z, rz=math.pi / 2 + .25, name='bed3_chair')
    collide(9.18, 2.83, 9.72, 3.37, z, z + .5)
    if ch:
        cloth.drop('makoto_jacket', (X(9.5), Y(3.1)), (.62, .5), z + 1.1, M['coat'], [ch], res=.025, frames=60, rumple=.06, seed=33,
                   floor=z, bend=.25, thick=.008)
    o = prim('cylinder', 'makoto_reflector', loc=(X(9.9), Y(3.75), z + .33), rot=(0, math.pi / 2 - .2, 0), scale=(.33, .33, .025), mat=M['refl'], vertices=32)
    apply_bevel(o, .02)
    lived.ghost_frames(M, 'Y', 6, 1, [(2.7, 3.15, z + 1.32, z + 1.7)])

    # 洗面・浴室 (x 6..10, y 4.2..8): the washbasin and machine by the door, the tub behind a low tiled step
    box('bath_floor', 6.06, 4.26, 9.94, 7.94, z, z + .015, M['bathtile'], 1.0)
    box('bath_part', 8.0, 4.26, 8.06, 5.4, z + .015, z + 2.0, M['bathtile'], col=True)
    box('bath_part', 8.0, 6.4, 8.06, 7.94, z + .015, z + 2.0, M['bathtile'], col=True)
    box('bath_tub', 8.5, 6.6, 9.94, 7.94, z, z + .58, M['enamel'], col=True)
    box('bath_water', 8.58, 6.68, 9.86, 7.86, z + .5, z + .505, M['glass'])
    box('bath_stool', 8.9, 5.6, 9.2, 5.9, z, z + .22, M['plastic'])
    cyl('bath_shower', 9.9, 6.0, z + 1.0, z + 1.9, .012, M['steel'], 8)
    box('wash_basin', 6.1, 4.9, 6.65, 5.7, z, z + .82, M['cabinet'], col=True)
    box('wash_top', 6.08, 4.88, 6.68, 5.72, z + .82, z + .86, M['enamel'])
    box('wash_mirror', 6.07, 4.95, 6.09, 5.65, z + 1.05, z + 1.75, M['mirror'])
    box('wash_machine', 6.1, 7.2, 6.7, 7.85, z, z + .85, M['fridge'], col=True)
    cyl('wash_machine_lid', 6.4, 7.52, z + .85, z + .86, .22, M['plastic'], 20)
    for i in range(3):
        box('wash_towel', 7.6 + i * .12, 7.9, 7.68 + i * .12, 7.94, z + 1.0, z + 1.45, M['towel'])

    # the landing: the runner; the crew's water and their rubbish by the bathroom door
    box('landing_runner', 4.12, 5.7, 5.9, 7.9, z, z + .008, M['rug'], 1.0)
    polytank(M, 5.75, 7.78, z, math.pi, 'polytank_landing')
    lived.phm('trashbag', 4.32, 7.72, z, rz=.7, s=.85, name='crew_trash')
    collide(4.1, 7.5, 4.55, 7.95, z, z + .45)

# ---------------------------------------------------------------- 地下 x 4..10, y 1..7 (the stair shaft x 5.06..6, y 2.5..5.64)
# the generator: plan centre, against the east wall under the small window (y 6.15..6.75). Poly Haven's
# portable_generator (CC0, its model number painted out: lived2_tex.py), long side along the wall, the control panel
# and its sockets toward the room (west), the recoil starter toward the stair (south), the exhaust side to the window
GEN = (9.45, 6.3)
GEN_Z = ZB + .045
GEN_SOCKET = (GEN[0] - .3, GEN[1] + .12, GEN_Z + .3)   # plan x, y, z: where the cord comes out of the panel
GEN_EXHAUST = (GEN[0] + .3, GEN[1] - .05, GEN_Z + .3)
def generator(M):
    gx, gy = GEN
    box('gen_plank', gx - .3, gy - .45, gx - .18, gy + .45, ZB, GEN_Z, M['board'])
    box('gen_plank', gx + .18, gy - .45, gx + .3, gy + .45, ZB, GEN_Z, M['board'])
    g = lived.phm('portable_generator', gx, gy, GEN_Z, rz=-math.pi / 2, name='generator')
    if g:
        im, nr = lib.img(tex_path('gen_diff')), lib.img(tex_path('gen_nor'), srgb=False)
        for m in g.data.materials:
            for n in m.node_tree.nodes:
                if n.type == 'TEX_IMAGE' and n.image and 'diff' in n.image.name: n.image = im
                elif n.type == 'TEX_IMAGE' and n.image and 'nor' in n.image.name: n.image = nr
        # the owner's old tape on the panel: how to start it
        tape(M, 'gen', (X(gx - .285), Y(gy - .12), GEN_Z + .47), (-1, 0, 0), .2)
        # 試作97: and a word on tape by each control (the same places as story.gd _gen_items)
        tape(M, 'gen_fuel', (X(gx - .285), Y(gy + .17), ZB + .625), (-1, 0, 0), .075)
        tape(M, 'gen_sw', (X(gx - .285), Y(gy - .1), ZB + .625), (-1, 0, 0), .09)
        tape(M, 'gen_choke', (X(gx - .285), Y(gy + .03), ZB + .385), (-1, 0, 0), .09)
        tape(M, 'gen_pull', (X(gx), Y(gy - .435), ZB + .52), (0, -1, 0), .075)
    collide(gx - .32, gy - .45, gx + .32, gy + .45, ZB, ZB + .65)
    # the exhaust hose: a flexible metal duct from the engine's side, up the wall and out of the small window
    ex, ey, ez = GEN_EXHAUST
    lib.tube('gen_hose', [(X(ex), Y(ey), ez), (X(ex + .12), Y(ey + .05), ez + .15), (X(9.82), Y(6.42), ZB + .8),
                          (X(9.9), Y(6.45), ZB + 1.0), (X(10.15), Y(6.45), ZB + .97),
                          # 試作97: on out between the boards and down to the ground (ユーザー「窓からホースが出てない」: in 96 it
                          # stopped inside the wall, behind the boards; Mio's testimony remembers it coming out)
                          (X(10.45), Y(6.45), ZB + .98), (X(10.75), Y(6.5), ZB + .82), (X(11.0), Y(6.58), ZB + .6),
                          (X(11.35), Y(6.68), ZB + .5)], [.045] * 9, M['hose'], seg=12, sub=4)

def cellar(M):
    z0 = ZB
    mats2(M)
    import lived; lived.mats(M)
    # every face down here is bare concrete (the hall's plaster and beadboard came with the walls; the stair shaft's
    # walls too, which reach up to the 1F floor)
    for o in bpy.data.objects:
        if o.type != 'MESH' or not o.data.materials: continue
        bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
        if max(v.z for v in bb) < .05 and min(v.z for v in bb) < -.5 and X(4) - .2 < min(v.x for v in bb) and max(v.x for v in bb) < X(10) + .2:
            for i, m in enumerate(o.data.materials):
                if m and m.name.split('.')[0] in ('plaster', 'beadboard', 'trim', 'wallcore'): o.data.materials[i] = M['concrete']
    for o in [o for o in bpy.data.objects if o.name.startswith('floorB')]: o.data.materials[0] = M['cfloor']
    box('cellar_ceiling', 4.0, 1.0, 10.0, 7.0, -.33, -.3, M['concrete'])
    for i in range(7):   # the joists of the floor above, bare
        x = 4.3 + i * .9
        box('cellar_joist', x - .04, 1.0, x + .04, 7.0, -.52, -.33, M['agari'])
    generator(M)
    # fuel: the owner's steel jerrycans along the north wall, his tape on the green one; a funnel by the generator
    for i, (a, x) in enumerate((('metal_jerrycan', 8.05), ('metal_jerrycan_green', 8.45), ('metal_jerrycan', 8.85))):
        lived.phm(a, x, 6.83, z0, rz=0.0, name=f'fuelcan_{i}')
    tape(M, 'gas', (X(8.45), Y(6.83 - .085), z0 + .3), (0, 1, 0), .13)
    collide(7.85, 6.72, 9.05, 6.95, z0, z0 + .48)
    lived.phm('plastic_jerrycan', 9.1, 5.55, z0, rz=.6, name='fuelcan_plastic')
    prim('cone', 'funnel', loc=(X(8.85), Y(6.35), z0 + .08), rot=(math.pi, 0, 0), scale=(.08, .08, .08), mat=M['plastic'], vertices=12)
    # the owner's things on two steel racks along the south wall (east of the barred door; the way past stays 1 m)
    LV = (.0, .43, .92, 1.41)
    for k, x in enumerate((6.97, 7.92)):
        lived.phm('worn_metal_rack', x, 1.38, z0, name=f'crack_{k}')
    collide(6.5, 1.08, 8.39, 1.68, z0, z0 + 1.9)
    stuff = [('cardboard_box_01', 6.7, 1.0, 1.57, 1), ('can_rusted', 7.1, 1.0, 0, 1), ('oil_tin', 7.28, 1.0, .3, 1), ('can_rusted', 7.2, 1.0, 1.2, 2),
             ('plastic_crate_03', 6.85, 1.0, 0, 2), ('wooden_bucket_01', 6.75, .7, 0, 0), ('cardboard_box_01', 7.65, .9, 1.57, 2),
             ('oil_tin', 8.1, 1.0, .1, 1), ('can_rusted', 7.95, 1.0, 0, 3), ('plastic_crate_03', 7.9, 1.0, .05, 0),
             ('vintage_suitcase', 7.9, .55, 0, 3)]
    for i, (a, x, s, r, lv) in enumerate(stuff):
        lived.phm(a, x, 1.4, z0 + LV[lv] + (.0 if lv == 0 else .005), rz=r, s=s, name=f'cshelf_{i}')
    # his winter tyres stacked in the north-west corner, a ladder and a spade against the west wall, a saw on a nail
    for i in range(4):
        lived.phm('old_tyre', 4.45, 6.5, z0 + .083 + i * .165, rx=math.pi / 2, rz=.3 * i, name=f'ctyre_{i}')
    collide(4.12, 6.18, 4.78, 6.82, z0, z0 + .66)
    lived.phm('wooden_ladder', 4.32, 5.3, z0, rz=math.pi / 2, ry=0.0, name='cladder')
    lived.phm('rusted_spade_01', 4.1, 5.95, z0, rx=-.12, rz=math.pi / 2, name='cspade')
    lived.phm('handsaw_wood', 4.0 + .07, 4.6, z0 + 1.4, rx=math.pi / 2, rz=math.pi / 2, name='csaw')
    lived.phm('metal_tool_chest', 9.65, 3.6, z0, rz=-math.pi / 2, name='ctoolchest')
    collide(9.42, 3.25, 9.95, 3.95, z0, z0 + .65)
    lived.phm('mousetrap', 9.0, 4.3, z0, rz=.4, name='cmousetrap')   # 試作77: was at the east wall, where the old cupboard is now
    # old furniture under a dust sheet in the south-east corner (a cabinet and a chair beneath)
    a = box('csheet_under', 8.7, 1.2, 9.35, 1.7, z0, z0 + .95, M['dust'])
    b = box('csheet_under', 9.35, 1.45, 9.85, 2.2, z0, z0 + .78, M['dust'])
    cloth.drop('csheet', (X(9.28), Y(1.7)), (1.9, 1.75), z0 + 1.25, M['dust'], [a, b], res=.035, frames=80, rumple=.08, seed=41, floor=z0, bend=.3)
    collide(8.6, 1.15, 9.9, 2.3, z0, z0 + .95)
    # the breaker and the generator's change-over switch by the stair's foot
    # (on the stair shaft's east wall: they had stood in the air at y 2.45, where no wall is)
    # (試作50: two flat boxes read as stand-in boards through the print) the breaker is Poly Haven's power_box_01, its
    # door left open (the crew switched over to the generator); the change-over switch a grey steel case with its lever
    # thrown down, a conduit up into the joists
    lived.phm('power_box_01', 6.06 + .047, 3.15, z0 + 1.45, rz=math.pi / 2, name='breaker')
    if 'greypaint' not in M: M['greypaint'] = mat_basic('greypaint', (.40, .41, .40), .55)
    co = box('changeover', 6.06, 3.62, 6.17, 3.86, z0 + 1.18, z0 + 1.5, M['greypaint']); apply_bevel(co, .008, 2)
    box('changeover_lid', 6.17, 3.64, 6.178, 3.84, z0 + 1.2, z0 + 1.48, M['greypaint'])
    box('changeover_pivot', 6.12, 3.86, 6.15, 3.885, z0 + 1.36, z0 + 1.4, M['steel'])
    lib.tube('changeover_lever', [(X(6.135), Y(3.885), z0 + 1.38), (X(6.135), Y(3.93), z0 + 1.3), (X(6.135), Y(3.94), z0 + 1.22)], [.007] * 3, M['plastic'], seg=8, sub=2)
    cyl('changeover_conduit', 6.115, 3.74, z0 + 1.5, -.05, .012, M['greypaint'], 8)
    cyl('breaker_conduit', 6.09, 3.1, z0 + 1.7, -.05, .014, M['greypaint'], 8)
    # the bare bulb on its cord over the middle of the room (the generator's circuit)
    cyl('cbulb_cord', 7.9, 4.2, -.62, -.33, .006, M['plastic'], 6)
    cyl('cbulb_socket', 7.9, 4.2, -.68, -.62, .02, M['plastic'], 10)
    bl = prim('uv_sphere', 'lampshade_lamp_cellar', loc=(X(7.9), Y(4.2), -.72), scale=(.03, .03, .04), mat=M['bulb'], segments=12, ring_count=8)
    bl.visible_shadow = False   # the light sits inside it: its glass shadowed the whole room in the bake (試作50; main.gd the same in Godot)
    # 試作80: the second bulb over the west strip by the barred door (times.P_CELLAR_W), in a pull-chain socket on the joist
    if not lived.phm('pull_chain_light_socket', 4.55, 2.25, -.33, name='cbulb_w_socket'):
        cyl('cbulb_w_socket', 4.55, 2.25, -.5, -.33, .02, M['plastic'], 10)
    bw = prim('uv_sphere', 'lampshade_lamp_cellarw', loc=(X(4.55), Y(2.25), -.535), scale=(.03, .03, .04), mat=M['bulb'], segments=12, ring_count=8)
    bw.visible_shadow = False
    # where Taiga is put at 0:00, by the barred door: a crew's sleeping bag open on the concrete (orange, its navy lining
    # turned back), a flashlight, a bottle of water
    if not F.tripo_prop('sleepbag', (X(4.65), Y(2.05), z0), 0.0, 1.9, name='csleepbag'):
        lump = prim('cube', 'csleepbag_pillow', loc=(X(4.62), Y(1.35), z0 + .06), scale=(.2, .13, .06), mat=M['bagolive'])
        apply_bevel(lump, .05, 4)
        cloth.drop('csleepbag', (X(4.63), Y(2.05)), (.78, 1.95), z0 + .35, M['sbag'], [lump], res=.03, frames=60, rumple=.1, seed=43,
                   floor=z0, bend=.6, stiff=10.0, thick=.03, mat2=M['sbag_in'])
    lived.phm('pastic_torch_6v', 5.0, 3.15, z0, rz=2.2, name='torch_cellar')
    # the crew's battery lantern left on the floor by it (試作50: the bulb is behind the stair shaft from here, and
    # this corner was black); lit from 23:00 (times.lantern_cellar)
    if 'lanternglow' not in M: M['lanternglow'] = mat_basic('lanternglow', (.95, .9, .8), .4, emit=lib.kelvin(3300), estr=4)
    x, y, z = 5.45, 1.25, z0
    cyl('clantern_base', x, y, z, z + .05, .055, M['plastic'], 16)
    cyl('lampshade_lantern_cellar', x, y, z + .05, z + .2, .045, M['lanternglow'], 16).visible_shadow = False
    cyl('clantern_top', x, y, z + .2, z + .24, .055, M['plastic'], 16)
    lib.tube('clantern_handle', [(X(x) - .04, Y(y), z + .24), (X(x), Y(y), z + .3), (X(x) + .04, Y(y), z + .24)], [.004] * 3, M['steel'], seg=6, sub=3)
    pet(M, 4.3, 3.05, z0, 'pet_cellar', lying=True, rot=.9)
    # the west part (x 4..5.06, behind the stair shaft): wood stacked for the stove
    for i in range(9):
        r = random.Random(i)
        o = prim('cylinder', 'cwood', loc=(X(4.35), Y(3.6 + (i % 3) * .14), z0 + .07 + (i // 3) * .13), rot=(0, math.pi / 2, r.uniform(-.1, .1)),
                 scale=(.06, .06, .3), mat=M['agari'], vertices=10)
    collide(4.05, 3.5, 4.7, 4.0, z0, z0 + .4)
    # 試作77 (レビュー 試作73: the cellar and Taiga's corner read empty through the print): his pickles in two cedar tubs
    # against the north wall, a river stone on each lid, a clay crock beside them; the old kitchen cupboard, its paint
    # peeling, put down here when the kitchen was redone, along the east wall (the mousetrap goes in front of it); by
    # the sleeping bag the crew's first-aid case and a thermos (Poly Haven's soil bags and gallon bottle carry brand
    # names: not used)
    for i, x in enumerate((6.52, 7.17)):
        lived.phm('wooden_bucket_02', x, 6.6, z0, rz=.7 * i, name=f'ctub_{i}')
        cyl(f'ctublid_{i}', x, 6.6, z0 + .27, z0 + .29, .26, M['agari'], 24)   # the drop lid (落とし蓋) inside the rim (試作78: the stone floated over the open tub)
        lived.phm('stone_01', x + .03, 6.58, z0 + .29, rz=1.1 + i, s=2.2, name=f'ctubstone_{i}')
    lived.phm('planter_pot_clay', 7.66, 6.72, z0, rz=.4, name='ccrock')
    collide(6.2, 6.28, 7.8, 6.95, z0, z0 + .4)
    lived.phm('painted_wooden_cabinet', 9.62, 4.85, z0, rz=-math.pi / 2, name='ccupboard')   # its front is -Y in the model: -pi/2 faces the room
    collide(9.3, 4.23, 9.95, 5.47, z0, z0 + 1.18)
    lived.phm('medical_box', 5.17, 1.78, z0, rz=.35, name='cfirstaid')
    lived.phm('plastic_thermos', 5.2, 2.32, z0, rz=.8, name='cthermos')

# ---------------------------------------------------------------- the generator's cord (20:00 on: the only power in the house)
def cord(M):
    """From the generator's socket across the cellar floor, up the cellar stair's west edge, through the cellar door,
    along the lobby and the hall's west wall to the fresnel's stand (stage.FRESNEL). Night only (Godot hides it at dusk)."""
    import stage as St
    step = lambda y: -(5.6 - y) / 3.0 * (-ZB)   # the cellar stair's tread line at plan y (z 0 at 5.6, ZB at 2.6)
    sx, sy, sz = GEN_SOCKET
    pts = [(sx, sy, sz), (sx - .12, sy, sz - .05), (sx - .2, sy - .1, ZB + .01), (8.0, 3.0, ZB + .01), (6.3, 2.35, ZB + .01), (5.5, 2.3, ZB + .01),
           (5.18, 2.7, ZB + .02)]
    for y in (3.0, 3.6, 4.2, 4.8, 5.4):
        pts.append((5.16, y, step(y) + .03))
    pts += [(5.16, 5.75, .01), (5.0, 6.1, .01), (4.25, 5.9, .01), (4.2, 4.5, .01), (4.25, 3.4, .01)]
    fx, fy = St.FRESNEL
    pts += [(fx + 4.8 - .2, 6.3 - fy, .01), (fx + 4.8, 6.3 - fy, .01)]
    lib.tube('gencord', [(X(x), Y(y), z) for (x, y, z) in pts], [.006] * len(pts), M['cord'], seg=6, sub=3)

# ---------------------------------------------------------------- the boards over the windows (23:00 on)
DEER_X = 2.1   # furnish.deer(M, 2.1)
def boards(M):
    """Rough boards nailed across every 1F window from inside (大河の主導で窓を板で塞ぐ), uneven, with gaps: the gaps are
    where the lightning and, at 4:30, the dawn come in. Named board_* (Godot shows them from 23:00). The cellar's small
    window is boarded from outside (named board_cellar*)."""
    rng = random.Random(23)
    n = 0
    for w in H4.F1_WALLS:
        ax, fixed, lo, hi, holes, wins, outer = w[:7]
        if not outer: continue
        for (a, b) in wins:
            if b - a < .3: continue    # the slit by the front door: Natsuki's hand is at it at 23:00
            s0, s1 = H4.SILL1 - .06, H4.SILL1 + H4.WH1 + .06
            z = s0
            off = fixed + (-outer) * (.06 + .035 + .012)
            while z < s1:
                bw = rng.uniform(.12, .21); gap = rng.choice((.0, .01, .02, .035, .05))
                z1 = min(s1 + .02, z + bw); tilt = rng.uniform(-.035, .035)
                a0, b0 = a - rng.uniform(.06, .14), b + rng.uniform(.06, .14)
                if ax == 'X' and fixed == 0 and b < 4:   # 試作97: the living room's front wall: the deer head hangs at x 2.1
                    # between its two windows; the boards stop at the casing on its side (ユーザー「鹿の剥製にかからないように」)
                    if b <= DEER_X: b0 = min(b0, b + .03)
                    if a >= DEER_X: a0 = max(a0, a - .03)
                if ax == 'X':
                    o = prim('cube', f'board_{n}', loc=((X(a0) + X(b0)) / 2, Y(off), (z + z1) / 2), rot=(0, tilt, 0), scale=((b0 - a0) / 2, .011, (z1 - z) / 2), mat=M['board'])
                else:
                    o = prim('cube', f'board_{n}', loc=(X(off), (Y(a0) + Y(b0)) / 2, (z + z1) / 2), rot=(tilt, 0, 0), scale=(.011, (b0 - a0) / 2, (z1 - z) / 2), mat=M['board'])
                lib.uv_box(o, 4.0, offset=(rng.random(), rng.random()))
                n += 1
                z = z1 + gap
    # the cellar's small window, from outside (east wall x = 10, y 6.15..6.75, z -1.6..-1.2): four boards, nailed tight
    for i in range(4):
        z = -1.66 + i * .13
        rx = rng.uniform(-.03, .03)
        if i == 1:   # 試作97: the hose comes out here: this board is two, either side of it
            for k, (y0, y1) in enumerate(((6.0, 6.39), (6.51, 6.9))):
                o = prim('cube', f'board_cellar{i}{"ab"[k]}', loc=(X(10) + .28, Y((y0 + y1) / 2), z + .06), rot=(rx, 0, 0), scale=(.011, (y1 - y0) / 2, .062), mat=M['board'])
                lib.uv_box(o, 4.0)
            continue
        o = prim('cube', f'board_cellar{i}', loc=(X(10) + .28, Y(6.45), z + .06), rot=(rx, 0, 0), scale=(.011, .45, .062), mat=M['board'])
        lib.uv_box(o, 4.0)
    print('boards', n)

# ---------------------------------------------------------------- doors upstairs, and the colliders for climbing
def doors2(M):
    out = {}
    for (ax, fx, a, b, nm, hinge) in (('Y', 4, 3.1, 3.95, 'bed1', 'lo'), ('Y', 4, 6.6, 7.45, 'bed2', 'hi'),
                                      ('Y', 6, 1.2, 2.05, 'bed3', 'lo'), ('Y', 6, 6.7, 7.55, 'bath', 'hi')):
        piv = H4.door_leaf(M, ax, fx, a, b, F2, hinge=hinge, name=f'door2_{nm}', h=H4.DOOR_H)
        out[nm] = piv
    return out

def climb_boxes():
    """Ramps for the two stairs and the rails that keep you on them (the treads themselves do not collide)."""
    x0, y0, x1, y1 = H4.STAIR
    out = []
    def ramp(ya, za, yb, zb, th=.1):
        L = math.hypot(yb - ya, zb - za); ang = math.atan2(zb - za, yb - ya)   # rising toward plan +y (Blender -Y, Godot +Z)
        cy, cz = (ya + yb) / 2, (za + zb) / 2
        # the box's top face on the line: centre half a thickness below it, perpendicular to the slope
        cy -= -math.sin(ang) * th / 2; cz -= math.cos(ang) * th / 2
        out.append(dict(c=[round((X(x0) + X(x1)) / 2, 3), round(Y(cy), 3), round(cz, 3)], s=[round(x1 - x0, 3), round(L + .1, 3), th],
                        ramp=1, rx=round(-ang, 4)))
    ramp(y0, 0.0, y1, F2)          # up: from the hall's floor at the foot to the 2F floor at the back
    ramp(y1, 0.0, y0, ZB)          # down: from the cellar door (y 5.6) toward the front, to the cellar floor
    # the stair's open (west) side: a wall up to the 2F rail, so you neither step off the treads nor walk under them;
    # upstairs it is the well's rail on that side. The well's south rail upstairs.
    out.append(dict(c=[X(x0 - .02), Y((y0 + y1) / 2), (F2 + 1.0) / 2], s=[.06, y1 - y0, F2 + 1.0]))
    out.append(dict(c=[(X(x0) + X(x1)) / 2, Y(y0 - .02), F2 + .5], s=[x1 - x0, .06, 1.0]))
    # floor beyond the cellar stair's foot (the barred door is open): the basement floor
    return out

def build(M):
    F.COL.clear(); mats(M)
    random.seed(7)
    study(M); upstairs(M); cellar(M); cord(M); boards(M); night_lights(M)
    d2 = doors2(M)
    return list(F.COL), d2
