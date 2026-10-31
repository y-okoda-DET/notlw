#!/bin/bash
# 使い方：bash blender/view4_glb.sh（書き出しのあと。$WORK/v4/v4_<人物>.png に正面・横・後ろ・横）
#   WHO="taiga dkiryu" で人物を絞る（d で始まるのは夕方）
# 4方向（Blender で glb を開いて。壁がないので全方向から見られる）
. "$(dirname "$0")/paths.sh"
mkdir -p $WORK/v4 && cd $WORK/v4
v() { # scene glb name x y z0 front
  python3 - "$@" <<'PY'
import sys, math
sc, glb, name, x, y, z0, f = sys.argv[1], sys.argv[2], sys.argv[3], *map(float, sys.argv[4:8])
cams = []
for a in (0, 90, 180, 270):
    t = math.radians(f + a); cams.append(f'{x + math.sin(t) * 2.2:.3f},{y - math.cos(t) * 2.2:.3f},{z0 + 1.3:.3f}')
print(f'{x},{y},{z0 + 1.0:.3f}', ';'.join(cams))
PY
}
for p in "night taiga.glb taiga .82 5.27 -.18 176" "night kiryu.glb kiryu -.32 4.02 0 -14" "night natsuki.glb natsuki .435 6.56 -.18 0" \
         "dusk dusk/taiga.glb dtaiga .82 6.47 -.18 -10" "dusk dusk/kiryu.glb dkiryu -.32 4.43 0 33" "dusk dusk/natsuki.glb dnatsuki .36 3.84 0 0" "dusk dusk/makoto.glb dmakoto 1.08 2.52 0 -151"; do
  set -- $p
  [ -n "${WHO:-}" ] && case " $WHO " in *" $3 "*) ;; *) continue;; esac
  read T CAMS < <(v $p)
  LENS=35 python3 $KF/glbview.py -- $RULES/assets/$2 49 $T "$CAMS" $WORK/v4/v4_$3 > /dev/null 2>&1
  python3 -c "
from PIL import Image; o=Image.new('RGB',(2000,500)); [o.paste(Image.open('$WORK/v4/v4_$3_%d.png'%i).convert('RGB'),(i*500,0)) for i in range(4)]; o.save('$WORK/v4/v4_$3.png')"
  echo "$3 ok"
done
echo V4_DONE
