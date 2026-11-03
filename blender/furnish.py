"""Furniture for the rooms off the hall in the dusk scene (試作33「部屋、もう少し回れるようにしたい」→ ユーザー「家具を作って
入れる」2026-11-03): the living room (the screening set up for tonight, the cold wood stove, the deer head), the dining
room (the big table) and the kitchen (counters, sink, fridge, the curry things bought on the way).
Plan coordinates (house4: x east, y back), the same as F1_WALLS; every room face stands .06 in from its wall line.
furnish(M) builds it all and returns collider boxes in the form house4.colliders() gives."""
import math
import bpy
import lib, house4 as H4
from lib import prim, mat_basic, mat_image, tex_path

X, Y = H4.X, H4.Y
COL = []

def box(name, x0, y0, x1, y1, z0, z1, mat, uv=1.0, col=False):
    """An axis-aligned block over plan rect (x0,y0)-(x1,y1), from z0 to z1."""
    x0, x1 = min(x0, x1), max(x0, x1); y0, y1 = min(y0, y1), max(y0, y1)
    o = prim('cube', name, loc=((X(x0) + X(x1)) / 2, (Y(y0) + Y(y1)) / 2, (z0 + z1) / 2), scale=((x1 - x0) / 2, (y1 - y0) / 2, (z1 - z0) / 2), mat=mat)
    lib.uv_box(o, uv)
    if col: collide(x0, y0, x1, y1, z0, z1)
    return o

def collide(x0, y0, x1, y1, z0, z1):
    COL.append(dict(c=[round((X(x0) + X(x1)) / 2, 3), round((Y(y0) + Y(y1)) / 2, 3), round((z0 + z1) / 2, 3)],
                    s=[round(abs(x1 - x0), 3), round(abs(y1 - y0), 3), round(z1 - z0, 3)]))

def cyl(name, x, y, z0, z1, r, mat, v=16):
    return prim('cylinder', name, loc=(X(x), Y(y), (z0 + z1) / 2), scale=(r, r, (z1 - z0) / 2), mat=mat, vertices=v)

def legs(name, x0, y0, x1, y1, h, t, mat, inset=.03):
    for (x, y) in ((x0 + inset, y0 + inset), (x1 - inset - t, y0 + inset), (x0 + inset, y1 - inset - t), (x1 - inset - t, y1 - inset - t)):
        box(name, x, y, x + t, y + t, 0, h, mat)

def mats(M):
    if 'sofa' in M: return
    M['sofa'] = mat_image('sofa', tex_path('ph/poly_wool_herringbone_diff'), rough=.9, coords='UV', bump=.15, tint=(.62, .7, .55))
    M['walnut'] = mat_image('walnut', tex_path('ph/american_walnut_veneer_diff'), rough=.45, coords='UV', bump=.05)
    M['oak'] = mat_image('oak', tex_path('ph/oak_veneer_01_diff'), rough=.5, coords='UV', bump=.05, tint=(.9, .85, .78))
    M['rug'] = mat_image('rug', tex_path('plaid'), rough=.95, coords='UV', bump=.05, tint=(.75, .55, .45))
    M['iron'] = mat_basic('iron', (.035, .033, .03), .55, metal=.6)
    M['hearth'] = mat_image('hearth', tex_path('tile'), rough=.5, coords='UV', bump=.1, tint=(.7, .55, .45))
    M['screen'] = mat_basic('screen', (.82, .82, .8), .9)
    M['fur'] = mat_image('fur', None, rough=.95, fallback=lib.noise_proc((.36, .25, .15), (.16, .1, .06), scale=60., bumpv=.25))
    M['antler'] = mat_basic('antler', (.72, .65, .52), .6)
    M['cabinet'] = mat_basic('cabinet', (.66, .63, .54), .5)   # painted cream (the painted-wood image is blue-grey: it turned the kitchen cold)
    M['steel'] = mat_basic('steel', (.6, .6, .6), .3, metal=1)
    M['fridge'] = mat_basic('fridge', (.78, .78, .74), .35)
    M['paperbag'] = mat_basic('paperbag', (.5, .36, .22), .9)
    M['onion'] = mat_basic('onion', (.62, .38, .18), .5)
    M['potato'] = mat_basic('potato', (.55, .43, .27), .85)
    M['carrot'] = mat_basic('carrot', (.8, .3, .06), .6)
    M['roux'] = mat_basic('roux', (.75, .55, .05), .5)
    M['cushion'] = mat_image('cushion', tex_path('knit'), rough=.9, coords='UV', bump=.1, tint=(.8, .45, .3))
    M['plastic'] = mat_basic('plastic', (.08, .08, .085), .4)
    M['shade'] = mat_basic('shade', (.9, .82, .65), .6, emit=lib.kelvin(2700), estr=4)
    M['shade_off'] = mat_basic('shade_off', (.75, .7, .6), .6)

# ---------------------------------------------------------------- 居間 (plan x 0..4, y 0..4.6)
def living(M):
    # the wood stove on the west wall, cold (it is summer), on a tiled hearth; the pipe goes out through the wall
    box('furn_hearth', .07, 2.85, 1.05, 3.95, 0, .035, M['hearth'], 1.2)
    sx0, sx1, sy0, sy1 = .3, .78, 3.13, 3.67
    box('furn_stove', sx0, sy0, sx1, sy1, .16, .74, M['iron'])
    box('furn_stovetop', sx0 - .03, sy0 - .03, sx1 + .03, sy1 + .03, .74, .77, M['iron'])
    legs('furn_stoveleg', sx0, sy0, sx1, sy1, .16, .05, M['iron'], inset=.01)
    box('furn_stovedoor', sx1, sy0 + .08, sx1 + .015, sy1 - .08, .26, .62, M['plastic'])   # its glass, sooted
    box('furn_stovehandle', sx1 + .015, sy1 - .14, sx1 + .04, sy1 - .11, .4, .5, M['steel'])
    px, py = (sx0 + sx1) / 2, (sy0 + sy1) / 2
    cyl('furn_pipe', px, py, .77, 1.72, .075, M['iron'])
    p = prim('cylinder', 'furn_pipe', loc=((X(.06) + X(px)) / 2, Y(py), 1.72), rot=(0, math.pi / 2, 0), scale=(.075, .075, (px - .06) / 2 + .075), mat=M['iron'], vertices=16)
    collide(.07, 2.85, 1.05, 3.95, 0, .9)
    # firewood basket beside it
    box('furn_basket', .15, 4.0, .6, 4.38, 0, .32, M['agari'])
    for i, (dy, dz) in enumerate(((.07, .37), (.19, .37), (.31, .37), (.13, .47), (.25, .47))):
        o = prim('cylinder', 'furn_log', loc=(X(.375), Y(4.0 + dy), dz), rot=(0, math.pi / 2, 0), scale=(.055, .055, .26), mat=M['agari'], vertices=10)
    collide(.15, 4.0, .6, 4.38, 0, .6)
    # the deer head (the owner's hunting) between the two front windows, looking into the room
    deer(M, 2.1)
    # the screening: a pull-up screen on a tripod in front of the west window, the sofa facing it, the projector on the
    # low table, cushions on the rug for the ones who do not get the sofa
    scr_y0, scr_y1 = .95, 2.55
    box('furn_screen', .42, scr_y0, .435, scr_y1, .88, 1.82, M['screen'])
    box('furn_scrbar', .41, scr_y0 - .02, .445, scr_y1 + .02, 1.82, 1.85, M['plastic'])
    box('furn_scrcase', .39, scr_y0 - .04, .47, scr_y1 + .04, .82, .88, M['plastic'])
    cyl('furn_scrpole', .48, (scr_y0 + scr_y1) / 2, .05, 1.85, .014, M['steel'], 8)
    for a in (0, 2.1, 4.2):
        lx, ly = .48 + .32 * math.cos(a), (scr_y0 + scr_y1) / 2 + .32 * math.sin(a)
        lib.tube('furn_scrleg', [(X(.48), Y((scr_y0 + scr_y1) / 2), .55), (X(lx), Y(ly), .01)], [.01, .01], M['steel'], seg=6, sub=1)
    collide(.15, scr_y0, .8, scr_y1, 0, 1.9)
    box('furn_rug', 1.25, .7, 3.75, 3.0, 0, .012, M['rug'], 1.0)
    # low table
    box('furn_ltable', 1.55, 1.25, 2.3, 2.45, .36, .4, M['walnut'])
    legs('furn_ltleg', 1.55, 1.25, 2.3, 2.45, .36, .05, M['walnut'])
    collide(1.55, 1.25, 2.3, 2.45, 0, .42)
    # projector, its lens toward the screen, a cable off the table's edge
    box('furn_proj', 1.7, 1.7, 1.98, 1.95, .4, .5, M['fridge'])
    o = prim('cylinder', 'furn_projlens', loc=(X(1.69), Y(1.77), .45), rot=(0, math.pi / 2, 0), scale=(.03, .03, .012), mat=M['plastic'], vertices=16)
    lib.tube('cable_proj', [(X(1.98), Y(1.88), .43), (X(2.15), Y(2.0), .41), (X(2.3), Y(2.3), .3), (X(2.45), Y(2.6), .015), (X(3.0), Y(2.95), .015)],
             [.005] * 5, M['plastic'], seg=6, sub=4)
    box('furn_remote', 2.0, 1.4, 2.05, 1.56, .4, .418, M['plastic'])
    # sofa: three-seater facing west (the screen)
    fx0, fx1, fy0, fy1 = 2.7, 3.55, .75, 2.75
    box('furn_sofabase', fx0, fy0, fx1, fy1, .08, .42, M['sofa'])
    box('furn_sofaback', fx1 - .22, fy0, fx1, fy1, .42, .86, M['sofa'])
    for (a, b) in ((fy0, fy0 + .2), (fy1 - .2, fy1)):
        box('furn_sofaarm', fx0, a, fx1, b, .42, .64, M['sofa'])
    for i in range(3):   # seat cushions
        a = fy0 + .2 + i * (fy1 - fy0 - .4) / 3
        box('furn_sofaseat', fx0 + .02, a + .01, fx1 - .22, a + (fy1 - fy0 - .4) / 3 - .01, .42, .52, M['sofa'])
    legs('furn_sofaleg', fx0, fy0, fx1, fy1, .08, .04, M['walnut'])
    collide(fx0, fy0, fx1, fy1, 0, .9)
    for (cx, cy) in ((1.45, .95), (2.45, 2.75)):   # floor cushions
        o = box('furn_cushion', cx - .22, cy - .22, cx + .22, cy + .22, .012, .1, M['cushion'])
        lib.smooth(o)
    # a floor lamp at the sofa's back end, short of the door (from the far corner it lit only the wall), on: the sun does not reach far past the front windows, and the room read black
    LY = 2.93
    cyl('furn_lampbase', 3.75, LY, 0, .03, .14, M['iron'])
    cyl('furn_lamppole', 3.75, LY, .03, 1.05, .012, M['iron'], 8)
    cyl('furn_lampshade', 3.75, LY, 1.0, 1.22, .16, M['shade'], 20)
    lib.point('lamp_living', (X(3.75), Y(LY), 1.08), 130, k=2800, radius=.1)
    collide(3.6, LY - .15, 3.9, LY + .15, 0, 1.25)   # shade below the eye: at 1.5 m it filled the view in from the door

def deer(M, x):
    cx = X(x); yw = Y(.06) - .005; z = 1.72
    o = prim('cylinder', 'furn_deerplaque', loc=(cx, yw - .02, z), rot=(math.pi / 2, 0, 0), scale=(.17, .24, .02), mat=M['door'], vertices=24)
    lib.tube('furn_deerneck', [(cx, yw - .03, z - .05), (cx, yw - .18, z), (cx, yw - .32, z + .1)], [(.1, .12), (.09, .1), (.08, .085)], M['fur'], seg=14)
    lib.tube('furn_deerhead', [(cx, yw - .3, z + .14), (cx, yw - .44, z + .1), (cx, yw - .57, z + .02)], [(.07, .08), (.055, .06), (.03, .035)], M['fur'], seg=14)
    prim('uv_sphere', 'furn_deernose', loc=(cx, yw - .585, z + .015), scale=(.025, .02, .02), mat=M['plastic'], segments=10, ring_count=6)
    for s in (-1, 1):
        prim('uv_sphere', 'furn_deereye', loc=(cx + s * .055, yw - .41, z + .14), scale=(.012, .012, .012), mat=M['plastic'], segments=8, ring_count=6)
        prim('uv_sphere', 'furn_deerear', loc=(cx + s * .1, yw - .31, z + .22), rot=(0, s * .5, 0), scale=(.05, .015, .025), mat=M['fur'], segments=10, ring_count=6)
        b = (cx + s * .04, yw - .32, z + .2)
        lib.tube('furn_antler', [b, (cx + s * .12, yw - .33, z + .33), (cx + s * .2, yw - .3, z + .45), (cx + s * .22, yw - .22, z + .58)], [.018, .014, .011, .007], M['antler'], seg=8)
        lib.tube('furn_antler', [(cx + s * .15, yw - .325, z + .37), (cx + s * .14, yw - .42, z + .47)], [.01, .006], M['antler'], seg=6, sub=1)
        lib.tube('furn_antler', [(cx + s * .2, yw - .3, z + .45), (cx + s * .26, yw - .36, z + .55)], [.009, .005], M['antler'], seg=6, sub=1)
    # a real head is bigger than first built (it read as a small ornament from the door): 1.3x about the plaque
    piv = lib.link(bpy.data.objects.new('furn_deer_pivot', None)); piv.location = (cx, yw, z)
    for o in [o for o in bpy.data.objects if o.name.startswith(('furn_deer', 'furn_antler')) and o.type == 'MESH']:
        o.parent = piv; o.location = o.location - piv.location
    piv.scale = (1.3, 1.3, 1.3); piv.location.z = z - .12

# ---------------------------------------------------------------- 食堂 (plan x 0..4, y 4.6..8)
def dining(M):
    tx0, tx1, ty0, ty1 = 1.0, 3.0, 5.85, 6.85
    box('furn_table', tx0, ty0, tx1, ty1, .69, .74, M['walnut'])
    legs('furn_tableleg', tx0, ty0, tx1, ty1, .69, .07, M['walnut'], inset=.06)
    for i in range(3):
        x = tx0 + .35 + i * .65
        for side in (-1, 1):
            chair(M, x, ty0 - .18 if side < 0 else ty1 + .18, side)
    collide(tx0 - .05, ty0 - .45, tx1 + .05, ty1 + .45, 0, .95)
    # on the table: the storyboard pages and a closed laptop (Kiryu's), a few mugs
    for i, (x, y, a) in enumerate(((1.4, 6.2, .1), (1.62, 6.3, -.15), (1.5, 6.45, .3))):
        o = prim('plane', 'furn_paper', loc=(X(x), Y(y), .741 + i * .001), rot=(0, 0, a), scale=(.105, .148, 1), mat=M['screen'])
    box('furn_laptop', 2.3, 6.1, 2.62, 6.32, .74, .76, M['plastic'])
    for (x, y) in ((2.1, 6.6), (2.75, 6.55)):
        cyl('furn_mug', x, y, .74, .83, .04, M['fridge'], 12)
    # sideboard on the north wall beside the window
    box('furn_sideboard', .15, 7.48, 1.1, 7.94, 0, .85, M['walnut'], col=True)
    # pendant over the table, on
    cyl('furn_pendcord', 2.0, 6.35, 1.75, H4.H1, .006, M['plastic'], 6)
    cyl('furn_pendshade', 2.0, 6.35, 1.6, 1.78, .2, M['shade'], 24)
    lib.point('lamp_dining', (X(2.0), Y(6.35), 1.56), 50, k=2800, radius=.1)

def chair(M, x, y, side):
    """side -1: the chair is on the table's front (plan -y) side, its back further out."""
    w = .42
    box('furn_chairseat', x - w / 2, y - w / 2, x + w / 2, y + w / 2, .43, .47, M['oak'], 1.25)
    legs('furn_chairleg', x - w / 2, y - w / 2, x + w / 2, y + w / 2, .43, .035, M['oak'], inset=.02)
    by = y + side * (w / 2 - .02)
    box('furn_chairback', x - w / 2 + .02, by - .02, x + w / 2 - .02, by + .02, .47, .9, M['oak'], 1.25)

# ---------------------------------------------------------------- 台所 (plan x 6..10, y 3.6..8; the pantry in its back east corner)
def kitchen(M):
    # north run under the window: cabinets, stainless top, the sink in the middle of the window
    nx0, nx1, ny0, ny1 = 6.07, 8.53, 7.33, 7.93
    counter(M, nx0, ny0, nx1, ny1, 'n')
    box('furn_sink', 7.1, 7.43, 7.75, 7.82, .76, .862, M['steel'])
    cyl('furn_tap', 7.42, 7.86, .862, 1.12, .012, M['steel'], 8)
    o = prim('cylinder', 'furn_tap', loc=(X(7.42), Y(7.79), 1.12), rot=(math.pi / 2, 0, 0), scale=(.012, .012, .07), mat=M['steel'], vertices=8)
    # south run along the study wall, a tabletop gas stove on it, cupboards over
    sx0, sx1, sy0, sy1 = 6.6, 9.3, 3.67, 4.27
    counter(M, sx0, sy0, sx1, sy1, 's')
    box('furn_gas', 7.55, 3.75, 8.15, 4.17, .86, .97, M['steel'])
    for gx in (7.7, 8.0):
        cyl('furn_burner', gx, 3.98, .97, .985, .06, M['plastic'], 14)
    cyl('furn_pot', 7.7, 3.98, .985, 1.15, .13, M['steel'], 20)
    box('furn_upper', sx0, 3.67, sx1, 4.0, 1.5, 2.2, M['cabinet'])
    # fridge in the corner, short of the back door
    box('furn_fridge', 9.32, 3.67, 9.93, 4.33, 0, 1.75, M['fridge'], col=True)
    box('furn_fridgegap', 9.31, 3.75, 9.32, 4.25, 1.15, 1.16, M['plastic'])
    box('furn_fridgehandle', 9.29, 4.2, 9.31, 4.23, .6, 1.05, M['steel'])
    # the curry things on the north counter: a paper bag, onions, potatoes, carrots, the roux; the rice cooker
    box('furn_bag', 6.3, 7.5, 6.62, 7.72, .862, 1.2, M['paperbag'])
    for i, (x, y) in enumerate(((6.8, 7.5), (6.88, 7.62), (6.74, 7.66))):
        prim('uv_sphere', 'furn_onion', loc=(X(x), Y(y), .9), scale=(.04, .04, .036), mat=M['onion'], segments=12, ring_count=8)
    for i, (x, y) in enumerate(((7.95, 7.5), (8.05, 7.56), (7.98, 7.64), (8.1, 7.45))):
        prim('uv_sphere', 'furn_potato', loc=(X(x), Y(y), .892), scale=(.042, .03, .028), rot=(0, 0, i), mat=M['potato'], segments=10, ring_count=6)
    for i in range(3):
        prim('cone', 'furn_carrot', loc=(X(8.25 + i * .03), Y(7.68 - i * .05), .88), rot=(0, math.pi / 2, .2 * i), scale=(.018, .018, .09), mat=M['carrot'], vertices=10)
    box('furn_roux', 8.25, 7.45, 8.4, 7.53, .862, .895, M['roux'])
    cyl('furn_ricecooker', 9.0, 3.95, .86, 1.08, .14, M['fridge'], 20)
    # the light is on in here (someone started on the rice)
    cyl('furn_kcord', 7.9, 5.6, 2.0, H4.H1, .006, M['plastic'], 6)
    cyl('furn_kshade', 7.9, 5.6, 1.88, 2.02, .16, M['shade'], 24)
    lib.point('lamp_kitchen', (X(7.9), Y(5.6), 1.84), 60, k=2900, radius=.08)

def counter(M, x0, y0, x1, y1, wall):
    box('furn_cab', x0, y0 + (.05 if wall == 'n' else 0), x1, y1 - (.05 if wall == 's' else 0), .1, .82, M['cabinet'])
    box('furn_kick', x0, y0 + (.1 if wall == 'n' else 0), x1, y1 - (.1 if wall == 's' else 0), 0, .1, M['plastic'])
    box('furn_top', x0, y0, x1, y1, .82, .862, M['steel'])
    collide(x0, y0, x1, y1, 0, .9)
    # door gaps on the cabinet front
    fy = y0 + .049 if wall == 'n' else y1 - .049
    n = max(1, int((x1 - x0) / .45))
    for i in range(1, n):
        x = x0 + i * (x1 - x0) / n
        box('furn_cabgap', x - .003, fy - .002, x + .003, fy + .002, .12, .8, M['plastic'])

def furnish(M):
    COL.clear(); mats(M)
    living(M); dining(M); kitchen(M)
    return list(COL)
