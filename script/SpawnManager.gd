extends Node

@export var spawn_zone_radius: float = 4.0
@export var spawn_marker_radius: float = 1.4
@export var spawn_marker_thickness: float = 0.04
@export var spawn_marker_color: Color = Color(1.0, 0.0, 0.0)
@export var spawn_marker_y_offset: float = 0.08

var city_builder: Node = null
var player_body: CharacterBody3D = null
var xr_camera: XRCamera3D = null
var logger_node: Node = null
var world: Node3D = null

var spawn_position: Vector3 = Vector3.ZERO
var player_inside_spawn_zone: bool = false
var spawn_marker: MeshInstance3D = null
var is_ready: bool = false

func setup(
	p_city_builder: Node,
	p_player_body: CharacterBody3D,
	p_xr_camera: XRCamera3D,
	p_logger_node: Node,
	p_world: Node3D
) -> void:
	city_builder = p_city_builder
	player_body = p_player_body
	xr_camera = p_xr_camera
	logger_node = p_logger_node
	world = p_world

	_resolve_spawn_position()
	print("SPAWN_POSITION_RESOLVED = ", spawn_position)

	_move_player_to_spawn()
	_create_spawn_marker()
	_update_spawn_zone_state(true)

	is_ready = true
	print("SPAWN_MANAGER_READY")

	_log_event("spawn_manager_ready", {
		"spawn_x": snappedf(spawn_position.x, 0.001),
		"spawn_y": snappedf(spawn_position.y, 0.001),
		"spawn_z": snappedf(spawn_position.z, 0.001),
		"spawn_zone_radius": spawn_zone_radius
	})

func _process(_delta: float) -> void:
	if not is_ready:
		return

	_update_spawn_zone_state(false)

func _resolve_spawn_position() -> void:
	if city_builder != null:
		if "spawn_position" in city_builder:
			spawn_position = city_builder.spawn_position
			return

		if city_builder.has_method("get_spawn_position"):
			var result = city_builder.call("get_spawn_position")
			if result is Vector3:
				spawn_position = result
				return

	# Temporary fallback.
	spawn_position = Vector3(-8.0, 0.0, -8.0)

func _move_player_to_spawn() -> void:
	if player_body == null:
		return

	var target := spawn_position

	if xr_camera != null:
		var head_offset := xr_camera.global_position - player_body.global_position
		head_offset.y = 0.0
		target -= head_offset

	player_body.global_position = target
	player_body.velocity = Vector3.ZERO

	print("PLAYER_MOVED_TO_SPAWN = ", player_body.global_position)

	_log_event("player_spawned", {
		"x": snappedf(player_body.global_position.x, 0.001),
		"y": snappedf(player_body.global_position.y, 0.001),
		"z": snappedf(player_body.global_position.z, 0.001)
	})

func _create_spawn_marker() -> void:
	if world == null:
		print("SPAWN_MARKER_FAILED: world is null")
		return

	if spawn_marker != null and is_instance_valid(spawn_marker):
		spawn_marker.queue_free()
		spawn_marker = null

	spawn_marker = MeshInstance3D.new()
	spawn_marker.name = "SpawnMarker"

	var mesh := CylinderMesh.new()
	mesh.top_radius = spawn_marker_radius
	mesh.bottom_radius = spawn_marker_radius
	mesh.height = spawn_marker_thickness
	spawn_marker.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = spawn_marker_color
	mat.emission_enabled = true
	mat.emission = spawn_marker_color * 1.2
	mat.roughness = 0.4
	spawn_marker.material_override = mat

	spawn_marker.position = spawn_position + Vector3(0, spawn_marker_y_offset, 0)
	world.add_child(spawn_marker)

	print("SPAWN_MARKER_CREATED = ", spawn_marker.position)

func _is_player_in_spawn_zone() -> bool:
	if player_body == null:
		return false

	var pos := player_body.global_position
	var dx := pos.x - spawn_position.x
	var dz := pos.z - spawn_position.z
	var dist_sq := dx * dx + dz * dz
	return dist_sq <= spawn_zone_radius * spawn_zone_radius

func _update_spawn_zone_state(force_emit_enter: bool) -> void:
	var inside := _is_player_in_spawn_zone()

	if force_emit_enter:
		player_inside_spawn_zone = inside
		if inside:
			_log_event("spawn_zone_enter", _build_spawn_zone_payload())
		return

	if inside != player_inside_spawn_zone:
		player_inside_spawn_zone = inside
		if inside:
			_log_event("spawn_zone_enter", _build_spawn_zone_payload())
		else:
			_log_event("spawn_zone_exit", _build_spawn_zone_payload())

func _build_spawn_zone_payload() -> Dictionary:
	var payload := {
		"spawn_x": snappedf(spawn_position.x, 0.001),
		"spawn_y": snappedf(spawn_position.y, 0.001),
		"spawn_z": snappedf(spawn_position.z, 0.001),
		"radius": spawn_zone_radius
	}

	if player_body != null:
		payload["player_x"] = snappedf(player_body.global_position.x, 0.001)
		payload["player_y"] = snappedf(player_body.global_position.y, 0.001)
		payload["player_z"] = snappedf(player_body.global_position.z, 0.001)

	return payload

func _log_event(event_name: String, payload: Dictionary = {}) -> void:
	if logger_node == null:
		return
	if logger_node.has_method("mark_event"):
		logger_node.call("mark_event", event_name, payload)
