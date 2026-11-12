class_name PostProcessController
extends CanvasLayer

var overlay_rect: ColorRect
var shader_mat: ShaderMaterial

var impact_timer: float = 0.0
var impact_duration: float = 0.0
var current_impact_style: int = 0

var speed_lines_target: float = 0.0
var speed_lines_current: float = 0.0
var speed_lines_decay_timer: float = 0.0

var hitstop_timer: float = 0.0
var active_time_scale: float = 1.0

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	overlay_rect = ColorRect.new()
	overlay_rect.name = "PostProcessOverlay"
	overlay_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	shader_mat = ShaderMaterial.new()
	var sh := load("res://shaders/post_process_impact.gdshader") as Shader
	shader_mat.shader = sh
	overlay_rect.material = shader_mat
	add_child(overlay_rect)

func trigger_impact_frame(duration: float = 0.11, style: int = 0, world_pos: Vector3 = Vector3.ZERO, cam: Camera3D = null) -> void:
	impact_duration = max(duration, 0.04)
	impact_timer = impact_duration
	current_impact_style = style
	shader_mat.set_shader_parameter("impact_style", style)
	
	if cam != null and not cam.is_position_behind(world_pos):
		var vp_size := get_viewport().get_visible_rect().size
		if vp_size.x > 0.0 and vp_size.y > 0.0:
			var screen_pt := cam.unproject_position(world_pos)
			var uv := Vector2(clamp(screen_pt.x / vp_size.x, 0.15, 0.85), clamp(screen_pt.y / vp_size.y, 0.15, 0.85))
			shader_mat.set_shader_parameter("impact_center", uv)
	else:
		shader_mat.set_shader_parameter("impact_center", Vector2(0.5, 0.5))

func trigger_speed_lines(intensity: float = 0.75, duration: float = 0.35, color: Color = Color(0.95, 0.98, 1.0)) -> void:
	speed_lines_target = clamp(intensity, 0.0, 1.0)
	speed_lines_current = max(speed_lines_current, speed_lines_target)
	speed_lines_decay_timer = max(speed_lines_decay_timer, duration)
	shader_mat.set_shader_parameter("speed_lines_color", Vector3(color.r, color.g, color.b))

func trigger_hitstop(duration: float = 0.055, slow_scale: float = 0.05) -> void:
	hitstop_timer = max(hitstop_timer, duration)
	active_time_scale = clamp(slow_scale, 0.02, 1.0)
	Engine.time_scale = active_time_scale

func _process(delta: float) -> void:
	# Unscaled delta so hitstop & impact frames always recover cleanly at 120Hz
	var unscaled_dt: float = delta / max(Engine.time_scale, 0.001)
	
	if hitstop_timer > 0.0:
		hitstop_timer -= unscaled_dt
		if hitstop_timer <= 0.0:
			hitstop_timer = 0.0
			Engine.time_scale = 1.0
	
	if impact_timer > 0.0:
		impact_timer -= unscaled_dt
		var norm: float = clamp(impact_timer / max(impact_duration, 0.001), 0.0, 1.0)
		shader_mat.set_shader_parameter("impact_intensity", norm)
	else:
		shader_mat.set_shader_parameter("impact_intensity", 0.0)
	
	if speed_lines_decay_timer > 0.0:
		speed_lines_decay_timer -= unscaled_dt
		speed_lines_current = move_toward(speed_lines_current, speed_lines_target, unscaled_dt * 8.0)
	else:
		speed_lines_current = move_toward(speed_lines_current, 0.0, unscaled_dt * 3.5)
	
	shader_mat.set_shader_parameter("speed_lines_intensity", speed_lines_current)
