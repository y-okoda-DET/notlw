"""Generate prep_<key>.py from the Natsuki script with per-character measurements."""
import sys, json
CFG = json.load(open('/home/claude/tripo/chars_cfg.json'))
src = open('/home/claude/tripo/prep_natsuki.py').read()
import re as _re
src = _re.sub(r'\nA\.data\.transform\([^\n]*# NIGHT_BODY[^\n]*', '', src)   # only the night body is turned back
a = src.index("A_HEIGHT = "); b = src.index("def imp(f):")
for key, c in CFG.items():
    if key == 'natsuki': continue
    s = src[:a] + f"""A_HEIGHT = {c['A_HEIGHT']}
H_BODY = {c['H']} / A_HEIGHT
S_HEAD = {c['S_HEAD']}
A_CHIN = {c['A_CHIN']}
B_CHIN = {c['B_CHIN']}
B_EYE_Z = {c['B_EYE_Z']}; B_EYE_X = {c['B_EYE_X']}; B_EYED = {c['B_EYED']}
B_CUT = {c.get('B_CUT', 0.0)}
NECK_K = 1.0
A_CUT = {c['A_CUT']}

""" + src[b:]
    s = s.replace("A.rotation_euler.z += math.pi; ", "A.rotation_euler.z += math.pi; " if c.get('rot180') else "")
    s = s.replace("n2_body.glb", f"{key}_body.glb").replace("n2_head.glb", f"{key}_head.glb")
    s = s.replace("natsuki_talk_open", "natsuki_talk").replace("natsuki", key)
    import re
    s = re.sub(r"hb_pts = \[.*\]", "hb_pts = " + json.dumps(c['hb']).replace('[[','[(').replace(']]',')]').replace('], [','), ('), s)
    s = re.sub(r"hp_pts = \[.*\]", "hp_pts = " + json.dumps(c['hp']).replace('[[','[(').replace(']]',')]').replace('], [','), ('), s)
    s = re.sub(r"K = 1\.0", f"K = {c['K']}", s)
    s = re.sub(r"bc_s = np.array\(\[[^\]]*\]\)", f"bc_s = np.array({c['cheek']})", s)
    s = re.sub(r"_ck = np.array\(\[[^\]]*\]\)", f"_ck = np.array({c['cheek']})", s)
    s = s.replace('CUT_UP = .003', 'CUT_UP = .012')
    s = s.replace('NECK_GEOM = True', 'NECK_GEOM = False')
    if c.get('collar_ring'): s = s.replace('COLLAR_RING = False', 'COLLAR_RING = True')   # Makoto: the rim under her generated hair
    if key == 'yota':   # no closed-eyes / talking drawings yet: open stands in for closed, the smile for talking
        s = s.replace("(('open', 'yota_open'), ('closed', 'yota_closed'), ('talk', 'yota_talk'))", "(('open', 'yota_open'), ('closed', 'yota_open'), ('talk', 'yota_smile'))")
    open(f'/home/claude/tripo/prep_{key}.py', 'w').write(s)
    print('wrote', key)

# Natsuki indoors (socks body n3, the same head): the template with her socks-body measurements
s = src
for a_, b_ in (("A_HEIGHT = .9778", "A_HEIGHT = .9799"), ("A_CHIN = .840", "A_CHIN = .845"), ("A_CUT = .826", "A_CUT = .828"), ("n2_body.glb", "n3_body.glb")):
    assert a_ in s, a_; s = s.replace(a_, b_)
s = s.replace('natsuki', 'natsuki_s')
s = s.replace('faces_style/natsuki_s_', 'faces_style/natsuki_').replace("['natsuki_s']", "['natsuki']")
s = s.replace("(('open', 'natsuki_s_open'), ('closed', 'natsuki_s_closed'), ('talk', 'natsuki_s_talk_open'))", "(('open', 'natsuki_open'), ('closed', 'natsuki_closed'), ('talk', 'natsuki_talk_open'))")
s = "# socks version of Natsuki (indoors, dusk): the same head, the body generated from the socks images (generated from prep_natsuki.py)\n" + s
open('/home/claude/tripo/prep_natsuki_s.py', 'w').write(s); print('wrote natsuki_s')
