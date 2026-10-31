# ルールズ（仮題）作業リポジトリ

企画書（正本）: docs/企画書.md
作品の中身（物語・章・ロードマップ・間取りの意図）は企画書が正本。ユーザーが決めた進め方と制作上の決定は docs/決定事項.md、次の作業は docs/次の作業.md（企画書「現在の状態と次の作業」の要約）。Claude への指示は docs/プロジェクトの指示.md。

## 中身
- `blender/` … Blender（bpy, 5.2）で家・人物・光を組み、Godot に書き出すスクリプト
  - `export_godot.py` 第2章 23時（夜）を書き出す / `export_dusk.py` 第1章 夕方を書き出す
  - `chars.py` 人物（`make_tripo()` が Tripo のモデルに骨を付ける）、`lib.py` 共通部品、`hall.py`・`door.py` 家
- `tripo/` … Tripo（有料版 H3.1・多視点）で作った元モデル（`<人物>_body.glb` / `<人物>_head.glb`。夏希は `n2_*`）と、
  頭と体をつないで描いた顔を貼る準備スクリプト（`prep_<人物>.py` → `<人物>_prep.blend`）。`chars_cfg.json` が人物ごとの寸法
- `godot/` … Godot 4.4 の試作（`scripts/main.gd`、刷りは `shaders/riso2.gdshader`）
- `assets/` … 描いた顔の絵（`faces_style/`）、テクスチャ（`tex/`）、フォント
- `plan/` … 間取り図（v4）

## Tripo の入れ方（間違えやすい）
多視点の欄：前＝正面、**左＝顔が画面の左を向く横顔**、**右＝顔が画面の右を向く横顔**、裏面＝後ろ姿。逆にすると後頭部に顔ができる。
全身と頭は別々に生成。設定は H3.1・ウルトラメッシュ品質・テクスチャ4K・ライティング除去 ON。GLB・骨なしで書き出す。

## 入れていないもの
書き出した Windows 版と動画（作り直せるため）。無料版で作った夏希のモデル（公開扱い・商用不可のため）。

## 書き出したデータ（godot/assets）は入れていない
`godot/assets/`（家と人物の glb、ライトマップ、顔の差し替え画像）は Blender スクリプトから作り直せるので入れていない。作り直し方：
`bash blender/build.sh <試作の番号>`（SETUP.md の 6）
（パスはリポジトリの根の paths.env の1か所。別の PC では paths.local.env で上書きする。SETUP.md 5）

## 大きなファイルの扱い
Git LFS は使っていない（この作業環境から LFS の保存先に接続できないため）。Tripo の元モデル（1つ約60MB）は通常の git で入っている。
GitHub の上限は1ファイル100MBなので、それを超えるモデルは入れられない。
