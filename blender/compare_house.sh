#!/bin/bash
# 外観の見比べ（ログハウス／白い下見板張りの洋館風）：bash blender/compare_house.sh
#   夕方の場面を家の外まで含めて2通り書き出し、それぞれ pck にする（/home/claude/build/cmp_log.pck, cmp_siding.pck）。
#   書き出しは godot/assets/dusk を上書きするので、先に /home/claude/work/dusk_backup に退避し、最後に戻す。
#   所要約30分。run_in_background で走らせ、/home/claude/work/cmp/cmp.log の最後が "== CMP_DONE" か見る。
#   そのあと check.sh を、指摘の一覧に外観と廊下の2項目を書いて、GARGS=--noclip で回す（左＝ログハウス、右＝洋館風）。
set -u
W=/home/claude/work/cmp; mkdir -p $W; L=$W/cmp.log
G=/home/claude/godot/Godot_v4.4.1-stable_linux.x86_64
R=/home/claude/rules
echo "== start $(date +%T)" > $L
# STYLES="siding"：片方だけ。NORESTORE=1：退避と復元をしない（あとで build.sh で書き出し直すとき）
[ -n "${NORESTORE:-}" ] || [ -d /home/claude/work/dusk_backup ] || cp -a $R/assets/dusk /home/claude/work/dusk_backup
for st in ${STYLES:-log siding}; do
  echo "== $st export $(date +%T)" >> $L
  cd /home/claude/notlw/blender   # not the kf symlink: paths.py finds the repo from the script's own place
  HOUSE=$st EXT=1 python3 export_dusk.py > $W/export_$st.log 2>&1 || { echo "EXPORT_FAIL $st" >> $L; break; }
  python3 denoise_lm.py -- $R/assets/dusk/lightmap.exr >> $W/export_$st.log 2>&1
  cd $R
  $G --headless --path . --import > /dev/null 2>&1
  for f in $(grep -l "size_limit=0" assets/*.import assets/dusk/*.import assets/faces/*.import | grep -v exr); do sed -i 's/size_limit=0/size_limit=2048/' $f; done
  $G --headless --path . --import > /dev/null 2>&1
  xvfb-run -a -s "-screen 0 960x540x24" $G --path . --windowed --resolution 960x540 -- --bake-gi --scene=dusk > /dev/null 2>&1
  echo "== $st pck $(date +%T)" >> $L
  $G --headless --path . --export-pack "Windows Desktop" /home/claude/build/cmp_$st.pck > $W/pck_$st.log 2>&1
  ls -la /home/claude/build/cmp_$st.pck >> $L 2>&1 || echo "PCK_FAIL $st" >> $L
done
if [ -z "${NORESTORE:-}" ]; then
  echo "== restore $(date +%T)" >> $L
  rm -rf $R/assets/dusk && cp -a /home/claude/work/dusk_backup $R/assets/dusk
  cd $R && $G --headless --path . --import > /dev/null 2>&1
fi
echo "== CMP_DONE $(date +%T)" >> $L
