#!/bin/bash
L=/home/claude/kf/run10.log; echo "== dusk $(date +%T)" >> $L
cd /home/claude/kf
python3 export_dusk.py > export10d.log 2>&1 || { echo DUSK_FAIL >> $L; exit 1; }
python3 denoise_lm.py -- /home/claude/rules/assets/dusk/lightmap.exr >> export10d.log 2>&1
echo "== godot $(date +%T)" >> $L
cd /home/claude/rules
G=/home/claude/godot/Godot_v4.4.1-stable_linux.x86_64
$G --headless --path . --import > /dev/null 2>&1
for f in $(grep -l "size_limit=0" assets/*.import assets/dusk/*.import | grep -v exr); do sed -i 's/size_limit=0/size_limit=2048/' $f; done
$G --headless --path . --import > /dev/null 2>&1
xvfb-run -a -s "-screen 0 960x540x24" $G --path . --windowed --resolution 960x540 -- --bake-gi --scene=night > /dev/null 2>&1
xvfb-run -a -s "-screen 0 960x540x24" $G --path . --windowed --resolution 960x540 -- --bake-gi --scene=dusk > /dev/null 2>&1
R=/tmp/claude-0/-home-claude/6407adc7-bdf3-5700-ba20-4629ee47fbe1/scratchpad/rec; rm -rf $R/night $R/dusk; mkdir -p $R/night $R/dusk
echo "== record $(date +%T)" >> $L
for sc in night dusk; do xvfb-run -a -s "-screen 0 960x540x24" $G --path . --windowed --resolution 960x540 --write-movie $R/$sc/f.png --fixed-fps 24 -- --record=walk --scene=$sc --gi=baked --pexp=3.0 > $R/$sc.log 2>&1; done
for sc in night dusk; do ffmpeg -y -loglevel error -framerate 24 -i $R/$sc/f%08d.png -c:v libx264 -pix_fmt yuv420p -crf 20 /home/claude/build/RULES_proto10_${sc}_walk.mp4; done
sed -i 's#../build/RULES_proto9/RULES.exe#../build/RULES_proto10/RULES.exe#' export_presets.cfg
rm -rf /home/claude/build/RULES_proto10; mkdir -p /home/claude/build/RULES_proto10
$G --headless --path . --export-release "Windows Desktop" ../build/RULES_proto10/RULES.exe > $R/export.log 2>&1
echo "== RUN10_DONE $(date +%T)" >> $L
