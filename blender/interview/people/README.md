# インタビューの二人の作り方（2026-11-16）

tripo/interview/ の GLB はここの手順で作った物。作り直すときだけ使う（ゲームの書き出しには要らない）。
作業の置き場所は WORK/kikite（paths.env の WORK。スクリプトの中のパスは /home/claude/work/kikite のまま）。

1. 聞き手：`prep_kikite.py`（gen_prep.py が作る）で Tripo の頭と体（ユーザーの Tripo、/mnt/project-files/インタビュー/tripo/kikite_*_plain.glb）をつなぐ。
2. `KEY=kikite python rig.py` / `KEY=mio python rig.py`：game_engine の骨、手首から先を MakeHuman の手に差し替え、袖口の掃除。
   澪は顎の線（顔の絵の輪郭）と首のつなぎ目の段も直す（NOTES 2026-11-16）。
3. `KEY=kikite python pose.py -- 0.88 8 <形> kikite_<形>.blend`（形：seiza・pinch・stroke・write）、
   `KEY=mio python pose.py -- 0.88 8 lap mio_seiza.blend`。
4. 形を焼いて GLB に：`python pose2glb.py -- <blend> <kikite|mio> <out.glb>`（手続きの肌は export_godot.bake_object で画像に）。
