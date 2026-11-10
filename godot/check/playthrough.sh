#!/bin/bash
# 遊びの流れの自動の通し：第1章の頭から、停電、発電機、ラジオ、窓の板、23時への切り替えまで（story.gd の --demo）。
#   bash godot/check/playthrough.sh <pck>          画面なしで通す（1分ほど）。最後の行が「通し ○」か「通し ×」
#   bash godot/check/playthrough.sh <pck> movie    同じ通しを動画にする（640x360、12コマ／秒。GPU なしで1時間前後）
#   OV=1 を付けると、pck の上にいまのリポジトリのスクリプトを重ねて通す（書き出し直す前の確認。overlay.sh）
#   出力：$WORK/check/通し.log（全部）、通し_台詞.txt（出た台詞を順に）、通し.mp4（movie のとき）
# × のときは、通し.log の DEMO FAIL の行に、どの手順で何ができなかったかが出る（歩いて行けない、手が届かない、話が進まない）。
set -u
. "$(dirname "$0")/../../blender/paths.sh"
P=$1; MODE=${2:-}; O=$WORK/check; mkdir -p $O; L=$O/通し.log
HP=$(dirname $P)/RULES_house.pck; [ -f "$HP" ] && HP="--housepack=$HP" || HP=
if [ -n "${OV:-}" ]; then bash "$(dirname "$0")/overlay.sh" > /dev/null; BASE="--path $WORK/overlay"; UA="--basepack=$P"; else BASE="--main-pack $P"; UA=; fi
cd /tmp
if [ "$MODE" = movie ]; then
  RES=${RES:-640x360}; rm -f $O/通し.avi
  timeout 14400 xvfb-run -a -s "-screen 0 ${RES}x24" $GODOT $BASE --windowed --resolution $RES --write-movie $O/通し.avi --fixed-fps 12 --quit-after ${FRAMES:-4700} -- $UA $HP --demo --mfps=12 > $L 2>&1
  ffmpeg -y -loglevel error -i $O/通し.avi -c:v libx264 -crf 23 -pix_fmt yuv420p $O/通し.mp4 && rm -f $O/通し.avi
else
  timeout 900 $GODOT $BASE --headless --fixed-fps 24 --quit-after 30000 -- $UA $HP --demo --demoquit --frameclock > $L 2>&1
fi
grep "^SAY " $L | sed 's/^SAY //' > $O/通し_台詞.txt
F=$(grep -c "DEMO FAIL" $L); E=$(grep -c "SCRIPT ERROR" $L)
if grep -q "DEMO DONE" $L && [ "$F" = 0 ] && [ "$E" = 0 ]; then echo "通し ○（$(grep -c . $O/通し_台詞.txt) 行、$(grep 'DEMO DONE' $L | sed 's/DEMO DONE //')）"; exit 0; fi
grep "DEMO FAIL\|SCRIPT ERROR" $L | head -20
echo "通し ×（最後まで行った：$(grep -q 'DEMO DONE' $L && echo はい || echo いいえ)、できなかった手順 $F、スクリプトのエラー $E）"; exit 1
