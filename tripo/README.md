# Tripo のモデルを人物にする手順

1. Tripo（Pro、H3.1、多視点）で全身と頭を別々に生成し、GLB・4K・骨なしで書き出す → `<人物>_body.glb`, `<人物>_head.glb`
   （多視点の欄：前＝正面、左＝顔が画面の左を向く横顔、右＝顔が画面の右を向く横顔、裏面＝後ろ姿）
2. 寸法を測る：`python3 ortho2.py -- <人物>_body.glb <tag> <カメラ高さ> <表示幅> <回転>` で正射投影の画を出し、
   体は「あごの線の高さ A_CHIN」「襟の上で切る高さ A_CUT」、頭は「あご B_CHIN」「目の高さ B_EYE_Z」「目の間隔 B_EYED」「ほおの肌色 cheek」を読む
   （単位は Tripo の元の寸法＝全高約0.98）。体が +Y を向いて出てきたら `rot180: true`。
   `hb` は Tripo の頭の、`hp` は描いた顔の絵の、目の線からの距離ごとの顔の半幅（目の間隔を1とする）。`blender/skinrows.py` と `masks_style.json` が絵の側の数値。
3. `chars_cfg.json` にその人物の項を足し、`python3 make_prep.py` で `prep_<人物>.py` を作る（夏希の `prep_natsuki.py` が雛形で、手で直すのはこれだけ。夏希の靴下版 `prep_natsuki_s.py` も make_prep.py が作る。雛形を直したら必ず make_prep.py を走らせ、全員の prep を1本ずつ走らせて、全員を4方向で見る）
4. `python3 prep_<人物>.py` → `<人物>_prep.blend`（頭と体をつなぎ、顔の正面を切り出して描いた顔を貼り、顔の絵を肌色に合わせた `<人物>_open/closed/talk.png` を出す）
5. `blender/chars.py` の `TRIPO` に人物名があれば `C.make_tripo('<人物>')` で骨付きの人物になる。確認は `t_rig.py` のように Blender で描くか、Godot に書き出す。

注意：描いた顔の絵は `assets/faces_style/<人物>_open.png` など。まばたきと口は Godot 側（main.gd `_faces`）で画像を差し替えて動かしている。
