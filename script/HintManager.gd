extends Node

@export var hints_visible_on_start: bool = true
@export var arrow_local_position: Vector3 = Vector3(0.0, -0.1, -1.2)
@export var hide_when_close: bool = false
@export var hide_distance: float = 2.0

var city_builder: Node = null
var spawn_manager: Node = null
var logger_node: Node = null
var world: Node3D = null
var xr_camera: XRCamera3D = null

var is_ready: bool = false
var hints_visible: bool = false
var spawn_position: Vector3 = Vector3.ZERO

var home_arrow_root: Node3D = null
var home_arrow_label: Label3D = null


func setup(
	p_city_builder: Node,
	p_spawn_manager: Node,
	p_logger_node: Node,
	p_world: Node3D,
	p_xr_camera: XRCamera3D
) -> void:
	city_builder = p_city_builder
	spawn_manager = p_spawn_manager
	logger_node = p_logger_node
	world = p_world
	xr_camera = p_xr_camera

	_resolve_spawn_position()
	_ensure_home_arrow()

	set_hints_visible(hints_visible_on_start, false)

	is_ready = true
	print("HINT_MANAGER_READY")

	_log_event("hint_manager_ready", {
		"hints_visible_on_start": hints_visible_on_start
	})


func _process(_delta: float) -> void:
	if not is_ready:
		return
	if not hints_visible:
		return
	if xr_camera == null:
		return
	if home_arrow_label == null:
		return

	_resolve_spawn_position()

	var cam_pos := xr_camera.global_position
	var to_home := spawn_position - cam_pos
	to_home.y = 0.0

	if to_home.length() < 0.001:
		home_arrow_label.visible = false
		return

	if hide_when_close and to_home.length() <= hide_distance:
		home_arrow_label.visible = false
		return

	home_arrow_label.visible = true

	var local_dir := xr_camera.global_transform.basis.inverse() * to_home.normalized()

	# Arrow points UP by default.
	# Forward = -Z, Right = +X in camera-local space.
	home_arrow_label.rotation = Vector3.ZERO
	home_arrow_label.rotation.z = -atan2(local_dir.x, -local_dir.z)


func show_all_hints() -> void:
	set_hints_visible(true)


func hide_all_hints() -> void:
	set_hints_visible(false)


func toggle_hints() -> void:
	set_hints_visible(not hints_visible)


func get_hints_visible() -> bool:
	return hints_visible


func set_hints_visible(enabled: bool, log_event: bool = true) -> void:
	hints_visible = enabled

	if home_arrow_root != null and is_instance_valid(home_arrow_root):
		home_arrow_root.visible = enabled

	if log_event:
		if enabled:
			_log_event("hints_enabled", {})
		else:
			_log_event("hints_disabled", {})


func _resolve_spawn_position() -> void:
	if spawn_manager != null:
		if "spawn_position" in spawn_manager:
			spawn_position = spawn_manager.spawn_position
			return

	if city_builder != null:
		if "spawn_position" in city_builder:
			spawn_position = city_builder.spawn_position
			return

		if city_builder.has_method("get_spawn_position"):
			var result = city_builder.call("get_spawn_position")
			if result is Vector3:
				spawn_position = result
				return

	spawn_position = Vector3.ZERO


func _ensure_home_arrow() -> void:
	if xr_camera == null:
		return

	var old_root := xr_camera.get_node_or_null("HomeArrowRoot")
	if old_root != null:
		old_root.queue_free()

	home_arrow_root = Node3D.new()
	home_arrow_root.name = "HomeArrowRoot"
	xr_camera.add_child(home_arrow_root)
	home_arrow_root.position = arrow_local_position

	home_arrow_label = Label3D.new()
	home_arrow_label.name = "HomeArrowLabel"
	home_arrow_label.text = "↑"
	home_arrow_label.font_size = 80
	home_arrow_label.pixel_size = 0.0045
	home_arrow_label.position = Vector3.ZERO
	home_arrow_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	home_arrow_label.no_depth_test = true
	home_arrow_label.modulate = Color(1.0, 0.2, 0.2)
	home_arrow_root.add_child(home_arrow_label)


func _log_event(event_name: String, payload: Dictionary = {}) -> void:
	if logger_node == null:
		return
	if logger_node.has_method("mark_event"):
		logger_node.call("mark_event", event_name, payload)
