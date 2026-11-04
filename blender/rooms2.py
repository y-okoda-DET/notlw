"""段階2: the rest of the house, so the whole of it can be walked (the study, the upstairs rooms, the cellar), and the
things the night changes in it (the boards over the windows, the generator's cord up the cellar stair).
Plan coordinates (house4: x east, y back), as furnish.py. build(M) makes it all and returns collider boxes.

Whose room is whose (企画書「間取り」, kept to what the story needs):
  寝室1 (SW, over the living room)   澪と夏希: two beds, their bags; the window looks south over the porch side
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
import lib, house4 as H4
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
    if 'lanternglow' not in M:
        M['lanternglow'] = mat_basic('lanternglow', (.95, .9, .8), .4, emit=lib.kelvin(3300), estr=4)
        M['flame'] = mat_basic('flame', (1, .7, .3), .4, emit=lib.kelvin(1800), estr=8)
        M['wax'] = mat_basic('wax', (.85, .82, .74), .5)
        M['phonescr'] = mat_basic('phonescr', (.6, .75, 1), .3, emit=lib.kelvin(8000), estr=3)
    x, y, z = 1.85, 1.6, .4
    cyl('lantern_base', x, y, z, z + .05, .055, M['plastic'], 16)
    cyl('lampshade_lantern_living', x, y, z + .05, z + .2, .045, M['lanternglow'], 16)
    cyl('lantern_top', x, y, z + .2, z + .24, .055, M['plastic'], 16)
    lib.tube('lantern_handle', [(X(x) - .04, Y(y), z + .24), (X(x), Y(y), z + .3), (X(x) + .04, Y(y), z + .24)], [.004] * 3, M['steel'], seg=6, sub=3)
    for i, (cx, cy, h) in enumerate(((8.7, 7.62, .14), (8.82, 7.55, .1), (8.76, 7.7, .17))):
        cyl('candle', cx, cy, .862, .862 + h, .012, M['wax'], 10)
        prim('uv_sphere', 'lampshade_candle_kitchen', loc=(X(cx), Y(cy), .862 + h + .012), scale=(.006, .006, .013), mat=M['flame'], segments=8, ring_count=6)
    cyl('candle_saucer', 8.76, 7.62, .862, .868, .09, M['fridge'], 16)
    o = prim('cube', 'phone_makoto', loc=(X(9.62), Y(1.72), F2 + .556), rot=(0, 0, .3), scale=(.035, .072, .004), mat=M['plastic'])
    prim('plane', 'lampshade_phone_makoto', loc=(X(9.62), Y(1.72), F2 + .561), rot=(0, 0, .3), scale=(.032, .068, 1), mat=M['phonescr'])

# ---------------------------------------------------------------- 2F
def bed(M, x0, y0, x1, y1, head='w', blanket=None, rumpled=0.0, name='bed'):
    box(f'{name}_frame', x0, y0, x1, y1, .1, .32, M['walnut'], col=True)
    legs(f'{name}_leg', x0, y0, x1, y1, .1, .05, M['walnut'], inset=.01)
    box(f'{name}_mattress', x0 + .02, y0 + .02, x1 - .02, y1 - .02, .32, .5, M['bedding'])
    hx = {'w': (x0, x0 + .05), 'e': (x1 - .05, x1)}.get(head)
    hy = {'s': (y0, y0 + .05), 'n': (y1 - .05, y1)}.get(head)
    if hx: box(f'{name}_head', hx[0], y0, hx[1], y1, .1, .95, M['walnut'])
    if hy: box(f'{name}_head', x0, hy[0], x1, hy[1], .1, .95, M['walnut'])
    # pillow at the head end, blanket over the rest (pushed back when slept in)
    if head == 'w': p = (x0 + .08, y0 + .12, x0 + .45, y1 - .12); b = (x0 + .55 + rumpled, y0 + .0, x1 + .01, y1 + .01)
    elif head == 'e': p = (x1 - .45, y0 + .12, x1 - .08, y1 - .12); b = (x0 - .01, y0, x1 - .55 - rumpled, y1 + .01)
    elif head == 'n': p = (x0 + .12, y1 - .45, x1 - .12, y1 - .08); b = (x0 - .01, y0 - .01, x1 + .01, y1 - .55 - rumpled)
    else: p = (x0 + .12, y0 + .08, x1 - .12, y0 + .45); b = (x0 - .01, y0 + .55 + rumpled, x1 + .01, y1 + .01)
    o = box(f'{name}_pillow', *p, .5, .62, M['bedding']); lib.smooth(o)
    box(f'{name}_blanket', *b, .49, .54, blanket or M['blanket'])

def bag(M, x, y, w, d, h, mat, name='bag', rot=0.0):
    o = prim('cube', name, loc=(X(x), Y(y), h / 2), rot=(0, 0, rot), scale=(w / 2, d / 2, h / 2), mat=mat)
    bv = o.modifiers.new('bv', 'BEVEL'); bv.width = min(w, d, h) * .3; bv.segments = 3
    lib.tube(f'{name}_handle', [(X(x) - w * .25, Y(y), h), (X(x), Y(y), h + .08), (X(x) + w * .25, Y(y), h)], [.01] * 3, M['plastic'], seg=6, sub=3)
    collide(x - w / 2, y - d / 2, x + w / 2, y + d / 2, 0, h)

def upstairs(M):
    z = F2
    def at(o):   # everything below was laid out at floor 0; lift it to the 2F floor
        o.location.z += z
    c0 = len(F.COL)
    # 寝室1 (x 0..4, y 0..4.2): Mio and Natsuki
    bed(M, .1, .3, 2.1, 1.25, head='w', blanket=M['blanket'], rumpled=.3, name='bed1a')
    bed(M, .1, 2.6, 2.1, 3.55, head='w', blanket=M['blanket2'], name='bed1b')
    box('bed1_table', .1, 1.65, .5, 2.15, 0, .55, M['oak'], col=True)
    bag(M, 2.9, .6, .6, .35, .38, M['bagred'], 'bag_natsuki', .2)      # Natsuki's bag, open on the floor (she went out)
    bag(M, 3.4, 3.7, .55, .3, .35, M['bagnavy'], 'bag_mio', -.1)
    o = prim('plane', 'natsuki_shirt', loc=(X(1.4), Y(.8), .545), rot=(0, 0, .4), scale=(.25, .3, 1), mat=M['bagolive'])
    # 寝室2 (x 0..4, y 4.2..8): Kiryu and Taiga; the camera cases, the make-up kit
    bed(M, .1, 4.5, 2.1, 5.45, head='w', blanket=M['blanket'], name='bed2a')
    bed(M, .1, 6.9, 2.1, 7.85, head='w', blanket=M['blanket'], rumpled=.4, name='bed2b')
    box('case_cam', 2.8, 4.45, 3.5, 4.9, 0, .32, M['case'], col=True)
    box('case_cam_foam', 2.85, 4.5, 3.45, 4.85, .32, .34, M['foam'])
    box('case_light', 2.5, 7.3, 3.6, 7.75, 0, .22, M['case'], col=True)
    box('makeup_box', 3.0, 5.6, 3.45, 5.9, 0, .25, M['bagolive'], col=True)
    for i in range(4):
        cyl('makeup_bottle', 3.08 + i * .1, 5.75, .25, .36 + .03 * (i % 2), .025, M['canred'] if i % 2 else M['plastic'], 10)
    bag(M, 2.6, 6.4, .7, .38, .4, M['bagolive'], 'bag_taiga', .3)
    # 寝室3 (x 6..10, y 0..4.2): Makoto (one bed, a futon rolled away)
    bed(M, 8.3, .2, 9.9, 1.2, head='e', blanket=M['blanket2'], rumpled=.2, name='bed3')
    box('bed3_table', 9.4, 1.4, 9.9, 1.85, 0, .55, M['oak'], col=True)
    cyl('bed3_cup', 9.6, 1.6, .55, .64, .035, M['fridge'], 12)
    box('futon_roll', 6.3, 3.5, 7.5, 3.95, 0, .35, M['bedding'], col=True)
    bag(M, 7.3, .6, .5, .3, .34, M['bagnavy'], 'bag_makoto', .5)
    # 洗面・浴室 (x 6..10, y 4.2..8): the washbasin and machine by the door, the tub behind a low tiled step
    box('bath_floor', 6.06, 4.26, 9.94, 7.94, 0, .015, M['bathtile'], 1.0)
    for (a, b, c, d) in ((8.0, 4.26, 8.06, 7.94), ):   # the glass partition's frame between the washroom and the bath
        box('bath_part', a, b, c, 5.4, .015, 2.0, M['bathtile'], col=True)
        box('bath_part', a, 6.4, c, d, .015, 2.0, M['bathtile'], col=True)
    box('bath_tub', 8.5, 6.6, 9.94, 7.94, 0, .58, M['enamel'], col=True)
    box('bath_water', 8.58, 6.68, 9.86, 7.86, .5, .505, M['glass'])
    box('bath_stool', 8.9, 5.6, 9.2, 5.9, 0, .22, M['plastic'])
    cyl('bath_shower', 9.9, 6.0, 1.0, 1.9, .012, M['steel'], 8)
    box('wash_basin', 6.1, 4.9, 6.65, 5.7, 0, .82, M['cabinet'], col=True)
    box('wash_top', 6.08, 4.88, 6.68, 5.72, .82, .86, M['enamel'])
    box('wash_mirror', 6.07, 4.95, 6.09, 5.65, 1.05, 1.75, M['mirror'])
    box('wash_machine', 6.1, 7.2, 6.7, 7.85, 0, .85, M['fridge'], col=True)
    cyl('wash_machine_lid', 6.4, 7.52, .85, .86, .22, M['plastic'], 20)
    for i in range(3):
        box('wash_towel', 7.6 + i * .12, 7.9, 7.68 + i * .12, 7.94, 1.0, 1.45, M['towel'])
    # lift everything built in this function (objects and colliders) to the 2F floor
    for o in list(bpy.data.objects):
        if o.get('_lifted') or o.parent is not None: continue
        if o.name.startswith(('bed1', 'bed2', 'bed3', 'bag_', 'natsuki_shirt', 'case_', 'makeup_', 'futon_', 'bath_', 'wash_')):
            o.location.z += z; o['_lifted'] = 1
    for c in F.COL[c0:]: c['c'][2] = round(c['c'][2] + z, 3)
    # the landing: a small table under the south window (the window over the front door: the porch and the car)
    box('landing_runner', 4.12, 5.7, 5.9, 7.9, z, z + .008, M['rug'], 1.0)

# ---------------------------------------------------------------- 地下 x 4..10, y 1..7 (the stair shaft x 5.06..6, y 2.5..5.64)
GEN = (9.25, 6.25)    # the generator: plan centre, under the small window (east wall, y 6.15..6.75)
def cellar(M):
    z0 = ZB
    # every face down here is bare concrete (the hall's plaster and beadboard came with the walls)
    for o in bpy.data.objects:
        if o.type != 'MESH' or not o.data.materials: continue
        bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
        if max(v.z for v in bb) < -.05 and X(4) - .2 < min(v.x for v in bb) and max(v.x for v in bb) < X(10) + .2:
            for i, m in enumerate(o.data.materials):
                if m and m.name.split('.')[0] in ('plaster', 'beadboard', 'trim', 'wallcore'): o.data.materials[i] = M['concrete']
    for o in [o for o in bpy.data.objects if o.name.startswith('floorB')]: o.data.materials[0] = M['cfloor']
    box('cellar_ceiling', 4.0, 1.0, 10.0, 7.0, -.33, -.3, M['concrete'])
    for i in range(7):   # the joists of the floor above, bare
        x = 4.3 + i * .9
        box('cellar_joist', x - .04, 1.0, x + .04, 7.0, -.52, -.33, M['agari'])
    # the generator: a red open-frame portable, on two planks; fuel tank on top, the pull cord, the control panel
    gx, gy = GEN; gz = z0 + .06
    box('gen_plank', gx - .45, gy - .32, gx + .45, gy - .22, z0, gz, M['board'])
    box('gen_plank', gx - .45, gy + .22, gx + .45, gy + .32, z0, gz, M['board'])
    w, d, h = .62, .48, .5
    for (sx, sy) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):   # the tube frame
        D_ = __import__('door').cyl_between
        D_('gen_frame', (X(gx + sx * w / 2), Y(gy + sy * d / 2), gz), (X(gx + sx * w / 2), Y(gy + sy * d / 2), gz + h), .014, M['iron'], 8)
    for zz in (gz + .01, gz + h):
        for (a, b) in (((-1, -1), (1, -1)), ((-1, 1), (1, 1)), ((-1, -1), (-1, 1)), ((1, -1), (1, 1))):
            __import__('door').cyl_between('gen_frame', (X(gx + a[0] * w / 2), Y(gy + a[1] * d / 2), zz), (X(gx + b[0] * w / 2), Y(gy + b[1] * d / 2), zz), .014, M['iron'], 8)
    box('gen_engine', gx - .22, gy - .17, gx + .08, gy + .17, gz + .03, gz + .33, M['iron'])
    box('gen_alt', gx + .08, gy - .14, gx + .28, gy + .14, gz + .05, gz + .3, M['genred'])
    o = box('gen_tank', gx - .27, gy - .2, gx + .25, gy + .2, gz + .35, gz + .49, M['genred']); bv = o.modifiers.new('bv', 'BEVEL'); bv.width = .03; bv.segments = 3
    cyl('gen_cap', gx - .1, gy, gz + .49, gz + .52, .035, M['iron'], 12)
    box('gen_panel', gx + .29, gy - .12, gx + .31, gy + .12, gz + .1, gz + .3, M['plastic'])
    for i in range(2): cyl('gen_socket', gx + .315, gy - .05 + i * .1, gz + .18, gz + .19, .025, M['genyel'], 10)
    box('gen_muffler', gx - .3, gy - .1, gx - .22, gy + .1, gz + .1, gz + .3, M['steel'])
    # the exhaust hose: a flexible metal duct from the muffler, up the wall and out of the small window
    lib.tube('gen_hose', [(X(gx - .3), Y(gy), gz + .2), (X(gx - .45), Y(gy + .05), gz + .35), (X(gx - .3), Y(6.45), z0 + 1.0),
                          (X(9.7), Y(6.45), z0 + 1.0), (X(9.95), Y(6.45), z0 + .95), (X(10.15), Y(6.45), z0 + .95)], [.045] * 6, M['hose'], seg=12, sub=4)
    collide(gx - .45, gy - .32, gx + .45, gy + .32, z0, z0 + .6)
    # fuel: red jerry cans along the north wall, one open beside the generator, a funnel
    for i in range(4):
        x = 8.0 + i * .32
        o = box('fuelcan', x, 6.62, x + .26, 6.92, z0, z0 + .38, M['canred'] if i != 2 else M['genyel'])
        box('fuelcan_handle', x + .08, 6.72, x + .18, 6.82, z0 + .38, z0 + .44, M['canred'] if i != 2 else M['genyel'])
    collide(8.0, 6.62, 9.3, 6.92, z0, z0 + .45)
    prim('cone', 'funnel', loc=(X(8.6), Y(6.2), z0 + .08), scale=(.08, .08, .08), mat=M['plastic'], vertices=12)
    # the owner's things on steel shelves along the south wall (east of the barred door; the way past them stays 1 m)
    sx0, sx1, sy0, sy1 = 6.5, 8.1, 1.08, 1.5
    for x in (sx0, sx1 - .05):
        for y in (sy0, sy1 - .05): box('cshelf_post', x, y, x + .05, y + .05, z0, z0 + 1.8, M['steel'])
    for k, zz in enumerate((.1, .6, 1.1, 1.6)):
        box('cshelf', sx0, sy0, sx1, sy1, z0 + zz, z0 + zz + .02, M['steel'])
        for j in range(4):
            x = sx0 + .06 + j * .38
            if (k + j) % 2: box('cshelf_box', x, sy0 + .04, x + .32, sy1 - .04, z0 + zz + .02, z0 + zz + .26, M['paperbag'])
            else: cyl('cshelf_paint', x + .16, (sy0 + sy1) / 2, z0 + zz + .02, z0 + zz + .2, .09, M['steel'], 14)
    collide(sx0, sy0, sx1, sy1, z0, z0 + 1.8)
    # old furniture under a dust sheet in the south-east corner
    o = box('csheet', 8.6, 1.15, 9.85, 2.3, z0, z0 + .85, M['sheet']); bv = o.modifiers.new('bv', 'BEVEL'); bv.width = .12; bv.segments = 4
    collide(8.6, 1.15, 9.85, 2.3, z0, z0 + .9)
    # the breaker and the generator's change-over switch by the stair's foot
    box('breaker', 6.95, 2.42, 7.4, 2.47, z0 + 1.2, z0 + 1.65, M['fridge'])
    box('changeover', 7.5, 2.42, 7.75, 2.47, z0 + 1.2, z0 + 1.5, M['genyel'])
    # the bare bulb on its cord over the middle of the room (the generator's circuit)
    cyl('cbulb_cord', 7.9, 4.2, -.62, -.33, .006, M['plastic'], 6)
    cyl('cbulb_socket', 7.9, 4.2, -.68, -.62, .02, M['plastic'], 10)
    g = prim('uv_sphere', 'lampshade_lamp_cellar', loc=(X(7.9), Y(4.2), -.72), scale=(.03, .03, .04), mat=M['bulb'], segments=12, ring_count=8)
    # a sleeping mat and a blanket left by the barred door (where Taiga is put at 0:00)
    box('cmat', 4.3, 1.2, 4.95, 2.95, z0, z0 + .02, M['bagolive'])
    box('cblanket', 4.35, 1.3, 4.9, 2.0, z0 + .02, z0 + .08, M['blanket'])
    # the west part (x 4..5.06, behind the stair shaft): wood stacked for the stove
    for i in range(9):
        r = random.Random(i)
        o = prim('cylinder', 'cwood', loc=(X(4.35), Y(3.0 + (i % 3) * .14), z0 + .07 + (i // 3) * .13), rot=(0, math.pi / 2, r.uniform(-.1, .1)),
                 scale=(.06, .06, .3), mat=M['agari'], vertices=10)
    collide(4.05, 2.9, 4.7, 3.4, z0, z0 + .4)

# ---------------------------------------------------------------- the generator's cord (20:00 on: the only power in the house)
def cord(M):
    """From the generator's socket across the cellar floor, up the cellar stair's west edge, through the cellar door,
    along the lobby and the hall's west wall to the fresnel's stand (stage.FRESNEL). Night only (Godot hides it at dusk)."""
    import stage as St
    gx, gy = GEN
    step = lambda y: -(5.6 - y) / 3.0 * (-ZB)   # the cellar stair's tread line at plan y (z 0 at 5.6, ZB at 2.6)
    pts = [(gx + .32, gy, ZB + .19), (gx + .5, gy - .3, ZB + .01), (8.0, 3.0, ZB + .01), (6.3, 2.35, ZB + .01), (5.5, 2.3, ZB + .01),
           (5.18, 2.7, ZB + .02)]
    for y in (3.0, 3.6, 4.2, 4.8, 5.4):
        pts.append((5.16, y, step(y) + .03))
    pts += [(5.16, 5.75, .01), (5.0, 6.1, .01), (4.25, 5.9, .01), (4.2, 4.5, .01), (4.25, 3.4, .01)]
    fx, fy = St.FRESNEL
    pts += [(fx + 4.8 - .2, 6.3 - fy, .01), (fx + 4.8, 6.3 - fy, .01)]
    lib.tube('gencord', [(X(x), Y(y), z) for (x, y, z) in pts], [.006] * len(pts), M['cord'], seg=6, sub=3)

# ---------------------------------------------------------------- the boards over the windows (23:00 on)
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
        o = prim('cube', f'board_cellar{i}', loc=(X(10) + .28, Y(6.45), z + .06), rot=(rng.uniform(-.03, .03), 0, 0), scale=(.011, .45, .062), mat=M['board'])
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
