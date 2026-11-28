#!/bin/bash
# タイトル画面の動く版を書き出す：mov.sh <コマ数> <出力フォルダ>
set -u
N=$1; OUT=$2; mkdir -p $OUT; rm -f $OUT/f_*.png $OUT/f_.wav
P=/home/claude/pck298/RULES_proto298
cd /tmp && timeout 7000 xvfb-run -a -s "-screen 0 1920x1080x24" /home/claude/godot/Godot_v4.4.1-stable_linux.x86_64 --path /home/claude/work/ovt --windowed --resolution 1920x1080 \
  --write-movie $OUT/f_.png --fixed-fps 24 --quit-after $N -- --basepack=$P/RULES.pck --housepack=$P/RULES_house.pck \
  --record=poses --nocard --scene=house --time=dusk --gi=baked --print=1 --shotframes=2000 "--shots=6.070,-24.960,164.1,9.8,1.550,2.0,-2.290" --titlemov > $OUT/log.txt 2>&1
echo "frames $(ls $OUT/f_*.png | wc -l)"; grep -a "TITLEMOV\|SCRIPT ERROR" $OUT/log.txt | head
echo "== DONE"
