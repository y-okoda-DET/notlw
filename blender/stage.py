"""Where the people, the film gear and the player stand in the v4 house (Blender metres; house4.X/Y map the plan).
The hall runs from the front door (Y 6.3) back to the rear wall; the up-stair is on its right seen from the back
(X .3..1.15, Y .7..3.7), the walkway beside it on the left (X -.8..0.3). Between the stair's foot and the genkan step
(Y 3.7..4.9) the hall is its full 2 m wide: that is where the shoot is set up."""
import house4 as H4

HALL = (H4.X(4), H4.X(6))                     # hall walls (inner faces .06 in)
DOOR_X = (H4.X(4.45), H4.X(5.55))             # front door opening
DOOR_C = (DOOR_X[0] + DOOR_X[1]) / 2
SLIT_X = (H4.X(4.08), H4.X(4.28))             # the narrow window beside the door
YF = H4.YF; ZG = H4.ZG
MARK = (.35, 4.1)                             # Natsuki's tape mark
TRIPOD_N = (-.45, 4.70)                       # 23:00 (the camcorder left standing since the afternoon)
TRIPOD_D = (-.45, 4.47)                       # dusk
KIRYU_D = (-.32, 4.78)                        # dusk: behind the camcorder, as on the old set (tripod + (.13, .31))
KIRYU_N = (-.32, 4.37)                        # 23:00: reading his phone
NATSUKI_D = (.36, 4.19)
MAKOTO_D = (.95, 3.86)                        # holding the reflector on Natsuki, just in front of the stair's foot
FRESNEL = (-.5, 2.9)                          # in the walkway by the living-room door, aimed at the mark
APPLEBOX = (-.6, 3.85)                        # by the walkway's mouth, out of the way of the views of Makoto
TAIGA_D = (DOOR_C + .06, YF + .17)            # in the doorway with an apple box
TAIGA_N = (DOOR_C + .06, YF - 1.03)           # leaning into the shut door
SHOECAB_TOP = (H4.X(5.77), H4.Y(.7), ZG + .91)
PLAYER = (-.3, 1.0, 1.55)                     # Mio's start (eye), in the walkway behind the stair's foot
PLAYER_LOOK = (DOOR_C, YF, .75)
GI_BOX = ((HALL[0] - .3, -1.0, ZG - .1), (HALL[1] + .3, YF + .4, H4.H1 + .4))

def scene_json(scene, boxes):
    """What Godot needs of the set besides the meshes: walls to bump into, people and stands to walk round, the start."""
    if scene == 'dusk':
        props = [[*NATSUKI_D, .24], [*KIRYU_D, .22], [*TRIPOD_D, .26], [*FRESNEL, .32], [*APPLEBOX, .22], [*MAKOTO_D, .2], [*TAIGA_D, .3]]
    else:
        props = [[*KIRYU_N, .24], [*TAIGA_N, .3], [*TRIPOD_N, .26], [*FRESNEL, .32], [*APPLEBOX, .22], [HALL[0] + .2, 5.15, .14]]
    boxes = boxes + [dict(c=[DOOR_C, YF + .95, ZG - .28], s=[2.8, 1.8, .5])]   # the porch outside the door (the ext deck has no collider)
    return dict(boxes=boxes, props=props, spawn=list(PLAYER), look=list(PLAYER_LOOK), gi_box=[list(GI_BOX[0]), list(GI_BOX[1])],
                mark=[*MARK, 0])
