extends Node3D

const BattlegroundsArenaScript := preload("res://scripts/BattlegroundsArena.gd")
const PostProcessControllerScript := preload("res://scripts/PostProcessController.gd")
const BattleCameraScript := preload("res://scripts/BattleCamera.gd")
const DestructibleWallScript := preload("res://scripts/DestructibleWall.gd")

var fps_label: Label
var info_label: Label
var status_label: Label
var lock_reticle: Control

var arena: Node3D
var post_fx: CanvasLayer
var battle_cam: Node3D

var hyun_fighter: Node3D
var combat_god_fighter: Node3D

var demo_wall_index: int = 0
var move_speed: float = 8.5

func _ready() -> void:
	# Enforce 120 FPS & 120Hz Physics Tick at runtime
	Engine.max_fps = 120
	Engine.physics_ticks_per_second = 120
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	_setup_environment()
	_setup_arena()
	_spawn_fighters()
	_setup_camera()
	_setup_post_processing()
	_setup_hud()
	
	# Trigger an initial wall crack showcase after a brief moment so debris & shaders are ready
	print("[STEP 2 OK] Full Destructible Battlegrounds Arena, 120Hz Action Camera & Anime Impact-Frame Shader Pipeline initialized.")

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.025, 0.035, 0.085)
	sky_mat.sky_horizon_color = Color(0.14, 0.16, 0.28)
	sky_mat.ground_bottom_color = Color(0.015, 0.018, 0.035)
	sky_mat.ground_horizon_color = Color(0.09, 0.1, 0.17)
	sky_mat.sun_angle_max = 35.0
	sky.sky_material = sky_mat
	env.sky = sky
	
	# Next-Gen Post-Processing (HDR Glow / Bloom, Volumetric Fog, SSR, SSAO, ACES Tonemap)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 1.25
	env.glow_strength = 1.1
	env.glow_bloom = 0.22
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.ssr_enabled = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0065
	env.volumetric_fog_albedo = Color(0.16, 0.19, 0.28)
	
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)
	
	# Main Directional Rim/Sun Light with Soft Shadows
	var sun := DirectionalLight3D.new()
	sun.name = "DirectionalSunLight"
	sun.rotation_degrees = Vector3(-50.0, 32.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.light_energy = 2.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)
	
	# Secondary Cool Rim Counter-Light for Anime Fighter Silhouettes
	var rim_dir := DirectionalLight3D.new()
	rim_dir.name = "AnimeRimLight"
	rim_dir.rotation_degrees = Vector3(-28.0, -145.0, 0.0)
	rim_dir.light_color = Color(0.35, 0.62, 1.0)
	rim_dir.light_energy = 0.85
	rim_dir.shadow_enabled = false
	add_child(rim_dir)

func _setup_arena() -> void:
	var arena_scene := load("res://scenes/BattlegroundsArena.tscn") as PackedScene
	if arena_scene != null:
		arena = arena_scene.instantiate()
	else:
		arena = BattlegroundsArenaScript.new()
	arena.name = "BattlegroundsArena"
	add_child(arena)
	arena.arena_heavy_impact.connect(_on_arena_heavy_impact)

func _spawn_fighters() -> void:
	# 1. Fighter 1: Hyun's Dojo (KJ / Martial Legend) - Downloaded 3D Model
	var ual1_scene := load("res://assets/models/ual1_standard.glb") as PackedScene
	if ual1_scene:
		hyun_fighter = ual1_scene.instantiate()
		hyun_fighter.name = "HyunDojoFighter"
		hyun_fighter.position = Vector3(-2.4, 0.0, 2.0)
		hyun_fighter.rotation_degrees = Vector3(0.0, 145.0, 0.0)
		add_child(hyun_fighter)
		_apply_fighter_aura(hyun_fighter, Color(0.95, 0.15, 0.2), Color(3.5, 0.2, 0.3))
		_play_first_matching_anim(hyun_fighter, ["Punch_Cross", "Punch_Jab", "Idle"])
		
		var red_light := OmniLight3D.new()
		red_light.light_color = Color(1.0, 0.15, 0.2)
		red_light.light_energy = 3.8
		red_light.omni_range = 6.5
		red_light.position = Vector3(0.0, 1.25, 0.4)
		hyun_fighter.add_child(red_light)

	# 2. Fighter 2: Combat Gods (Jun / Weapon God) - Downloaded 3D Model + Downloaded Katana
	var ual2_scene := load("res://assets/models/ual2_standard.glb") as PackedScene
	if ual2_scene:
		combat_god_fighter = ual2_scene.instantiate()
		combat_god_fighter.name = "CombatGodFighter"
		combat_god_fighter.position = Vector3(2.4, 0.0, -3.5)
		combat_god_fighter.rotation_degrees = Vector3(0.0, -35.0, 0.0)
		add_child(combat_god_fighter)
		_apply_fighter_aura(combat_god_fighter, Color(0.15, 0.2, 0.28), Color(0.1, 1.8, 4.0))
		_play_first_matching_anim(combat_god_fighter, ["Sword_Regular_Combo", "Sword_Heavy_Combo", "Idle_FoldArms"])
		
		var cyan_light := OmniLight3D.new()
		cyan_light.light_color = Color(0.1, 0.75, 1.0)
		cyan_light.light_energy = 3.8
		cyan_light.omni_range = 6.5
		cyan_light.position = Vector3(0.0, 1.25, 0.4)
		combat_god_fighter.add_child(cyan_light)
		
		var katana_scene := load("res://assets/weapons/katana.glb") as PackedScene
		if katana_scene:
			var katana := katana_scene.instantiate()
			katana.position = Vector3(0.55, 1.1, 0.38)
			katana.scale = Vector3(0.32, 0.32, 0.32)
			combat_god_fighter.add_child(katana)

func _setup_camera() -> void:
	battle_cam = BattleCameraScript.new()
	battle_cam.name = "BattleCamera"
	battle_cam.follow_target = hyun_fighter
	battle_cam.lock_target = combat_god_fighter
	battle_cam.position = hyun_fighter.position + Vector3(0.0, 1.45, 0.0) if hyun_fighter else Vector3(0.0, 1.45, 0.0)
	add_child(battle_cam)
	battle_cam.lock_on_changed.connect(_on_lock_on_changed)

func _setup_post_processing() -> void:
	post_fx = PostProcessControllerScript.new()
	post_fx.name = "PostProcessController"
	add_child(post_fx)

func _setup_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "BattleHUD"
	canvas.layer = 60
	add_child(canvas)
	
	fps_label = Label.new()
	fps_label.position = Vector2(24, 18)
	fps_label.add_theme_font_size_override("font_size", 22)
	fps_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.48))
	canvas.add_child(fps_label)
	
	info_label = Label.new()
	info_label.position = Vector2(24, 52)
	info_label.add_theme_font_size_override("font_size", 15)
	info_label.add_theme_color_override("font_color", Color(0.88, 0.93, 1.0))
	info_label.text = (
		"LEGENDS BATTLEGROUNDS PC — STEP 2: DESTRUCTIBLE ARENA, NEXT-GEN POST-FX & 120HZ CAMERA\n"
		+ "[WASD] Move Fighter  |  [Right-Click / ESC] Toggle Mouse Orbit  |  [Shift / MMB] Lock-On Target\n"
		+ "[E] Smash Wall (wall -> wall_cracked -> wall_broken + 3D Rock Debris)  |  [F] Anime Impact Frame + Hitstop  |  [Q] Dash Speed-Lines + FOV Punch  |  [R] Repair Walls"
	)
	canvas.add_child(info_label)
	
	status_label = Label.new()
	status_label.position = Vector2(24, 132)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.25))
	status_label.text = "LOCK-ON: OFF (Press SHIFT)   |   ARENA WALLS: 44 DESTRUCTIBLE SEGMENTS READY"
	canvas.add_child(status_label)
	
	# Lock-on diamond reticle projected onto locked enemy
	lock_reticle = Control.new()
	lock_reticle.name = "LockOnReticle"
	lock_reticle.visible = false
	canvas.add_child(lock_reticle)
	
	var reticle_lbl := Label.new()
	reticle_lbl.text = "[ + LOCKED + ]"
	reticle_lbl.position = Vector2(-56, -14)
	reticle_lbl.add_theme_font_size_override("font_size", 18)
	reticle_lbl.add_theme_color_override("font_color", Color(1.0, 0.22, 0.28))
	lock_reticle.add_child(reticle_lbl)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo:
			match ke.keycode:
				KEY_ESCAPE:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				KEY_E:
					_trigger_wall_destruction_showcase()
				KEY_F:
					_trigger_anime_impact_showcase(1)
				KEY_Q:
					_trigger_dash_fx_showcase()
				KEY_R:
					if arena != null:
						arena.repair_all_walls()
						status_label.text = "ALL PERIMETER WALLS REPAIRED TO wall.glb"

func _trigger_wall_destruction_showcase() -> void:
	if arena == null or arena.destructible_walls.is_empty():
		return
	var ref_pos: Vector3 = hyun_fighter.global_position if hyun_fighter != null else Vector3(0.0, 0.0, -24.0)
	var wall: Node3D = arena.damage_nearest_wall(ref_pos)
	if wall != null:
		var state_names := ["wall.glb (INTACT)", "wall_cracked.glb (CRACKED)", "wall_broken.glb (BROKEN)"]
		status_label.text = "WALL IMPACT! Swapped to %s + Spawned 3D rock_chunk_01/02 Debris!" % state_names[wall.state]

func _trigger_anime_impact_showcase(style: int = 1) -> void:
	var focus_pt: Vector3 = combat_god_fighter.global_position + Vector3(0.0, 1.2, 0.0) if combat_god_fighter else Vector3.ZERO
	if post_fx != null and battle_cam != null:
		post_fx.trigger_impact_frame(0.13, style, focus_pt, battle_cam.camera)
		post_fx.trigger_hitstop(0.06, 0.04)
		post_fx.trigger_speed_lines(0.85, 0.35, Color(1.0, 0.25, 0.3) if style == 1 else Color(0.25, 0.85, 1.0))
		battle_cam.add_shake(0.75, Vector3(0.0, 0.2, -0.6))
		battle_cam.add_fov_punch(13.0, 0.22)
	if arena != null:
		arena.spawn_debris_burst(focus_pt, Vector3.UP, 10, 11.5)

func _trigger_dash_fx_showcase() -> void:
	if post_fx != null and battle_cam != null:
		post_fx.trigger_speed_lines(0.9, 0.38, Color(0.85, 0.95, 1.0))
		battle_cam.add_fov_punch(14.0, 0.26)
		battle_cam.add_shake(0.32, Vector3(0.0, 0.0, 0.5))
	if hyun_fighter != null and battle_cam != null:
		var forward: Vector3 = -battle_cam.camera.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() > 0.001:
			forward = forward.normalized()
			hyun_fighter.global_position += forward * 3.2
			hyun_fighter.global_position.x = clamp(hyun_fighter.global_position.x, -21.5, 21.5)
			hyun_fighter.global_position.z = clamp(hyun_fighter.global_position.z, -21.5, 21.5)
			if arena != null:
				arena.spawn_debris_burst(hyun_fighter.global_position, Vector3.UP, 6, 7.5)

func _on_arena_heavy_impact(impact_pos: Vector3, wall_state: int) -> void:
	var impact_style := 1 if wall_state == DestructibleWallScript.WallState.BROKEN else 0
	if post_fx != null and battle_cam != null:
		post_fx.trigger_impact_frame(0.12 if wall_state == DestructibleWallScript.WallState.BROKEN else 0.08, impact_style, impact_pos, battle_cam.camera)
		post_fx.trigger_hitstop(0.055, 0.05)
		post_fx.trigger_speed_lines(0.8, 0.32)
		battle_cam.add_shake(0.85 if wall_state == DestructibleWallScript.WallState.BROKEN else 0.58)
		battle_cam.add_fov_punch(12.0, 0.2)

func _on_lock_on_changed(locked: bool, target: Node3D) -> void:
	if status_label != null:
		if locked and target != null:
			status_label.text = "LOCK-ON: ACTIVE -> %s   |   Press [E] Smash Nearest Wall  |  [F] Impact Frame" % target.name
		else:
			status_label.text = "LOCK-ON: FREE ORBIT   |   Press [SHIFT] or [MMB] to Lock-On Target"

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

func _physics_process(delta: float) -> void:
	if hyun_fighter == null or battle_cam == null:
		return
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0
	
	if input_dir.length_squared() > 0.01:
		input_dir = input_dir.normalized()
		var cam_basis := Basis.from_euler(Vector3(0.0, battle_cam.yaw, 0.0))
		var move_vec := (cam_basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
		hyun_fighter.global_position += move_vec * move_speed * delta
		hyun_fighter.global_position.x = clamp(hyun_fighter.global_position.x, -21.8, 21.8)
		hyun_fighter.global_position.z = clamp(hyun_fighter.global_position.z, -21.8, 21.8)
		
		var target_yaw := atan2(move_vec.x, move_vec.z)
		if battle_cam.is_locked_on and combat_god_fighter != null:
			var to_enemy := combat_god_fighter.global_position - hyun_fighter.global_position
			target_yaw = atan2(to_enemy.x, to_enemy.z)
		hyun_fighter.rotation.y = lerp_angle(hyun_fighter.rotation.y, target_yaw, clamp(delta * 16.0, 0.0, 1.0))

func _process(delta: float) -> void:
	if fps_label:
		var fps: int = Engine.get_frames_per_second()
		var frame_ms: float = (delta / max(Engine.time_scale, 0.001)) * 1000.0
		var lock_str: String = "LOCKED" if (battle_cam and battle_cam.is_locked_on) else "FREE"
		fps_label.text = "FPS: %d / 120  (%.2f ms) | Physics: %d Hz | Camera: %s | Vulkan Forward+" % [fps, frame_ms, Engine.physics_ticks_per_second, lock_str]
	
	# Update 2D lock-on reticle over locked 3D target
	if lock_reticle != null and battle_cam != null and battle_cam.camera != null:
		if battle_cam.is_locked_on and battle_cam.lock_target != null and is_instance_valid(battle_cam.lock_target):
			var target_world: Vector3 = battle_cam.lock_target.global_position + Vector3(0.0, 1.25, 0.0)
			if not battle_cam.camera.is_position_behind(target_world):
				lock_reticle.visible = true
				lock_reticle.position = battle_cam.camera.unproject_position(target_world)
			else:
				lock_reticle.visible = false
		else:
			lock_reticle.visible = false
