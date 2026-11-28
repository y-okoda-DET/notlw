# タイトル画面の動く版（確認用の映像を撮るため。ゲームの本体ではない）：夕方の家の前でカメラがゆっくり寄り、
# ロゴと項目が出て、選ぶ印が動く。画の層は tm/ の PNG（layers.py）。
extends Node
const START := Vector3(6.070, -2.290 + 1.55, -24.960)
const YAW := 164.1
const PITCH0 := 9.8
const PUSH := 1.8          # m toward the house over the clip
const LEN := 18.0
const ORANGE := Color(0.91, 0.46, 0.27)
var cam: Camera3D
var t := 0.0
var cover: ColorRect; var logo: TextureRect; var veil: TextureRect
var items := []; var info := []; var mark: ColorRect
var sel := 0; var sel_y := 0.0; var sel_x := 0.0
var main: Node
var started := false
var plan := [[7.0, 1], [9.0, 2], [11.0, 3], [13.6, 0]]

func _tex(p: String) -> ImageTexture:
	return ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://tm/" + p)))

func _ready():
	var cl := CanvasLayer.new(); cl.layer = 100; add_child(cl)
	veil = TextureRect.new(); veil.texture = _tex("veil.png"); cl.add_child(veil); veil.modulate.a = 0.0
	logo = TextureRect.new(); logo.texture = _tex("logo.png"); cl.add_child(logo); logo.modulate.a = 0.0
	for l in FileAccess.get_file_as_string("res://tm/items.txt").split("\n"):
		var p := l.split(" "); info.append([float(p[0]), float(p[1]), float(p[2])])
	for i in 4:
		var r := TextureRect.new(); r.texture = _tex("item%d.png" % i); r.position = Vector2(info[i][0], info[i][1]); cl.add_child(r)
		r.modulate.a = 0.0; items.append(r)
	mark = ColorRect.new(); mark.color = ORANGE; mark.size = Vector2(24, 6); mark.modulate.a = 0.0; cl.add_child(mark)
	sel_y = info[0][1]; sel_x = info[0][0]
	cover = ColorRect.new(); cover.color = Color(0.03, 0.13, 0.14, 1.0); cover.set_anchors_preset(Control.PRESET_FULL_RECT); cl.add_child(cover)

func _snd(n: String, db: float, loop := false):
	var p := AudioStreamPlayer.new(); p.stream = load("res://sound/" + n); p.volume_db = db; add_child(p); p.play()
	if loop: p.finished.connect(p.play)

func _process(dt):
	if not started:
		main = get_tree().root.find_child("Main", true, false)
		var vp_cam := get_viewport().get_camera_3d()
		if vp_cam == null: return
		cam = Camera3D.new(); cam.fov = vp_cam.fov; cam.near = vp_cam.near; cam.far = vp_cam.far
		get_tree().root.add_child(cam); started = true
		_snd("dusk_amb.wav", -6.0, true); _snd("ch8_wind.ogg", -16.0, true)
		print("TITLEMOV start fov ", cam.fov)
	t += dt
	var k := clampf(t / LEN, 0.0, 1.0); k = k * k * (3.0 - 2.0 * k) * 0.7 + k * 0.3
	var b := Basis.from_euler(Vector3(deg_to_rad(PITCH0 - 1.2 * k), deg_to_rad(YAW), 0.0), EULER_ORDER_YXZ)
	var fwd := -b.z; fwd.y = 0.0; fwd = fwd.normalized()
	# a held camera: a breath of sway, no steps
	var sway := Vector3(sin(t * 0.37) * 0.012, sin(t * 0.53 + 1.0) * 0.008, 0.0)
	cam.global_transform = Transform3D(b * Basis(Vector3.FORWARD, sin(t * 0.29) * 0.002), START + fwd * PUSH * k + sway)
	cam.make_current()
	cover.modulate.a = clampf(1.0 - t / 1.6, 0.0, 1.0)
	veil.modulate.a = clampf((t - 0.3) / 1.5, 0.0, 1.0)
	if t >= 1.6 and logo.modulate.a == 0.0: _snd("hit.wav", -10.0)
	logo.modulate.a = clampf((t - 1.6) / 0.12, 0.0, 1.0)
	var mk := clampf((t - 2.8) / 0.8, 0.0, 1.0)
	for p in plan:
		if t >= p[0] and t - dt < p[0]: sel = p[1]; _snd("dial_tick.wav", -8.0)
	sel_y = lerpf(sel_y, info[sel][1], 1.0 - exp(-dt * 18.0)); sel_x = lerpf(sel_x, info[sel][0], 1.0 - exp(-dt * 18.0))
	for i in 4:
		var want := 1.0 if i == sel else 0.59
		items[i].modulate.a = mk * lerpf(items[i].modulate.a / maxf(mk, 0.001) if mk > 0.01 else want, want, 1.0 - exp(-dt * 14.0))
	mark.position = Vector2(sel_x - 46, sel_y + 22); mark.modulate.a = mk
