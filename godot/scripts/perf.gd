extends Node
# 重さ（2026-11-13、ユーザー「僕のPCではせめて滑らかに動いてほしい」）。ゲームの最初に1つだけ root に置き、場面が変わっても残る。
# 1) 重さの記録：場面ごとの1コマの時間を数え、10秒ごとに「重さの記録.txt」（書き出した版は RULES.exe の隣）を書き直す。
#    遊び終わったら、ユーザーがこのファイルを送る。
# 2) 画質の自動の切り替え：場面が始まって 4 秒たってから、3 秒の平均が 1コマ 22ms（45fps）より重ければ、画質を一段下げる。
#    高（今の画）→ 低（main._quality(false)：内部の解像度 0.6＋FSR、霧を粗く、影を軽く）→ 最低（解像度 0.5、霧なし）。
#    Q キーで自分で選んだら、自動は止まる。書き出した版だけで動く（確認の画は変わらない）。
const FILE := "重さの記録.txt"
const SLOW_MS := 22.0
var main: Node                      # the current main (it is made again at each scene change)
var where := ""
var segs := []                      # [{"where", "q", "n", "sum", "over33", "over50", "ms": [frame ms]}]
var cur: Dictionary = {}
var since_scene := 0.0
var win_sum := 0.0; var win_n := 0
var write_t := 0.0
var auto := true
var level := 2                      # 2 高, 1 低, 0 最低
var notes := []
var started := ""

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	started = Time.get_datetime_string_from_system(false, true)

func set_main(m: Node, w: String):
	main = m
	if w != where or cur.is_empty():
		where = w; cur = {"where": w, "q": level, "n": 0, "sum": 0.0, "over33": 0, "over50": 0, "ms": []}
		segs.append(cur)
	since_scene = 0.0; win_sum = 0.0; win_n = 0
	if level < 2: _apply(level)

func user_chose(high: bool):   # Q
	auto = false; level = 2 if high else 1
	notes.append("%s  Q キーで画質を%s に（自動の切り替えは止めた）" % [_clock(), "高" if high else "低"])

func _clock() -> String:
	var t := Time.get_ticks_msec() / 1000.0
	return "%d:%02d" % [int(t / 60.0), int(t) % 60]

var last_us := 0
func _process(_dt: float):
	var now := Time.get_ticks_usec()
	var ms := (now - last_us) / 1000.0 if last_us > 0 else 16.7   # the real time between frames (not the engine's delta)
	last_us = now
	var dt := ms / 1000.0
	since_scene += dt
	if not cur.is_empty() and since_scene > 1.5:   # the first frames of a scene are its loading, not its weight
		cur.n += 1; cur.sum += ms
		if ms > 33.4: cur.over33 += 1
		if ms > 50.0: cur.over50 += 1
		if (cur.ms as Array).size() < 60000: (cur.ms as Array).append(ms)
	if auto and level > 0 and since_scene > 4.0 and main and is_instance_valid(main):
		win_sum += ms; win_n += 1
		if win_n >= 90 or win_sum > 3000.0:
			var avg := win_sum / win_n
			if avg > SLOW_MS:
				level -= 1; _apply(level)
				notes.append("%s  %s：平均 %.1f ms で重いので、画質を自動で%s に" % [_clock(), where, avg, ["最低", "低", "高"][level]])
				cur = {"where": where, "q": level, "n": 0, "sum": 0.0, "over33": 0, "over50": 0, "ms": []}; segs.append(cur)
				since_scene = 2.0
			win_sum = 0.0; win_n = 0
	write_t += dt
	if write_t > 10.0: write_t = 0.0; write()

func _apply(l: int):
	if not (main and is_instance_valid(main)): return
	main._quality(l >= 2)
	if l == 0:
		get_viewport().scaling_3d_scale = 0.5
		if main.env: main.env.volumetric_fog_enabled = false

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE: write()

func write():
	if not is_inside_tree(): return
	var dir := OS.get_executable_path().get_base_dir() if OS.has_feature("template") else ProjectSettings.globalize_path("user://")
	var f := FileAccess.open(dir.path_join(FILE), FileAccess.WRITE)
	if f == null: return
	var vp := get_viewport()
	f.store_line("重さの記録（遊び終わったら、このファイルをチャットに送ってください）")
	f.store_line("始めた時刻 %s　遊んだ時間 %s" % [started, _clock()])
	f.store_line("CPU %s（%d スレッド）　GPU %s %s　%s" % [OS.get_processor_name(), OS.get_processor_count(), RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()])
	f.store_line("画面 %s　ウィンドウ %s　内部の解像度 %.2f　いまの画質 %s　自動の切り替え %s" % [DisplayServer.screen_get_size(), get_window().size, vp.scaling_3d_scale, ["最低", "低", "高"][level], "あり" if auto else "なし（Q キー）"])
	f.store_line("")
	f.store_line("場面\t画質\t秒\t平均fps\t平均ms\t遅い1%のms\t最も遅いms\t33msを超えたコマ\t50msを超えたコマ")
	for s in segs:
		if s.n < 10: continue
		var a: Array = (s.ms as Array).duplicate(); a.sort()
		var p99: float = a[int(a.size() * 0.99)] if a.size() > 0 else 0.0
		var mx: float = a[a.size() - 1] if a.size() > 0 else 0.0
		f.store_line("%s\t%s\t%.0f\t%.1f\t%.1f\t%.1f\t%.0f\t%d\t%d" % [s.where, ["最低", "低", "高"][s.q], s.sum / 1000.0, 1000.0 * s.n / maxf(s.sum, 1.0), s.sum / s.n, p99, mx, s.over33, s.over50])
	if not notes.is_empty():
		f.store_line("")
		for n in notes: f.store_line(n)
	f.close()
