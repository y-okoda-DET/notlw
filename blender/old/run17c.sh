#!/bin/bash
cd /home/claude/tripo && python3 make_prep.py >/dev/null
timeout 1500 python3 prep_makoto.py > p_makoto.log 2>&1; grep "non-cloth\|SAVED" p_makoto.log
timeout 600 python3 view4.py -- makoto 1.33 >/dev/null 2>&1
python3 -c "
from PIL import Image
o=Image.new('RGB',(1800,450))
for i,n in enumerate(['front','up','side','back']): o.paste(Image.open(f'v4_makoto_{n}.png').convert('RGB'),(i*450,0))
o.save('/home/claude/kf/v4m.png')"
echo PREP_DONE $(date +%T)
cd /home/claude/kf
python3 export_dusk.py > export17d.log 2>&1 || echo DUSK_FAIL
python3 denoise_lm.py -- /home/claude/rules/assets/dusk/lightmap.exr >> export17d.log 2>&1
cd /home/claude/rules; G=/home/claude/godot/Godot_v4.4.1-stable_linux.x86_64
$G --headless --path . --import > /dev/null 2>&1
for f in $(grep -l "size_limit=0" assets/*.import assets/dusk/*.import assets/faces/*.import | grep -v exr); do sed -i 's/size_limit=0/size_limit=2048/' $f; done
$G --headless --path . --import > /dev/null 2>&1
xvfb-run -a -s "-screen 0 960x540x24" $G --path . --windowed --resolution 960x540 -- --bake-gi --scene=dusk > /dev/null 2>&1
rm -rf /home/claude/build/RULES_proto17; mkdir -p /home/claude/build/RULES_proto17
$G --headless --path . --export-release "Windows Desktop" ../build/RULES_proto17/RULES.exe > /home/claude/kf/export17w.log 2>&1
ls -la /home/claude/build/RULES_proto17; echo DONE $(date +%T)
