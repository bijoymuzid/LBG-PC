class_name BattleCamera
extends Node3D

signal lock_on_changed(locked: bool, target: Node3D)

@export var follow_target: Node3D
@export var lock_target: Node3D

@export var mouse_sensitivity: float = 0.0024
@export var min_pitch_deg: float = -42.0
@export var max_pitch_deg: float = 55.0
@export var default_distance: float = 5.4
@export var min_distance: float = 1.6
@export var max_distance: float = 9.5
@export var pivot_height: float = 1.45
@export var shoulder_offset: Vector3 = Vector3(0.52, 0.15, 0.0)
@export var base_fov: float = 62.0

var camera: Camera3D
var is_locked_on: bool = false
var yaw: float = 0.0
var pitch: float = -12.0 * PI / 180.0
var target_distance: float = 5.4
var current_distance: float = 5.4

# Dynamic FOV Punch
var fov_offset: float = 0.0
var fov_punch_timer: float = 0.0
var fov_punch_target: float = 0.0

# High-frequency 120Hz Trauma / Camera Shake
var shake_trauma: float = 0.0
var shake_decay: float = 3.2
var shake_time: float = 0.0
var directional_kick: Vector3 = Vector3.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	target_distance = default_distance
	current_distance = default_distance
	
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = base_fov
	camera.near = 0.08
	camera.far = 300.0
	camera.current = true
	add_child(camera)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		if not is_locked_on:
			yaw -= mm.relative.x * mouse_sensitivity
			pitch = clamp(pitch - mm.relative.y * mouse_sensitivity, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
		else:
			# Subtle pitch adjust allowed while locked on
			pitch = clamp(pitch - mm.relative.y * mouse_sensitivity * 0.4, deg_to_rad(-28.0), deg_to_rad(25.0))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_MIDDLE:
				toggle_lock_on()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				target_distance = clamp(target_distance - 0.45, min_distance, max_distance)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				target_distance = clamp(target_distance + 0.45, min_distance, max_distance)
	elif event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_SHIFT:
			toggle_lock_on()

func toggle_lock_on() -> void:
	if lock_target == null or not is_instance_valid(lock_target):
		is_locked_on = false
	else:
		is_locked_on = not is_locked_on
	lock_on_changed.emit(is_locked_on, lock_target if is_locked_on else null)
	add_fov_punch(-4.5 if is_locked_on else 3.0, 0.14)

func add_shake(trauma_amount: float, dir_impulse: Vector3 = Vector3.ZERO) -> void:
	shake_trauma = clamp(shake_trauma + trauma_amount, 0.0, 1.0)
	directional_kick += dir_impulse * 0.22

func add_fov_punch(delta_fov: float = 11.0, duration: float = 0.22) -> void:
	fov_punch_target = clamp(delta_fov, -18.0, 24.0)
	fov_punch_timer = max(fov_punch_timer, duration)

func _process(delta: float) -> void:
	var unscaled_dt: float = clamp(delta / max(Engine.time_scale, 0.001), 0.0001, 0.05)
	shake_time += unscaled_dt * 42.0
	
	# Pivot center tracks follow_target (or midpoint if overviewing)
	var focus_pos := Vector3(0.0, pivot_height, 0.0)
	if follow_target != null and is_instance_valid(follow_target):
		focus_pos = follow_target.global_position + Vector3(0.0, pivot_height, 0.0)
	
	# Lock-On tracking rotation toward opponent
	if is_locked_on and lock_target != null and is_instance_valid(lock_target):
		var target_chest := lock_target.global_position + Vector3(0.0, 1.25, 0.0)
		var to_enemy := target_chest - focus_pos
		var flat_dist := Vector2(to_enemy.x, to_enemy.z).length()
		if flat_dist > 0.05:
			var desired_yaw: float = atan2(-to_enemy.x, -to_enemy.z)
			yaw = lerp_angle(yaw, desired_yaw, clamp(unscaled_dt * 14.0, 0.0, 1.0))
			var desired_pitch: float = clamp(atan2(to_enemy.y - 0.35, flat_dist) - 0.14, deg_to_rad(-28.0), deg_to_rad(22.0))
			pitch = lerp(pitch, desired_pitch, clamp(unscaled_dt * 10.0, 0.0, 1.0))
	
	# Smooth pivot interpolation at 120Hz
	global_position = global_position.lerp(focus_pos, clamp(unscaled_dt * 22.0, 0.0, 1.0))
	
	var rot_basis := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var active_shoulder := shoulder_offset
	if is_locked_on:
		active_shoulder = Vector3(0.68, 0.28, 0.0)
	
	var desired_cam_offset := rot_basis * Vector3(active_shoulder.x, active_shoulder.y, target_distance)
	var desired_world_pos := global_position + desired_cam_offset
	
	# Wall & pillar raycast collision avoidance
	var safe_dist := target_distance
	var world_3d := get_world_3d()
	if world_3d != null and world_3d.direct_space_state != null:
		var query := PhysicsRayQueryParameters3D.create(global_position, desired_world_pos)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := world_3d.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var hit_pos: Vector3 = hit["position"]
			var hit_dist: float = global_position.distance_to(hit_pos) - 0.35
			safe_dist = clamp(hit_dist, min_distance, target_distance)
	
	if safe_dist < current_distance:
		current_distance = lerp(current_distance, safe_dist, clamp(unscaled_dt * 28.0, 0.0, 1.0))
	else:
		current_distance = lerp(current_distance, safe_dist, clamp(unscaled_dt * 10.0, 0.0, 1.0))
	
	var final_local_pos := rot_basis * Vector3(active_shoulder.x, active_shoulder.y, current_distance)
	
	# Apply 120Hz Camera Shake & Directional Impact Kick
	var shake_pos_offset := Vector3.ZERO
	var shake_rot_z := 0.0
	if shake_trauma > 0.001:
		var shake_pow := shake_trauma * shake_trauma
		shake_pos_offset = Vector3(
			sin(shake_time * 1.9) * cos(shake_time * 1.1),
			cos(shake_time * 2.3) * sin(shake_time * 1.4),
			sin(shake_time * 1.5) * 0.5
		) * (0.42 * shake_pow)
		shake_rot_z = sin(shake_time * 2.7) * 0.045 * shake_pow
		shake_trauma = max(shake_trauma - shake_decay * unscaled_dt, 0.0)
	
	directional_kick = directional_kick.lerp(Vector3.ZERO, clamp(unscaled_dt * 16.0, 0.0, 1.0))
	
	camera.global_position = global_position + final_local_pos + shake_pos_offset + directional_kick
	
	if is_locked_on and lock_target != null and is_instance_valid(lock_target):
		var look_mid := focus_pos.lerp(lock_target.global_position + Vector3(0.0, 1.15, 0.0), 0.62)
		camera.look_at(look_mid + shake_pos_offset * 0.4, Vector3.UP)
	else:
		var look_target_pt := global_position + (rot_basis * Vector3(active_shoulder.x * 0.35, active_shoulder.y * 0.5, -10.0))
		camera.look_at(look_target_pt, Vector3.UP)
	camera.rotation.z += shake_rot_z
	
	# Dynamic FOV punch update
	if fov_punch_timer > 0.0:
		fov_punch_timer -= unscaled_dt
		fov_offset = lerp(fov_offset, fov_punch_target, clamp(unscaled_dt * 18.0, 0.0, 1.0))
	else:
		fov_offset = lerp(fov_offset, 0.0, clamp(unscaled_dt * 9.0, 0.0, 1.0))
	
	camera.fov = clamp(base_fov + fov_offset, 42.0, 92.0)
