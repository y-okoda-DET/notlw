# 作業環境の作り方（新しいチャット／新しい作業環境で最初にやること）

この作業環境（Linux、GPUなし、CPU2コア、メモリ約7GB）で確かめた手順。所要 20〜40 分。

## 1. Python ライブラリ
```
pip install --break-system-packages bpy==5.2.3 numpy scipy pillow fonttools matplotlib
```
`bpy` は Blender 5.2.3 を Python から使うための本体（約 300MB）。

## 2. MakeHuman（MPFB2）……人物の骨組みの元
```
git clone https://github.com/makehumancommunity/mpfb2.git /home/claude/mh/mpfb2   # 使ったのは 6ff1eb3
pip install --break-system-packages makehuman   # MakeHuman 1.3.x の wheel。MPFB2 が内部で使う
```
MPFB2 を Blender の拡張として入れる：`/home/claude/mh/mpfb2/src/mpfb` を
`~/.config/blender/5.2/extensions/user_default/mpfb` にコピー（または symlink）する。
`blender/chars.py` の `mpfb()` が `bl_ext.user_default.mpfb` として読み込む。
MakeHuman の体データ（base.obj とターゲット）は MPFB2 に同梱。

## 3. Godot 4.4.1
```
mkdir -p /home/claude/godot && cd /home/claude/godot
# Godot_v4.4.1-stable_linux.x86_64 を GitHub の godotengine/godot の release から取得し、実行権限を付ける
# Windows 書き出し用テンプレート（Godot_v4.4.1-stable_export_templates.tpz）を取得し、
# 展開して ~/.local/share/godot/export_templates/4.4.1.stable/ に置く
```
画面なしで動かすので `xvfb-run` が必要（`apt install xvfb`）。動画の結合に `ffmpeg`、配布に `zip`。

## 4. フォント
Noto Serif CJK（`fonts-noto-cjk`）。`godot/fonts/SerifJP-Bold.otf` は使う文字だけ抜き出したもの。
文字を増やしたら `fonttools` で作り直す（main.gd の文字列から文字集合を取る。やり方はこのチャットの履歴ではなく、以下）:
```
python3 - <<'PY'
from fontTools.ttLib import TTCollection; from fontTools import subset; import re
tc=TTCollection('/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc')
f=[x for x in tc.fonts if 'JP' in x['name'].getDebugName(1)][0]
src=open('godot/scripts/main.gd').read()+open('godot/scripts/player.gd').read()
chars=set(''.join(re.findall(r'"([^"]*)"',src)))|set('0123456789.０１２３４５６７８９ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz　、。，．・：；？！ー（）「」『』／｜＋－＝ ')
o=subset.Options(); o.layout_features=['*']; o.name_IDs=['*']
s=subset.Subsetter(o); s.populate(text=''.join(chars)); s.subset(f); f.save('godot/fonts/SerifJP-Bold.otf')
PY
```

## 5. パス
スクリプトは `/home/claude/kf`（= このリポジトリの `blender/`）、`/home/claude/rules`（= `godot/`）、
`/home/claude/tripo`（= `tripo/`）、`/home/claude/assets`（= `assets/`）を決め打ちで参照している。
新しい環境では、リポジトリを `/home/claude/notlw` に置いたうえで symlink を張るのが一番早い：
```
ln -s /home/claude/notlw/blender /home/claude/kf
ln -s /home/claude/notlw/godot   /home/claude/rules
ln -s /home/claude/notlw/tripo   /home/claude/tripo
ln -s /home/claude/notlw/assets  /home/claude/assets
mkdir -p /home/claude/kf/out /home/claude/build /home/claude/rules_movie/st
```

## 6. 一通り動くか確かめる
```
cd /home/claude/tripo && python3 make_prep.py           # 雛形 prep_natsuki.py から各人物の prep_*.py を作る（雛形を直したら必ず実行）
for k in makoto natsuki_s natsuki kiryu taiga; do python3 prep_$k.py; done   # 1本ずつ（同時に走らせるとメモリ不足）
/home/claude/kf/run17.sh                                # 夜・夕方の書き出し→光の焼き込み→Godot取り込み→Windows版（約40分）
```
run17.sh の中の版の番号（RULES_proto17）と export_presets.cfg の書き出し先は、新しい試作のたびに変える。
人物だけを直したときは `SKIP_LM=1 python3 export_godot.py`（光の焼き込みを飛ばす。小道具が動いたら `ENV=1` も）。
確認画は godot/close.py（書き出した pck から、位置・方位・時刻を指定して撮る。`PCK=... PRINT=1` で網点あり）。
