class_name BattlegroundsArena
extends Node3D

const DestructibleWallScript := preload("res://scripts/DestructibleWall.gd")

signal arena_heavy_impact(impact_pos: Vector3, wall_state: int)

const ARENA_HALF_TILES: int = 6 # 13x13 grid of 4x4m tiles = 52m x 52m combat arena
const TILE_SIZE: float = 4.0
const PERIMETER_DIST: float = 24.0 # 6 * 4.0m

var tile_scene: PackedScene
var tile_rock_scene: PackedScene
var pillar_scene: PackedScene
var rubble_scene: PackedScene
var boulder_01_scene: PackedScene
var arena_boulder_scene: PackedScene
var rock_chunk_01_scene: PackedScene
var rock_chunk_02_scene: PackedScene

var floor_root: Node3D
var walls_root: Node3D
var pillars_root: Node3D
var boulders_root: Node3D
var debris_root: Node3D

var destructible_walls: Array = []
var active_debris: Array[Dictionary] = []

func _ready() -> void:
	tile_scene = load("res://assets/arena/floor_tile_large.glb") as PackedScene
	tile_rock_scene = load("res://assets/arena/floor_tile_large_rocks.glb") as PackedScene
	pillar_scene = load("res://assets/arena/pillar_decorated.glb") as PackedScene
	rubble_scene = load("res://assets/arena/rubble_large.glb") as PackedScene
	boulder_01_scene = load("res://assets/debris/boulder_01.glb") as PackedScene
	arena_boulder_scene = load("res://assets/debris/arena_boulder.glb") as PackedScene
	rock_chunk_01_scene = load("res://assets/debris/rock_chunk_01.glb") as PackedScene
	rock_chunk_02_scene = load("res://assets/debris/rock_chunk_02.glb") as PackedScene
	
	floor_root = Node3D.new()
	floor_root.name = "TiledFloor"
	add_child(floor_root)
	
	walls_root = Node3D.new()
	walls_root.name = "DestructibleWalls"
	add_child(walls_root)
	
	pillars_root = Node3D.new()
	pillars_root.name = "DecoratedPillars"
	add_child(pillars_root)
	
	boulders_root = Node3D.new()
	boulders_root.name = "PerimeterBoulders"
	add_child(boulders_root)
	
	debris_root = Node3D.new()
	debris_root.name = "DynamicRockDebris"
	add_child(debris_root)
	
	_build_tiled_floor()
	_build_destructible_perimeter_walls()
	_build_pillars_and_rubble()
	_build_perimeter_pbr_boulders()
	_build_arena_lighting()

func _build_tiled_floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12043
	
	for gx in range(-ARENA_HALF_TILES, ARENA_HALF_TILES + 1):
		for gz in range(-ARENA_HALF_TILES, ARENA_HALF_TILES + 1):
			var dist_from_center := Vector2(float(gx), float(gz)).length()
			# Outer ring uses more rocky floor tiles, inner combat ring stays mostly clean stone
			var use_rock := (dist_from_center > 3.2 and ((gx * 3 + gz * 5) % 3 == 0)) or ((gx + gz) % 7 == 0 and dist_from_center > 1.8)
			var chosen := tile_rock_scene if (use_rock and tile_rock_scene != null) else tile_scene
			if chosen == null:
				continue
			var tile := chosen.instantiate() as Node3D
			tile.position = Vector3(float(gx) * TILE_SIZE, 0.0, float(gz) * TILE_SIZE)
			tile.rotation_degrees.y = float(rng.randi_range(0, 3) * 90)
			floor_root.add_child(tile)
	
	# Solid physics floor collider under the entire Battlegrounds Arena
	var floor_body := StaticBody3D.new()
	floor_body.name = "ArenaFloorStaticBody"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(140.0, 2.0, 140.0)
	col.shape = box
	col.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(col)
	add_child(floor_body)

func _build_destructible_perimeter_walls() -> void:
	# 4-sided destructible perimeter wall enclosure (North, South, East, West)
	for i in range(-ARENA_HALF_TILES + 1, ARENA_HALF_TILES):
		var offset := float(i) * TILE_SIZE
		# North Wall (-Z)
		_spawn_destructible_wall(Vector3(offset, 0.0, -PERIMETER_DIST), 0.0)
		# South Wall (+Z)
		_spawn_destructible_wall(Vector3(offset, 0.0, PERIMETER_DIST), 180.0)
		# West Wall (-X)
		_spawn_destructible_wall(Vector3(-PERIMETER_DIST, 0.0, offset), 90.0)
		# East Wall (+X)
		_spawn_destructible_wall(Vector3(PERIMETER_DIST, 0.0, offset), -90.0)

func _spawn_destructible_wall(pos: Vector3, yaw_deg: float) -> Node3D:
	var wall := DestructibleWallScript.new() as Node3D
	wall.position = pos
	wall.rotation_degrees.y = yaw_deg
	walls_root.add_child(wall)
	wall.wall_damaged.connect(_on_wall_damaged)
	destructible_walls.append(wall)
	return wall

func _build_pillars_and_rubble() -> void:
	if pillar_scene != null:
		# Corner & gateway pillars + wall interval pillars
		var pillar_coords := [
			Vector3(-PERIMETER_DIST, 0.0, -PERIMETER_DIST),
			Vector3(PERIMETER_DIST, 0.0, -PERIMETER_DIST),
			Vector3(-PERIMETER_DIST, 0.0, PERIMETER_DIST),
			Vector3(PERIMETER_DIST, 0.0, PERIMETER_DIST),
			Vector3(-12.0, 0.0, -PERIMETER_DIST + 0.4),
			Vector3(0.0, 0.0, -PERIMETER_DIST + 0.4),
			Vector3(12.0, 0.0, -PERIMETER_DIST + 0.4),
			Vector3(-12.0, 0.0, PERIMETER_DIST - 0.4),
			Vector3(0.0, 0.0, PERIMETER_DIST - 0.4),
			Vector3(12.0, 0.0, PERIMETER_DIST - 0.4),
			Vector3(-PERIMETER_DIST + 0.4, 0.0, -12.0),
			Vector3(-PERIMETER_DIST + 0.4, 0.0, 0.0),
			Vector3(-PERIMETER_DIST + 0.4, 0.0, 12.0),
			Vector3(PERIMETER_DIST - 0.4, 0.0, -12.0),
			Vector3(PERIMETER_DIST - 0.4, 0.0, 0.0),
			Vector3(PERIMETER_DIST - 0.4, 0.0, 12.0),
		]
		for p_pos in pillar_coords:
			var p_body := StaticBody3D.new()
			p_body.position = p_pos
			var p_inst := pillar_scene.instantiate() as Node3D
			p_inst.scale = Vector3(1.15, 1.25, 1.15)
			p_body.add_child(p_inst)
			
			var col := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 1.05
			cyl.height = 5.0
			col.shape = cyl
			col.position = Vector3(0.0, 2.5, 0.0)
			p_body.add_child(col)
			pillars_root.add_child(p_body)
	
	if rubble_scene != null:
		var rubble_spots := [
			{"pos": Vector3(-19.5, 0.0, -21.0), "rot": 18.0, "scale": 0.9},
			{"pos": Vector3(19.5, 0.0, -21.0), "rot": -24.0, "scale": 0.95},
			{"pos": Vector3(-19.5, 0.0, 21.0), "rot": 155.0, "scale": 0.9},
			{"pos": Vector3(19.5, 0.0, 21.0), "rot": -148.0, "scale": 0.95},
		]
		for r_info in rubble_spots:
			var r := rubble_scene.instantiate() as Node3D
			r.position = r_info["pos"]
			r.rotation_degrees.y = r_info["rot"]
			r.scale = Vector3.ONE * float(r_info["scale"])
			pillars_root.add_child(r)

func _build_perimeter_pbr_boulders() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	var count := 20
	for i in range(count):
		var angle := (float(i) / float(count)) * TAU
		var radius := rng.randf_range(18.5, 22.8)
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var use_alt := (i % 2 == 1)
		var b_scene := arena_boulder_scene if (use_alt and arena_boulder_scene != null) else boulder_01_scene
		if b_scene == null:
			continue
		var b_body := StaticBody3D.new()
		b_body.position = pos
		b_body.rotation_degrees.y = rng.randf_range(0.0, 360.0)
		var s := rng.randf_range(1.25, 2.35)
		
		var b_inst := b_scene.instantiate() as Node3D
		b_inst.scale = Vector3(s, s * rng.randf_range(0.85, 1.3), s)
		b_body.add_child(b_inst)
		
		var col := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.85 * s
		col.shape = sph
		col.position = Vector3(0.0, 0.55 * s, 0.0)
		b_body.add_child(col)
		boulders_root.add_child(b_body)

func _build_arena_lighting() -> void:
	# Corner & gateway dramatic rim point lights for next-gen arena atmosphere
	var light_positions := [
		{"pos": Vector3(-16.0, 3.8, -16.0), "col": Color(1.0, 0.42, 0.18), "energy": 3.5},
		{"pos": Vector3(16.0, 3.8, -16.0), "col": Color(0.22, 0.65, 1.0), "energy": 3.5},
		{"pos": Vector3(-16.0, 3.8, 16.0), "col": Color(0.22, 0.65, 1.0), "energy": 3.5},
		{"pos": Vector3(16.0, 3.8, 16.0), "col": Color(1.0, 0.42, 0.18), "energy": 3.5},
	]
	for lp in light_positions:
		var omni := OmniLight3D.new()
		omni.position = lp["pos"]
		omni.light_color = lp["col"]
		omni.light_energy = lp["energy"]
		omni.omni_range = 18.0
		add_child(omni)

func _on_wall_damaged(wall: Node3D, new_state: int, impact_point: Vector3) -> void:
	# Spawn flying RigidBody3D rock_chunk_01.glb & rock_chunk_02.glb debris
	var inward_normal := -wall.global_position.normalized()
	inward_normal.y = 0.35
	inward_normal = inward_normal.normalized()
	var chunk_count := 10 if new_state == DestructibleWallScript.WallState.CRACKED else 18
	spawn_debris_burst(impact_point, inward_normal, chunk_count, 13.5)
	arena_heavy_impact.emit(impact_point, new_state)

func spawn_debris_burst(origin: Vector3, main_dir: Vector3, count: int = 12, impulse_speed: float = 12.0) -> void:
	for i in range(count):
		var use_chunk_2 := (i % 2 == 1)
		var chunk_scene := rock_chunk_02_scene if (use_chunk_2 and rock_chunk_02_scene != null) else rock_chunk_01_scene
		if chunk_scene == null:
			continue
		
		var rb := RigidBody3D.new()
		rb.mass = randf_range(0.8, 2.4)
		rb.position = origin + Vector3(
			randf_range(-1.2, 1.2),
			randf_range(0.2, 1.8),
			randf_range(-1.2, 1.2)
		)
		
		var model := chunk_scene.instantiate() as Node3D
		# Keep only LOD0 visible if multiple LOD meshes exist in rock_chunk_01.glb
		for child in model.get_children():
			if child is MeshInstance3D and ("LOD1" in child.name or "LOD2" in child.name or "LOD3" in child.name):
				child.visible = false
		
		var scale_factor := randf_range(2.2, 4.8) if not use_chunk_2 else randf_range(1.6, 3.6)
		model.scale = Vector3.ONE * scale_factor
		rb.add_child(model)
		
		var col := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.22
		col.shape = sph
		rb.add_child(col)
		
		debris_root.add_child(rb)
		
		var spread := Vector3(
			randf_range(-0.85, 0.85),
			randf_range(0.35, 1.15),
			randf_range(-0.85, 0.85)
		)
		var launch_dir := (main_dir + spread).normalized()
		rb.linear_velocity = launch_dir * randf_range(impulse_speed * 0.55, impulse_speed * 1.25)
		rb.angular_velocity = Vector3(
			randf_range(-12.0, 12.0),
			randf_range(-12.0, 12.0),
			randf_range(-12.0, 12.0)
		)
		
		active_debris.append({
			"body": rb,
			"ttl": randf_range(5.5, 8.5)
		})

func damage_nearest_wall(reference_pos: Vector3) -> Node3D:
	if destructible_walls.is_empty():
		return null
	# Prioritize intact or cracked walls near reference_pos so repeated tests showcase wall -> cracked -> broken
	var best_wall: Node3D = null
	var best_score: float = 999999.0
	for w in destructible_walls:
		if not is_instance_valid(w):
			continue
		var d: float = w.global_position.distance_to(reference_pos)
		var penalty: float = 45.0 if w.state == DestructibleWallScript.WallState.BROKEN else 0.0
		if d + penalty < best_score:
			best_score = d + penalty
			best_wall = w
	if best_wall != null:
		best_wall.advance_destruction_stage(best_wall.global_position + Vector3(0.0, 1.8, 0.0))
	return best_wall

func repair_all_walls() -> void:
	for w in destructible_walls:
		if is_instance_valid(w):
			w.repair_wall()

func _process(delta: float) -> void:
	for i in range(active_debris.size() - 1, -1, -1):
		var item := active_debris[i]
		var ttl: float = float(item["ttl"]) - delta
		item["ttl"] = ttl
		var body := item["body"] as RigidBody3D
		if ttl <= 0.0 or body == null or not is_instance_valid(body):
			if body != null and is_instance_valid(body):
				body.queue_free()
			active_debris.remove_at(i)
		elif ttl < 1.0:
			body.scale = Vector3.ONE * clamp(ttl, 0.05, 1.0)
