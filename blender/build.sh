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
SCENES=${SCENES:-night dusk house}
[ -z "$FAST" ] && SCENES="night dusk house"   # 配布用はいつも全部（house：段階2の家まるごと、6つの時刻）
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
  python3 export_t20.py >> $W/export${N}d.log 2>&1 || { echo T20_FAIL >> $L; exit 1; }   # 試作91: the people of 第2章 at 20:00 (movement only)
fi
if [[ " $SCENES " == *" house "* ]]; then
  echo "== house $(date +%T)" >> $L
  python3 wear_tex.py > $W/wear${N}.log 2>&1   # 段階2 使い込みの跡の画像（godot/assets は git に入らない）
  FAST=$FAST python3 export_house.py > $W/export${N}h.log 2>&1 || { echo HOUSE_FAIL >> $L; exit 1; }
  grep -E "^lightmap .*(baked|hit)" $W/export${N}h.log | sed 's/^/  house /' >> $L
  for t in $(python3 -c "import times; print(' '.join(times.TIMES))"); do LM_IDS=$W/lm_ids_house.npy python3 denoise_lm.py -- $RULES/assets/house/$t/lightmap.exr >> $W/export${N}h.log 2>&1; done
fi
[ "$SCENES" != "night dusk house" ] && echo "  書き出さなかった場面は前回のまま（FAST だけ。送る前は FAST なしで両方）" >> $L
# 人体の構造の確認（顔・つま先の向き、ひじ・ひざの曲がる向き、前腕のねじれ）。NG なら止める
python3 anatomy.py > $W/anatomy${N}.log 2>&1; tail -1 $W/anatomy${N}.log >> $L
grep -q "^ANATOMY_OK" $W/anatomy${N}.log || { grep "NG" $W/anatomy${N}.log >> $L; echo ANATOMY_FAIL >> $L; exit 1; }
echo "== godot $(date +%T)" >> $L
cd $RULES
# glb から取り出された画像（env_<hash>_a/_n.png）のうち、今の env.glb が使わない古い物を消す（残すと pck に入る）
python3 - <<'PY'
import json, struct, os, glob
for d in ('assets', 'assets/dusk', 'assets/house'):
    g = d + '/env.glb'
    if not os.path.exists(g): continue
    b = open(g, 'rb').read(); n = struct.unpack('<I', b[12:16])[0]
    used = {i.get('name') for i in json.loads(b[20:20 + n]).get('images', [])}
    for f in glob.glob(d + '/env_*.png'):
        if os.path.basename(f)[4:-4] not in used:
            for x in (f, f + '.import'):
                if os.path.exists(x): os.remove(x)
PY
$G --headless --path . --import > /dev/null 2>&1
for f in $(grep -l "size_limit=0" assets/*.import assets/dusk/*.import assets/house/*.import assets/faces/*.import 2>/dev/null | grep -v exr); do sed -i 's/size_limit=0/size_limit=2048/' $f; done
# 家と外の画像は WebP の非可逆（品質 0.85）で持つ。可逆のままだと外の画像だけで zip の上限 400MiB を超える
for f in $(grep -l "compress/mode=0" assets/env_*.png.import assets/dusk/env_*.png.import assets/house/env_*.png.import 2>/dev/null); do sed -i 's/compress\/mode=0/compress\/mode=1/; s/compress\/lossy_quality=0.7/compress\/lossy_quality=0.85/' $f; done
# ライトマップ（EXR）は BC6H（VRAM 圧縮の HDR、高品質）で持つ。無圧縮だと家の6時刻だけで 300MB、夜の 4096 で 200MB あり、
# zip が上限の 400MiB を超えた（試作45）。なめらかな明るさだけの画なので BC6H にした（前後の見比べは NOTES.md）
for f in $(grep -l "compress/mode=0" assets/lightmap.exr.import assets/dusk/lightmap.exr.import assets/house/*/lightmap.exr.import 2>/dev/null); do sed -i 's/compress\/mode=0/compress\/mode=2/; s/compress\/high_quality=false/compress\/high_quality=true/' $f; done
$G --headless --path . --import > /dev/null 2>&1
# VoxelGI：焼くのは家（env）だけ。家・光・場面の設定・Godot のスクリプトとシェーダーが前回と同じなら前の gi.res を使う
GIS="night dusk"; [ -f assets/house/scene.json ] && GIS="$GIS $(cd $KF && python3 -c "import times; print(' '.join('house:' + t for t in times.TIMES))")"
for sc in $GIS; do
  A=assets; [ $sc = dusk ] && A=assets/dusk
  TM=""; if [[ $sc == house:* ]]; then TM=${sc#house:}; A=assets/house/$TM; fi
  SC=${sc%%:*}
  E=$A; [ -n "$TM" ] && E=assets/house
  K=$( { for f in $E/env.glb $A/lightmap.exr $A/lights.json $E/scene.json project.godot $(ls *.tscn scripts/*.gd shaders/* 2>/dev/null | sort); do sha256sum $f; done; $G --version; } | sha256sum | cut -c1-24)
  C=$W/cache/gi/${sc/:/-}-$K.res
  if [ -f $C ]; then cp $C $A/gi.res; echo "  $sc gi: cache hit $K" >> $L
  else
    timeout 1800 xvfb-run -a -s "-screen 0 960x540x24" $G --path . --windowed --resolution 960x540 -- --bake-gi --scene=$SC ${TM:+--time=$TM} > /dev/null 2>&1
    S=$(stat -c %s $A/gi.res 2>/dev/null || echo 0)
    if [ $S -gt 100000 ]; then mkdir -p $W/cache/gi; cp $A/gi.res $C; ls -t $W/cache/gi/${sc/:/-}-*.res | tail -n +5 | xargs -r rm; echo "  $sc gi: baked $K ($S bytes)" >> $L
    else echo "GI_FAIL $sc gi.res $S bytes (Vulkan がない？ SETUP.md 3)" >> $L; exit 1; fi
  fi
done
sed -i -E "s#RULES_proto[0-9]+/RULES.exe#RULES_proto$N/RULES.exe#" export_presets.cfg
D=$BUILD/RULES_proto$N; rm -rf $D; mkdir -p $D
echo "== export $(date +%T)" >> $L
# 配布の版（FAST なし）は pck を2つに分ける：本体（物語の場面）RULES.pck と、家まるごと RULES_house.pck（main.gd _house_pack）。
# 1つだと zip が 400MiB を超えた（試作54、526MiB。決定事項 2026-11-04）。FAST の確認用は1つのまま（house_shots.py・check.sh がそのまま使える）
SPLIT=; [ -z "$FAST" ] && [ -f assets/house/scene.json ] && SPLIT=1
python3 - "$SPLIT" <<'PY'
import sys, glob, re
split = sys.argv[1] == '1'
p = 'export_presets.cfg'; s = open(p).read()
s = re.sub(r'\n\[preset\.1\].*', '', s, flags=re.S).rstrip('\n') + '\n'
s = re.sub(r'exclude_filter="[^"]*"', 'exclude_filter="scripts/dbg*.gd' + (', assets/house/*' if split else '') + '"', s, count=1)
if split:
    files = sorted({f[:-7] for f in glob.glob('assets/house/**/*.import', recursive=True)} | set(glob.glob('assets/house/**/*.res', recursive=True)))
    s += ('\n[preset.1]\n\nname="House"\nplatform="Windows Desktop"\nrunnable=false\ndedicated_server=false\ncustom_features=""\n'
          'export_filter="resources"\nexport_files=PackedStringArray(' + ', '.join('"res://%s"' % f for f in files) + ')\n'
          'include_filter="assets/house/*.json"\nexclude_filter=""\nexport_path=""\nencryption_include_filters=""\nencryption_exclude_filters=""\n'
          'encrypt_pck=false\nencrypt_directory=false\n\n[preset.1.options]\n\ntexture_format/s3tc_bptc=true\ntexture_format/etc2_astc=false\n'
          'binary_format/architecture="x86_64"\n')
open(p, 'w').write(s)
PY
$G --headless --path . --export-release "Windows Desktop" $D/RULES.exe > $W/export${N}w.log 2>&1
[ -f $D/RULES.pck ] || { echo EXPORT_FAIL >> $L; exit 1; }
if [ -n "$SPLIT" ]; then
  $G --headless --path . --export-pack "House" $D/RULES_house.pck >> $W/export${N}w.log 2>&1
  [ -f $D/RULES_house.pck ] || { echo EXPORT_HOUSE_FAIL >> $L; exit 1; }
fi
if [ -n "$FAST" ]; then
  echo "FAST（確認用。配布しない。zip なし）" >> $L
else
  if [ -f $BUILD/hajimeni$N.txt ]; then cp $BUILD/hajimeni$N.txt $D/はじめに.txt; else echo "NO_HAJIMENI (zip にはじめにが入っていない)" >> $L; fi
  # zip も2つ：本体（RULES.exe・RULES.pck・はじめに）と家（RULES_house.pck）。同じフォルダに展開してもらう
  cd $BUILD && rm -f RULES_proto$N.zip RULES_proto${N}_house.zip
  zip -qr RULES_proto$N.zip RULES_proto$N -x "RULES_proto$N/RULES_house.pck"
  [ -f $D/RULES_house.pck ] && zip -qr RULES_proto${N}_house.zip RULES_proto$N/RULES_house.pck
  ls -la $D $BUILD/RULES_proto$N*.zip >> $L
  for z in $BUILD/RULES_proto$N.zip $BUILD/RULES_proto${N}_house.zip; do
    [ -f $z ] || continue; S=$(stat -c %s $z); [ $S -gt 419430400 ] && echo "ZIP_OVER_400MiB $z $S" >> $L
  done
fi
echo "== DONE $(date +%T)" >> $L
