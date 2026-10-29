#!/bin/bash
G=/home/claude/godot/Godot_v4.4.1-stable_linux.x86_64; P=/home/claude/build/RULES_proto12/RULES.pck
S=/tmp/claude-0/-home-claude/6407adc7-bdf3-5700-ba20-4629ee47fbe1/scratchpad; R=$S/chk; rm -rf $R; mkdir -p $R
NP=$(cat $S/night_poses.txt)
DP=$(cat $S/dusk_poses.txt)
cd /tmp
for pr in 0 1; do
 xvfb-run -a -s "-screen 0 960x540x24" $G --main-pack $P --windowed --resolution 960x540 --write-movie $R/n${pr}_.png --fixed-fps 24 -- --record=poses --nocard --scene=night --gi=baked --pexp=3.0 --print=$pr "--poses=$NP" > $R/n$pr.log 2>&1
 xvfb-run -a -s "-screen 0 960x540x24" $G --main-pack $P --windowed --resolution 960x540 --write-movie $R/d${pr}_.png --fixed-fps 24 -- --record=poses --nocard --scene=dusk --gi=baked --pexp=3.0 --print=$pr "--poses=$DP" > $R/d$pr.log 2>&1
done
echo CHK_DONE
