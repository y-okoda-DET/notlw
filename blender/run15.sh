#!/bin/bash
L=/home/claude/kf/run15.log; echo "== night $(date +%T)" > $L
cd /home/claude/kf
python3 export_godot.py > export15n.log 2>&1 || { echo NIGHT_FAIL >> $L; exit 1; }
python3 denoise_lm.py -- /home/claude/rules/assets/lightmap.exr >> export15n.log 2>&1
echo "== dusk $(date +%T)" >> $L
python3 export_dusk.py > export15d.log 2>&1 || { echo DUSK_FAIL >> $L; exit 1; }
python3 denoise_lm.py -- /home/claude/rules/assets/dusk/lightmap.exr >> export15d.log 2>&1
echo "== godot $(date +%T)" >> $L
cd /home/claude/rules
G=/home/claude/godot/Godot_v4.4.1-stable_linux.x86_64
$G --headless --path . --import > /dev/null 2>&1
for f in $(grep -l "size_limit=0" assets/*.import assets/dusk/*.import assets/faces/*.import | grep -v exr); do sed -i 's/size_limit=0/size_limit=2048/' $f; done
$G --headless --path . --import > /dev/null 2>&1
xvfb-run -a -s "-screen 0 960x540x24" $G --path . --windowed --resolution 960x540 -- --bake-gi --scene=night > /dev/null 2>&1
xvfb-run -a -s "-screen 0 960x540x24" $G --path . --windowed --resolution 960x540 -- --bake-gi --scene=dusk > /dev/null 2>&1
sed -i 's#../build/RULES_proto14/RULES.exe#../build/RULES_proto15/RULES.exe#' export_presets.cfg
rm -rf /home/claude/build/RULES_proto15; mkdir -p /home/claude/build/RULES_proto15
echo "== export $(date +%T)" >> $L
$G --headless --path . --export-release "Windows Desktop" ../build/RULES_proto15/RULES.exe > /home/claude/kf/export15w.log 2>&1
ls -la /home/claude/build/RULES_proto15 >> $L
echo "== DONE $(date +%T)" >> $L
python3 /tmp/claude-0/-home-claude/6407adc7-bdf3-5700-ba20-4629ee47fbe1/scratchpad/chk2.py /home/claude/build/RULES_proto15/RULES.pck p15 >> $L 2>&1; echo "== SHEET $(date +%T)" >> $L
