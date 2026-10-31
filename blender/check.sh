#!/bin/bash
# 確認を1本で：bash blender/check.sh <確認する pck> [<直す前の pck>] [<指摘の一覧>]
#   書き出しのあとに走らせる（run_in_background）。全部で約1時間。終わったら最後の行が CHECK_DONE か見る。
#   1. 人体の構造の自動確認（anatomy.py）。NG があっても止めずに最後まで撮り、一覧の先頭に出す
#   2. 4方向（Blender、人物だけ）
#   3. 指摘の項目：ユーザーの言葉と撮る位置を並べた一覧から、同じ位置を「直す前」「直した後」で撮って左右に並べる
#      （刷りあり＋刷りなし・確認用の光の2枚ずつ）。一覧の書き方は docs/手順_確認.md
#   4. 動き（夜・夕方、同じ位置から6時刻）
#   出力：/home/claude/work/check/ と、見る項目を並べた /home/claude/work/check/一覧.md（ここに○×を書いて確かめる）
set -u
AFTER=$1; BEFORE=${2:-}; ITEMS=${3:-}
K=/home/claude/notlw; O=/home/claude/work/check; L=$O/check.log
mkdir -p $O; rm -f $O/*.png
echo "== start $(date +%T)" > $L
M=$O/一覧.md
{
echo "# 確認の一覧（$(date '+%m/%d %H:%M')、$(basename $(dirname $AFTER))）"
echo
echo "各行に ○（問題なし）か ×（問題あり、何がどう）を書く。○ だけになるまでユーザーに送らない。"
echo
} > $M

# 1. 構造
echo "== anatomy $(date +%T)" >> $L
cd $K/blender && python3 anatomy.py > $O/anatomy.log 2>&1
R=$(tail -1 $O/anatomy.log); echo "$R" >> $L
{
echo "## 1. 人体の構造（自動）：$R"
grep "  NG" $O/anatomy.log | sed 's/^  NG /- [ ] NG：/'
echo
echo "## 2. 人体の構造（目で。4方向の画 v4_*.png で、人物ごとに）"
for p in taiga kiryu natsuki dtaiga dkiryu dnatsuki dmakoto; do
  echo "- [ ] $p：顔・胸・つま先・ひざ・ズボンの前が同じ向き／ひじ・ひざが逆に曲がっていない／前腕が棒のように回っていない（ひじ側は回らず、手首側でひねる）／肩・首・手首が人のできる角度／持ち物の向き（スマホの画面は本人へ）"
done
echo
} >> $M

# 2. 4方向
echo "== 4dir $(date +%T)" >> $L
bash $K/blender/view4_glb.sh >> $L 2>&1
cp /home/claude/work/v4/v4_*[a-z].png $O/ 2>/dev/null

# 3. 指摘の項目（直す前と後を同じ位置で）
echo "## 3. ユーザーの指摘（言葉はそのまま。直す前＝左、直した後＝右で、その点が変わったか）" >> $M
if [ -n "$ITEMS" ] && [ -f "$ITEMS" ]; then
  echo "== items $(date +%T)" >> $L
  n=0
  while IFS='|' read -r words args; do
    case "$words" in \#*|"") continue;; esac
    n=$((n + 1))   # numbered by the line in the list, so 指摘N matches the Nth remark
    if [ -z "${args// }" ] || [ "${args// }" = v4 ]; then echo "- [ ] 指摘$n「$words」 → v4_*.png（ゲームの中で撮れない位置。Blender の4方向で）" >> $M; continue; fi
    set -- $args; sc=$1; shift
    for mode in print raw; do
      for side in after before; do
        P=$AFTER; [ $side = before ] && P=$BEFORE
        [ -z "$P" ] && continue
        if [ $mode = print ]; then PCK=$P PRINT=1 python3 $K/godot/close.py $sc ck_${n}_${mode}_$side "$1" "$2" "$3" "$4" "${5:-0}" >> $L 2>&1
        else PCK=$P PRINT=0 python3 $K/godot/close.py $sc ck_${n}_${mode}_$side "$1" "$2" "$3" "$4" "${5:-0}" .2 >> $L 2>&1; fi
      done
      python3 - "$n" "$mode" "$words" <<'PY'
import sys, os
from PIL import Image, ImageDraw
n, mode, words = sys.argv[1:4]
W = '/home/claude/work'
a = f'{W}/close_ck_{n}_{mode}_after.png'; b = f'{W}/close_ck_{n}_{mode}_before.png'
ims = [Image.open(p).convert('RGB') for p in (b, a) if os.path.exists(p)]
o = Image.new('RGB', (sum(i.width for i in ims), max(i.height for i in ims)))
x = 0
for i in ims: o.paste(i, (x, 0)); x += i.width
o.save(f'{W}/check/指摘{n}_{"刷り" if mode == "print" else "刷りなし"}_左が前_右が後.png')
PY
    done
    echo "- [ ] 指摘$n「$words」 → 指摘${n}_*.png" >> $M
  done < "$ITEMS"
else
  echo "- （指摘の一覧なし）" >> $M
fi
echo >> $M

# 4. 動き
echo "== motion $(date +%T)" >> $L
for sc in night dusk; do PCK=$AFTER python3 $K/godot/motion.py $sc >> $L 2>&1; done
cp /home/claude/work/close_*_mv_*.png $O/ 2>/dev/null
{
echo "## 4. 動き（6時刻のどれか1枚でも崩れていれば ×）"
for f in $O/close_*_mv_*.png; do echo "- [ ] $(basename $f)：首（浮く・ねじれ・刺さる）／腕（袖口が開く・裂ける・ひじの折れ）／手（指が抜ける・手首の折れ）"; done
echo
echo "## 5. 送る前"
echo "- [ ] 独立レビュー（直したことを知らないエージェント）に、画像・参考写真・ユーザーの指摘の言葉・この一覧の 2 の項目を渡した"
echo "- [ ] レビューの指摘ごとに、問題とした／しないとその理由を書いた。見ていないものは「未確認」と書いた"
} >> $M
echo "== CHECK_DONE $(date +%T)" >> $L
echo CHECK_DONE
