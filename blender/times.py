"""段階2: the six times of the night in the one house (企画書 ロードマップ「時間帯ごとの光」).

The direction (one plan, chosen for the story, not for the look of a horror game):
  After 20:00 the house's own power is dead. The only electricity left is the generator in the cellar, and it reaches
  the house by two routes: the owner's emergency circuit (the bulb over the cellar door's lobby, the bare bulb in the
  cellar) and one orange extension cord the film crew run up the cellar stair to their fresnel in the hall. So every
  warm light after 20:00 comes up out of the cellar, from the machine that kills Taiga, and the night is told by what
  that light does: it is not there yet (20:00, only the crew's battery LED, blue), it makes the hall a film set (23:00),
  it lights an open door into the rain (2:00, Kiryu goes), its fresnel has blown and only the lobby bulb is left at the
  far end of the hall, behind whoever comes down it (3:30), and it is still burning when the dawn comes through the
  gaps of the boards (4:30). The natural light does the opposite: the sun of the afternoon, then nothing, then the
  thin cold slits of the morning. In the print the warm and the cold land on different plates, so the two
  stories of light stay apart on the page.

Each light: Blender light (for the lightmap bake) + 'g' (how Godot builds it; Blender watts and Godot energies are not
the same scale, and the night/dusk scenes were tuned by eye in Godot). Positions in Blender metres."""
import math, json
import bpy
from mathutils import Vector
import lib, house4 as H4, stage as St, door as D

X, Y = H4.X, H4.Y

# where the lamps are (furnish.py, house4.lobby_lamp, rooms2.cellar)
P_LOBBY = (X(H4.LAMP[0]), Y(H4.LAMP[1]), H4.H1 - .28)
P_LIVING = (X(3.75), Y(2.93), 1.08)
P_DINING = (X(2.0), Y(6.35), 1.56)
P_KITCHEN = (X(7.9), Y(5.6), 1.84)
P_CELLAR = (X(7.9), Y(4.2), -.72)
FRES_HP = Vector((St.FRESNEL[0], St.FRESNEL[1], 2.12)); FRES_AIM = Vector((*St.MARK, 0.0))
FRES_P = tuple(FRES_HP + (FRES_AIM - FRES_HP).normalized() * .12)
BX, BY, BZ = St.SHOECAB_TOP; BZ += .12
BLUE_P = tuple(Vector((BX, BY, BZ)) + (Vector((St.DOOR_C, St.YF - .1, 1.2)) - Vector((BX, BY, BZ))).normalized() * .03)
SLIT = sum(St.SLIT_X) / 2

TIMES = ['dusk', 't20', 't23', 't02', 't0330', 't0430']
LABEL = {'dusk': '十七時半（夕方）', 't20': '二十時（停電）', 't23': '二十三時', 't02': '二時', 't0330': '三時半', 't0430': '四時半（夜明け）'}

# the state of the house at each time (Godot reads this from scene.json)
# 試作68 (レビュー 試作65: at dusk the shadow side was lifted by the world, the ambient and the fog into one murk, the
# lit side no brighter than the dark): less world in the bake, half the ambient, less fog, the window light up
DUSK_WIN = 2.0   # 1.4 (試作68): the lit walls upstairs came up, the print's darkest ink was already the shadows' floor
STATE = {
    #        boards  front door (deg open)  cord  print exposure  ambient (colour, energy)       sky ring (emission, tint)        fog
    # slip: the forest road's outer shoulder at the bend has gone (outside.py; the storm takes it before 桐生 goes out at 2:00)
    'dusk':  dict(boards=False, front=105, cord=False, exp=1.3, amb=[.55, .42, .34], ambe=.05, sky=.75, skyc=[1, 1, 1], fog=.03, slip=False),
    't20':   dict(boards=False, front=0, cord=False, exp=1.8, amb=[.22, .26, .34], ambe=.03, sky=.1, skyc=[.55, .62, .8], fog=.06, slip=False),
    't23':   dict(boards=True, front=0, cord=True, exp=1.8, amb=[.22, .26, .32], ambe=.02, sky=.06, skyc=[.55, .62, .75], fog=.085, slip=False),
    't02':   dict(boards=True, front=88, cord=True, exp=1.8, amb=[.22, .26, .32], ambe=.02, sky=.06, skyc=[.55, .62, .75], fog=.085, slip=True),
    't0330': dict(boards=True, front=0, cord=True, exp=1.8, amb=[.2, .24, .3], ambe=.015, sky=.05, skyc=[.55, .62, .75], fog=.07, slip=True),
    't0430': dict(boards=True, front=0, cord=True, exp=1.6, amb=[.4, .46, .58], ambe=.05, sky=.35, skyc=[.7, .78, .95], fog=.06, slip=True),
}

def _g(o, **g):
    o['g'] = json.dumps(g); return o

def lobby(e=1.25):
    return _g(lib.point('lamp_lobby', P_LOBBY, 40 * e / 1.25, k=2700, radius=.06), kind='omni', e=e, r=3.5, att=1.4, sh=1, fog=.3, size=.06, flick='gen')

def cellar(e=2.6):   # 1.6 left the cellar unreadable through the print (試作49): a bare bulb in a small concrete room
    return _g(lib.point('lamp_cellar', P_CELLAR, 60 * e / 1.6, k=2600, radius=.03), kind='omni', e=e, r=7.0, att=1.3, sh=1, fog=.5, size=.03, flick='gen')

def fresnel(e=9.0, w=520):
    return _g(lib.spot('fresnel_key', FRES_P, tuple(FRES_AIM), w, k=3200, size=30, blend=.18, radius=.05), kind='spot', e=e, ang=15, sh=1, fog=3.0, size=.06, flick='fres')

P_LANTERN = (X(1.85), Y(1.6), .55)
P_CANDLE = (X(8.76), Y(7.62), 1.0)
P_PHONE_M = (X(9.62), Y(1.72), H4.F2 + .62)
P_LANTERN_C = (X(5.45), Y(1.25), H4.ZB + .15)   # the crew's lantern by the sleeping bag in the cellar (rooms2.cellar)
def lantern_cellar(e=1.0):
    return _g(lib.point('lantern_cellar', P_LANTERN_C, 8 * e, k=3300, radius=.05), kind='omni', e=.35 * e, r=3.5, att=1.4, sh=1, fog=.2, size=.05, flick='batt')
# the crew's battery lanterns left lit upstairs and on the landing after the outage (ユーザー 2026-11-06 「部屋の仕上がり
# レビュー」: at 23:00 the bedrooms and the landing were black through the print; the windows are boarded and the storm
# has no moon, so the light has to be one they carried in). rooms2.night_lights puts each lantern where its light is
# 試作67 (レビュー: five lanterns on the floor in the middle of each room, the same round pool, read as markers): each
# stands where its owner put it down. bed1: on the nightstand between the girls' beds; bed2: on the chest of drawers
# by the make-up kit; bed3: on Makoto's nightstand; the landing: the one left on the floor, at the head of the stair so
# the treads catch it going down; the study: by his low desk
P_CREW = {'lantern_bed1': (.38, 2.1, H4.F2 + .616), 'lantern_bed2': (3.62, 5.62, H4.F2 + .676), 'lantern_bed3': (9.6, 1.76, H4.F2 + .616),
          'lantern_landing': (5.5, 5.82, H4.F2), 'lantern_study': (9.0, 2.45, 0.0)}
# candles the crew stood about downstairs (試作64: the south counter and the dining table were black at 23:00; 試作67:
# the kitchen's sink side still black)
P_CANDLES = {'candle_counter': (6.95, 3.95, .862), 'candle_dining': (2.0, 6.35, .74), 'candle_sink': (6.85, 7.62, .862)}
def crew_lanterns(e=1.0):
    return [_g(lib.point(n, (X(x), Y(y), z + .15), 8 * e, k=3300, radius=.05), kind='omni', e=.7 * e, r=4.5, att=1.3, sh=1, fog=.2, size=.05, flick='batt')
            for n, (x, y, z) in P_CREW.items()] + \
           [_g(lib.point(n, (X(x), Y(y), z + .2), 8 * e, k=1800, radius=.03), kind='omni', e=.8 * e, r=3.0, att=1.5, sh=1, fog=.1, size=.03, flick='candle')
            for n, (x, y, z) in P_CANDLES.items()]
def lantern(e=1.0):
    return _g(lib.point('lantern_living', P_LANTERN, 25 * e, k=3300, radius=.05), kind='omni', e=e, r=4.5, att=1.4, sh=1, fog=.2, size=.05, flick='batt')
def cabinet():
    """The battery LED bars in the study's cabinet (rooms2.night_lights): the same at every time."""
    out = []
    for nm, z in (('cab_led', 1.37), ('cab_led2', .87)):
        out.append(_g(lib.point(nm, (X(7.2), Y(.42), z), 1.0, k=4300, radius=.02), kind='omni', e=.2, r=1.1, att=1.6, sh=1, fog=0, size=.02, spec=.2))
    return out
def candles(e=.5):
    return _g(lib.point('candle_kitchen', P_CANDLE, 8 * e / .5, k=1800, radius=.03), kind='omni', e=e, r=3.0, att=1.5, sh=1, fog=.1, size=.03, flick='candle')
def storm(e=.1):
    s = lib.sun('storm_sky', (0, 0, 0), .25 * e / .1, k=12000, angle=8)
    s.rotation_euler = Vector((.2, -.6, -.75)).to_track_quat('-Z', 'Y').to_euler()
    return _g(s, kind='sun', e=e, sh=1, fog=.4, ang=0, spec=0)   # soft (8) went through the walls, see dawn

def lights(t):
    """Make the Blender lights for time t (removing any there are). Returns them."""
    for o in [o for o in bpy.data.objects if o.type == 'LIGHT']: bpy.data.objects.remove(o)
    w = bpy.context.scene.world.node_tree.nodes['Background']
    w.inputs[1].default_value = 0.0
    L = []
    if t == 'dusk':
        # 第1章 as it was tuned (export_dusk): the low sun from the south-west, the sky in the open door, the room lamps,
        # the fresnel being aimed at Natsuki's mark (on the mains)
        s = lib.sun('sun', (0, 0, 0), 14, k=2200, angle=.8)
        s.rotation_euler = Vector((.3, -.95, -.25)).to_track_quat('-Z', 'Y').to_euler()
        L.append(_g(s, kind='sun', e=2.4, sh=1, fog=1.6, ang=.8, spec=.3))
        w.inputs[0].default_value = (*lib.kelvin(3400), 1); w.inputs[1].default_value = .2   # .35 lifted every shadow into one murk through the print (レビュー 試作65)
        L.append(_g(lib.area('door_sky', (St.DOOR_C, St.YF + .25, 1.1), (St.DOOR_C - .16, 3.5, .7), 30, k=4200, size=(.8, 2.1), spread=120),
                    kind='spot', e=1.1, ang=60, sh=0, size=.6, spec=.15))
        L.append(fresnel(2.6, 160))
        L.append(lobby())
        L.append(_g(lib.point('lamp_living', P_LIVING, 186, k=2800, radius=.1), kind='omni', e=5.0, r=5.0, att=1.3, sh=1, fog=0, size=.08))   # 3.5 left the living room under the print's ink (試作69)
        L.append(_g(lib.point('lamp_dining', P_DINING, 50, k=2800, radius=.1), kind='omni', e=1.4, r=5.0, att=1.3, sh=1, fog=0, size=.08))
        L.append(_g(lib.point('lamp_kitchen', P_KITCHEN, 60, k=2900, radius=.08), kind='omni', e=1.4, r=5.0, att=1.3, sh=1, fog=0, size=.08))
        L.append(cellar(1.2))
        # the dusk sky in 寝室1's south and west windows (試作49-51: the room was black through the print; the low sun
        # is behind the cedars by then and the upstairs has no lamp lit)
        for (nm, src, dst) in (('dusk_bed1s', (X(1.5), Y(-1.3), H4.F2 + 2.0), (X(1.8), Y(2.4), H4.F2 + .4)),
                               ('dusk_bed1w', (X(-1.3), Y(1.9), H4.F2 + 2.0), (X(2.4), Y(2.1), H4.F2 + .4))):
            L.append(_g(lib.area(nm, src, dst, 15 * DUSK_WIN, k=4200, size=(1.0, 1.0)), kind='spot', e=2.2 * DUSK_WIN, ang=48, sh=1, size=.08, fog=.6, spec=.15))
        # the same through the other upstairs windows (レビュー 試作63: 寝室2・3, the landing and the stairwell dissolved
        # into the print at dusk). West and south take the low sky at full, north and east the cooler half of it
        for (nm, src, dst, e_) in (('dusk_bed2w', (X(-1.3), Y(6.1), H4.F2 + 2.0), (X(2.4), Y(6.3), H4.F2 + .4), 2.2),
                                   ('dusk_bed2n', (X(2.0), Y(9.3), H4.F2 + 2.0), (X(2.1), Y(5.6), H4.F2 + .4), 1.2),
                                   ('dusk_bed3s', (X(7.3), Y(-1.3), H4.F2 + 2.0), (X(7.6), Y(2.4), H4.F2 + .4), 2.2),
                                   ('dusk_bed3e', (X(11.3), Y(1.9), H4.F2 + 2.0), (X(7.6), Y(2.0), H4.F2 + .4), 1.2),
                                   ('dusk_stairs', (X(5.0), Y(-1.3), H4.F2 + 2.2), (X(5.0), Y(3.0), H4.F2 - .6), 2.2),
                                   # the landing has no window: the bathroom's north one, through its door (試作69)
                                   ('dusk_bathn', (X(7.1), Y(9.3), H4.F2 + 2.0), (X(5.2), Y(7.1), H4.F2 + .3), 1.2)):
            L.append(_g(lib.area(nm, src, dst, 15 * e_ / 2.2 * DUSK_WIN, k=4200, size=(1.0, 1.0)), kind='spot', e=e_ * DUSK_WIN, ang=48, sh=1, size=.08, fog=.6, spec=.15))
    elif t == 't20':
        # just after the cut: the generator has only just been started (the lobby bulb is dim and unsteady), the crew's
        # battery LED panel, gelled blue for tonight's planned shot, is the one light anyone can carry about; the
        # windows are still bare (the boarding starts after the radio), the storm's sky faintly in them
        L.append(lobby(.8)); L.append(cellar(1.2))
        L.append(_g(lib.area('blue_door', BLUE_P, (St.DOOR_C, St.YF - .1, 1.2), 7, color=(.4, .56, 1.0), size=(.24, .18), spread=75),
                    kind='spot', e=1.6, ang=37, sh=1, size=.2))
        L.append(storm(.12)); L.append(lantern()); L.append(candles())
        L.append(_g(lib.area('lightning', (SLIT + .4, St.YF + 2.5, 2.2), (SLIT, St.YF, 1.1), 0, k=16000, size=(1.5, 1.5)), kind='bolt', e=0))
    elif t == 't23':
        # the 第2章 door scene as tuned (export_godot): the fresnel on the generator's cord, the blue panel at the door,
        # the rain sky at the slit, the lobby bulb, the camera's tally
        L.append(fresnel()); L.append(lobby()); L.append(cellar()); L.append(storm()); L.append(lantern(2.0)); L.append(candles(1.0)); L.append(lantern_cellar())
        L.extend(crew_lanterns())   # lantern 2.0, candles 1.0: at 1.0 / .5 the living room and the kitchen went black in the print (レビュー 試作63)
        L.append(_g(lib.area('blue_door', BLUE_P, (St.DOOR_C, St.YF - .1, 1.2), 7, color=(.4, .56, 1.0), size=(.24, .18), spread=75),
                    kind='spot', e=1.4, ang=37, sh=1, size=.2))
        L.append(_g(lib.area('rain_sky', (SLIT - .5, St.YF + 1.4, 2.2), (SLIT, St.YF + .2, 1.1), 6, k=14000, size=(.8, .8)), kind='spot', e=1.6, ang=40, sh=1, size=.6))
        L.append(_g(lib.area('lightning', (SLIT + .4, St.YF + 2.5, 2.2), (SLIT, St.YF, 1.1), 0, k=16000, size=(1.5, 1.5)), kind='bolt', e=0))
        L.append(_g(lib.point('rec_light', D.rec_pos(St.TRIPOD_N, math.radians(205)), .25, color=(1, .03, .01), radius=.004), kind='omni', e=.25, r=.6, sh=0, size=.005))
    elif t == 't02':
        # Kiryu goes: the front door stands open on the rain, the fresnel (still on the cord) lights the doorway from
        # behind; the blue panel's battery is flat (six hours)
        L.append(fresnel()); L.append(lobby()); L.append(cellar()); L.append(storm()); L.append(lantern(1.6)); L.append(candles(.8)); L.append(lantern_cellar(.8)); L.extend(crew_lanterns(.8))
        L.append(_g(lib.area('rain_sky', (St.DOOR_C, St.YF + 1.6, 2.4), (St.DOOR_C, St.YF - .5, .6), 6, k=14000, size=(1.2, 1.2)), kind='spot', e=1.2, ang=45, sh=1, size=.6))
        L.append(_g(lib.area('lightning', (St.DOOR_C + .6, St.YF + 3.0, 2.6), (St.DOOR_C, St.YF - .5, 1.1), 0, k=16000, size=(1.5, 1.5)), kind='bolt', e=0))
        L.append(_g(lib.point('rec_light', D.rec_pos(St.TRIPOD_N, math.radians(205)), .25, color=(1, .03, .01), radius=.004), kind='omni', e=.25, r=.6, sh=0, size=.005))
    elif t == 't0330':
        # the fresnel's lamp has blown (tungsten, seven hours on a generator's surges). What is left in the hall is the
        # lobby bulb at its far end: whoever comes down the hall from the back comes against it, a shape before a
        # person. The tally of the camera Mio set up is still red. Lightning through the gaps of the boards.
        L.append(lobby(1.4)); L.append(cellar())
        L.append(_g(lib.point('rec_light', D.rec_pos(St.TRIPOD_N, math.radians(205)), .25, color=(1, .03, .01), radius=.004), kind='omni', e=.3, r=.7, sh=0, size=.005))
        L.append(storm(.08)); L.append(lantern(.3)); L.append(candles(.25)); L.append(lantern_cellar(.3)); L.extend(crew_lanterns(.3))
        # Makoto upstairs with her headache: her phone face up on the bedside table, the screen still on
        L.append(_g(lib.point('phone_makoto', P_PHONE_M, 1.5, k=8000, radius=.02), kind='omni', e=.35, r=1.8, att=1.5, sh=1, fog=.1, size=.02))
        L.append(_g(lib.area('lightning', (X(10) + 2.5, Y(5.0), 2.0), (X(8), Y(5.0), 1.0), 0, k=16000, size=(1.5, 1.5)), kind='bolt', e=0))
    elif t == 't0430':
        # first light: the storm has passed east of the ridge; the low sky there comes through the gaps between the
        # boards in thin cold bars that cross the floors. The lobby bulb still burns (the generator runs to 5:00).
        L.append(lobby()); L.append(cellar()); L.append(lantern_cellar(.2))
        # not a sun: the sun is not up yet and the wood and the ridge hide the low east anyway (a sun here was
        # blocked by the trees, and a soft one went through every wall in Godot). What comes in is the cold sky in the
        # east windows: a soft light outside each, aimed in and down, so the gaps between the boards throw bars.
        for (nm, px, py, z, k) in (('dawn_study', 10, 1.7, H4.SILL1 + H4.WH1 + .5, 1.0), ('dawn_kitchen', 10, 6.2, H4.SILL1 + H4.WH1 + .5, 1.0),
                                   ('dawn_bed3', 10, 1.9, H4.F2 + 2.1, .55), ('dawn_bath', 10, 6.5, H4.F2 + 2.1, .6)):
            src = (X(px + 1.3), Y(py - .25), z); dst = (X(px - 2.2), Y(py + .2), z - 1.9 if z < 2.5 else z - 2.0)
            L.append(_g(lib.area(nm, src, dst, 30 * k, k=11000, size=(1.0, 1.0)), kind='spot', e=4.0 * k, ang=48, sh=1, size=.08, fog=1.0, spec=.15))
        # the paler sky to the south, in the living room's boarded front windows (試作45: the room was black at 4:30)
        for (nm, px) in (('dawn_living1', 1.2), ('dawn_living2', 2.9)):
            src = (X(px), Y(-1.3), 2.6); dst = (X(px), Y(2.2), .5)
            L.append(_g(lib.area(nm, src, dst, 15, k=10000, size=(1.0, 1.0)), kind='spot', e=2.2, ang=48, sh=1, size=.08, fog=1.0, spec=.15))
        w.inputs[0].default_value = (*lib.kelvin(11000), 1); w.inputs[1].default_value = .12
        L.append(_g(lib.point('rec_light', D.rec_pos(St.TRIPOD_N, math.radians(205)), .25, color=(1, .03, .01), radius=.004), kind='omni', e=.25, r=.6, sh=0, size=.005))
    L += cabinet()
    bpy.context.view_layer.update()
    return L

def on_lamps(t):
    """Which lampshades glow at time t (their emission is kept, the others are dark)."""
    names = {o.name for o in bpy.data.objects if o.type == 'LIGHT'}
    return names

def dump(path):
    out = []
    for o in [o for o in bpy.data.objects if o.type == 'LIGHT']:
        d = o.data; mw = o.matrix_world
        fwd = (mw.to_3x3() @ Vector((0, 0, -1))).normalized()
        e = dict(name=o.name, type=d.type, pos=list(mw.translation), dir=list(fwd), color=list(d.color), g=json.loads(o.get('g', '{}')))
        out.append(e)
    json.dump(out, open(path, 'w'), indent=1)
