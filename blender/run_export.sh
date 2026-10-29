#!/bin/bash
set -o pipefail
cd /home/claude/kf
L=/home/claude/kf/export9.log
echo "== night $(date +%T)" > $L
python3 export_godot.py >> $L 2>&1 || { echo NIGHT_FAIL >> $L; exit 1; }
python3 denoise_lm.py -- /home/claude/rules/assets/lightmap.exr >> $L 2>&1
echo "== dusk $(date +%T)" >> $L
python3 export_dusk.py >> $L 2>&1 || { echo DUSK_FAIL >> $L; exit 1; }
python3 denoise_lm.py -- /home/claude/rules/assets/dusk/lightmap.exr >> $L 2>&1
echo "== godot import $(date +%T)" >> $L
cd /home/claude/rules && G=/home/claude/godot/Godot_v4.4.1-stable_linux.x86_64
$G --headless --path . --import >> $L 2>&1
echo "== bake $(date +%T)" >> $L
xvfb-run -a -s "-screen 0 960x540x24" $G --path . --windowed --resolution 960x540 -- --bake-gi --scene=night >> $L 2>&1
xvfb-run -a -s "-screen 0 960x540x24" $G --path . --windowed --resolution 960x540 -- --bake-gi --scene=dusk >> $L 2>&1
echo "== ALL_DONE $(date +%T)" >> $L
