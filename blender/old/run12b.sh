#!/bin/bash
L=/home/claude/kf/run12.log; echo "== night $(date +%T)" >> $L
cd /home/claude/kf
python3 export_godot.py > export10n.log 2>&1 || { echo NIGHT_FAIL >> $L; exit 1; }
python3 denoise_lm.py -- /home/claude/rules/assets/lightmap.exr >> export10n.log 2>&1
cd /home/claude/rules; G=/home/claude/godot/Godot_v4.4.1-stable_linux.x86_64
$G --headless --path . --import > /dev/null 2>&1
for f in $(grep -l "size_limit=0" assets/*.import assets/dusk/*.import | grep -v exr); do sed -i 's/size_limit=0/size_limit=2048/' $f; done
$G --headless --path . --import > /dev/null 2>&1
xvfb-run -a -s "-screen 0 960x540x24" $G --path . --windowed --resolution 960x540 -- --bake-gi --scene=night > /dev/null 2>&1
rm -rf /home/claude/build/RULES_proto12; mkdir -p /home/claude/build/RULES_proto12
$G --headless --path . --export-release "Windows Desktop" ../build/RULES_proto12/RULES.exe > /dev/null 2>&1
echo "== build $(date +%T)" >> $L
/tmp/claude-0/-home-claude/6407adc7-bdf3-5700-ba20-4629ee47fbe1/scratchpad/chk.sh
echo "== CHK_DONE $(date +%T)" >> $L
