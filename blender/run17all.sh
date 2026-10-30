#!/bin/bash
cd /home/claude/tripo
for k in makoto natsuki_s natsuki kiryu taiga; do timeout 1500 python3 prep_$k.py > p_$k.log 2>&1; echo "$k $(grep -c SAVED p_$k.log) $(grep 'neck skin polys' p_$k.log) $(date +%T)"; done
for k in makoto natsuki_s kiryu taiga; do timeout 600 python3 view4.py -- $k 1.33 >/dev/null 2>&1; done
python3 -c "
from PIL import Image
o=Image.new('RGB',(1800,1800))
for r,k in enumerate(['makoto','natsuki_s','kiryu','taiga']):
  for i,n in enumerate(['front','up','side','back']): o.paste(Image.open(f'v4_{k}_{n}.png').convert('RGB'),(i*450,r*450))
o.save('/home/claude/kf/v4all.png')"
echo PREPS_DONE $(date +%T)
/home/claude/kf/run17.sh; cat /home/claude/kf/run17.log
