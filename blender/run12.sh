#!/bin/bash
L=/home/claude/kf/run12.log; echo "== preps $(date +%T)" > $L
cd /home/claude/tripo
for k in kiryu makoto natsuki natsuki_s; do timeout 3000 python3 prep_$k.py > p_$k.log 2>&1; echo "$k $(grep -c SAVED p_$k.log) $(date +%T)" >> $L; done
echo "== PREPS_DONE $(date +%T)" >> $L
sed -i 's/RULES_proto11/RULES_proto12/g; s#../build/RULES_proto10/RULES.exe#../build/RULES_proto11/RULES.exe#' /home/claude/kf/run10b.sh
/home/claude/kf/run10b.sh
sed -i 's#RULES_proto11/RULES.pck#RULES_proto12/RULES.pck#' /tmp/claude-0/-home-claude/6407adc7-bdf3-5700-ba20-4629ee47fbe1/scratchpad/chk.sh
/tmp/claude-0/-home-claude/6407adc7-bdf3-5700-ba20-4629ee47fbe1/scratchpad/chk.sh
echo "== CHK_DONE $(date +%T)" >> $L
