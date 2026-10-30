# 作業環境の作り方（新しいチャット／新しい作業環境で最初にやること）

この作業環境（Linux、GPUなし）で確かめた手順。CPU とメモリは会話ごとに違う（2コア・7GB のことも、4コア・15GB のこともあった。`nproc; free -g` で見る）。
所要：1〜5 が約20分、6 が約40分（4コア・15GB で prep 5本 17分、build.sh 20分。2コアだと書き出しは約45分）。

## 0. リポジトリを取り込む
```
git clone --depth 1 https://github.com/y-okoda-DET/notlw /home/claude/notlw   # 約1.9GB。timeout は10分にする
```

## 1. Python ライブラリ
```
pip install --break-system-packages bpy==5.2.3 numpy scipy pillow fonttools matplotlib "opencv-python-headless<5"
```
`bpy` は Blender 5.2.3 を Python から使うための本体（約 400MB）。Python 3.13 が必要（bpy 5.2 の wheel は cp313 だけ）。
opencv（`import cv2`）は prep が顔の絵を変形するのに使う。入れ忘れると prep が全員、最後の数十秒で落ちる（2026-10-30 の検証で起きた）。
書き出しのログに出る `ERROR Draco is not available` `MeshOptimizer is not available` `CUEW initialization failed` は無害（使っていない）。

## 2. MakeHuman（MPFB2）……人物の骨組みの元
```
git clone https://github.com/makehumancommunity/mpfb2.git /home/claude/mh/mpfb2
git -C /home/claude/mh/mpfb2 checkout 6ff1eb3   # 使ったのはこの版
pip install --break-system-packages makehuman   # MakeHuman 1.3.x の wheel。MPFB2 が内部で使う
mkdir -p ~/.config/blender/5.2/extensions/user_default
ln -s /home/claude/mh/mpfb2/src/mpfb ~/.config/blender/5.2/extensions/user_default/mpfb
```
MPFB2 を Blender の拡張として入れている（`~` は /root のことが多い）。
`blender/chars.py` の `mpfb()` が `bl_ext.user_default.mpfb` として読み込む。
MakeHuman の体データ（base.obj とターゲット）は MPFB2 に同梱。

## 3. Godot 4.4.1
```
mkdir -p /home/claude/godot && cd /home/claude/godot
R=https://github.com/godotengine/godot/releases/download/4.4.1-stable
curl -fsSL -o g.zip $R/Godot_v4.4.1-stable_linux.x86_64.zip && unzip -o g.zip && chmod +x Godot_v4.4.1-stable_linux.x86_64
curl -fsSL -o t.tpz $R/Godot_v4.4.1-stable_export_templates.tpz     # 約1GB。中身は zip
mkdir -p ~/.local/share/godot/export_templates/4.4.1.stable
unzip -o t.tpz -d tt && mv tt/templates/* ~/.local/share/godot/export_templates/4.4.1.stable/ && rm -rf tt
```
画面なしで動かすので `xvfb-run` が必要。まとめて：`apt-get install -y xvfb ffmpeg zip fonts-noto-cjk fonts-noto-cjk-extra`。
**フォントは書き出しで必須**：hall.py の貼り紙（地下・発電機）が `NotoSansCJK-Medium.ttc` を使い、これは `fonts-noto-cjk-extra` にしか入っていない。ないと export_godot.py が落ちる。

### Godot の描画方式（必須：CPU で描く Vulkan を入れる）
`apt-get install -y mesa-vulkan-drivers`
前の作業環境（試作17まで）にはこれが入っていて、Godot は Vulkan（llvmpipe）の Forward+ で動いていた（起動時のログ：`Vulkan … Forward+ … llvmpipe`）。
VoxelGI の焼き込み（gi.res、約6MB）も、確認画（close.py）も、すべてこの状態で作った。
入れないと Godot は OpenGL（互換）に落ち、VoxelGI の焼き込みが空（約400バイト）のまま Windows 版に入る。確認画の見え方も変わる。
確かめ方：Godot の起動ログに `Forward+` と出ること、build のあと assets/gi.res と assets/dusk/gi.res が数MBあること。

## 4. フォント
Noto Serif CJK（`fonts-noto-cjk`）。`godot/fonts/SerifJP-Bold.otf` は使う文字だけ抜き出したもの。
文字を増やしたら `fonttools` で作り直す（リポジトリの根 /home/claude/notlw で実行する）:
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
ln -s /home/claude/notlw/plan    /home/claude/plan
mkdir -p /home/claude/kf/out /home/claude/build /home/claude/work /home/claude/rules_movie/st
```

## 6. 一通り動くか確かめる（合わせて約1時間。長い処理は run_in_background と長い timeout で走らせ、ログで終わりを確かめる）
```
cd /home/claude/tripo && python3 make_prep.py           # 雛形 prep_natsuki.py から各人物の prep_*.py（夏希の靴下版も）を作る
for k in makoto natsuki_s natsuki kiryu taiga; do python3 prep_$k.py > /home/claude/work/p_$k.log 2>&1; done   # 1本ずつ（同時だとメモリ不足）。各約2.5分
bash /home/claude/kf/build.sh 0                         # 試作0として書き出す（約45分）。ログ /home/claude/work/build0.log
```
3行はファイル（例：/home/claude/work/run0.sh）に書いて `run_in_background` で走らせる。prep の成否は各ログの最後が `SAVED` かで見る。
**途中で作業環境が再起動されたとき**：pip・apt・/home/claude 以下は残る。build0.log の最後の `==` の行で、どこまで進んだかを見る。
夜と夕方の書き出しが済んでいれば（`== godot` まで進んでいれば）、build.sh の `echo "== godot` 以降だけを別のファイルに写して走らせれば続きから作れる。
**できたと判定する基準**：build0.log の最後が `== DONE` で、`_FAIL` がない。/home/claude/build/RULES_proto0/RULES.pck があり、
`PCK=/home/claude/build/RULES_proto0/RULES.pck PRINT=1 python3 /home/claude/rules/close.py night chk -.33,3.72,1.3 .7 90 2.0 .2` で
桐生がスマホを持っている画（/home/claude/work/close_chk.png）が撮れる。
見え方（試作17の確認画はリポジトリにないので、言葉で書く）：真横から。右上に桐生の横顔（目を伏せて手元を見る）、画面の中ほどにスマホの画面が白く光る。
手と体は暗くて網点の中に沈む。手まで見たいときは網点なし＋確認用の光で同じ位置を撮る：末尾に ` .2` を足して `PRINT=0`。
正しければ、手のひらにスマホを乗せ、画面を見下ろしている。奥に大河が扉を押している（正面 az0 から撮ると見える）。
tripo/ の `*_prep.blend` と `*_headtex_*.png` は prep で作り直される。リポジトリには段階0（試作17）の時点のものを入れてある。

新しい試作は `bash /home/claude/kf/build.sh <番号>`。先に /home/claude/build/hajimeni<番号>.txt を書いておく（zip に「はじめに.txt」として入る）。
人物だけを直したときの速い確認：`SKIP_LM=1 python3 export_godot.py`（光の焼き込みを飛ばす。小道具が動いたら `ENV=1` も）→ Godot の取り込み → close.py。
close.py は書き出した pck から撮る（`PCK=...`）。pck がまだないときは pck なしでプロジェクトから撮れる（途中確認だけに使う。ユーザーに見せる画は pck から）。
確認画や作業ログは /home/claude/work に出す（リポジトリに入れない）。
