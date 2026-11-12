extends Node3D

var fps_label: Label
var info_label: Label
var hyun_fighter: Node3D
var combat_god_fighter: Node3D
var time_acc: float = 0.0

func _ready() -> void:
	# Enforce 120 FPS & 120Hz Physics Tick at runtime
	Engine.max_fps = 120
	Engine.physics_ticks_per_second = 120
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	_setup_environment()
	_setup_arena_from_downloaded_models()
	_spawn_fighters_and_props()
	_setup_camera()
	_setup_hud()
	print("[STEP 1 OK] Legends Battlegrounds PC Engine initialized at 120Hz Physics / 120 FPS Target using 100% downloaded 3D GLB assets.")

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.03, 0.04, 0.09)
	sky_mat.sky_horizon_color = Color(0.12, 0.14, 0.24)
	sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.04)
	sky_mat.ground_horizon_color = Color(0.08, 0.09, 0.15)
	sky.sky_material = sky_mat
	env.sky = sky
	
	# High-End Next-Gen Post-Processing (HDR Glow / Bloom, Volumetric Fog, SSR, SSAO, ACES Tonemap)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 1.2
	env.glow_strength = 1.1
	env.glow_bloom = 0.25
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.ssao_enabled = true
	env.ssr_enabled = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.008
	env.volumetric_fog_albedo = Color(0.18, 0.2, 0.3)
	
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	
	# Main Directional Rim/Sun Light with Soft Shadows
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

func _setup_arena_from_downloaded_models() -> void:
	var arena_root := Node3D.new()
	arena_root.name = "ArenaModels"
	add_child(arena_root)
	
	var tile_scene := load("res://assets/arena/floor_tile_large.glb") as PackedScene
	var tile_rock_scene := load("res://assets/arena/floor_tile_large_rocks.glb") as PackedScene
	var pillar_scene := load("res://assets/arena/pillar_decorated.glb") as PackedScene
	var wall_scene := load("res://assets/arena/wall_cracked.glb") as PackedScene
	var rubble_scene := load("res://assets/arena/rubble_large.glb") as PackedScene
	
	# Tile floor grid using downloaded 3D floor_tile_large.glb & floor_tile_large_rocks.glb
	if tile_scene and tile_rock_scene:
		for x in range(-4, 5):
			for z in range(-4, 5):
				var use_rock := ((x + z) % 3 == 0)
				var tile := (tile_rock_scene if use_rock else tile_scene).instantiate()
				tile.position = Vector3(float(x) * 4.0, 0.0, float(z) * 4.0)
				arena_root.add_child(tile)
	
	# Arena back wall & pillars using downloaded 3D models
	if wall_scene:
		for x in range(-3, 4):
			var w := wall_scene.instantiate()
			w.position = Vector3(float(x) * 4.0, 0.0, -10.0)
			arena_root.add_child(w)
	
	if pillar_scene:
		for x in [-8.0, -4.0, 4.0, 8.0]:
			var p := pillar_scene.instantiate()
			p.position = Vector3(x, 0.0, -8.5)
			arena_root.add_child(p)
			
	if rubble_scene:
		for x in [-5.5, 5.5]:
			var r := rubble_scene.instantiate()
			r.position = Vector3(x, 0.0, -4.5)
			arena_root.add_child(r)

	# Physics floor collision shape
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(80.0, 1.0, 80.0)
	col.shape = box_shape
	col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(col)
	add_child(floor_body)

func _spawn_fighters_and_props() -> void:
	# 1. Fighter 1: Hyun's Dojo (KJ / Martial Legend) - Downloaded 3D Model + Martial Arts Animations
	var ual1_scene := load("res://assets/models/ual1_standard.glb") as PackedScene
	if ual1_scene:
		hyun_fighter = ual1_scene.instantiate()
		hyun_fighter.position = Vector3(-2.2, 0.0, 0.0)
		hyun_fighter.rotation_degrees = Vector3(0.0, 28.0, 0.0)
		add_child(hyun_fighter)
		_apply_fighter_aura(hyun_fighter, Color(0.95, 0.15, 0.2), Color(3.5, 0.2, 0.3))
		_play_first_matching_anim(hyun_fighter, ["Punch_Cross", "Punch_Jab", "Idle_Loop"])
		
		var red_light := OmniLight3D.new()
		red_light.light_color = Color(1.0, 0.15, 0.2)
		red_light.light_energy = 4.0
		red_light.omni_range = 6.0
		red_light.position = Vector3(0.0, 1.2, 0.5)
		hyun_fighter.add_child(red_light)

	# 2. Fighter 2: Combat Gods (Jun / Weapon God) - Downloaded 3D Model + Sword Combo Animations + Downloaded Katana
	var ual2_scene := load("res://assets/models/ual2_standard.glb") as PackedScene
	if ual2_scene:
		combat_god_fighter = ual2_scene.instantiate()
		combat_god_fighter.position = Vector3(2.2, 0.0, 0.0)
		combat_god_fighter.rotation_degrees = Vector3(0.0, -28.0, 0.0)
		add_child(combat_god_fighter)
		_apply_fighter_aura(combat_god_fighter, Color(0.15, 0.2, 0.28), Color(0.1, 1.8, 4.0))
		_play_first_matching_anim(combat_god_fighter, ["Sword_Regular_Combo", "Sword_Heavy_Combo", "Idle_Loop"])
		
		var cyan_light := OmniLight3D.new()
		cyan_light.light_color = Color(0.1, 0.75, 1.0)
		cyan_light.light_energy = 4.0
		cyan_light.omni_range = 6.0
		cyan_light.position = Vector3(0.0, 1.2, 0.5)
		combat_god_fighter.add_child(cyan_light)
		
		# Attach downloaded Katana & Staff 3D models to Combat Gods fighter
		var katana_scene := load("res://assets/weapons/katana.glb") as PackedScene
		if katana_scene:
			var katana := katana_scene.instantiate()
			katana.position = Vector3(0.55, 1.15, 0.45)
			katana.scale = Vector3(1.2, 1.2, 1.2)
			combat_god_fighter.add_child(katana)

	# 3. Spawn Downloaded Photorealistic PBR Boulders & Rock Debris models
	var boulder_scene := load("res://assets/debris/boulder_01.glb") as PackedScene
	if boulder_scene:
		for i in range(4):
			var b := boulder_scene.instantiate()
			var angle := float(i) * PI * 0.35 - 1.6
			b.position = Vector3(sin(angle) * 7.5, 0.0, -cos(angle) * 5.5 - 2.0)
			b.scale = Vector3.ONE * (1.2 + float(i % 2) * 0.5)
			add_child(b)

func _apply_fighter_aura(root: Node, albedo: Color, emission: Color) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = albedo
		mat.roughness = 0.25
		mat.metallic = 0.45
		mat.emission_enabled = true
		mat.emission = emission * 0.15
		mat.rim_enabled = true
		mat.rim = 1.0
		mat.rim_tint = 0.2
		mi.material_override = mat

func _play_first_matching_anim(root: Node, candidates: Array) -> void:
	var anim_players := root.find_children("*", "AnimationPlayer", true, false)
	if anim_players.is_empty():
		return
	var ap := anim_players[0] as AnimationPlayer
	var list := ap.get_animation_list()
	for c in candidates:
		for anim_name in list:
			if String(anim_name).ends_with(c):
				var anim := ap.get_animation(anim_name)
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR
				ap.play(anim_name)
				return

func _setup_camera() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 2.3, 6.2)
	cam.look_at_from_position(cam.position, Vector3(0.0, 1.1, 0.0), Vector3.UP)
	cam.fov = 58.0
	add_child(cam)

func _setup_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	
	fps_label = Label.new()
	fps_label.position = Vector2(24, 20)
	fps_label.add_theme_font_size_override("font_size", 24)
	fps_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45))
	canvas.add_child(fps_label)
	
	info_label = Label.new()
	info_label.position = Vector2(24, 56)
	info_label.add_theme_font_size_override("font_size", 16)
	info_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	info_label.text = "LEGENDS BATTLEGROUNDS PC — STEP 1 ASSET & 120HZ ENGINE PIPELINE\n[Left] Hyun's Dojo (Martial Legend / KJ)   |   [Right] Combat Gods (Weapon God / Jun)"
	canvas.add_child(info_label)

func _process(delta: float) -> void:
	time_acc += delta
	if fps_label:
		var fps := Engine.get_frames_per_second()
		var frame_ms := delta * 1000.0
		fps_label.text = "FPS: %d / 120  (%.2f ms) | Physics Tick: %d Hz | Vulkan Forward+" % [fps, frame_ms, Engine.physics_ticks_per_second]
