#!/bin/bash
# 証言 一〜三（scripts/interview.gd）を、書き出した pck にいまのリポジトリのスクリプトと assets/interview を重ねて確かめる。
#   bash godot/check/interview.sh <pck> run  1|2|3          画面なしで自動の通し（最後の行が「証言N ○／×」。IVARGS="--ivlie --ivflags=…" で嘘と記録つきの行）
#   bash godot/check/interview.sh <pck> shots 1|2|3         同じ通しを 2 コマ／秒で画にする（$WORK/iv/N/*.png、1920x1080）
#   bash godot/check/interview.sh <pck> stills <名前[@コマ][+手の形][+fist][+deck][+meishi][+tv=on|tape],…> [--print=0]   カットやカメラごとの静止画（$WORK/iv/stills/）
#   bash godot/check/interview.sh <pck> order               第6章の終わり（--ch6at=end）から：証言一 → 仮のカード → … → 第11章の頭まで並びを通す（1分）
# 先に python3 blender/interview/export_interview.py（godot/assets/interview/ を作る）。
set -u
. "$(dirname "$0")/../../blender/paths.sh"
P=$1; MODE=${2:-run}; N=${3:-1}; W=${4:-}
O=$WORK/overlay; S=$REPO/godot; L=$WORK/iv; mkdir -p $L
bash "$(dirname "$0")/overlay.sh" > /dev/null
mkdir -p $O/assets/interview; [ -d $S/assets/interview ] && cp -ru $S/assets/interview/. $O/assets/interview/
# 2026-11-20 第2稿：骨つきの二人（tripo/interview/*_rig.glb）、テレビ（props/crt_tv）。pck にまだ無い物を重ねる
cp -u $REPO/tripo/interview/*_rig.glb $O/assets/interview/ 2>/dev/null
mkdir -p $O/props; cp -u $S/props/crt_tv* $O/props/ 2>/dev/null; rm -f $O/props/*.import
[ -d $S/ui ] && mkdir -p $O/ui && cp $S/ui/iv_* $O/ui/ 2>/dev/null
$GODOT --headless --path $O --import > $L/import.log 2>&1 || true
HP="--housepack=$(dirname $P)/RULES_house.pck"
SL="${IVARGS:-}"   # 第2稿：IVARGS="--ivlie --ivflags=hands_cut,leaned,talked_kiryu_1am" で嘘の答えと記録つきの行を通す
cd /tmp
if [ "$MODE" = run ]; then
  timeout 900 $GODOT --path $O --headless --fixed-fps 24 --quit-after 60000 -- --basepack=$P $HP --play=i$N --demo --ivonly $SL > $L/run$N.log 2>&1
  grep "^SAY " $L/run$N.log | sed 's/^SAY //' > $L/台詞$N.txt
  E=$(grep -c "SCRIPT ERROR" $L/run$N.log)
  if grep -q "DEMO DONE interview $N fails=0" $L/run$N.log && [ "$E" = 0 ]; then echo "証言$N ○（$(grep -c . $L/台詞$N.txt) 行）"; else grep "SCRIPT ERROR\|ERROR" $L/run$N.log | head -20; echo "証言$N ×"; exit 1; fi
elif [ "$MODE" = shots ]; then
  rm -rf $L/$N; mkdir -p $L/$N
  timeout 7200 xvfb-run -a -s "-screen 0 1920x1080x24" $GODOT --path $O --windowed --resolution 1920x1080 --write-movie $L/$N/f.png --fixed-fps ${FPS:-2} --quit-after ${FRAMES:-600} -- --basepack=$P $HP --play=i$N --ivonly $SL ${DEMO:---demoslow} > $L/shots$N.log 2>&1
  ls $L/$N | wc -l
elif [ "$MODE" = stills ]; then   # stills <名前,名前…> [--print=0 など]：カットやカメラの名前ごとに1枚（$WORK/iv/stills/）
  mkdir -p $L/stills ${OUT:-$L/stills}
  timeout 1800 xvfb-run -a -s "-screen 0 1920x1080x24" $GODOT --path $O --windowed --resolution 1920x1080 -- --basepack=$P $HP --play=i${IV:-1} --ivstill=$N --ivout=${OUT:-$L/stills} $W > $L/stills.log 2>&1
  grep "SCRIPT ERROR" $L/stills.log; ls ${OUT:-$L/stills} | wc -l
elif [ "$MODE" = order ]; then
  timeout 1800 $GODOT --path $O --headless --fixed-fps 24 --quit-after 90000 -- --basepack=$P $HP --scene=house --time=t0430 --nocard --gi=baked --lite=t --play=ch6 --demo --ch6at=end --orderonly > $L/order.log 2>&1
  grep "^ORDER \|DEMO DONE\|SCRIPT ERROR" $L/order.log
fi
