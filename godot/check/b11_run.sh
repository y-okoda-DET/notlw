#!/bin/bash
# 第11章の最後のカット（試作260〜、A と B を並べる）。テープの終わり（end_t2=0）から SEC 秒を、音つきの AVI に撮る。
#   bash godot/check/b11_run.sh <名前> [ゲームへの引数…]   例：bash godot/check/b11_run.sh B --d11b
#   → $WORK/b11/<名前>/m.avi とログ。PCKDIR（既定 $WORK/pck231/RULES_proto231）RES=1280x720 MFPS=12 SEC=40 NOOV=1（重ね直さない）
set -eu
. "$(dirname "$0")/../../blender/paths.sh"
N=$1; shift
PCKDIR=${PCKDIR:-$WORK/pck231/RULES_proto231}; RES=${RES:-1280x720}; MFPS=${MFPS:-12}; SEC=${SEC:-40}
if [ -z "${NOOV:-}" ]; then
  bash "$(dirname "$0")/e_overlay.sh" >/dev/null
  mkdir -p $WORK/overlay/props/mio_face_states && cp $REPO/godot/props/mio_face_states/*.png $WORK/overlay/props/mio_face_states/
  cp $REPO/godot/sound/tv_off.wav $WORK/overlay/sound/ 2>/dev/null || true
  $GODOT --headless --path $WORK/overlay --import >/dev/null 2>&1 || true
fi
OUT=$WORK/b11/$N; rm -rf $OUT; mkdir -p $OUT
# the card (2.5 s at the start is skipped with --nocard4), a few frames to load, then SEC seconds
Q=$(( (SEC + 3) * MFPS ))
cd /tmp && xvfb-run -a -s "-screen 0 ${RES}x24" $GODOT --path $WORK/overlay --windowed --resolution $RES --write-movie $OUT/m.avi --fixed-fps $MFPS --quit-after $Q -- \
  --basepack=$PCKDIR/RULES.pck --housepack=$PCKDIR/RULES_house.pck --scene=house --time=t0330 --nocard --gi=baked --lite=t --mfps=$MFPS --play=ch11 --nocard4 --d11end "$@" > $OUT/log.txt 2>&1 || true
grep -a "STORY\|M220\|B11\|SCRIPT ERROR\|Parse Error" $OUT/log.txt | grep -av "invalid UID" | head -40
ls -la $OUT/m.avi
echo "== DONE $N"
