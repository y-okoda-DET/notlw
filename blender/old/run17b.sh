#!/bin/bash
cd /home/claude/tripo
for k in makoto kiryu taiga; do timeout 1500 python3 prep_$k.py > p_$k.log 2>&1; echo "$k $(grep -c SAVED p_$k.log) $(grep 'neck skin polys' p_$k.log) $(date +%T)"; done
timeout 600 python3 view4.py -- makoto 1.33 >/dev/null 2>&1; timeout 600 python3 view4.py -- kiryu 1.5 >/dev/null 2>&1; timeout 600 python3 view4.py -- taiga 1.55 >/dev/null 2>&1
python3 -c "
from PIL import Image
o=Image.new('RGB',(1800,1350))
for r,k in enumerate(['makoto','kiryu','taiga']):
  for i,n in enumerate(['front','up','side','back']): o.paste(Image.open(f'v4_{k}_{n}.png').convert('RGB'),(i*450,r*450))
o.save('/home/claude/kf/v4b.png')"
echo PREPS_DONE $(date +%T)
/home/claude/kf/run17.sh; cat /home/claude/kf/run17.log
