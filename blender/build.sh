#!/bin/bash
# 試作を1本作る：bash blender/build.sh 18
#   夜・夕方を書き出し（光の焼き込みあり）→ Godot 取り込み（テクスチャ 2048 に制限）→ VoxelGI の焼き込み →
#   Windows 版 → はじめにNN.txt を入れて zip。必ず run_in_background と長い timeout で走らせ、
#   終わったら $WORK/buildNN.log の最後が "== DONE" か、途中に "_FAIL" がないかを見る。
#   はじめにNN.txt は先に $BUILD/hajimeniNN.txt として書いておく（前の版を写して「前回からの変更」を書き換える）。
#
# 変わった所だけ作り直す（docs/手順_作り直し.md）：
#   光の焼き込み（Cycles）と VoxelGI の焼き込みは、焼く直前の中身のハッシュが前回と同じなら前の結果を使う
#   （$WORK/cache）。ログに「cache hit」と出る。中身が1つでも違えば焼き直すので、配布用にもそのまま使える。
#   FAST=1 bash blender/build.sh 18 … 確認用の速い書き出し。人物や光だけが変わったときは、同じ形の家で焼いた
#     前の光を使う（ログに LM_STALE。配布しない）。zip は作らない。ユーザーが OK を出したら FAST なしで作り直す。
#   FAST=1 SCENES=night … 直した場面だけ書き出す（もう片方は前回の書き出しのまま）。chars.py や prep のように
#     両方の場面に効く直しでは使わない。
#   途中で止まったときは、同じコマンドをもう一度走らせれば、焼き込みは済んだ所から使い回される。
set -u
. "$(dirname "$0")/paths.sh"
N=$1; FAST=${FAST:-}; W=$WORK; mkdir -p $W $BUILD; L=$W/build$N.log
G=$GODOT
SCENES=${SCENES:-night dusk}
[ -z "$FAST" ] && SCENES="night dusk"   # 配布用はいつも両方
echo "== start $(date +%T)${FAST:+ (FAST: $SCENES)}" > $L
cd $KF
if [[ " $SCENES " == *" night "* ]]; then
  echo "== night $(date +%T)" >> $L
  FAST=$FAST python3 export_godot.py > $W/export${N}n.log 2>&1 || { echo NIGHT_FAIL >> $L; exit 1; }
  grep -E "^lightmap|^LM_STALE" $W/export${N}n.log | sed 's/^/  night /' >> $L
  python3 denoise_lm.py -- $RULES/assets/lightmap.exr >> $W/export${N}n.log 2>&1
fi
if [[ " $SCENES " == *" dusk "* ]]; then
  echo "== dusk $(date +%T)" >> $L
  FAST=$FAST python3 export_dusk.py > $W/export${N}d.log 2>&1 || { echo DUSK_FAIL >> $L; exit 1; }
  grep -E "^lightmap|^LM_STALE" $W/export${N}d.log | sed 's/^/  dusk /' >> $L
  python3 denoise_lm.py -- $RULES/assets/dusk/lightmap.exr >> $W/export${N}d.log 2>&1
fi
[ "$SCENES" != "night dusk" ] && echo "  書き出さなかった場面は前回のまま（FAST だけ。送る前は FAST なしで両方）" >> $L
# 人体の構造の確認（顔・つま先の向き、ひじ・ひざの曲がる向き、前腕のねじれ）。NG なら止める
python3 anatomy.py > $W/anatomy${N}.log 2>&1; tail -1 $W/anatomy${N}.log >> $L
grep -q "^ANATOMY_OK" $W/anatomy${N}.log || { grep "NG" $W/anatomy${N}.log >> $L; echo ANATOMY_FAIL >> $L; exit 1; }
echo "== godot $(date +%T)" >> $L
cd $RULES
$G --headless --path . --import > /dev/null 2>&1
for f in $(grep -l "size_limit=0" assets/*.import assets/dusk/*.import assets/faces/*.import | grep -v exr); do sed -i 's/size_limit=0/size_limit=2048/' $f; done
$G --headless --path . --import > /dev/null 2>&1
# VoxelGI：焼くのは家（env）だけ。家・光・場面の設定・Godot のスクリプトとシェーダーが前回と同じなら前の gi.res を使う
for sc in night dusk; do
  A=assets; [ $sc = dusk ] && A=assets/dusk
  K=$( { for f in $A/env.glb $A/lightmap.exr $A/lights.json $A/scene.json project.godot $(ls *.tscn scripts/*.gd shaders/* 2>/dev/null | sort); do sha256sum $f; done; $G --version; } | sha256sum | cut -c1-24)
  C=$W/cache/gi/$sc-$K.res
  if [ -f $C ]; then cp $C $A/gi.res; echo "  $sc gi: cache hit $K" >> $L
  else
    xvfb-run -a -s "-screen 0 960x540x24" $G --path . --windowed --resolution 960x540 -- --bake-gi --scene=$sc > /dev/null 2>&1
    S=$(stat -c %s $A/gi.res 2>/dev/null || echo 0)
    if [ $S -gt 100000 ]; then mkdir -p $W/cache/gi; cp $A/gi.res $C; ls -t $W/cache/gi/$sc-*.res | tail -n +5 | xargs -r rm; echo "  $sc gi: baked $K ($S bytes)" >> $L
    else echo "GI_FAIL $sc gi.res $S bytes (Vulkan がない？ SETUP.md 3)" >> $L; exit 1; fi
  fi
done
sed -i -E "s#RULES_proto[0-9]+/RULES.exe#RULES_proto$N/RULES.exe#" export_presets.cfg
D=$BUILD/RULES_proto$N; rm -rf $D; mkdir -p $D
echo "== export $(date +%T)" >> $L
$G --headless --path . --export-release "Windows Desktop" $D/RULES.exe > $W/export${N}w.log 2>&1
[ -f $D/RULES.pck ] || { echo EXPORT_FAIL >> $L; exit 1; }
if [ -n "$FAST" ]; then
  echo "FAST（確認用。配布しない。zip なし）" >> $L
else
  if [ -f $BUILD/hajimeni$N.txt ]; then cp $BUILD/hajimeni$N.txt $D/はじめに.txt; else echo "NO_HAJIMENI (zip にはじめにが入っていない)" >> $L; fi
  cd $BUILD && rm -f RULES_proto$N.zip && zip -qr RULES_proto$N.zip RULES_proto$N
  ls -la $D $BUILD/RULES_proto$N.zip >> $L
  S=$(stat -c %s $BUILD/RULES_proto$N.zip); [ $S -gt 419430400 ] && echo "ZIP_OVER_400MiB $S" >> $L
fi
echo "== DONE $(date +%T)" >> $L
