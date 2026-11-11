#!/bin/bash
# ステップ D の場面を画面なしで動かして、コマを png に書く（6コマ／秒、外の杉なし）。
#   bash godot/check/d_run.sh fps|tape <名前> [コマ数=0（最後まで）] [ほかの引数…]   → $WORK/d/<名前>/f_NNNNNNNN.png とログ
#   PCKDIR=<RULES.pck と RULES_house.pck のある所> RES=960x540 MFPS=6
set -eu
. "$(dirname "$0")/../../blender/paths.sh"
D=$1; N=$2; Q=${3:-0}; shift; shift; [ $# -gt 0 ] && shift
PCKDIR=${PCKDIR:-$BUILD/p96/RULES_proto96}; RES=${RES:-960x540}; MFPS=${MFPS:-6}
OUT=$WORK/d/$N; rm -rf $OUT; mkdir -p $OUT
QA=""; [ "$Q" != "0" ] && QA="--quit-after $Q"
cd /tmp && xvfb-run -a -s "-screen 0 ${RES}x24" $GODOT --path $WORK/overlay --windowed --resolution $RES --write-movie $OUT/f_.png --fixed-fps $MFPS $QA -- \
  --basepack=$PCKDIR/RULES.pck --housepack=$PCKDIR/RULES_house.pck --scene=house --time=t0330 --nocard --gi=baked --lite=${LITE:-t} --mfps=$MFPS --d=$D "$@" > $OUT/log.txt 2>&1 || true
grep -a "STORY\|DEMO\|SAY\|SCRIPT ERROR\|ERROR\|Parse Error" $OUT/log.txt | grep -av "invalid UID" | head -60
ls $OUT | grep -c png
