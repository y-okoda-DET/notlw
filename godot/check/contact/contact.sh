#!/bin/bash
# 赤字用のコンタクトシートの画を撮る（2026-11-27）：自動の通し（--demo）を最後まで回し、カットの変わり目と3秒ごとに
# 実際の画面（字幕・カードもそのまま、1920x1080）を撮る。そのあと sheet.py で章ごとの PDF にする。
#   bash godot/check/contact/contact.sh <pck のフォルダ（RULES.pck・RULES_house.pck・RULES_iv.pck）> [名前] [ゲームへの引数…]
#   例：bash godot/check/contact/contact.sh $WORK/pck295/RULES_proto295 p295
#       python3 godot/check/contact/sheet.py $WORK/contact/p295 /mnt/project-files/コンタクトシート/試作295
#   出力：$WORK/contact/<名前>/0000.png …、shots.tsv、ログは $WORK/contact/<名前>.log（最後に == DONE）
#   CEVERY=3（秒ごと）、RES=1920x1080、TMO（秒、既定 4時間）
# pck のスクリプトをいまのリポジトリの物で重ねる（overlay.sh）。pck を書き出した版のリポジトリで回すこと（ずれると画が変わる）。
set -u
. "$(dirname "$0")/../../../blender/paths.sh"
P=$(realpath $1); N=${2:-contact}; shift 2 || shift $#
OUT=$WORK/contact/$N; mkdir -p $OUT; rm -f $OUT/*.png $OUT/shots.tsv
bash $REPO/godot/check/overlay.sh > /dev/null
O=$WORK/overlay
cp $REPO/godot/check/contact/contact.gd $O/contact.gd
python3 - "$O/boot.gd" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read()
if "contact.gd" not in s:
    s=s.rstrip("\n")+"\n\tif not get_tree().root.has_node(\"Contact\") and \" \".join(OS.get_cmdline_user_args()).contains(\"--contact=\"):\n\t\tvar cn: Node = load(\"res://contact.gd\").new(); cn.name = \"Contact\"; get_tree().root.add_child.call_deferred(cn)\n"
open(p,'w').write(s)
PY
cd /tmp
timeout ${TMO:-14400} xvfb-run -a -s "-screen 0 ${RES:-1920x1080}x24" $GODOT --path $O --windowed --resolution ${RES:-1920x1080} --fixed-fps 24 --quit-after ${QA:-90000} -- \
  --basepack=$P/RULES.pck --housepack=$P/RULES_house.pck --demo --demoquit --frameclock --contact=$OUT --cevery=${CEVERY:-3} "$@" > $WORK/contact/$N.log 2>&1
echo "撮った枚数 $(ls $OUT/*.png 2>/dev/null | wc -l)、通しの最後：$(grep -a 'DEMO DONE' $WORK/contact/$N.log | tail -1)、エラー $(grep -ac 'SCRIPT ERROR' $WORK/contact/$N.log)"
echo "== DONE $N"
