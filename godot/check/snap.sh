#!/bin/bash
# 自動の通しを画面つきで回し、決めた時刻の画を撮る（直す前と後を同じ所で並べるため）。撮らない間は 3D を描かない。
#   bash godot/check/snap.sh <pck のある所> <出力の名前> <snaps の txt>      → $WORK/snap/<名前>/*.png と log.txt
#   REV=<git の版> を付けると、その版のスクリプトを重ねる（直す前の画）。付けなければ、いまのリポジトリ。
#   snaps の書式は snap.gd の頭。初めは空の txt で回して、log.txt の SNAPCLK と台詞から秒を決める。
set -eu
. "$(dirname "$0")/../../blender/paths.sh"
PD=$1; N=$2; SN=$(realpath $3); RES=${RES:-960x540}
OUT=$WORK/snap/$N; rm -rf $OUT; mkdir -p $OUT
if [ -n "${REV:-}" ]; then
  T=$WORK/snap/src_$REV; rm -rf $T; git -C $REPO worktree add -f --detach $T $REV >/dev/null 2>&1
  WORK=$WORK/snap/w_$REV bash $T/godot/check/e_overlay.sh >/dev/null; O=$WORK/snap/w_$REV/overlay
  git -C $REPO worktree remove --force $T
else
  bash "$(dirname "$0")/e_overlay.sh" >/dev/null; O=$WORK/overlay
fi
cp "$(dirname "$0")/snap.gd" $O/snap.gd
python3 - "$O/boot.gd" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read()
if "snap.gd" not in s:
    s=s.rstrip("\n")+"\n\tif not has_node(\"/root/Snap\"):\n\t\tvar sn: Node = load(\"res://snap.gd\").new(); sn.name = \"Snap\"; get_tree().root.add_child.call_deferred(sn)\n"
open(p,'w').write(s)
PY
cd /tmp
timeout 7000 xvfb-run -a -s "-screen 0 ${RES}x24" $GODOT --path $O --windowed --resolution $RES --fixed-fps 24 --quit-after 40000 -- \
  --basepack=$PD/RULES.pck --housepack=$PD/RULES_house.pck --demo --demoquit --lite=${LITE:-t} --snaps=$SN --snapdir=$OUT > $OUT/log.txt 2>&1 || true
grep -a "SNAP \|DEMO FAIL\|SCRIPT ERROR" $OUT/log.txt | head -40; tail -2 $OUT/log.txt
