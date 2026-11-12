class_name DestructibleWall
extends StaticBody3D

signal wall_damaged(wall: DestructibleWall, new_state: int, impact_point: Vector3)

enum WallState {
	INTACT = 0,
	CRACKED = 1,
	BROKEN = 2
}

@export var max_hp: float = 100.0
var current_hp: float = 100.0
var state: int = WallState.INTACT

var intact_scene: PackedScene
var cracked_scene: PackedScene
var broken_scene: PackedScene

var visual_root: Node3D
var collision_shape: CollisionShape3D
var current_model: Node3D
var shake_timer: float = 0.0
var base_visual_pos: Vector3 = Vector3.ZERO

func _ready() -> void:
	current_hp = max_hp
	intact_scene = load("res://assets/arena/wall.glb") as PackedScene
	cracked_scene = load("res://assets/arena/wall_cracked.glb") as PackedScene
	broken_scene = load("res://assets/arena/wall_broken.glb") as PackedScene
	
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	
	collision_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 1.1)
	collision_shape.shape = box
	collision_shape.position = Vector3(0.0, 2.0, 0.0)
	add_child(collision_shape)
	
	_swap_wall_model(WallState.INTACT)

func apply_impact(damage: float, impact_world_pos: Vector3 = Vector3.ZERO) -> int:
	if impact_world_pos == Vector3.ZERO:
		impact_world_pos = global_position + Vector3(0.0, 1.8, 0.0)
	
	current_hp = max(current_hp - damage, 0.0)
	shake_timer = 0.22
	
	var prev_state := state
	if current_hp <= 0.0:
		state = WallState.BROKEN
	elif current_hp <= max_hp * 0.55:
		state = WallState.CRACKED
	else:
		state = WallState.INTACT
	
	if state != prev_state:
		_swap_wall_model(state)
	
	wall_damaged.emit(self, state, impact_world_pos)
	return state

func advance_destruction_stage(impact_world_pos: Vector3 = Vector3.ZERO) -> int:
	if state == WallState.INTACT:
		return apply_impact(max_hp * 0.55, impact_world_pos)
	elif state == WallState.CRACKED:
		return apply_impact(max_hp, impact_world_pos)
	else:
		# Already broken — still emit debris burst on heavy wall-splat
		shake_timer = 0.22
		wall_damaged.emit(self, state, impact_world_pos if impact_world_pos != Vector3.ZERO else global_position + Vector3(0.0, 1.5, 0.0))
		return state

func repair_wall() -> void:
	current_hp = max_hp
	if state != WallState.INTACT:
		_swap_wall_model(WallState.INTACT)

func _swap_wall_model(new_state: int) -> void:
	state = new_state
	if current_model != null and is_instance_valid(current_model):
		current_model.queue_free()
		current_model = null
	
	var chosen_scene: PackedScene = intact_scene
	if state == WallState.CRACKED and cracked_scene != null:
		chosen_scene = cracked_scene
	elif state == WallState.BROKEN and broken_scene != null:
		chosen_scene = broken_scene
	
	if chosen_scene != null:
		current_model = chosen_scene.instantiate()
		visual_root.add_child(current_model)
	
	# Lower collision height slightly when broken so camera/debris can fly over shattered top
	if collision_shape != null and collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		if state == WallState.BROKEN:
			box.size = Vector3(4.0, 2.3, 1.1)
			collision_shape.position = Vector3(0.0, 1.15, 0.0)
		else:
			box.size = Vector3(4.0, 4.0, 1.1)
			collision_shape.position = Vector3(0.0, 2.0, 0.0)

func _process(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer = max(shake_timer - delta, 0.0)
		var mag := shake_timer * 0.45
		visual_root.position = base_visual_pos + Vector3(
			 randf_range(-mag, mag),
			 randf_range(-mag * 0.5, mag * 0.5),
			 randf_range(-mag, mag)
		)
	else:
		visual_root.position = base_visual_pos
