extends Node3D
## Drainpipe Dash — game controller: level building, physics, hazards, camera, effects, audio, HUD.

const Track = preload("res://scripts/track.gd")
const Tex = preload("res://scripts/textures.gd")
const Synth = preload("res://scripts/audio_synth.gd")
const PostShader = preload("res://shaders/post.gdshader")
const WaterShader = preload("res://shaders/water.gdshader")
const BoostShader = preload("res://shaders/boost.gdshader")

const K := 5.0
const GRAV := 13.0
const JUMPV := 4.2
const MAXTH := 2.5
const MAXTH_HALL := 0.88
const CAMD := 1.35
const WA := 1.5 * TAU / 16.0
const SAVE_PATH := "user://save.json"

# Zone list per level: [type, material, length (tube units), radius scale]
# types: pipe (round), square (culvert), hall (open channel in a vault), planks (open wooden deck)
var LEVELS := [
	{"name": "Gearworks", "blurb": "Extraction fans, floating junk, S-bends", "speed": 7.5, "diff": 0, "seed": 11,
	 "zones": [["pipe", "brick", 70], ["pipe", "steel", 60], ["pipe", "brick", 50], ["hall", "brick", 50],
		["pipe", "steel", 70], ["pipe", "brick", 45], ["pipe", "steel", 60], ["pipe", "brick", 55],
		["hall", "brick", 45], ["pipe", "steel", 55], ["pipe", "brick", 45]],
	 "hazards": {"coins": 2.0, "fan": 2.0, "debris": 1.6, "scurve": 1.4, "low": 0.8, "side": 1.0, "gap": 0.6, "boost": 0.7, "slot": 0.4},
	 "ax": [6.0, 0.5], "kx": [0.035, 0.08], "px": [0.0, 1.3], "ay": 1.4, "ky": 0.06, "py": 0.5, "grade": 0.03,
	 "markers": true, "amb": "hum", "deck_drop": 6.0,
	 "pipe": Color(0.68, 0.67, 0.64), "deep": Color(0.045, 0.055, 0.06), "shallow": Color(0.17, 0.2, 0.21), "glow": 0.0,
	 "fog": Color(0.045, 0.05, 0.06), "sky": Color(0.0, 0.0, 0.0), "ambient": Color(0.22, 0.24, 0.27),
	 "lamp": Color(0.6, 0.72, 0.95), "wall": Color(0.62, 0.62, 0.62)},
	{"name": "Drip Yard", "blurb": "Broken pipes, scaffolding decks, crates", "speed": 8.0, "diff": 1, "seed": 23,
	 "zones": [["pipe", "rust", 70], ["planks", "wood", 40], ["pipe", "brick", 70], ["pipe", "rust", 60],
		["planks", "wood", 40], ["square", "concrete", 55], ["pipe", "rust", 65], ["planks", "wood", 45],
		["pipe", "brick", 60], ["pipe", "rust", 55]],
	 "hazards": {"coins": 2.0, "crate": 2.0, "crates2": 1.0, "gap": 1.8, "gapside": 0.8, "low": 0.7, "side": 0.7, "slot": 0.5},
	 "ax": [7.0, 0.7], "kx": [0.04, 0.085], "px": [2.0, 0.4], "ay": 1.8, "ky": 0.07, "py": 2.0, "grade": 0.04,
	 "long_gaps": true, "broken": true, "leaks": true, "amb": "hiss", "deck_drop": 7.0, "ground": "water",
	 "pipe": Color(0.74, 0.62, 0.46), "deep": Color(0.04, 0.07, 0.035), "shallow": Color(0.2, 0.32, 0.12), "glow": 0.25,
	 "fog": Color(0.075, 0.062, 0.04), "sky": Color(0.03, 0.03, 0.02), "ambient": Color(0.3, 0.26, 0.19),
	 "lamp": Color(0.95, 0.72, 0.42), "wall": Color(0.7, 0.6, 0.5)},
	{"name": "Grand Outfall", "blurb": "Night walkways, grates, beams, the big drop", "speed": 8.6, "diff": 2, "seed": 37,
	 "zones": [["planks", "wood", 60], ["pipe", "steel", 80, 1.3], ["planks", "wood", 40], ["pipe", "steel", 90, 1.3],
		["hall", "brick", 50], ["pipe", "steel", 70, 1.3], ["planks", "wood", 35], ["pipe", "steel", 80, 1.3]],
	 "hazards": {"coins": 2.0, "grate": 2.0, "beam": 1.8, "gratebeam": 1.2, "gap": 0.8, "boost": 1.0, "side": 0.6},
	 "ax": [10.0, 1.2], "kx": [0.045, 0.09], "px": [1.0, 0.3], "ay": 2.2, "ky": 0.06, "py": 1.0, "grade": 0.05,
	 "night": true, "giants": true, "dive": true, "vfog": 0.004, "vfog_light": 0.12, "dfog": 0.0026, "amb": "wind_loop", "deck_drop": 18.0, "ground": "dirt",
	 "pipe": Color(0.6, 0.63, 0.7), "deep": Color(0.03, 0.05, 0.08), "shallow": Color(0.14, 0.2, 0.26), "glow": 0.0,
	 "fog": Color(0.04, 0.05, 0.1), "sky": Color(0.03, 0.045, 0.1), "ambient": Color(0.18, 0.21, 0.3),
	 "lamp": Color(0.78, 0.82, 0.95), "wall": Color(0.55, 0.55, 0.6)},
	{"name": "Scullery Drain", "blurb": "Copper pipes, blind drops, gushers, slime", "speed": 8.4, "diff": 2, "seed": 53,
	 "zones": [["pipe", "copper", 80, 0.72], ["square", "wood", 65], ["square", "concrete", 80, 1.35], ["pipe", "copper", 70, 0.72],
		["square", "wood", 60], ["square", "concrete", 80, 1.35], ["pipe", "copper", 55, 0.72]],
	 "hazards": {"coins": 2.0, "chute": 1.6, "gusher": 1.8, "slime_ramp": 1.4, "slime": 0.8, "crate": 0.7, "side": 0.7, "low": 0.6},
	 "ax": [6.0, 0.8], "kx": [0.04, 0.09], "px": [3.0, 1.0], "ay": 1.6, "ky": 0.07, "py": 0.2, "grade": 0.04,
	 "amb": "rumble", "deck_drop": 6.0,
	 "pipe": Color(0.82, 0.8, 0.76), "deep": Color(0.05, 0.055, 0.045), "shallow": Color(0.2, 0.21, 0.17), "glow": 0.0,
	 "fog": Color(0.06, 0.055, 0.05), "sky": Color(0.0, 0.0, 0.0), "ambient": Color(0.27, 0.25, 0.22),
	 "lamp": Color(0.95, 0.85, 0.68), "wall": Color(0.68, 0.6, 0.55)},
]

# --- game state
var track
var course := {}
var decor := {}
var built_level := -1
var built_course := false
var li := 0
var LV := {}
var state := "title"
var T := 0.0
var count_t := 0.0
var last_count := 4
var fin_t := 0.0
var over_t := 0.0
var menu_sel := 0
var paused_from := "play"
var save := {"best": [0, 0, 0, 0], "unlocked": 0}
var muted := false
var last_stars := 0
var new_best := false
var bullseye := false

# --- player (tube units)
var ps := 4.0
var pth := 0.0
var pom := 0.0
var ph := 0.0
var pvh := 0.0
var pv := 0.0
var hearts := 3
var invul := 0.0
var coins_got := 0
var hits := 0
var boost := 0.0
var fall_t := 0.0
var fall_o = null
var squash := 0.0
var jbuf := 0.0
var coy := 0.0
var ptime := 0.0
var combo := 0
var combo_t := 0.0
var flap := 0.0
var was_deck := false
var deck_cam := 0.0
var slime_t := 0.0
var ramp_ref = null
var wet := 0.0

# --- dive (end of Grand Outfall)
var shaft := {}
var dive_pos := Vector3.ZERO
var dive_vel := Vector3.ZERO
var land_t := 0.0

# --- nodes
var world_root: Node3D
var cam: Camera3D
var env: Environment
var glob: Node3D
var glob_squash: Node3D
var glob_tail: Node3D
var antennae: Array = []
var splash: CPUParticles3D
var sparks: CPUParticles3D
var sparkle: CPUParticles3D
var streaks: CPUParticles3D
var streak_mat: StandardMaterial3D
var drips: CPUParticles3D
var lamp_lights: Array = []
var zone_lights: Array = []
var outflow_fx: Array = []
var fans: Array = []
var debris_nodes: Array = []
var gushers: Array = []
var post_mat: ShaderMaterial
var hud: Control
var rush: AudioStreamPlayer
var wind: AudioStreamPlayer
var drone: AudioStreamPlayer
var amb2: AudioStreamPlayer
var sounds := {}
var mats := {}
var tube_mats := {}

# --- fx state
var roll := 0.0
var shake := 0.0
var flash := 0.0
var flash_col := Color.WHITE
var fov := 70.0
var amb_t := 3.0
var drip_t := 0.5
var sf := 0.0


func _ready() -> void:
	_setup_input()
	_setup_audio()
	_load_save()
	_make_materials()
	_make_env()
	_make_camera()
	_make_glob()
	_make_fx()
	_make_ui()
	_to_title()
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		autotest = true
		for a in args:
			if a.begins_with("--level="):
				test_level = int(a.substr(8))
		start_level(test_level)


# ---- developer smoke test: run with  godot --path . -- --autotest
var autotest := false
var test_t := 0.0
var test_level := 0
var shots_taken := 0


func _autotest(dt: float) -> void:
	test_t += dt
	hearts = 3
	if state == "play" and randf() < 0.02:
		jbuf = 0.13
	if state == "over":
		state = "play"
	if shots_taken == 1 and test_t > 4.0 and test_t < 4.1:
		ps = track.zones[1]["s0"] + 5.0
	if shots_taken == 2 and test_t > 7.0 and test_t < 7.1:
		ps = track.zones[mini(3, track.zones.size() - 2)]["s0"] + 5.0
	if LV.get("dive", false) and shots_taken == 3 and test_t > 9.0 and test_t < 9.1:
		ps = float(course["len"]) - 2.0
	var shots_max := 4 if LV.get("dive", false) else 3
	var headless := DisplayServer.get_name() == "headless"
	if not headless and shots_taken < shots_max and test_t > 2.0 + shots_taken * 3.0 + (1.0 if shots_taken == 3 else 0.0):
		var dir := ProjectSettings.globalize_path("res://").path_join("../shots")
		DirAccess.make_dir_recursive_absolute(dir)
		get_viewport().get_texture().get_image().save_png(dir.path_join("level%d_%d.png" % [test_level, shots_taken]))
		shots_taken += 1
	if test_t > (13.5 if LV.get("dive", false) else 11.0):
		print("autotest level %d: state=%s s=%.1f v=%.1f coins=%d hits=%d fps=%d" % [test_level, state, ps, pv, coins_got, hits, Engine.get_frames_per_second()])
		test_level += 1
		test_t = 0.0
		shots_taken = 0
		if test_level >= LEVELS.size():
			get_tree().quit()
		else:
			start_level(test_level)


# ================================================================== setup
func _setup_input() -> void:
	_act("left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_act("right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_act("jump", [KEY_SPACE, KEY_K, KEY_Z], [JOY_BUTTON_A], [])
	_act("faster", [KEY_UP, KEY_W], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0], [JOY_AXIS_LEFT_Y, -1.0]])
	_act("brake", [KEY_DOWN, KEY_S], [JOY_BUTTON_X], [[JOY_AXIS_TRIGGER_LEFT, 1.0], [JOY_AXIS_LEFT_Y, 1.0]])
	_act("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])
	_act("mute", [KEY_M], [], [])
	_act("fullscreen", [KEY_F11], [], [])


func _act(n: String, keys: Array, pads: Array, axes: Array) -> void:
	if not InputMap.has_action(n):
		InputMap.add_action(n, 0.25)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(n, e)
	for b in pads:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(n, e)
	for a in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = a[0]
		e.axis_value = a[1]
		InputMap.action_add_event(n, e)


func _setup_audio() -> void:
	sounds = Synth.make_all()
	if AudioServer.get_bus_index("Echo") == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Echo")
		AudioServer.set_bus_send(idx, "Master")
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.88
		rv.damping = 0.3
		rv.spread = 0.9
		rv.dry = 0.85
		rv.wet = 0.45
		rv.predelay_msec = 70.0
		rv.predelay_feedback = 0.35
		rv.hipass = 0.05
		AudioServer.add_bus_effect(idx, rv)
	rush = _loop_player("rush", "Master")
	wind = _loop_player("rush", "Master")
	drone = _loop_player("drone", "Echo")
	drone.volume_db = -16.0
	amb2 = _loop_player("hum", "Echo")


func _loop_player(snd: String, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = sounds[snd]
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


func sfx(snd: String, vol := 0.0, pitch := 1.0, bus := "Echo") -> void:
	var p := AudioStreamPlayer.new()
	p.stream = sounds[snd]
	p.volume_db = vol
	p.pitch_scale = pitch
	p.bus = bus
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func sfx3d(snd: String, pos: Vector3, vol := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = sounds[snd]
	p.volume_db = vol
	p.pitch_scale = pitch
	p.bus = "Echo"
	p.unit_size = 10.0
	p.max_distance = 120.0
	add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


func _loop3d(snd: String, pos: Vector3, vol: float, unit: float, pitch := 1.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = sounds[snd]
	p.bus = "Echo"
	p.unit_size = unit
	p.max_distance = unit * 14.0
	p.volume_db = vol
	p.pitch_scale = pitch
	world_root.add_child(p)
	p.global_position = pos
	return p


func _load_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary and d.has("best") and d.has("unlocked"):
				save = d
	while save["best"].size() < LEVELS.size():
		save["best"].append(0)


func _write_save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save))


func _std(color: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


func _glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color * energy
	m.albedo_color.a = 1.0
	return m


func _tex_mat(pair: Array, rough: float, metal: float, vcol := true) -> StandardMaterial3D:
	var m := _std(Color.WHITE, rough, metal)
	m.albedo_texture = pair[0]
	if pair.size() > 1:
		m.normal_enabled = true
		m.normal_texture = pair[1]
	if pair.size() > 2:
		m.roughness_texture = pair[2]
		m.roughness = 1.0
	m.vertex_color_use_as_albedo = vcol
	return m


func _make_materials() -> void:
	var br := Tex.brick(5)
	var rs := Tex.rust(9)
	tube_mats["brick"] = _tex_mat(br, 1.0, 0.0)
	tube_mats["brick"].metallic_specular = 0.7
	tube_mats["steel"] = _tex_mat(Tex.rust(13, Color(0.5, 0.52, 0.54), Color(0.45, 0.3, 0.18), 0.25), 0.5, 0.3)
	tube_mats["rust"] = _tex_mat(Tex.rust(17, Color(0.4, 0.36, 0.32), Color(0.5, 0.27, 0.1), 0.75), 0.6, 0.45)
	tube_mats["copper"] = _tex_mat(Tex.rust(19, Color(0.62, 0.38, 0.22), Color(0.3, 0.46, 0.38), 0.4), 0.35, 0.75)
	tube_mats["wood"] = _tex_mat(Tex.wood(3, Color(0.42, 0.31, 0.2)), 0.85, 0.0)
	tube_mats["concrete"] = _tex_mat(Tex.concrete(21), 0.85, 0.0)
	mats["vault"] = tube_mats["brick"].duplicate()

	mats["rust"] = _tex_mat(rs, 0.65, 0.45)
	var fm := _std(Color(0.5, 0.48, 0.45), 0.55, 0.6)
	fm.albedo_texture = rs[0]
	fm.normal_enabled = true
	fm.normal_texture = rs[1]
	mats["flange"] = fm
	var hz := _std(Color.WHITE, 0.5, 0.1)
	hz.albedo_texture = Tex.hazard(4)
	hz.vertex_color_use_as_albedo = true
	mats["hazard"] = hz
	var ck := _std(Color.WHITE, 0.4)
	ck.albedo_texture = Tex.checker()
	ck.emission_enabled = true
	ck.emission = Color(0.35, 0.35, 0.35)
	ck.emission_texture = ck.albedo_texture
	mats["checker"] = ck
	var gr := _std(Color.WHITE, 0.6, 0.7)
	gr.albedo_texture = Tex.grate()
	gr.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	gr.alpha_scissor_threshold = 0.5
	gr.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["grate"] = gr
	var gf := gr.duplicate()
	gf.albedo_color = Color(0.55, 0.57, 0.6)
	gf.uv1_scale = Vector3(2.0, 2.0, 1.0)
	mats["grate_fence"] = gf
	mats["deck"] = _tex_mat(Tex.wood(8, Color(0.5, 0.38, 0.25)), 0.9, 0.0, false)
	mats["beam_wood"] = _tex_mat(Tex.wood(12, Color(0.36, 0.26, 0.17)), 0.9, 0.0, false)
	var crt := _std(Color.WHITE, 0.85)
	crt.albedo_texture = Tex.crate(31)
	mats["crate"] = crt
	mats["sky"] = _glow_mat(Color(0.78, 0.8, 0.82), 2.2)
	mats["sludge"] = _glow_mat(Color(0.32, 0.45, 0.28), 1.0)
	mats["warn"] = _glow_mat(Color(0.85, 0.25, 0.15), 2.5)
	mats["go"] = _glow_mat(Color(0.5, 0.85, 0.55), 3.0)
	mats["marker"] = _glow_mat(Color(0.35, 0.55, 1.0), 2.6)
	mats["housing"] = _std(Color(0.12, 0.12, 0.11), 0.5, 0.8)
	mats["stub"] = _std(Color(0.3, 0.28, 0.25), 0.5, 0.6)
	mats["stub"].albedo_texture = rs[0]
	mats["hole"] = _std(Color(0.0, 0.0, 0.0), 1.0)
	mats["fan"] = _std(Color(0.35, 0.36, 0.37), 0.4, 0.8)
	mats["fan"].albedo_texture = rs[0]
	var sl := _std(Color(0.3, 0.42, 0.18), 0.15, 0.0)
	sl.emission_enabled = true
	sl.emission = Color(0.2, 0.32, 0.1)
	sl.emission_energy_multiplier = 0.6
	mats["slime"] = sl
	var win := _std(Color(1.4, 1.4, 1.4), 1.0)
	win.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # facades are silhouettes; only the windows glow
	win.albedo_texture = Tex.windows(5)
	win.disable_receive_shadows = true
	mats["windows"] = win
	mats["dirt"] = _std(Color(0.08, 0.08, 0.09), 1.0)
	mats["tin"] = _std(Color(0.55, 0.56, 0.58), 0.35, 0.85)
	mats["label"] = _std(Color(0.45, 0.22, 0.18), 0.8)
	var glass := _std(Color(0.22, 0.32, 0.24, 0.75), 0.1, 0.2)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats["glass"] = glass
	mats["moon"] = _glow_mat(Color(0.75, 0.8, 0.9), 2.0)
	mats["target"] = _glow_mat(Color(0.35, 0.6, 1.0), 3.0)

	var cm := _std(Color(1.0, 0.75, 0.2), 0.25, 1.0)
	cm.emission_enabled = true
	cm.emission = Color(1.0, 0.6, 0.1)
	cm.emission_energy_multiplier = 0.15
	cm.rim_enabled = true
	cm.rim = 0.5
	mats["coin"] = cm
	var wm := ShaderMaterial.new()
	wm.shader = WaterShader
	wm.set_shader_parameter("nmap", Tex.water_normal())
	mats["water"] = wm
	var bm := ShaderMaterial.new()
	bm.shader = BoostShader
	bm.set_shader_parameter("col", Color(0.42, 0.62, 0.62))
	mats["boost"] = bm
	var drop := _std(Color(0.75, 0.95, 1.0, 0.4), 0.1)
	drop.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mats["drop"] = drop
	var mist := _std(Color(0.7, 0.85, 0.65, 0.3), 0.1)
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mats["mist"] = mist


func _make_env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_density = 0.0042
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.011
	env.volumetric_fog_length = 220.0
	env.volumetric_fog_detail_spread = 2.5
	env.volumetric_fog_anisotropy = 0.55
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.62
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _make_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	cam.far = 1600.0
	add_child(cam)
	cam.current = true
	streaks = CPUParticles3D.new()
	streaks.amount = 70
	streaks.lifetime = 0.28
	streaks.local_coords = true
	streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	streaks.emission_ring_axis = Vector3(0, 0, 1)
	streaks.emission_ring_radius = 4.0
	streaks.emission_ring_inner_radius = 2.2
	streaks.emission_ring_height = 4.0
	streaks.direction = Vector3(0, 0, 1)
	streaks.spread = 0.0
	streaks.gravity = Vector3.ZERO
	streaks.initial_velocity_min = 70.0
	streaks.initial_velocity_max = 95.0
	var sm := BoxMesh.new()
	sm.size = Vector3(0.025, 0.025, 1.8)
	streak_mat = StandardMaterial3D.new()
	streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	streak_mat.albedo_color = Color(0.8, 1.0, 0.95, 0.0)
	sm.material = streak_mat
	streaks.mesh = sm
	streaks.position = Vector3(0, 0, -16)
	cam.add_child(streaks)


func _mesh(m: Mesh, mat: Material, parent: Node3D, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _sphere(r: float, segs := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = segs / 2
	return s


func _box(size: Vector3, mat: Material, xf: Transform3D, parent: Node3D = null) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := _mesh(bm, mat, parent if parent else world_root)
	mi.global_transform = xf
	return mi


func _cyl(r: float, h: float, mat: Material, xf: Transform3D, segs := 12, parent: Node3D = null) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = segs
	var mi := _mesh(cm, mat, parent if parent else world_root)
	mi.global_transform = xf
	return mi


## Glob: an original orange slime with a red scarf, glowing antennae and a headlamp.
func _make_glob() -> void:
	glob = Node3D.new()
	add_child(glob)
	glob_squash = Node3D.new()
	glob.add_child(glob_squash)
	var body_mat := _std(Color(0.88, 0.5, 0.24), 0.3)
	body_mat.metallic_specular = 0.9
	body_mat.rim_enabled = true
	body_mat.rim = 0.7
	body_mat.rim_tint = 0.4
	body_mat.emission_enabled = true
	body_mat.emission = Color(1.0, 0.3, 0.05)
	body_mat.emission_energy_multiplier = 0.15
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.5
	body_mesh.height = 0.88
	body_mesh.radial_segments = 16
	body_mesh.rings = 8
	_mesh(body_mesh, body_mat, glob_squash, Vector3(0, 0.44, 0))
	var scarf_mat := _std(Color(0.7, 0.18, 0.2), 0.7)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.46
	tm.outer_radius = 0.58
	tm.rings = 14
	tm.ring_segments = 6
	var scarf := _mesh(tm, scarf_mat, glob_squash, Vector3(0, 0.36, 0))
	scarf.scale = Vector3(1, 0.7, 1)
	glob_tail = Node3D.new()
	glob_tail.position = Vector3(0.15, 0.36, 0.48)
	glob_squash.add_child(glob_tail)
	var tb := BoxMesh.new()
	tb.size = Vector3(0.2, 0.05, 0.55)
	_mesh(tb, scarf_mat, glob_tail, Vector3(0, -0.05, 0.27))
	var eye_mat := _std(Color(1, 1, 1), 0.2)
	var pup_mat := _std(Color(0.02, 0.02, 0.03), 0.1)
	for sd in [-1.0, 1.0]:
		_mesh(_sphere(0.12), eye_mat, glob_squash, Vector3(sd * 0.18, 0.56, -0.4))
		_mesh(_sphere(0.065), pup_mat, glob_squash, Vector3(sd * 0.18, 0.57, -0.5))
		var piv := Node3D.new()
		piv.position = Vector3(sd * 0.16, 0.8, 0.02)
		piv.rotation = Vector3(0.2, 0, -sd * 0.35)
		glob_squash.add_child(piv)
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.035
		cyl.height = 0.45
		cyl.radial_segments = 6
		_mesh(cyl, body_mat, piv, Vector3(0, 0.22, 0))
		_mesh(_sphere(0.075, 8), _glow_mat(Color(0.95, 0.85, 0.5), 2.0), piv, Vector3(0, 0.47, 0))
		antennae.append([piv, sd])
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(0, 0.95, -0.25)
	lamp.rotation_degrees = Vector3(-7, 0, 0)
	lamp.spot_range = 90.0
	lamp.spot_angle = 34.0
	lamp.spot_attenuation = 0.8
	lamp.light_energy = 3.2
	lamp.light_color = Color(1.0, 0.92, 0.78)
	lamp.light_volumetric_fog_energy = 0.2
	glob_squash.add_child(lamp)
	var aura := OmniLight3D.new()
	aura.position = Vector3(0, 0.6, 0)
	aura.omni_range = 4.0
	aura.light_energy = 0.9
	aura.light_color = Color(1.0, 0.5, 0.15)
	aura.light_volumetric_fog_energy = 0.0
	glob_squash.add_child(aura)

	splash = _particles(glob, 40, 0.5, mats["drop"], 0.06)
	splash.position = Vector3(0, 0.05, 0.35)
	splash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	splash.emission_box_extents = Vector3(0.4, 0.02, 0.1)
	splash.direction = Vector3(0, 1, 1)
	splash.spread = 40.0
	splash.initial_velocity_min = 3.0
	splash.initial_velocity_max = 7.0
	splash.gravity = Vector3(0, -18, 0)
	sparks = _particles(glob, 36, 0.55, _glow_mat(Color(1.0, 0.55, 0.15), 3.0), 0.06)
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.position = Vector3(0, 0.5, -0.3)
	sparks.spread = 180.0
	sparks.initial_velocity_min = 5.0
	sparks.initial_velocity_max = 12.0
	sparks.gravity = Vector3(0, -14, 0)
	sparks.emitting = false
	sparkle = _particles(glob, 6, 0.28, _glow_mat(Color(0.95, 0.85, 0.55), 1.1), 0.035)
	sparkle.one_shot = true
	sparkle.explosiveness = 1.0
	sparkle.position = Vector3(0, 0.6, -0.4)
	sparkle.spread = 180.0
	sparkle.initial_velocity_min = 0.6
	sparkle.initial_velocity_max = 1.6
	sparkle.gravity = Vector3.ZERO
	sparkle.emitting = false


func _particles(parent: Node3D, amount: int, life: float, mat: Material, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	var m := BoxMesh.new()
	m.size = Vector3(size, size, size)
	m.material = mat
	p.mesh = m
	parent.add_child(p)
	return p


func _make_fx() -> void:
	for i in 8:
		var l := OmniLight3D.new()
		l.omni_range = 34.0
		l.omni_attenuation = 1.3
		l.light_energy = 3.0
		l.light_volumetric_fog_energy = 2.0
		add_child(l)
		lamp_lights.append(l)
	drips = CPUParticles3D.new()
	drips.amount = 28
	drips.lifetime = 0.8
	drips.local_coords = false
	drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drips.emission_box_extents = Vector3(3.5, 0.05, 30.0)
	drips.direction = Vector3(0, -1, 0)
	drips.spread = 0.0
	drips.initial_velocity_min = 0.0
	drips.initial_velocity_max = 0.5
	drips.gravity = Vector3(0, -26, 0)
	var dm := BoxMesh.new()
	dm.size = Vector3(0.03, 0.3, 0.03)
	dm.material = _glow_mat(Color(0.7, 0.85, 0.9), 1.0)
	drips.mesh = dm
	add_child(drips)


func _make_ui() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 1
	add_child(cl)
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = PostShader
	cr.material = post_mat
	cl.add_child(cr)
	var cl2 := CanvasLayer.new()
	cl2.layer = 2
	add_child(cl2)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl2.add_child(hud)
	hud.draw.connect(_draw_hud)


# ================================================================== level building
func build_level(i: int, with_course: bool) -> void:
	li = i
	LV = LEVELS[i]
	if built_level == i and built_course == with_course and world_root:
		for c in course["coins"]:
			c["got"] = false
			c["node"].visible = true
		for b in shaft.get("beams", []):
			b["passed"] = false
		return
	built_level = i
	built_course = with_course
	track = Track.new()
	var dive: bool = LV.get("dive", false) and with_course
	track.setup(LV, 0.0 if dive else 90.0)
	if world_root:
		world_root.free()
	world_root = Node3D.new()
	add_child(world_root)
	zone_lights.clear()
	outflow_fx.clear()
	fans.clear()
	debris_nodes.clear()
	gushers.clear()
	shaft = {}
	if with_course:
		course = track.gen_course(LV)
	else:
		course = {"obs": [], "coins": [], "len": float(LV["len"])}
	var length: float = track.total
	decor = track.gen_decor(length)
	var holes := []
	for o in course["obs"]:
		if o["type"] == "gap":
			holes.append(o)
	for g in decor["grates"]:
		holes.append(g)
	for g in decor["broken"]:
		holes.append(g)

	for k in tube_mats.keys():
		tube_mats[k].albedo_color = LV["pipe"]
	mats["vault"].albedo_color = LV["pipe"] * 0.85
	mats["rust"].albedo_color = LV["wall"]
	mats["water"].set_shader_parameter("deep", LV["deep"])
	mats["water"].set_shader_parameter("shallow", LV["shallow"])
	mats["water"].set_shader_parameter("glow", LV["glow"])
	env.background_color = LV["sky"]
	env.fog_light_color = LV["fog"]
	env.volumetric_fog_albedo = LV["fog"].lightened(LV.get("vfog_light", 0.55))
	env.volumetric_fog_density = LV.get("vfog", 0.011)
	env.fog_density = LV.get("dfog", 0.0042)
	env.volumetric_fog_emission = LV["fog"] * 0.4
	env.ambient_light_color = LV["ambient"]
	for l in lamp_lights:
		l.light_color = LV["lamp"]
	amb2.stream = sounds[LV["amb"]]
	amb2.play()

	track.build_pipe(world_root, holes, length, tube_mats, mats["water"])
	var s := 0.0
	while s < length:   # pipe joints every 20 m; they strobe past and sell the speed
		var zt: String = track.zone_type(s)
		if (zt == "pipe" or zt == "square") and not track.in_planks(s, 0.5) and track.mat_at(s) != "wood":
			world_root.add_child(track.arc_block(s, s + 0.1, PI, PI - WA, 0.95, 1.0, mats["flange"], "all", true))
		s += 4.0
	_build_halls()
	_build_decks()
	_build_lamps()
	_build_grates()
	_build_outflows()
	_build_markers()
	_build_leaks()
	_build_gaps()
	_build_obstacles()
	_build_coins()
	if with_course:
		if dive:
			_build_shaft()
		else:
			_build_finish()


func _build_halls() -> void:
	for ch in track.chambers:
		var s0: float = ch["s0"]
		var s1: float = ch["s1"]
		track.tube(world_root, s0, s1, 1.0, Track.HALL_R, 18, 0.0, Track.HALL_UP, mats["vault"], true, 14.0, 0.1)
		track.cap(world_root, s0, mats["vault"], false)
		track.cap(world_root, s1, mats["vault"], true)
		var rx := sqrt(Track.HALL_R * Track.HALL_R - pow(Track.RIVER_Y - Track.HALL_UP, 2.0)) - 0.05
		track.ribbon(world_root, s0, s1, -rx, rx, Track.RIVER_Y, mats["water"])
		for sd in [-1.0, 1.0]:
			var wy := -1.5
			var wx := sqrt(Track.HALL_R * Track.HALL_R - pow(wy - Track.HALL_UP, 2.0))
			track.ribbon(world_root, s0, s1, minf(sd * (wx - 1.0), sd * wx), maxf(sd * (wx - 1.0), sd * wx), wy, mats["vault"], 0.2)
			track.tube(world_root, s0, s1, 2.0, 0.32, 8, sd * 5.0, 0.4, mats["stub"], false, 2.0, 0.2)
			track.tube(world_root, s0, s1, 2.0, 0.18, 6, sd * 5.2, 1.3, mats["flange"], false, 2.0, 0.2)
		var s := s0 + 2.0
		var k := 0
		while s < s1 - 1.0:
			track.tube(world_root, s, s + 0.4, 0.4, Track.HALL_R - 0.25, 18, 0.0, Track.HALL_UP, mats["flange"], true, 14.0, 0.1)
			var b: Basis = track.track_basis(s)
			var f: Array = track.frame(s)
			var ph_y := (-1.12 + Track.RIVER_Y) * 0.5
			_box(Vector3(2.4, (-1.12 - Track.RIVER_Y) * K + 1.0, 2.4), mats["vault"], Transform3D(b, f[0] + f[3] * (ph_y * K)))
			var sd2 := 1.0 if k % 2 == 0 else -1.0
			var lp: Vector3 = f[0] + (f[2] * (sd2 * 2.8) + f[3] * 3.2) * K
			_box(Vector3(0.1, 30.0, 0.1), mats["housing"], Transform3D(b, lp + f[3] * 15.5))
			_box(Vector3(1.0, 0.5, 1.0), mats["housing"], Transform3D(b, lp + f[3] * 0.4))
			_box(Vector3(0.7, 0.35, 0.7), _glow_mat(LV["lamp"], 4.0), Transform3D(b, lp))
			var hl := OmniLight3D.new()
			world_root.add_child(hl)
			hl.global_position = lp - f[3] * 1.0
			hl.omni_range = 75.0
			hl.omni_attenuation = 0.9
			hl.light_energy = 9.0
			hl.light_color = LV["lamp"]
			hl.light_volumetric_fog_energy = 2.5
			zone_lights.append({"node": hl, "s": s})
			s += 6.0
			k += 1
		for sd in [-1.0, 1.0]:
			var ws := lerpf(s0, s1, 0.35 if sd < 0.0 else 0.7)
			var f: Array = track.frame(ws)
			var mouth: Vector3 = f[0] + (f[2] * (sd * 5.3) + f[3] * 0.9) * K
			var inward: Vector3 = -f[2] * sd
			var y := inward
			var z: Vector3 = f[1]
			var x := y.cross(z).normalized()
			_cyl(1.65, 3.0, mats["stub"], Transform3D(Basis(x, y, x.cross(y)), mouth))
			if LV.get("markers", false):
				# a giant wall fan in the machinery hall (decor), turning slowly behind a grille
				var fanb := Basis(x, y, x.cross(y))
				_cyl(6.5, 0.6, mats["housing"], Transform3D(fanb, mouth + f[3] * 11.0 + inward * 0.2), 20)
				var rotor := Node3D.new()
				world_root.add_child(rotor)
				rotor.global_transform = Transform3D(Basis(z, inward, z.cross(inward).normalized()), mouth + f[3] * 11.0 + inward * 0.6)
				for bi in 5:
					var bp := Node3D.new()
					bp.rotation = Vector3(0, bi * TAU / 5.0, 0)
					rotor.add_child(bp)
					var bl := BoxMesh.new()
					bl.size = Vector3(1.6, 0.15, 5.6)
					_mesh(bl, mats["fan"], bp, Vector3(0, 0, 3.0))
				fans.append({"node": rotor, "decor": true, "s": ws, "axis": "y", "om": 1.2})
				var hum := _loop3d("hum", mouth, -2.0, 18.0, 0.8)
				outflow_fx.append({"fx": null, "snd": hum, "s": ws})
			var fx := _particles(world_root, 140, 1.6, mats["drop"], 0.25)
			fx.global_position = mouth + inward * 1.6
			fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			fx.emission_sphere_radius = 1.0
			fx.direction = inward
			fx.spread = 6.0
			fx.initial_velocity_min = 5.0
			fx.initial_velocity_max = 7.0
			fx.gravity = Vector3(0, -20, 0)
			fx.emitting = false
			var snd := _loop3d("pour", mouth, 2.0, 14.0, 0.7)
			outflow_fx.append({"fx": fx, "snd": snd, "s": ws})


## Open wooden scaffolding decks between pipe sections
func _build_decks() -> void:
	var drop: float = LV["deck_drop"]
	var gi := 0
	for z in track.planks:
		var s0: float = z["s0"]
		var s1: float = z["s1"]
		# deck boards, skipping missing-plank gaps
		var gaps := []
		for o in course["obs"]:
			if o["type"] == "gap" and o["s0"] < s1 and o["s1"] > s0:
				gaps.append(o)
		var a := s0
		while a < s1:
			var b := a
			var in_gap := false
			for g in gaps:
				if a >= g["s0"] and a < g["s1"]:
					in_gap = true
					b = minf(g["s1"], s1)
			if in_gap:
				a = b
				continue
			b = s1
			for g in gaps:
				if g["s0"] > a and g["s0"] < b:
					b = g["s0"]
			track.ribbon(world_root, a, b, -Track.DECK_W, Track.DECK_W, -Track.DECK_Y, mats["deck"], 0.25)
			track.ribbon(world_root, a, b, -Track.DECK_W, Track.DECK_W, -Track.DECK_Y - 0.06, mats["beam_wood"], 0.25, false)
			a = b
		var s := s0
		var k := 0
		while s <= s1:
			var bs: Basis = track.track_basis(s)
			var f: Array = track.frame(s)
			# cross joist + edge stringers
			_box(Vector3(Track.DECK_W * 2.0 * K + 0.8, 0.4, 0.5), mats["beam_wood"], Transform3D(bs, f[0] + f[3] * ((-Track.DECK_Y - 0.12) * K)))
			for sd in [-1.0, 1.0]:
				var ex: Vector3 = f[0] + (f[2] * (sd * (Track.DECK_W + 0.03)) + f[3] * (-Track.DECK_Y - 0.05)) * K
				_box(Vector3(0.35, 0.5, 2.0 * K), mats["beam_wood"], Transform3D(bs, ex + f[1] * K))
				if k % 2 == 0:
					var post_base: Vector3 = f[0] + (f[2] * (sd * (Track.DECK_W + 0.08)) + f[3] * (-Track.DECK_Y)) * K
					_box(Vector3(0.45, drop * K, 0.45), mats["beam_wood"], Transform3D(Basis(), post_base + Vector3.DOWN * (drop * K * 0.5)))
					_box(Vector3(0.32, 1.5 * K, 0.32), mats["beam_wood"], Transform3D(bs, post_base + f[3] * (0.75 * K)))
					if drop < 10.0:
						# X-bracing between scaffold posts
						var brace := Basis(f[2], deg_to_rad(40.0 * sd)) * bs
						_box(Vector3(0.22, drop * K * 0.9, 0.22), mats["beam_wood"], Transform3D(brace, post_base + Vector3.DOWN * (drop * K * 0.45) + f[1] * K))
				if k % 4 == 0:
					var top: Vector3 = f[0] + (f[2] * (sd * (Track.DECK_W + 0.08)) + f[3] * (-Track.DECK_Y + 1.5)) * K
					if sd > 0.0:
						_box(Vector3(Track.DECK_W * 2.0 * K + 1.2, 0.35, 0.35), mats["beam_wood"], Transform3D(bs, f[0] + f[3] * ((-Track.DECK_Y + 1.5) * K)))
					if (k / 4 + int(sd > 0.0)) % 2 == 0:
						_box(Vector3(0.5, 0.7, 0.5), _glow_mat(LV["lamp"], 3.0), Transform3D(bs, top + f[3] * 0.5))
						var ll := OmniLight3D.new()
						world_root.add_child(ll)
						ll.global_position = top + f[3] * 0.2
						ll.omni_range = 40.0
						ll.light_energy = 4.5
						ll.light_color = LV["lamp"]
						ll.light_volumetric_fog_energy = 0.5
						zone_lights.append({"node": ll, "s": s})
			s += 2.0
			k += 1
		# ground / pool far below
		var sm := (s0 + s1) * 0.5
		var fm: Array = track.frame(sm)
		var pm := PlaneMesh.new()
		pm.size = Vector2(260.0, (s1 - s0) * K + 220.0)
		var gm: Material = mats["water"] if LV.get("ground", "dirt") == "water" else mats["dirt"]
		var gnd := _mesh(pm, gm, world_root)
		gnd.global_transform = Transform3D(Basis(fm[2], Vector3.UP, fm[2].cross(Vector3.UP)), fm[0] + Vector3.DOWN * ((Track.DECK_Y + drop) * K))
		# open pipe mouths at both ends, water pouring off the first one
		track.mouth(world_root, s0, tube_mats.get(track.mat_at(s0 - 1.0), tube_mats["brick"]), false)
		track.mouth(world_root, s1, tube_mats.get(track.mat_at(s1 + 1.0), tube_mats["brick"]), true)
		var pb: Basis = track.wall_basis(s0, 0.0)
		var pour := _particles(world_root, 90, 1.6, mats["drop"], 0.14)
		pour.global_transform = Transform3D(pb, track.point(s0 - 0.05, 0.0, Track.surf_r(0.0) - 0.02))
		pour.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		pour.emission_box_extents = Vector3(2.6, 0.05, 0.1)
		pour.direction = Vector3(0, 0.1, -1)
		pour.spread = 12.0
		pour.initial_velocity_min = 3.0
		pour.initial_velocity_max = 5.0
		pour.gravity = Vector3(0, -18, 0)
		pour.emitting = false
		outflow_fx.append({"fx": pour, "snd": _loop3d("pour", track.point(s0, 0.0, 0.8), 0.0, 10.0, 0.8), "s": s0})
		if LV.get("night", false):
			_build_city(s0, s1, drop)
		if LV.get("giants", false):
			_build_giant(gi, sm, drop)
			gi += 1


func _build_city(s0: float, s1: float, drop: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s0 * 13.0)
	for i in 12:
		var s := lerpf(s0 - 10.0, s1 + 20.0, rng.randf())
		var f: Array = track.frame(s)
		var sd := -1.0 if i % 2 == 0 else 1.0
		var dist := 150.0 + rng.randf() * 160.0
		var w := 20.0 + rng.randf() * 35.0
		var h := 90.0 + rng.randf() * 150.0
		var base: Vector3 = f[0] + f[2] * (sd * dist) + Vector3.DOWN * ((Track.DECK_Y + drop) * K)
		var bm := BoxMesh.new()
		bm.size = Vector3(w, h, w * (0.6 + rng.randf()))
		var mi := _mesh(bm, mats["windows"], world_root)
		mi.global_position = base + Vector3.UP * (h * 0.5)
	if not shaft.has("moon"):
		shaft["moon"] = true
		var mn := _mesh(_sphere(30.0, 16), mats["moon"], world_root)
		var f2: Array = track.frame(s0)
		mn.global_position = f2[0] + f2[2] * 420.0 + Vector3.UP * 300.0 - f2[1] * 500.0


## Oversized discarded objects next to the walkways
func _build_giant(i: int, s: float, drop: float) -> void:
	var f: Array = track.frame(s)
	var sd := 1.0 if i % 2 == 0 else -1.0
	var ground: Vector3 = f[0] + Vector3.DOWN * ((Track.DECK_Y + drop) * K) + f[2] * (sd * 34.0)
	match i % 3:
		0:   # a huge tin can
			_cyl(10.0, 26.0, mats["tin"], Transform3D(Basis(), ground + Vector3.UP * 13.0), 24)
			_cyl(10.08, 12.0, mats["label"], Transform3D(Basis(), ground + Vector3.UP * 12.0), 24)
		1:   # a huge glass bottle lying on its side
			var b := Basis(f[1], PI * 0.5)
			_cyl(7.0, 30.0, mats["glass"], Transform3D(b, ground + Vector3.UP * 7.0), 18)
			_cyl(3.0, 12.0, mats["glass"], Transform3D(b, ground + Vector3.UP * 7.0 + f[1] * 21.0 * sd), 14)
		2:   # a huge spanner leaning on the scaffolding
			var lean := Basis(f[1], deg_to_rad(28.0 * -sd))
			_box(Vector3(4.0, 60.0, 1.6), mats["tin"], Transform3D(lean, ground + Vector3.UP * 26.0 - f[2] * (sd * 6.0)))
			var head: Vector3 = ground + lean * Vector3(0, 56.0, 0) - f[2] * (sd * 6.0)
			_box(Vector3(3.0, 9.0, 1.6), mats["tin"], Transform3D(lean, head + lean * Vector3(-4.0, 3.0, 0)))
			_box(Vector3(3.0, 9.0, 1.6), mats["tin"], Transform3D(lean, head + lean * Vector3(4.0, 3.0, 0)))


func _build_lamps() -> void:
	var hb := BoxMesh.new()
	hb.size = Vector3(1.2, 0.3, 1.8)
	var gb := BoxMesh.new()
	gb.size = Vector3(0.85, 0.16, 1.4)
	var gm := _glow_mat(LV["lamp"], 3.0)
	for l in decor["lamps"]:
		var b: Basis = track.wall_basis(l["s"], l["a"])
		var p: Vector3 = track.point(l["s"], l["a"], track.wall_r(l["s"], l["a"]) - 0.015)
		var h := _mesh(hb, mats["housing"], world_root)
		h.global_transform = Transform3D(b, p)
		var g := _mesh(gb, gm, world_root)
		g.global_transform = Transform3D(b, p + b.y * 0.2)
		l["pos"] = track.point(l["s"], l["a"], track.wall_r(l["s"], l["a"]) - 0.12)


func _build_grates() -> void:
	for g in decor["grates"]:
		world_root.add_child(track.arc_block(g["s0"], g["s1"], PI, g["w"], 0.99, 1.0, mats["grate"], "inner"))
		world_root.add_child(track.arc_block(g["s0"] - 0.4, g["s1"] + 0.4, PI, g["w"] + 0.3, 1.4, 1.45, mats["sky"], "inner"))
		var sm: float = (g["s0"] + g["s1"]) * 0.5
		var sl := SpotLight3D.new()
		world_root.add_child(sl)
		var from: Vector3 = track.point(sm, PI, 1.6)
		var to: Vector3 = track.point(sm + 0.6, 0.0, 0.8)
		sl.look_at_from_position(from, to, track.frame(sm)[1])
		sl.spot_range = 40.0
		sl.spot_angle = 14.0
		sl.light_energy = 9.0
		sl.light_color = Color(0.75, 0.8, 0.88)
		sl.light_volumetric_fog_energy = 6.0
		zone_lights.append({"node": sl, "s": sm})


func _build_outflows() -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 1.0
	cyl.height = 1.4
	cyl.radial_segments = 10
	var disc := CylinderMesh.new()
	disc.top_radius = 0.72
	disc.bottom_radius = 0.72
	disc.height = 0.05
	disc.radial_segments = 10
	for o in decor["outflows"]:
		var b: Basis = track.wall_basis(o["s"], o["a"])
		var p: Vector3 = track.point(o["s"], o["a"], track.wall_r(o["s"], o["a"]) - 0.03)
		var stub := _mesh(cyl, mats["stub"], world_root)
		stub.global_transform = Transform3D(b, p)
		var hole := _mesh(disc, mats["hole"], world_root)
		hole.global_transform = Transform3D(b, p + b.y * 0.68)
		var fx := _particles(world_root, 60, 1.1, mats["drop"], 0.12)
		fx.global_position = p + b.y * 0.7
		fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		fx.emission_sphere_radius = 0.45
		fx.direction = b.y
		fx.spread = 8.0
		fx.initial_velocity_min = 4.0
		fx.initial_velocity_max = 5.5
		fx.gravity = Vector3(0, -18, 0)
		fx.emitting = false
		outflow_fx.append({"fx": fx, "snd": _loop3d("pour", p, -4.0, 10.0), "s": o["s"]})


## Soft blue guide markers along the walls (Gearworks)
func _build_markers() -> void:
	var ms: Array = decor["markers"]
	if ms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.1, 1.1)
	mm.mesh = bm
	mm.instance_count = ms.size()
	for i in ms.size():
		var m: Dictionary = ms[i]
		var b: Basis = track.wall_basis(m["s"], m["a"])
		mm.set_instance_transform(i, Transform3D(b, track.point(m["s"], m["a"], track.wall_r(m["s"], m["a"]) - 0.005)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mats["marker"]
	world_root.add_child(mi)


## Leaking pipes hissing green spray (Drip Yard)
func _build_leaks() -> void:
	for l in decor["leaks"]:
		var b: Basis = track.wall_basis(l["s"], l["a"])
		var p: Vector3 = track.point(l["s"], l["a"], track.wall_r(l["s"], l["a"]) - 0.02)
		_cyl(0.3, 0.8, mats["stub"], Transform3D(b, p), 8)
		var fx := _particles(world_root, 50, 0.7, mats["mist"], 0.22)
		fx.global_position = p + b.y * 0.4
		fx.direction = b.y + b.z * 0.3
		fx.spread = 18.0
		fx.initial_velocity_min = 7.0
		fx.initial_velocity_max = 11.0
		fx.gravity = Vector3(0, -4, 0)
		fx.emitting = false
		var gl := OmniLight3D.new()
		world_root.add_child(gl)
		gl.global_position = p + b.y * 1.5
		gl.omni_range = 12.0
		gl.light_energy = 2.0
		gl.light_color = Color(0.45, 0.85, 0.35)
		zone_lights.append({"node": gl, "s": l["s"]})
		outflow_fx.append({"fx": fx, "snd": _loop3d("hiss", p, -6.0, 6.0, 0.8 + randf() * 0.4), "s": l["s"]})


func _build_gaps() -> void:
	for o in course["obs"]:
		if o["type"] != "gap":
			continue
		var sm: float = (o["s0"] + o["s1"]) * 0.5
		if track.in_planks(sm):
			continue   # missing deck boards need no extra dressing
		world_root.add_child(track.floor_strip(o["s0"] - 0.9, o["s0"], o["c"], o["w"], -0.004, mats["hazard"]))
		world_root.add_child(track.arc_block(o["s1"], o["s1"] + 0.06, o["c"], o["w"], 1.0, 1.18, mats["rust"], "all", true))
		world_root.add_child(track.arc_block(o["s0"] - 0.06, o["s0"], o["c"], o["w"], 1.0, 1.18, mats["rust"], "all", true))
		var f: Array = track.frame(sm)
		if not track.in_chamber(sm, 1.0):
			var pm := PlaneMesh.new()
			pm.size = Vector2(20.0, (o["s1"] - o["s0"]) * K + 20.0)
			var sl := _mesh(pm, mats["sludge"], world_root)
			sl.global_transform = Transform3D(Basis(f[2], f[3], -f[1]), f[0] - f[3] * 22.0)
			var gl := OmniLight3D.new()
			world_root.add_child(gl)
			gl.global_position = f[0] - f[3] * 12.0
			gl.omni_range = 20.0
			gl.light_energy = 2.0
			gl.light_color = Color(0.4, 0.6, 0.35)
			gl.light_volumetric_fog_energy = 2.0
			zone_lights.append({"node": gl, "s": sm})
		if absf(Track.ang_diff(0.0, o["c"])) < o["w"]:
			var b: Basis = track.wall_basis(o["s0"], 0.0)
			var fx := _particles(world_root, 60, 1.1, mats["drop"], 0.07)
			fx.global_transform = Transform3D(b, track.point(o["s0"], 0.0, track.sr(o["s0"], 0.0) - 0.02))
			fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			fx.emission_box_extents = Vector3(2.6, 0.05, 0.1)
			fx.direction = Vector3(0, 0.2, -1)
			fx.spread = 10.0
			fx.initial_velocity_min = 4.0
			fx.initial_velocity_max = 6.0
			fx.gravity = Vector3(0, -18, 0)
			fx.emitting = false
			outflow_fx.append({"fx": fx, "snd": _loop3d("pour", fx.global_position, -2.0, 7.0, 0.8), "s": o["s0"]})


func _build_obstacles() -> void:
	var wm := _sphere(0.22, 8)
	for o in course["obs"]:
		var sm: float = (o["s0"] + o["s1"]) * 0.5
		match o["type"]:
			"wall":
				world_root.add_child(track.arc_block(o["s0"], o["s1"], o["c"], o["w"], 1.0 - o["h"], 1.02, mats["rust"], "all", true))
				if o["w"] > 2.0:
					var door: float = o["c"] + PI
					var open: float = PI - o["w"]
					for sd in [-1.0, 1.0]:
						for k in 5:
							var lm := _mesh(wm, mats["go"], world_root)
							lm.global_position = track.point(o["s0"] - 0.03, door + sd * (open + 0.02), track.sr(o["s0"], door) - 0.04 - k * 0.16)
					var dl := OmniLight3D.new()
					world_root.add_child(dl)
					dl.global_position = track.point(o["s0"] - 0.4, door, track.sr(o["s0"], door) - 0.35)
					dl.omni_range = 14.0
					dl.light_energy = 3.0
					dl.light_color = Color(0.45, 0.85, 0.55)
					zone_lights.append({"node": dl, "s": o["s0"]})
				else:
					var lm2 := _mesh(wm, mats["warn"], world_root)
					lm2.global_position = track.point(o["s0"] - 0.03, o["c"], track.sr(o["s0"], o["c"]) - o["h"] + 0.05)
			"low":
				world_root.add_child(track.arc_block(o["s0"], o["s1"], o["c"], o["w"], 1.0 - o["h"], 1.02, mats["hazard"], "all", true))
			"grate":
				# low security grate across the channel: hop it
				world_root.add_child(track.arc_block(o["s0"], o["s1"], o["c"], o["w"], 1.0 - o["h"], 1.02, mats["grate_fence"], "all", true))
				world_root.add_child(track.arc_block(o["s0"] - 0.02, o["s1"] + 0.02, o["c"], o["w"], 1.0 - o["h"] - 0.03, 1.0 - o["h"] + 0.01, mats["flange"], "all", true))
			"boost":
				world_root.add_child(track.floor_strip(o["s0"], o["s1"], o["c"], o["w"], 0.01, mats["boost"]))
				var bl := OmniLight3D.new()
				world_root.add_child(bl)
				bl.global_position = track.point(sm, 0.0, 0.6)
				bl.omni_range = 7.0
				bl.light_energy = 1.5
				bl.light_color = Color(0.45, 0.7, 0.75)
				zone_lights.append({"node": bl, "s": o["s0"]})
			"crate":
				var r: float = minf(track.sr(sm, o["c"]), 1.5)
				var wdt: float = 2.0 * o["w"] * r * K
				var hgt: float = o["h"] * K
				var b2: Basis = track.wall_basis(sm, o["c"])
				_box(Vector3(wdt, hgt, (o["s1"] - o["s0"]) * K), mats["crate"],
					Transform3D(b2, track.point(sm, o["c"], r) + b2.y * (hgt * 0.5)))
			"beam":
				var f: Array = track.frame(sm)
				var yc: float = (o["y0"] + o["y1"]) * 0.5
				var wr: float = track.wall_r(sm, PI * 0.5)
				var half := sqrt(maxf(0.04, wr * wr - yc * yc)) if not track.in_planks(sm) else Track.DECK_W + 0.3
				var bmat: Material = mats["beam_wood"] if (track.in_planks(sm) or li == 2 and int(sm) % 2 == 0) else mats["rust"]
				_box(Vector3(half * 2.0 * K, (o["y1"] - o["y0"]) * K, (o["s1"] - o["s0"]) * K), bmat,
					Transform3D(track.track_basis(sm), f[0] + f[3] * (yc * K)))
				if track.in_planks(sm):
					for sd in [-1.0, 1.0]:
						_box(Vector3(0.3, 2.0 * K, 0.3), mats["beam_wood"],
							Transform3D(track.track_basis(sm), f[0] + (f[2] * (sd * half) + f[3] * (yc + 1.0)) * K))
				var wl := _mesh(wm, mats["warn"], world_root)
				wl.global_position = f[0] + f[3] * (o["y0"] * K - 0.1)
			"fan":
				var f2: Array = track.frame(o["s0"])
				var root := Node3D.new()
				world_root.add_child(root)
				root.global_transform = Transform3D(track.track_basis(o["s0"]), f2[0])
				var blen: float = track.wall_r(o["s0"], 0.0) * K * 0.97
				for bi in 3:
					var piv := Node3D.new()
					piv.rotation = Vector3(0, 0, bi * TAU / 3.0)
					root.add_child(piv)
					var blm := BoxMesh.new()
					blm.size = Vector3(2.3, blen, 0.35)
					_mesh(blm, mats["fan"], piv, Vector3(0, -blen * 0.5, 0))
				var hub := CylinderMesh.new()
				hub.top_radius = 0.7
				hub.bottom_radius = 0.7
				hub.height = 1.2
				var hubn := _mesh(hub, mats["housing"], root)
				hubn.rotation = Vector3(PI * 0.5, 0, 0)
				world_root.add_child(track.arc_block(o["s0"] - 0.15, o["s1"] + 0.15, PI, PI, 0.9, 1.0, mats["flange"], "all", true))
				fans.append({"node": root, "o": o, "decor": false})
				outflow_fx.append({"fx": null, "snd": _loop3d("hum", f2[0], 0.0, 9.0, 0.9 + randf() * 0.2), "s": o["s0"]})
			"debris":
				var dn := Node3D.new()
				world_root.add_child(dn)
				match int(o["kind"]):
					0:
						_cyl(0.55, 1.4, mats["rust"], Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5), Vector3.ZERO), 10, dn)
					1:
						var bx := BoxMesh.new()
						bx.size = Vector3(1.2, 0.9, 1.2)
						_mesh(bx, mats["crate"], dn)
					_:
						_cyl(0.4, 0.8, mats["tin"], Transform3D(Basis(Vector3(0, 0, 1), 1.3), Vector3.ZERO), 10, dn)
				debris_nodes.append({"node": dn, "o": o})
			"gusher":
				var gb: Basis = track.wall_basis(sm, o["c"])
				var gp: Vector3 = track.point(sm, o["c"], track.wall_r(sm, o["c"]) - 0.02)
				_cyl(0.5, 1.2, mats["stub"], Transform3D(gb, gp), 10)
				_cyl(0.75, 0.25, mats["warn"], Transform3D(gb, gp + gb.y * 0.5), 10)
				var jet := _particles(world_root, 120, 0.8, mats["drop"], 0.13)
				jet.global_position = gp + gb.y * 0.7
				jet.direction = gb.y
				jet.spread = 14.0
				jet.initial_velocity_min = 16.0
				jet.initial_velocity_max = 22.0
				jet.gravity = Vector3(0, -12, 0)
				jet.emitting = false
				gushers.append({"fx": jet, "o": o, "pos": gp, "was": false})
			"slime":
				world_root.add_child(track.floor_strip(o["s0"], o["s1"], o["c"], o["w"], -0.006, mats["slime"]))
				var sl2 := OmniLight3D.new()
				world_root.add_child(sl2)
				sl2.global_position = track.point(sm, 0.0, 0.5)
				sl2.omni_range = 10.0
				sl2.light_energy = 1.2
				sl2.light_color = Color(0.5, 0.75, 0.3)
				zone_lights.append({"node": sl2, "s": sm})
			"ramp":
				world_root.add_child(track.floor_strip(o["s0"], o["s1"], o["c"], o["w"], 0.0, mats["beam_wood"], o["h"]))


func _build_coins() -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.5
	cm.bottom_radius = 0.5
	cm.height = 0.12
	cm.radial_segments = 12
	for c in course["coins"]:
		c["got"] = false
		var f: Array = track.frame(c["s"])
		var n: Vector3 = -Track.radial(f, c["a"])
		var t: Vector3 = f[1]
		var base := Basis(n, t, n.cross(t).normalized())
		var mi := _mesh(cm, mats["coin"], world_root)
		var r: float = minf(track.sr(c["s"], c["a"]), 1.5) - 0.14 - c["h"]
		mi.global_transform = Transform3D(base, track.point(c["s"], c["a"], r))
		c["node"] = mi
		c["n"] = n
		c["base"] = base


func _build_finish() -> void:
	var L: float = course["len"]
	world_root.add_child(track.arc_block(L, L + 0.4, PI, PI, 0.86, 1.0, mats["checker"], "all", true))
	world_root.add_child(track.arc_block(L + 0.1, L + 0.3, PI, 0.9, 0.55, 0.86, mats["checker"], "all", true))
	for a in [-1.9, 1.9, PI]:
		var fl := OmniLight3D.new()
		world_root.add_child(fl)
		fl.global_position = track.point(L + 0.5, a, 0.7)
		fl.omni_range = 10.0
		fl.light_energy = 3.0
		fl.light_color = Color(1.0, 0.95, 0.8)
		zone_lights.append({"node": fl, "s": L})


## The huge vertical shaft at the end of Grand Outfall: dive, dodge beams, land on the target
func _build_shaft() -> void:
	var L: float = course["len"]
	var f: Array = track.frame(L)
	var fwd: Vector3 = Vector3(f[1].x, 0.0, f[1].z).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var E: Vector3 = f[0]
	var R := 17.0
	var C := E + fwd * 15.0
	var top := E.y + 22.0
	var bottom := E.y - 165.0
	track.mouth(world_root, L, tube_mats["steel"], false)
	# walls
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var sides := 28
	var y := top
	while y > bottom:
		var y2 := maxf(bottom, y - 10.0)
		for j in sides:
			var a0 := TAU * j / sides
			var a1 := TAU * (j + 1) / sides
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var p := [C + d0 * R + Vector3.UP * (y - C.y), C + d1 * R + Vector3.UP * (y - C.y),
				C + d1 * R + Vector3.UP * (y2 - C.y), C + d0 * R + Vector3.UP * (y2 - C.y)]
			var shade := 0.7 + 0.3 * sin(y * 0.05 + j)
			Track._add_quad(v, n, uv, col, p, -(d0 + d1).normalized(),
				[Vector2(float(j) / sides * 12.0, y * 0.1), Vector2(float(j + 1) / sides * 12.0, y * 0.1),
				 Vector2(float(j + 1) / sides * 12.0, y2 * 0.1), Vector2(float(j) / sides * 12.0, y2 * 0.1)], Color(shade, shade, shade))
		y = y2
	var wall := MeshInstance3D.new()
	wall.mesh = Track._mesh_from(v, n, uv, col)
	wall.material_override = tube_mats["steel"]
	world_root.add_child(wall)
	# helix of lamps down the walls + a few real lights
	var lm := _glow_mat(LV["lamp"], 3.0)
	for i in 46:
		var a := i * 0.55
		var p2 := C + Vector3(cos(a), 0, sin(a)) * (R - 0.2) + Vector3.UP * (top - 10.0 - i * 3.5 - C.y)
		_box(Vector3(0.8, 0.4, 0.8), lm, Transform3D(Basis(), p2))
	for i in 5:
		var ol := OmniLight3D.new()
		world_root.add_child(ol)
		ol.global_position = C + Vector3.UP * (top - 30.0 - i * 30.0 - C.y)
		ol.omni_range = 60.0
		ol.light_energy = 4.0
		ol.light_color = LV["lamp"]
		ol.light_volumetric_fog_energy = 2.0
		zone_lights.append({"node": ol, "s": L})
	# beams to dodge on the way down
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var beams := []
	for i in 5:
		var by := top - 45.0 - i * 24.0
		var ang := rng.randf() * PI
		var dir := Vector3(cos(ang), 0, sin(ang))
		var bb := Basis(Vector3.UP, -ang)
		_box(Vector3(R * 2.0, 1.4, 2.6), mats["rust"], Transform3D(bb, Vector3(C.x, by, C.z)))
		beams.append({"y": by, "dir": dir, "passed": false})
	# pool + landing target
	var pool := CylinderMesh.new()
	pool.top_radius = R
	pool.bottom_radius = R
	pool.height = 0.4
	pool.radial_segments = 28
	var pl := _mesh(pool, mats["water"], world_root)
	pl.global_position = Vector3(C.x, bottom, C.z)
	var toff := Vector3(rng.randf_range(-7.0, 7.0), 0, rng.randf_range(-7.0, 7.0))
	var tgt := Vector3(C.x, bottom + 0.35, C.z) + toff
	var tor := TorusMesh.new()
	tor.inner_radius = 3.4
	tor.outer_radius = 4.4
	tor.rings = 24
	var tn := _mesh(tor, mats["target"], world_root)
	tn.global_position = tgt
	var tl := OmniLight3D.new()
	world_root.add_child(tl)
	tl.global_position = tgt + Vector3.UP * 4.0
	tl.omni_range = 30.0
	tl.light_energy = 5.0
	tl.light_color = Color(0.4, 0.6, 1.0)
	zone_lights.append({"node": tl, "s": L})
	# water streaks pouring down the walls
	var falls := _particles(world_root, 140, 6.0, mats["drop"], 0.12)
	falls.global_position = Vector3(C.x, top - 2.0, C.z)
	falls.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	falls.emission_ring_axis = Vector3.UP
	falls.emission_ring_radius = R - 0.6
	falls.emission_ring_inner_radius = R - 1.5
	falls.emission_ring_height = 1.0
	falls.direction = Vector3.DOWN
	falls.spread = 2.0
	falls.initial_velocity_min = 20.0
	falls.initial_velocity_max = 28.0
	falls.gravity = Vector3(0, -10, 0)
	outflow_fx.append({"fx": falls, "snd": _loop3d("pour", Vector3(C.x, top - 40.0, C.z), 6.0, 30.0, 0.6), "s": L})
	shaft = {"C": C, "R": R, "top": top, "bottom": bottom, "beams": beams, "target": tgt, "fwd": fwd, "right": right, "moon": shaft.get("moon", false)}


# ================================================================== flow
func _reset_player() -> void:
	ps = 4.0; pth = 0.0; pom = 0.0; ph = 0.0; pvh = 0.0; pv = 0.0
	hearts = 3; invul = 0.0; coins_got = 0; hits = 0; boost = 0.0
	fall_t = 0.0; fall_o = null; squash = 0.0; jbuf = 0.0; coy = 0.0
	ptime = 0.0; combo = 0; combo_t = 0.0; flap = 0.0
	roll = 0.0; shake = 0.0; flash = 0.0; wet = 0.0; slime_t = 0.0; ramp_ref = null
	was_deck = false; deck_cam = 0.0; bullseye = false


func _to_title() -> void:
	build_level(0, false)
	_reset_player()
	ps = 30.0
	state = "title"
	menu_sel = mini(int(save["unlocked"]), LEVELS.size() - 1)


func start_level(i: int) -> void:
	build_level(i, true)
	_reset_player()
	state = "count"
	count_t = 3.2
	last_count = 4


func _pause() -> void:
	paused_from = state
	state = "paused"
	menu_sel = 0


func _game_over() -> void:
	state = "over"
	over_t = 0.0
	menu_sel = 0
	sfx("over", -4.0, 1.0, "Master")


func _show_results() -> void:
	state = "results"
	menu_sel = 0
	var tot: int = course["coins"].size()
	var ratio := float(coins_got) / maxf(1.0, tot) + (0.15 if bullseye else 0.0)
	last_stars = 1 + (1 if ratio >= 0.5 else 0) + (1 if ratio >= 0.85 else 0)
	var prev := int(save["best"][li])
	new_best = last_stars > prev
	save["best"][li] = maxi(prev, last_stars)
	save["unlocked"] = maxi(int(save["unlocked"]), mini(LEVELS.size() - 1, li + 1))
	_write_save()


func _menu_items() -> Array:
	match state:
		"paused": return ["Resume", "Restart", "Quit to menu"]
		"over": return ["Try again", "Quit to menu"]
		"results":
			if li < LEVELS.size() - 1:
				return ["Next level", "Retry", "Quit to menu"]
			return ["Retry", "Quit to menu"]
	return []


func _handle_input() -> void:
	if Input.is_action_just_pressed("mute"):
		muted = not muted
		AudioServer.set_bus_mute(0, muted)
	if Input.is_action_just_pressed("fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	var n := LEVELS.size()
	match state:
		"title":
			if Input.is_action_just_pressed("ui_up"):
				menu_sel = (menu_sel + n - 1) % n
				sfx("beep", -14.0, 1.5, "Master")
			if Input.is_action_just_pressed("ui_down"):
				menu_sel = (menu_sel + 1) % n
				sfx("beep", -14.0, 1.5, "Master")
			if Input.is_action_just_pressed("ui_accept"):
				if menu_sel <= int(save["unlocked"]):
					start_level(menu_sel)
				else:
					sfx("clang", -12.0, 2.0, "Master")
			if Input.is_action_just_pressed("ui_cancel"):
				get_tree().quit()
		"play", "count", "dive":
			if Input.is_action_just_pressed("pause"):
				_pause()
			elif state == "play" and Input.is_action_just_pressed("jump"):
				jbuf = 0.13
		"paused", "over", "results":
			if state == "over" and over_t < 1.0:
				return
			if state == "paused" and Input.is_action_just_pressed("pause"):
				state = paused_from
				return
			var items := _menu_items()
			if Input.is_action_just_pressed("ui_up"):
				menu_sel = (menu_sel + items.size() - 1) % items.size()
				sfx("beep", -14.0, 1.5, "Master")
			if Input.is_action_just_pressed("ui_down"):
				menu_sel = (menu_sel + 1) % items.size()
				sfx("beep", -14.0, 1.5, "Master")
			if Input.is_action_just_pressed("ui_accept"):
				var it: String = items[menu_sel]
				match it:
					"Resume": state = paused_from
					"Restart", "Retry", "Try again": start_level(li)
					"Next level": start_level(li + 1)
					"Quit to menu": _to_title()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and (state == "play" or state == "count" or state == "dive"):
		_pause()


# ================================================================== frame
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	T += dt
	_handle_input()
	match state:
		"title":
			ps += 6.5 * dt
			pth = sin(T * 0.45) * 0.6
			pv = 6.5
			if ps > float(LV["len"]) - 10.0:
				ps = 30.0
		"count":
			count_t -= dt
			var n := int(ceil(count_t - 0.2))
			if n != last_count:
				last_count = n
				sfx("beep" if n > 0 else "go", -6.0, 1.0, "Master")
			if count_t <= 0.0:
				state = "play"
		"play", "finish":
			_physics(dt)
		"dive":
			_dive(dt)
		"landed":
			land_t += dt
			if land_t > 2.0:
				_show_results()
		"over":
			over_t += dt
	if autotest:
		_autotest(dt)
	if state != "paused":
		if state == "dive" or state == "landed":
			_update_dive_camera(dt)
		else:
			_update_camera(dt)
			_update_glob(dt)
		_update_world_fx(dt)
	_update_audio(dt)
	hud.queue_redraw()


func _debris_angle(o: Dictionary) -> float:
	return o["c0"] + o["amp"] * sin(o["om"] * T + o["ph"])


func _gusher_on(o: Dictionary) -> bool:
	return fmod(T + o["ph"], o["period"]) < o["on"]


func _physics(dt: float) -> void:
	var fin := state == "finish"
	if fall_t > 0.0:
		fall_t -= dt
		ph -= dt * 2.8
		if fall_t <= 0.0:
			_after_fall()
		return
	if not fin:
		ptime += dt
	var deck: bool = track.in_planks(ps)
	if deck and not was_deck and ph <= 0.01:
		pvh = 1.8   # thrown out of the pipe onto the boards
		ph = 0.01
		sfx("creak", -6.0, randf_range(0.8, 1.1))
	was_deck = deck
	var target: float = float(LV["speed"]) * (1.0 + (0.15 if Input.is_action_pressed("faster") else 0.0) - (0.3 if Input.is_action_pressed("brake") else 0.0))
	target += ps / float(course["len"]) * 0.8
	target += maxf(0.0, -track.slope(ps) - float(LV["grade"])) * 7.0
	if deck:
		target *= 0.85
	if boost > 0.0:
		boost -= dt
		target *= 1.35
	slime_t -= dt
	if slime_t > 0.0:
		target *= 0.3
		pv -= pv * 2.2 * dt
	if fin:
		target = 3.5
	pv += (target - pv) * minf(1.0, dt * (1.3 if pv < target else 2.4))
	ps += pv * dt

	var steer := 0.0 if fin else Input.get_axis("left", "right")
	var acc: float
	if ph <= 0.0:
		if deck:
			acc = steer * 11.0   # flat boards: no pull back to the middle
		else:
			acc = steer * 16.0 - 10.0 * sin(pth) - track.curv(ps) * pv * pv * 1.1
	else:
		acc = steer * 7.0
	pom += acc * dt
	pom *= exp(-(1.0 if ph > 0.0 else (4.0 if deck else 2.6)) * dt)
	pth += pom * dt
	var lim := MAXTH
	if track.in_chamber(ps):
		lim = MAXTH_HALL
	elif deck:
		lim = Track.deck_edge() + 0.3
	if absf(pth) > lim:
		pth = signf(pth) * lim
		pom = 0.0
	flap += (steer - flap) * minf(1.0, dt * 5.0)

	jbuf -= dt
	coy -= dt
	if jbuf > 0.0 and coy > 0.0 and not fin:
		pvh = JUMPV
		ph = 0.001
		jbuf = 0.0
		coy = 0.0
		ramp_ref = null
		sfx("jump", -8.0, randf_range(0.95, 1.05), "Master")
	if ph > 0.0 or pvh > 0.0:
		pvh -= GRAV * dt
		ph += pvh * dt
		if ph <= 0.0:
			ph = 0.0
			pvh = 0.0
			squash = 1.0
			if ramp_ref == null:
				if deck:
					sfx("creak", -10.0, randf_range(0.9, 1.2))
				else:
					sfx("splash", -6.0 if absf(pth) < WA else -12.0, randf_range(0.9, 1.15))
	if ph <= 0.0:
		coy = 0.1
	invul -= dt
	squash *= exp(-8.0 * dt)
	combo_t -= dt
	if combo_t <= 0.0:
		combo = 0
	wet = maxf(0.0, wet - dt * 0.7)

	# off the side of a deck
	if deck and ph <= 0.0 and absf(pth) > Track.deck_edge() - 0.01:
		_fall({"s1": ps + 3.0, "w": 9.0})
		return

	for o in course["obs"]:
		if o["s0"] > ps + 0.3:
			break
		if o["s1"] < ps - 0.3:
			continue
		if not (ps > o["s0"] - 0.1 and ps < o["s1"] + 0.1):
			continue
		var d := absf(Track.ang_diff(pth, o["c"]))
		match o["type"]:
			"gap":
				if ph <= 0.0 and ps > o["s0"] + 0.15 and ps < o["s1"] - 0.1 and d < o["w"] - 0.04:
					_fall(o)
					return
			"boost":
				if ph < 0.05 and d < o["w"] + 0.05 and boost < 1.4:
					boost = 1.7
					flash = 0.25
					flash_col = Color(0.6, 0.85, 0.85)
					sfx("boost", -3.0, 1.0, "Master")
			"fan":
				var rot: float = o["ph"] + o["om"] * T
				for k in 3:
					if absf(Track.ang_diff(pth, rot + k * TAU / 3.0)) < o["bw"] + 0.07 and invul <= 0.0:
						_hit(o)
						break
			"debris":
				var dc := absf(Track.ang_diff(pth, _debris_angle(o)))
				if dc < o["w"] + 0.07 and ph < o["h"] and invul <= 0.0:
					_hit(o)
			"beam":
				var base_r := minf(track.sr(ps, pth), 1.5)
				var py := -cos(pth) * (base_r - ph)
				var top := py + 0.2 * maxf(cos(pth), 0.3)
				if top > o["y0"] and py < o["y1"] and invul <= 0.0:
					_hit(o)
			"gusher":
				if _gusher_on(o) and ph < 0.7:
					pom -= signf(o["c"]) * 10.0 * dt
					pv *= exp(-0.6 * dt)
					wet = 1.0
			"slime":
				if ph <= 0.02 and d < o["w"]:
					if slime_t <= 0.0:
						sfx("squelch", -4.0, randf_range(0.8, 1.1))
					slime_t = 0.15
			"ramp":
				if d < o["w"] and ph <= o["h"] + 0.03 and pvh <= 0.5:
					var u := clampf((ps - o["s0"]) / (o["s1"] - o["s0"]), 0.0, 1.0)
					ph = u * o["h"]
					pvh = 0.0
					ramp_ref = o
			"slot_dummy":
				pass
			_:
				if d < o["w"] + 0.06 and ph < o["h"] and invul <= 0.0:
					_hit(o)
					if state != "play" and state != "finish":
						return
		if state != "play" and state != "finish":
			return
	if ramp_ref != null and ps >= ramp_ref["s1"]:
		pvh = pv * 0.62 + 0.4   # launch: only enough speed clears the gap ahead
		ph = ramp_ref["h"] + 0.01
		ramp_ref = null
		sfx("jump", -6.0, 0.8, "Master")
	elif ramp_ref != null and ps < ramp_ref["s0"] - 0.2:
		ramp_ref = null

	for c in course["coins"]:
		if c["got"] or absf(c["s"] - ps) > 0.45:
			continue
		if absf(Track.ang_diff(pth, c["a"])) < 0.25 and absf(ph - c["h"]) < 0.3:
			c["got"] = true
			c["node"].visible = false
			coins_got += 1
			combo += 1
			combo_t = 1.2
			sfx("coin", -9.0, pow(1.05, mini(combo, 12)), "Master")
			sparkle.restart()

	if not fin and ps >= float(course["len"]) - (0.5 if LV.get("dive", false) else 0.0):
		if LV.get("dive", false) and not shaft.is_empty():
			_start_dive()
			return
		state = "finish"
		fin_t = 0.0
		sfx("finish", -4.0, 1.0, "Master")
	if state == "finish":
		fin_t += dt
		if fin_t > 1.8:
			_show_results()


func _hit(o: Dictionary) -> void:
	hearts -= 1
	hits += 1
	invul = 1.6
	pv *= 0.45
	shake = 1.0
	flash = 0.6
	flash_col = Color(0.9, 0.35, 0.2)
	sfx("clang", -2.0, randf_range(0.85, 1.1))
	sparks.restart()
	var dir := signf(Track.ang_diff(pth, o["c"]))
	if dir == 0.0:
		dir = 1.0 if randf() < 0.5 else -1.0
	pom = dir * 3.5
	if hearts <= 0:
		_game_over()


func _fall(o: Dictionary) -> void:
	fall_t = 1.0
	fall_o = o
	pv = 0.0
	ramp_ref = null
	sfx("fall", -4.0, 1.0)


func _after_fall() -> void:
	hearts -= 1
	hits += 1
	if hearts <= 0:
		_game_over()
		return
	ps = fall_o["s1"] + 1.2
	ph = 0.0
	pvh = 0.0
	pom = 0.0
	if fall_o["w"] > 3.0:
		pth = 0.0
	invul = 2.0
	pv = float(LV["speed"]) * 0.6
	fall_o = null
	flash = 0.8
	flash_col = Color(1, 1, 1)
	was_deck = track.in_planks(ps)


# ------------------------------------------------------------------ dive
func _start_dive() -> void:
	state = "dive"
	var f: Array = track.frame(ps)
	dive_pos = glob.global_position
	dive_vel = f[1] * (pv * K * 0.8) + Vector3.UP * 3.0
	for b in shaft["beams"]:
		b["passed"] = false
	sfx("fall", -2.0, 0.6)


func _dive(dt: float) -> void:
	ptime += dt
	var fwd: Vector3 = shaft["fwd"]
	var right: Vector3 = shaft["right"]
	var inp := Vector2(Input.get_axis("left", "right"), Input.get_axis("brake", "faster"))
	var hv := Vector3(dive_vel.x, 0, dive_vel.z)
	hv += (right * inp.x + fwd * inp.y) * 34.0 * dt
	hv *= exp(-1.7 * dt)
	dive_vel = Vector3(hv.x, maxf(-46.0, dive_vel.y - 30.0 * dt), hv.z)
	dive_pos += dive_vel * dt
	var C: Vector3 = shaft["C"]
	var off := Vector3(dive_pos.x - C.x, 0, dive_pos.z - C.z)
	var maxr: float = shaft["R"] - 1.5
	if off.length() > maxr:
		off = off.normalized() * maxr
		dive_pos = Vector3(C.x + off.x, dive_pos.y, C.z + off.z)
		dive_vel -= off.normalized() * off.normalized().dot(dive_vel) * 1.5
	invul -= dt
	for b in shaft["beams"]:
		if b["passed"] or dive_pos.y > b["y"] + 0.8:
			continue
		b["passed"] = true
		var dir: Vector3 = b["dir"]
		var rel := Vector3(dive_pos.x - C.x, 0, dive_pos.z - C.z)
		var dist := absf(rel.cross(dir).y)
		if dist < 1.3 + 0.6 and invul <= 0.0:
			hearts -= 1
			hits += 1
			invul = 1.0
			shake = 1.0
			flash = 0.6
			flash_col = Color(0.9, 0.35, 0.2)
			sfx("clang", 0.0, 0.8)
			if hearts <= 0:
				_game_over()
				return
	if dive_pos.y <= float(shaft["bottom"]) + 0.6:
		var tg: Vector3 = shaft["target"]
		bullseye = Vector2(dive_pos.x - tg.x, dive_pos.z - tg.z).length() < 4.6
		state = "landed"
		land_t = 0.0
		sfx("splash", 4.0, 0.6)
		sfx("finish", -4.0, 1.0, "Master")
		flash = 0.5
		flash_col = Color(0.7, 0.8, 1.0)
		splash.restart()
	glob.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, fwd) * Basis(Vector3(0, 0, 1), sin(T * 3.0) * 0.4), dive_pos)


func _update_dive_camera(dt: float) -> void:
	var fwd: Vector3 = shaft["fwd"]
	var pos := dive_pos + Vector3.UP * 9.0 - fwd * 3.0
	shake = maxf(0.0, shake - dt * 2.0)
	pos += Vector3(sin(T * 37.0), 0.0, sin(T * 43.0)) * shake * 0.4
	cam.look_at_from_position(pos, dive_pos + Vector3.DOWN * 30.0 + fwd * 2.0, fwd)
	fov = lerpf(fov, 80.0, minf(1.0, dt * 2.0))
	cam.fov = fov
	flash = maxf(0.0, flash - dt * 2.2)
	sf = clampf(-dive_vel.y / 46.0, 0.0, 1.0)
	post_mat.set_shader_parameter("blur", sf * 0.03)
	post_mat.set_shader_parameter("aberration", flash * 0.02)
	post_mat.set_shader_parameter("flash", flash * 0.55)
	post_mat.set_shader_parameter("flash_color", flash_col)
	post_mat.set_shader_parameter("wet", 0.0)
	streak_mat.albedo_color.a = sf * 0.4
	streaks.emitting = sf > 0.2


# ================================================================== camera + visuals
func _surf(s: float, a: float) -> float:
	var r: float = track.sr(s, a)
	if r > 5.0:
		r = Track.DECK_Y / maxf(cos(a), 0.3)
	return r


func _update_camera(dt: float) -> void:
	var deck: bool = track.in_planks(ps)
	deck_cam = lerpf(deck_cam, 1.0 if deck else 0.0, minf(1.0, dt * 2.5))
	roll += (pth * 0.8 * (1.0 - deck_cam) - roll) * minf(1.0, dt * 7.0)
	sf = clampf((pv - 7.0) / 6.0, 0.0, 1.0)
	var boosting := boost > 0.0 and state == "play"
	var camd := CAMD + sf * 0.12 + deck_cam * 0.5
	var k: float = track.scale_at(ps - camd)
	var f: Array = track.frame(ps - camd)
	var cr: float = _surf(ps - camd, roll) - lerpf(0.6 * k, 1.05, deck_cam) - maxf(0.0, ph) * 0.45
	var pos: Vector3 = f[0] + Track.radial(f, roll) * (cr * K)
	var tf: Array = track.frame(ps + 4.0)
	var tgt: Vector3 = tf[0] + Track.radial(tf, pth * 0.85 * (1.0 - deck_cam)) * ((_surf(ps + 4.0, pth) - 0.36 * k - ph * 0.3) * K)
	var up: Vector3 = -Track.radial(f, roll)
	shake = maxf(0.0, shake - dt * 2.0)
	var amp := shake * 0.45 + sf * 0.05 + (0.06 if boosting else 0.0)
	pos += Vector3(sin(T * 37.0) + sin(T * 61.0) * 0.5, sin(T * 43.0 + 1.0) + sin(T * 71.0) * 0.5, 0.0) * amp * 0.6
	cam.look_at_from_position(pos, tgt, up)
	var target_fov := 68.0 + sf * 12.0 + (4.0 if boosting else 0.0) + deck_cam * 4.0
	fov = lerpf(fov, target_fov, minf(1.0, dt * 2.0))
	cam.fov = fov
	flash = maxf(0.0, flash - dt * 2.2)
	post_mat.set_shader_parameter("blur", sf * 0.022 + (0.014 if boosting else 0.0))
	post_mat.set_shader_parameter("aberration", sf * 0.003 + (0.005 if boosting else 0.0) + flash * 0.02)
	post_mat.set_shader_parameter("flash", flash * 0.55)
	post_mat.set_shader_parameter("flash_color", flash_col)
	post_mat.set_shader_parameter("wet", wet)
	var sa := clampf((sf - 0.3) * 0.4 + (0.2 if boosting else 0.0), 0.0, 0.6)
	streak_mat.albedo_color.a = sa
	streaks.emitting = sa > 0.04


func _update_glob(dt: float) -> void:
	var r: float = _surf(ps, pth) - ph
	var b: Basis = track.wall_basis(ps, pth)
	glob.global_transform = Transform3D(b, track.point(ps, pth, r))
	glob_squash.rotation = Vector3(0.0, 0.0, -flap * 0.3 - pom * 0.03)
	var st := 0.14 if pvh > 1.0 else 0.0
	var sc := Vector3(1.0 + squash * 0.3 - st * 0.5, 1.0 - squash * 0.28 + st, 1.0 + squash * 0.3 - st * 0.5)
	if fall_t > 0.0:
		sc *= maxf(0.05, fall_t)
	glob_squash.scale = sc
	glob.visible = not (invul > 0.0 and fmod(T * 14.0, 2.0) < 1.0 and fall_t <= 0.0)
	for an in antennae:
		var piv: Node3D = an[0]
		var sd: float = an[1]
		piv.rotation = Vector3(0.2 + sf * 0.5 + sin(T * 9.0 + sd) * 0.12, 0.0, -sd * 0.35 - flap * 0.3)
	glob_tail.rotation = Vector3(sin(T * 21.0) * 0.15, -flap * 0.7 + sin(T * 17.0) * 0.3, 0.0)
	var playing := state == "play" or state == "title" or state == "count"
	splash.emitting = playing and ph <= 0.0 and absf(pth) < WA and pv > 3.0 and fall_t <= 0.0 and not track.in_planks(ps)
	splash.initial_velocity_max = 5.0 + sf * 6.0


func _update_world_fx(dt: float) -> void:
	var lamps: Array = decor["lamps"]
	var first := 0
	while first < lamps.size() and lamps[first]["s"] < ps - 2.0:
		first += 1
	for i in lamp_lights.size():
		var l: OmniLight3D = lamp_lights[i]
		var k := first + i
		if k < lamps.size() and state != "dive" and state != "landed":
			l.visible = true
			l.global_position = lamps[k]["pos"]
			var flick := 1.0
			if k % 4 == 1 and sin(T * 23.0 + k) * sin(T * 7.3 + k * 2.0) > 0.35:
				flick = 0.15
			l.light_energy = 2.6 * flick
		else:
			l.visible = false
	var diving := state == "dive" or state == "landed"
	var endl: float = course["len"]
	for z in zone_lights:
		if diving:
			z["node"].visible = z["s"] >= endl - 0.1
		else:
			z["node"].visible = absf(z["s"] - ps) < 60.0 and z["s"] > ps - 8.0
	for o in outflow_fx:
		var near: bool = absf(o["s"] - ps) < 30.0 or (diving and o["s"] >= endl - 0.1)
		if o["fx"] != null and o["fx"].emitting != near:
			o["fx"].emitting = near
		if near and not o["snd"].playing:
			o["snd"].play()
		elif not near and o["snd"].playing:
			o["snd"].stop()
	var ds := ps + 7.0
	drips.global_transform = Transform3D(track.wall_basis(ds, PI), track.point(ds, PI, minf(track.wall_r(ds, PI), 1.0) * 0.92))
	drips.emitting = not track.in_chamber(ds) and not track.in_planks(ds) and not diving
	# fans
	for fn in fans:
		var node: Node3D = fn["node"]
		if fn["decor"]:
			node.rotate_object_local(Vector3.UP, fn["om"] * dt)
		else:
			var o: Dictionary = fn["o"]
			if absf(o["s0"] - ps) > 60.0:
				continue
			node.global_transform = Transform3D(track.track_basis(o["s0"]) * Basis(Vector3(0, 0, 1), o["ph"] + o["om"] * T), node.global_position)
	# bobbing debris
	for dn in debris_nodes:
		var o2: Dictionary = dn["o"]
		var sm: float = (o2["s0"] + o2["s1"]) * 0.5
		if absf(sm - ps) > 50.0:
			continue
		var a := _debris_angle(o2)
		var bob := sin(T * 2.6 + o2["ph"]) * 0.03
		var b: Basis = track.wall_basis(sm, a)
		var node2: Node3D = dn["node"]
		node2.global_transform = Transform3D(b * Basis(Vector3.UP, T * 0.7 + o2["ph"]) * Basis(Vector3(1, 0, 0), bob * 4.0),
			track.point(sm, a, track.sr(sm, a) - 0.08 + bob))
	# gushers
	for g in gushers:
		var o3: Dictionary = g["o"]
		var on := _gusher_on(o3)
		var near2 := absf(o3["s0"] - ps) < 40.0
		var fx: CPUParticles3D = g["fx"]
		fx.emitting = on and near2
		if on and not g["was"] and near2:
			sfx3d("gush", g["pos"], 2.0, randf_range(0.8, 1.1))
		g["was"] = on
	# spinning coins
	for c in course["coins"]:
		if c["got"]:
			continue
		var cs: float = c["s"]
		if cs < ps - 3.0 or cs > ps + 45.0:
			continue
		if cs < ps - 0.4:
			c["node"].visible = false
			continue
		c["node"].basis = Basis(c["n"], T * 4.0 + cs) * c["base"]
	mats["warn"].albedo_color = Color(0.85, 0.25, 0.15) * (3.0 if fmod(T, 0.6) < 0.3 else 0.4)


func _update_audio(dt: float) -> void:
	var active := state == "play" or state == "finish" or state == "count"
	var deck: bool = track.in_planks(ps)
	var rv := 0.12
	if active:
		rv = 0.3 + sf * 0.6
		if track.scale_at(ps) < 0.9:
			rv *= 1.4   # water roars in the narrow pipes
		if ph > 0.0 or deck:
			rv *= 0.4
	if state == "paused" or state == "results" or state == "over" or state == "dive" or state == "landed":
		rv = 0.0
	rush.volume_db = lerpf(rush.volume_db, linear_to_db(maxf(rv, 0.0001)), minf(1.0, dt * 5.0))
	rush.pitch_scale = 0.75 + pv / 22.0
	var wv := 0.0
	if active:
		wv = sf * 0.35 + (0.3 if boost > 0.0 else 0.0) + (0.25 if deck else 0.0)
	if state == "dive":
		wv = 0.4 + sf * 0.5
	wind.volume_db = lerpf(wind.volume_db, linear_to_db(maxf(wv, 0.0001)), minf(1.0, dt * 4.0))
	wind.pitch_scale = 1.6 + sf * 0.8
	drone.volume_db = -14.0 if state != "paused" else -24.0
	var av := -10.0
	if LV["amb"] == "wind_loop":
		av = -4.0 if deck else -14.0
	amb2.volume_db = av if state != "paused" else av - 10.0
	if state == "paused":
		return
	drip_t -= dt
	if drip_t <= 0.0:
		drip_t = randf_range(0.25, 1.1)
		var s := ps + randf_range(-4.0, 30.0)
		sfx3d("drip", track.point(s, randf_range(-2.5, 2.5), 0.6), -6.0, randf_range(0.6, 1.5))
	amb_t -= dt
	if amb_t <= 0.0:
		var s2 := ps + randf_range(-20.0, 60.0)
		match LV["amb"]:
			"rumble":
				# appliances thumping on the floor above
				amb_t = randf_range(1.8, 4.5)
				sfx("thump", randf_range(-10.0, -4.0), randf_range(0.7, 1.1))
				shake = maxf(shake, 0.18)
			"hum":
				amb_t = randf_range(2.5, 6.0)
				sfx3d("clang", track.point(s2, randf_range(-2.0, 2.0), 0.8), -14.0, randf_range(0.5, 1.2))
			"hiss":
				amb_t = randf_range(3.0, 7.0)
				sfx3d("creak" if randf() < 0.5 else "groan", track.point(s2, PI, 0.5), -6.0, randf_range(0.7, 1.2))
			_:
				amb_t = randf_range(5.0, 12.0)
				sfx3d("groan", track.point(s2, PI, 0.5), -6.0, randf_range(0.7, 1.3))


# ================================================================== HUD
func _txt(s: String, pos: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := ThemeDB.fallback_font
	hud.draw_string_outline(f, pos, s, align, width, size, 5, Color(0, 0, 0, 0.85))
	hud.draw_string(f, pos, s, align, width, size, col)


func _heart(c: Vector2, sz: float, full: bool) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		pts.append(c + Vector2(16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * sz / 16.0)
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	hud.draw_colored_polygon(pts, Color(0.85, 0.3, 0.35) if full else Color(1, 1, 1, 0.12))
	hud.draw_polyline(outline, Color(0.2, 0.0, 0.05, 0.9), 1.5)


func _star(c: Vector2, r: float, on: bool) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	hud.draw_colored_polygon(pts, Color(0.95, 0.75, 0.25) if on else Color(1, 1, 1, 0.15))


func _fmt(t: float) -> String:
	var m := int(t / 60.0)
	var s := t - m * 60.0
	return "%d:%05.2f" % [m, s]


func _draw_hud() -> void:
	var W := hud.size.x
	var H := hud.size.y
	var orange := Color(0.95, 0.58, 0.28)
	var cream := Color(0.96, 0.93, 0.85)
	var muted_c := Color(0.65, 0.7, 0.68)
	if state == "title":
		hud.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.4))
		_txt("DRAINPIPE", Vector2(0, 62), 50, orange, HORIZONTAL_ALIGNMENT_CENTER, W)
		_txt("DASH", Vector2(0, 106), 50, Color(0.92, 0.75, 0.32), HORIZONTAL_ALIGNMENT_CENTER, W)
		_txt("Ride the sewers as Glob. Lean into the bends, hop the gaps, grab the coins.", Vector2(0, 128), 11, muted_c, HORIZONTAL_ALIGNMENT_CENTER, W)
		for i in LEVELS.size():
			var y := 158.0 + i * 33.0
			var locked := i > int(save["unlocked"])
			var sel := i == menu_sel
			var rx := W * 0.5 - 160.0
			hud.draw_rect(Rect2(rx, y - 20, 320, 30), Color(0.95, 0.58, 0.28, 0.25) if sel else Color(0, 0, 0, 0.45))
			if sel:
				hud.draw_rect(Rect2(rx, y - 20, 320, 30), orange, false, 2.0)
			var col := Color(1, 1, 1, 0.35) if locked else cream
			_txt(str(i + 1) + "  " + LEVELS[i]["name"], Vector2(rx + 12, y), 15, col)
			_txt("Clear level %d to unlock" % i if locked else LEVELS[i]["blurb"], Vector2(rx + 30, y + 8), 8, muted_c)
			for st in 3:
				_star(Vector2(rx + 270 + st * 16, y - 5), 6.5, st < int(save["best"][i]))
		_txt("Steer  ARROWS or A/D     Jump  SPACE     Faster / Brake  UP / DOWN     Pause  ESC     Sound  M     Fullscreen  F11", Vector2(0, H - 26), 9, muted_c, HORIZONTAL_ALIGNMENT_CENTER, W)
		_txt("Press ENTER to slide", Vector2(0, H - 10), 13, Color(1, 1, 1, 0.6 + 0.4 * sin(T * 4.0)), HORIZONTAL_ALIGNMENT_CENTER, W)
		return

	for i in 3:
		_heart(Vector2(22 + i * 26, 20), 10.0, i < hearts)
	var ctxt := "%d / %d" % [coins_got, course["coins"].size()]
	_txt(ctxt, Vector2(W - 150, 28), 18, cream, HORIZONTAL_ALIGNMENT_RIGHT, 136)
	hud.draw_circle(Vector2(W - 165 + 150 - 136 - 4, 22), 7.0, Color(0.8, 0.58, 0.15))
	hud.draw_circle(Vector2(W - 165 + 150 - 136 - 4, 22), 4.5, Color(0.95, 0.8, 0.4))
	var bw := 220.0
	var bx := (W - bw) * 0.5
	var pr := clampf(ps / float(course["len"]), 0.0, 1.0)
	hud.draw_rect(Rect2(bx - 2, 12, bw + 4, 10), Color(0, 0, 0, 0.55))
	hud.draw_rect(Rect2(bx, 14, bw * pr, 6), Color(0.45, 0.7, 0.66))
	hud.draw_circle(Vector2(bx + bw * pr, 17), 5.0, orange)
	_txt(_fmt(ptime), Vector2(0, 40), 13, cream, HORIZONTAL_ALIGNMENT_CENTER, W)
	var kmh := pv * K * 3.6
	if state == "dive":
		kmh = dive_vel.length() * 3.6
	var c := Vector2(48, H - 30)
	hud.draw_arc(c, 30, PI * 0.8, PI * 2.2, 24, Color(0, 0, 0, 0.6), 6.0)
	var frac := clampf(kmh / 240.0, 0.0, 1.0)
	var spc := Color(0.45, 0.7, 0.66).lerp(Color(0.9, 0.4, 0.25), frac)
	if frac > 0.01:
		hud.draw_arc(c, 30, PI * 0.8, PI * 0.8 + PI * 1.4 * frac, 24, spc, 4.0)
	_txt("%d" % int(kmh), Vector2(c.x - 40, c.y + 4), 18, cream, HORIZONTAL_ALIGNMENT_CENTER, 80)
	_txt("km/h", Vector2(c.x - 40, c.y + 16), 8, muted_c, HORIZONTAL_ALIGNMENT_CENTER, 80)
	if boost > 0.0 and state == "play":
		_txt("BOOST!", Vector2(0, 64), 20, Color(0.6, 0.85, 0.85, 0.6 + 0.4 * sin(T * 20.0)), HORIZONTAL_ALIGNMENT_CENTER, W)
	if slime_t > 0.0 and state == "play":
		_txt("SLIME!", Vector2(0, 64), 18, Color(0.6, 0.8, 0.35), HORIZONTAL_ALIGNMENT_CENTER, W)
	if combo >= 4 and combo_t > 0.0:
		_txt("x%d STREAK" % combo, Vector2(W - 150, 48), 12, Color(0.95, 0.8, 0.4), HORIZONTAL_ALIGNMENT_RIGHT, 136)

	match state:
		"count":
			var n := int(ceil(count_t - 0.2))
			_txt("LEVEL %d  ·  %s" % [li + 1, LV["name"]], Vector2(0, H * 0.3), 16, muted_c, HORIZONTAL_ALIGNMENT_CENTER, W)
			_txt(str(n) if n > 0 else "GO!", Vector2(0, H * 0.52), 72, Color(0.95, 0.75, 0.3) if n > 0 else Color(0.5, 0.85, 0.8), HORIZONTAL_ALIGNMENT_CENTER, W)
		"play":
			if ptime < 0.6:
				_txt("GO!", Vector2(0, H * 0.52), 72, Color(0.5, 0.85, 0.8, 1.0 - ptime / 0.6), HORIZONTAL_ALIGNMENT_CENTER, W)
		"finish":
			_txt("FINISH!", Vector2(0, H * 0.5), 64, Color(0.95, 0.78, 0.3), HORIZONTAL_ALIGNMENT_CENTER, W)
		"dive":
			_txt("DIVE!  Steer onto the blue target", Vector2(0, 70), 16, Color(0.6, 0.75, 1.0), HORIZONTAL_ALIGNMENT_CENTER, W)
			var depth := clampf((float(shaft["top"]) - dive_pos.y) / (float(shaft["top"]) - float(shaft["bottom"])), 0.0, 1.0)
			hud.draw_rect(Rect2(W - 24, 70, 8, 200), Color(0, 0, 0, 0.5))
			hud.draw_rect(Rect2(W - 24, 70, 8, 200 * depth), Color(0.45, 0.6, 0.95))
		"landed":
			_txt("BULLSEYE!" if bullseye else "SPLASHDOWN!", Vector2(0, H * 0.5), 56, Color(0.6, 0.78, 1.0) if bullseye else Color(0.95, 0.78, 0.3), HORIZONTAL_ALIGNMENT_CENTER, W)
		"paused":
			_panel(W, H, "PAUSED", [])
		"over":
			if over_t > 0.6:
				_panel(W, H, "WASHED OUT!", ["You made it %d%% through %s." % [int(pr * 100.0), LV["name"]]])
		"results":
			var tot: int = course["coins"].size()
			var extra := "Bullseye landing bonus!  " if bullseye else ""
			_panel(W, H, "ALL LEVELS CLEARED!" if li >= LEVELS.size() - 1 else "LEVEL CLEARED!",
				["Coins  %d / %d        Time  %s        Bumps  %d" % [coins_got, tot, _fmt(ptime), hits],
				 extra + ("New best!  " if new_best else "") + ("Perfect run." if last_stars == 3 else "Grab 85% of the coins for three stars.")])
			for st in 3:
				_star(Vector2(W * 0.5 - 30 + st * 30, H * 0.5 - 52), 12.0, st < last_stars)


func _panel(W: float, H: float, title: String, lines: Array) -> void:
	hud.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.45))
	var pw := 380.0
	var phh := 200.0
	var r := Rect2((W - pw) * 0.5, (H - phh) * 0.5, pw, phh)
	hud.draw_rect(r, Color(0.09, 0.1, 0.1, 0.92))
	hud.draw_rect(r, Color(0.35, 0.38, 0.36), false, 2.0)
	for p in [r.position + Vector2(8, 8), r.position + Vector2(pw - 8, 8), r.position + Vector2(8, phh - 8), r.position + Vector2(pw - 8, phh - 8)]:
		hud.draw_circle(p, 3.0, Color(0.5, 0.52, 0.5))
	_txt(title, Vector2(0, r.position.y + 40), 28, Color(0.95, 0.75, 0.3), HORIZONTAL_ALIGNMENT_CENTER, W)
	var y := r.position.y + 92
	for l in lines:
		_txt(l, Vector2(0, y), 10, Color(0.78, 0.8, 0.78), HORIZONTAL_ALIGNMENT_CENTER, W)
		y += 16
	var items := _menu_items()
	var iy := r.position.y + phh - 16 - items.size() * 20
	for i in items.size():
		var sel := i == menu_sel
		_txt(("> " + items[i] + " <") if sel else items[i], Vector2(0, iy + i * 20), 15, Color(0.95, 0.6, 0.3) if sel else Color(0.9, 0.9, 0.85), HORIZONTAL_ALIGNMENT_CENTER, W)
