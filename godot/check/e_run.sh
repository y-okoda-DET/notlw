#!/bin/bash
# ステップ E の場面（第0章など）を、書き出した pck に重ねて画面なしで動かし、コマを png に書く（main.gd に入口を足すまでの仮の入口）。
#   bash godot/check/e_run.sh ch0 <名前> [コマ数=0（最後まで）] [ほかの引数…]   → $WORK/e/<名前>/f_NNNNNNNN.png とログ
#   PCKDIR=<RULES.pck と RULES_house.pck のある所>（既定は試作97） RES=960x540 MFPS=6 TIME=t0430 NOOV=1（重ね直さない）
set -eu
. "$(dirname "$0")/../../blender/paths.sh"
D=$1; N=$2; Q=${3:-0}; shift; shift; [ $# -gt 0 ] && shift
PCKDIR=${PCKDIR:-$BUILD/p97/RULES_proto97}; RES=${RES:-960x540}; MFPS=${MFPS:-6}; TIME=${TIME:-t0430}
[ -z "${NOOV:-}" ] && bash "$(dirname "$0")/e_overlay.sh" >/dev/null
OUT=$WORK/e/$N; rm -rf $OUT; mkdir -p $OUT
QA=""; [ "$Q" != "0" ] && QA="--quit-after $Q"
cd /tmp && xvfb-run -a -s "-screen 0 ${RES}x24" $GODOT --path $WORK/overlay --windowed --resolution $RES --write-movie $OUT/f_.png --fixed-fps $MFPS $QA -- \
  --basepack=$PCKDIR/RULES.pck --housepack=$PCKDIR/RULES_house.pck --scene=house --time=$TIME --nocard --gi=baked --lite=${LITE:-t} --mfps=$MFPS --d=$D --ch0only "$@" > $OUT/log.txt 2>&1 || true
grep -a "STORY\|DEMO\|SAY\|SCRIPT ERROR\|ERROR\|Parse Error" $OUT/log.txt | grep -av "invalid UID" | head -60
ls $OUT | grep -c png
