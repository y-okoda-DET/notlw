"""Keyframe: 第1章 夕方 — Natsuki tapes her own mark while Kiryu aims the fresnel at it."""
import sys, math
sys.path.insert(0, '/home/claude/kf')
import bpy
from mathutils import Vector
import lib, door as D, hall as Hm
from lib import prim, mat_basic, mat_image, kelvin
from night import CAM

def build():
    lib.reset()
    s = bpy.context.scene
    M = D.mats()
    A = Hm.build_hall(M, door_open=True)
    Hm.genkan_props(M, shoes=5, umbrellas=5)
    Y = Hm.YF
    # outside: porch, then the sunset forest as a far backdrop
    porch = prim('cube', 'porch', loc=(.75, Y + 1.0, Hm.ZG - .03), scale=(1.6, 1.0, .03), mat=M['floor']); lib.uv_box(porch, .87)
    sky = bpy.data.materials.new('sunset'); sky.use_nodes = True; N = sky.node_tree.nodes; L = sky.node_tree.links
    N.remove(N['Principled BSDF']); em = N.new('ShaderNodeEmission'); t = N.new('ShaderNodeTexImage'); t.image = lib.img(lib.tex_path('sunset'))
    L.new(t.outputs[0], em.inputs[0]); em.inputs[1].default_value = 2.2; L.new(em.outputs[0], N['Material Output'].inputs[0])
    bd = prim('plane', 'backdrop', loc=(.9, Y + 9, 1.6), rot=(math.pi / 2, 0, 0), scale=(8, 8 * 876 / 1358, 1), mat=sky)
    bd.visible_shadow = False; bd.visible_diffuse = False
    # low sun through the open door, raking across the floor toward the camera
    sun = lib.sun('sun', (0, 0, 0), 14, k=2200, angle=.8)
    sun.rotation_euler = Vector((.3, -.95, -.25)).to_track_quat('-Z', 'Y').to_euler()
    w = s.world.node_tree.nodes['Background']; w.inputs[0].default_value = (*kelvin(3400), 1); w.inputs[1].default_value = .35
    lib.area('door_sky', (.76, Y + .25, 1.1), (.6, 3.5, .7), 30, k=4200, size=(.8, 2.1), spread=120)
    # film gear: the same fresnel, being aimed at her mark
    D.fresnel((1.25, 2.55), 2.0, (.35, 3.75, 0), M, energy=160, size=30)
    D.tripod((-.45, 4.35), math.radians(205), M)
    Hm.tape_mark(.35, 3.75, CAM[:2], 'tape_natsuki.png')
    ab = prim('cube', 'applebox', loc=(1.25, 3.3, .1), rot=(0, 0, .3), scale=(.25, .15, .1), mat=M['agari']); lib.uv_box(ab, 1.25)
    # Natsuki kneeling on her mark, looking up at Mio
    # standing on her own mark, the tape roll in both hands, looking at Mio
    hold = dict(lel=(.19, -.06, 1.13), lwr=(.08, -.2, 1.0), lha=(.03, -.23, .97), rel=(-.2, -.06, 1.13), rwr=(-.08, -.2, 1.0), rha=(-.03, -.23, .97))
    lib.figure('natsuki', top=M['knit'], pants=M['denim'], feet=M['sock'], skin=(.78, .58, .47), female=True, s=.96,
               loc=(.36, 3.82, 0), yaw=-16, head_yaw=4, head_pitch=-4, head_roll=4, pose=hold)
    # a white bounce board on a stand, sending the floor's sunlight back into her face
    rf = prim('cube', 'reflector', loc=(.95, 2.75, .95), scale=(.3, .006, .3), mat=mat_basic('refl', (.9, .9, .88), .7))
    rf.rotation_euler = (Vector((.36, 3.82, 1.5)) - Vector((.95, 2.75, .95))).to_track_quat('-Y', 'Z').to_euler()
    D.cyl_between('rf_stand', (.95, 2.78, 0), (.95, 2.78, .7), .012, M['metal'], 8)
    lib.area('reflector_bounce', (.93, 2.8, .97), (.36, 3.82, 1.5), 9, k=3000, size=(.6, .6), spread=150)
    roll = D.cyl_between('taperoll', (.31, 3.6, .93), (.31, 3.6, .98), .05, mat_basic('tapeyel', (.85, .65, .08), .5), 20)
    # Kiryu behind the fixed camera, framing her on its screen
    frame = dict(lel=(.2, -.14, 1.18), lwr=(.12, -.3, 1.36), lha=(.08, -.33, 1.42), rel=(-.2, -.14, 1.18), rwr=(-.12, -.3, 1.36), rha=(-.08, -.33, 1.42))
    lib.figure('kiryu', top=M['plaid'], pants=M['olive'], feet=M['sockd'], skin=(.76, .57, .45), s=1.04,
               loc=(-.32, 4.75, 0), yaw=-12, head_yaw=10, head_pitch=14, pose=dict(frame, lean=(0, -.06, 0)))
    # Taiga in the doorway carrying an apple box, backlit
    carry = dict(lel=(.2, -.12, 1.1), lwr=(.17, -.3, 1.05), lha=(.15, -.34, 1.06), rel=(-.2, -.12, 1.1), rwr=(-.17, -.3, 1.05), rha=(-.15, -.34, 1.06))
    lib.figure('taiga', top=M['tee'], pants=M['track'], feet=M['sockd'], skin=(.74, .55, .43), sleeve='short', s=1.07, wide=1.1,
               loc=(.82, Y + .15, Hm.ZG), yaw=-8, head_yaw=-10, head_pitch=0, pose=carry)
    ab2 = prim('cube', 'applebox2', loc=(.8, Y - .2, 1.12 + Hm.ZG), rot=(0, 0, -.14), scale=(.25, .15, .1), mat=M['agari']); lib.uv_box(ab2, 1.25)
    lib.haze(((-1.6, .6, -.2), (1.6, 6.3, 2.45)), density=.06, aniso=.6)
    return M

if __name__ == '__main__':
    a = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    out = a[0] if a else '/home/claude/kf/out/dusk_t.png'
    spp = int(a[1]) if len(a) > 1 else 24; pct = int(a[2]) if len(a) > 2 else 50
    exp = float(a[3]) if len(a) > 3 else 0.0
    build(); import night; night.cam()
    bpy.context.scene.view_settings.exposure = exp
    bpy.context.scene.view_settings.look = 'AgX - Medium High Contrast'
    lib.render(out, samples=spp, pct=pct)
