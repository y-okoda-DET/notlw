#!/bin/bash
cd /home/claude/tripo
for k in makoto natsuki_s natsuki kiryu taiga; do timeout 3000 python3 prep_$k.py > p_$k.log 2>&1; echo "$k $(grep -c SAVED p_$k.log) $(date +%T)"; done
S=/tmp/claude-0/-home-claude/6407adc7-bdf3-5700-ba20-4629ee47fbe1/scratchpad
for a in "makoto_prep.blend $S/d_m makoto_head" "natsuki_s_prep.blend $S/d_n natsuki_s_head" "taiga_prep.blend $S/d_t taiga_head" "kiryu_prep.blend $S/d_k kiryu_head"; do set -- $a; timeout 600 python3 $S/chin.py $1 $2 $3 >/dev/null 2>&1; done
python3 -c "
from PIL import Image, ImageEnhance
S='$S'; o=Image.new('RGB',(1440,720))
for i,n in enumerate(['d_m','d_n','d_t','d_k']):
  for j,v in enumerate(['side','q']): o.paste(Image.open(f'{S}/{n}_{v}.png').convert('RGB'),(i*360,j*360))
ImageEnhance.Brightness(o).enhance(2.6).save(f'{S}/chin_after.png')"
echo PREPS_DONE $(date +%T)
/home/claude/kf/run15.sh; cat /home/claude/kf/run15.log
