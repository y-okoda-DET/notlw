#!/bin/bash
# 試作を1本作る：bash blender/build.sh 18
#   夜・夕方を書き出し（光の焼き込みあり）→ Godot 取り込み（テクスチャ 2048 に制限）→ VoxelGI の焼き込み →
#   Windows 版 → はじめにNN.txt を入れて zip。所要約45分。必ず run_in_background と長い timeout で走らせ、
#   終わったら /home/claude/work/buildNN.log の最後が "== DONE" か、途中に "_FAIL" がないかを見る。
#   はじめにNN.txt は先に /home/claude/build/hajimeniNN.txt として書いておく（前の版を写して「前回からの変更」を書き換える）。
set -u
N=$1; W=/home/claude/work; mkdir -p $W /home/claude/build; L=$W/build$N.log
G=/home/claude/godot/Godot_v4.4.1-stable_linux.x86_64
echo "== night $(date +%T)" > $L
cd /home/claude/kf
python3 export_godot.py > $W/export${N}n.log 2>&1 || { echo NIGHT_FAIL >> $L; exit 1; }
python3 denoise_lm.py -- /home/claude/rules/assets/lightmap.exr >> $W/export${N}n.log 2>&1
echo "== dusk $(date +%T)" >> $L
python3 export_dusk.py > $W/export${N}d.log 2>&1 || { echo DUSK_FAIL >> $L; exit 1; }
python3 denoise_lm.py -- /home/claude/rules/assets/dusk/lightmap.exr >> $W/export${N}d.log 2>&1
echo "== godot $(date +%T)" >> $L
cd /home/claude/rules
$G --headless --path . --import > /dev/null 2>&1
for f in $(grep -l "size_limit=0" assets/*.import assets/dusk/*.import assets/faces/*.import | grep -v exr); do sed -i 's/size_limit=0/size_limit=2048/' $f; done
$G --headless --path . --import > /dev/null 2>&1
xvfb-run -a -s "-screen 0 960x540x24" $G --path . --windowed --resolution 960x540 -- --bake-gi --scene=night > /dev/null 2>&1
xvfb-run -a -s "-screen 0 960x540x24" $G --path . --windowed --resolution 960x540 -- --bake-gi --scene=dusk > /dev/null 2>&1
sed -i -E "s#RULES_proto[0-9]+/RULES.exe#RULES_proto$N/RULES.exe#" export_presets.cfg
D=/home/claude/build/RULES_proto$N; rm -rf $D; mkdir -p $D
echo "== export $(date +%T)" >> $L
$G --headless --path . --export-release "Windows Desktop" $D/RULES.exe > $W/export${N}w.log 2>&1
[ -f $D/RULES.pck ] || { echo EXPORT_FAIL >> $L; exit 1; }
if [ -f /home/claude/build/hajimeni$N.txt ]; then cp /home/claude/build/hajimeni$N.txt $D/はじめに.txt; else echo "NO_HAJIMENI (zip にはじめにが入っていない)" >> $L; fi
cd /home/claude/build && rm -f RULES_proto$N.zip && zip -qr RULES_proto$N.zip RULES_proto$N
ls -la $D /home/claude/build/RULES_proto$N.zip >> $L
S=$(stat -c %s /home/claude/build/RULES_proto$N.zip); [ $S -gt 419430400 ] && echo "ZIP_OVER_400MiB $S" >> $L
echo "== DONE $(date +%T)" >> $L
