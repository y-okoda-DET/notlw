## Mio. First person, slow and careful. The view rides on her footsteps:
## each footfall drops the eye a little and lands with a short settle, the body sways toward the planted foot,
## and stopping takes a step to come to rest. Nothing glides.
extends CharacterBody3D

@export var walk_speed := 1.05
@export var eye_height := 1.52
@export var mouse_sens := 0.0022
@export var step_length := 0.62        # metres per step
@export var bob_drop := 0.026          # eye drop at footfall
@export var sway := 0.014              # lateral shift toward the planted foot
@export var roll_deg := 0.55

var yaw := 0.0
var pitch := 0.0
var step_phase := 0.0                  # 0..1 per step
var step_amp := 0.0                    # 0 standing .. 1 walking, follows speed with lag
var settle := 0.0                      # decaying impulse after each footfall
var foot := 1.0
var stepped_camera := true             # kept for old callers
var cam_mode := 1                      # 0: 12 updates/s  1: 18/s  2: 12/s with a short slide between  3: smooth
const CAM_MODES := ["12コマ", "18コマ", "12コマ＋すべり", "なめらか"]
var _slide_from := Transform3D()
var _slide_t := 1.0
var _cam_accum := 0.0
var _held_tf := Transform3D()
var fly := false                       # --noclip: hold the height, ignore gravity
var auto_path: Array = []              # for unattended recordings: [[t, x, z, yaw_deg, pitch_deg], ...]
var auto_t := 0.0
var input_enabled := true

@onready var head: Node3D = $Head
@onready var cam: Camera3D = $Head/Camera

func _ready():
	head.position.y = eye_height

func _unhandled_input(e):
	if not input_enabled: return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * mouse_sens
		pitch = clamp(pitch - e.relative.y * mouse_sens, -1.2, 1.2)
	elif e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(dt):
	var dir := Vector3.ZERO
	if auto_path.size() > 0:
		auto_t += dt
		var a = _sample_path(auto_t)
		var target := Vector3(a[0], global_position.y, a[1])
		var to := target - global_position
		to.y = 0
		dir = to / max(dt * walk_speed, 0.0001) / 1.0
		if dir.length() > 1.0: dir = dir.normalized()
		if to.length() < 0.004: dir = Vector3.ZERO
		yaw = deg_to_rad(a[2]); pitch = deg_to_rad(a[3])
	elif input_enabled:
		var f := Input.get_axis("ui_down", "ui_up") + (1.0 if Input.is_key_pressed(KEY_W) else 0.0) - (1.0 if Input.is_key_pressed(KEY_S) else 0.0)
		var s := Input.get_axis("ui_left", "ui_right") + (1.0 if Input.is_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) else 0.0)
		var basis := Basis(Vector3.UP, yaw)
		dir = basis * Vector3(s, 0, -f)
		if dir.length() > 1.0: dir = dir.normalized()
	var vel := dir * walk_speed
	velocity.x = lerp(velocity.x, vel.x, 1.0 - exp(-dt * 9.0))
	velocity.z = lerp(velocity.z, vel.z, 1.0 - exp(-dt * 9.0))
	if fly: velocity.y = 0.0
	elif not is_on_floor(): velocity.y -= 9.8 * dt
	else: velocity.y = -0.1
	move_and_slide()
	_steps(dt)

func _sample_path(t: float) -> Array:
	var p = auto_path
	if t <= p[0][0]: return [p[0][1], p[0][2], p[0][3], p[0][4]]
	for i in range(p.size() - 1):
		if t < p[i + 1][0]:
			var u = (t - p[i][0]) / (p[i + 1][0] - p[i][0])
			u = u * u * (3.0 - 2.0 * u)
			return [lerp(p[i][1], p[i + 1][1], u), lerp(p[i][2], p[i + 1][2], u), lerp(p[i][3], p[i + 1][3], u), lerp(p[i][4], p[i + 1][4], u)]
	var l = p[p.size() - 1]
	return [l[1], l[2], l[3], l[4]]

func _steps(dt):
	var speed := Vector2(velocity.x, velocity.z).length()
	step_amp = lerp(step_amp, clamp(speed / walk_speed, 0.0, 1.0), 1.0 - exp(-dt * 5.0))
	var before := step_phase
	if speed > 0.05:
		step_phase += speed * dt / step_length
	elif step_phase > 0.0 and fmod(step_phase, 1.0) > 0.02:
		# finish the step you are in, then stand
		step_phase += dt * 1.6
		if floor(step_phase) > floor(before): step_phase = floor(step_phase)
	if floor(step_phase) > floor(before):
		settle = 1.0
		foot = -foot
	settle = max(0.0, settle - dt * 6.0)

	var ph: float = fmod(step_phase, 1.0)
	# eye height: rises through the stride, drops sharply at the footfall, small overshoot as the knee takes the weight
	var rise: float = sin(ph * PI)                          # 0 at footfall, 1 mid-stride
	var land: float = settle * settle
	var y: float = (rise - 0.5) * bob_drop * step_amp - land * bob_drop * 0.6 * step_amp
	var x: float = foot * sway * step_amp * (0.5 - abs(ph - 0.5)) * 2.0
	var rl: float = deg_to_rad(roll_deg) * foot * step_amp * sin(ph * PI)
	var nod: float = -land * 0.012 * step_amp
	# breathing, even when still
	var t := Time.get_ticks_msec() / 1000.0
	y += sin(t * 1.55) * 0.0035
	var target := Transform3D(Basis.from_euler(Vector3(pitch + nod, yaw, rl), EULER_ORDER_YXZ), Vector3(x * cos(yaw), eye_height + y, -x * sin(yaw)))
	if cam_mode == 3:
		head.transform = target
		_held_tf = target
	else:
		var rate: float = 18.0 if cam_mode == 1 else 12.0
		_cam_accum += dt
		if _cam_accum >= 1.0 / rate:
			_cam_accum = fmod(_cam_accum, 1.0 / rate)
			_slide_from = head.transform
			_held_tf = target
			_slide_t = 0.0
		if cam_mode == 2:
			_slide_t = min(1.0, _slide_t + dt / 0.035)
			var e: float = _slide_t * _slide_t * (3.0 - 2.0 * _slide_t)
			head.transform = _slide_from.interpolate_with(_held_tf, e)
		else:
			head.transform = _held_tf
