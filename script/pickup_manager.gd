extends Node

# PickupManager v4
# Experimental supply-item version with:
# - collectible green spheres
# - current-trial collected count HUD
# - respawn per trial
# - reset collected count per trial

@export var pickup_action_name: String = "ax_button"
@export var pickup_radius: float = 1.5
@export var enable_debug_print: bool = true
@export var enable_highlight_hint: bool = true
@export var debug_status_every_sec: float = 1.0

@export var auto_spawn_on_setup: bool = true
@export var supply_item_count: int = 25
@export var supply_spawn_margin_in_cell: float = 1.0
@export var min_spawn_distance_from_spawn_marker: float = 18.0
@export var supply_ball_radius: float = 0.30
@export var supply_ball_height_offset: float = 0.38
@export var supply_ball_color: Color = Color(0.15, 0.95, 0.25)
@export var supply_ball_emission_strength: float = 0.6

var xr_origin: XROrigin3D = null
var xr_camera: XRCamera3D = null
var left_controller: XRController3D = null
var right_controller: XRController3D = null
var logger_node = null
var world: Node3D = null
var floating_hint_label: Label3D = null
var pickup_count_label: Label3D = null

var is_ready: bool = false
var _pickup_button_prev: bool = false
var _debug_time_accum: float = 0.0
var _highlighted_object: RigidBody3D = null

var _rng := RandomNumberGenerator.new()
var _spawned_supply_items: Array[RigidBody3D] = []
var _current_trial_index: int = 0
var _collected_in_current_trial: int = 0

func setup(
	p_xr_origin: XROrigin3D,
	p_xr_camera: XRCamera3D,
	p_left_controller: XRController3D,
	p_right_controller: XRController3D,
	p_logger_node = null,
	p_world: Node3D = null,
	p_floating_hint_label: Label3D = null,
	p_pickup_count_label: Label3D = null
) -> void:
	xr_origin = p_xr_origin
	xr_camera = p_xr_camera
	left_controller = p_left_controller
	right_controller = p_right_controller
	logger_node = p_logger_node
	world = p_world
	floating_hint_label = p_floating_hint_label
	pickup_count_label = p_pickup_count_label

	_rng.randomize()

	is_ready = true
	_debug_print("PICKUP_MANAGER_READY action=%s radius=%.2f" % [pickup_action_name, pickup_radius])

	_reset_trial_pickup_count()

	if auto_spawn_on_setup:
		spawn_supply_items()

func _process(delta: float) -> void:
	if not is_ready:
		return
	if right_controller == null:
		return

	_update_highlight_hint()
	_handle_pickup_toggle()
	_update_floating_hint_label()
	_update_pickup_count_label()

	_debug_time_accum += delta
	if _debug_time_accum >= debug_status_every_sec:
		_debug_time_accum = 0.0
		_debug_nearest_status()

# =========================================================
# Public trial helpers
# =========================================================

func get_collected_count_current_trial() -> int:
	return _collected_in_current_trial

func reset_trial_pickup_count() -> void:
	_reset_trial_pickup_count()

func clear_supply_items() -> void:
	for item in _spawned_supply_items:
		if item != null and is_instance_valid(item):
			item.queue_free()
	_spawned_supply_items.clear()

	if _highlighted_object != null:
		_highlighted_object = null

func spawn_supply_items() -> void:
	clear_supply_items()

	var cells_root := _get_cells_root()
	if cells_root == null:
		_debug_print("SUPPLY_SPAWN_FAILED cells_root=null")
		return

	var candidate_cells: Array[Node3D] = _get_valid_spawn_cells(cells_root)
	if candidate_cells.is_empty():
		_debug_print("SUPPLY_SPAWN_FAILED no_valid_cells")
		return

	candidate_cells.shuffle()

	var spawn_count := mini(supply_item_count, candidate_cells.size())
	for i in range(spawn_count):
		var cell := candidate_cells[i]
		var item := _spawn_supply_item_in_cell(cell, i)
		if item != null:
			_spawned_supply_items.append(item)

	_debug_print("SUPPLY_SPAWN_DONE count=%d" % _spawned_supply_items.size())
	_log_event("supply_spawn_batch", {
		"trial_index": _current_trial_index,
		"spawned_count": _spawned_supply_items.size()
	})

func respawn_supply_items_for_trial(trial_index: int) -> void:
	_current_trial_index = trial_index
	_reset_trial_pickup_count()
	spawn_supply_items()

# =========================================================
# UI
# =========================================================

func _update_floating_hint_label() -> void:
	if floating_hint_label == null:
		return

	var candidate := _find_nearest_pickupable()
	if candidate == null:
		floating_hint_label.visible = false
		floating_hint_label.text = ""
		return

	floating_hint_label.visible = true
	floating_hint_label.text = "Press A"

	var body_pos := candidate.global_transform.origin
	floating_hint_label.global_position = body_pos + Vector3(0, 0.45, 0)

func _update_pickup_count_label() -> void:
	if pickup_count_label == null:
		return
	pickup_count_label.text = "Collected: %d" % _collected_in_current_trial

func _reset_trial_pickup_count() -> void:
	_collected_in_current_trial = 0
	_update_pickup_count_label()

# =========================================================
# Pickup / collect
# =========================================================

func _handle_pickup_toggle() -> void:
	var pressed := _is_button_pressed(right_controller, pickup_action_name)
	if pressed and not _pickup_button_prev:
		_debug_print("BUTTON_DETECTED action=%s" % pickup_action_name)
		_try_collect_supply_item()
	_pickup_button_prev = pressed

func _try_collect_supply_item() -> void:
	var candidate := _find_nearest_pickupable()
	if candidate == null:
		_debug_print("COLLECT_NONE_FOUND radius=%.2f" % pickup_radius)
		_log_event("pickup_none_found", {
			"radius": pickup_radius,
			"action": pickup_action_name,
			"trial_index": _current_trial_index
		})
		return

	var collected_name := candidate.name
	var collected_pos := candidate.global_position

	if _highlighted_object == candidate:
		_clear_highlight_hint()

	candidate.remove_from_group("pickupable")
	_spawned_supply_items.erase(candidate)
	candidate.queue_free()

	_collected_in_current_trial += 1
	_update_pickup_count_label()

	print("COLLECT_SUCCESS:", collected_name)
	_log_event("pickup_collect", {
		"object_name": collected_name,
		"x": snappedf(collected_pos.x, 0.001),
		"y": snappedf(collected_pos.y, 0.001),
		"z": snappedf(collected_pos.z, 0.001),
		"trial_index": _current_trial_index,
		"collected_in_trial": _collected_in_current_trial
	})

	_debug_print("COLLECT_OK object=%s count=%d" % [collected_name, _collected_in_current_trial])

# =========================================================
# Nearest search
# =========================================================

func _find_nearest_pickupable() -> RigidBody3D:
	var best: RigidBody3D = null
	var best_dist := INF
	var hand_pos := right_controller.global_transform.origin

	var nodes := get_tree().get_nodes_in_group("pickupable")
	for n in nodes:
		if not (n is RigidBody3D):
			continue
		var rb := n as RigidBody3D
		if not is_instance_valid(rb):
			continue
		var d := hand_pos.distance_to(rb.global_transform.origin)
		if d <= pickup_radius and d < best_dist:
			best = rb
			best_dist = d

	return best

func _find_nearest_pickupable_any_distance() -> Dictionary:
	var best: RigidBody3D = null
	var best_dist := INF
	if right_controller == null:
		return {"node": null, "distance": INF}

	var hand_pos := right_controller.global_transform.origin
	var nodes := get_tree().get_nodes_in_group("pickupable")
	for n in nodes:
		if not (n is RigidBody3D):
			continue
		var rb := n as RigidBody3D
		if not is_instance_valid(rb):
			continue
		var d := hand_pos.distance_to(rb.global_transform.origin)
		if d < best_dist:
			best = rb
			best_dist = d

	return {"node": best, "distance": best_dist}

# =========================================================
# Spawn helpers
# =========================================================

func _get_cells_root() -> Node3D:
	if world == null:
		return null

	var generated := world.get_node_or_null("GeneratedBackrooms")
	if generated == null:
		return null

	var cells_root := generated.get_node_or_null("Cells")
	if cells_root is Node3D:
		return cells_root as Node3D

	return null

func _get_valid_spawn_cells(cells_root: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var has_spawn_marker: bool = _has_spawn_marker()
	var spawn_marker_pos: Vector3 = _get_spawn_marker_position()
	var min_dist_sq: float = min_spawn_distance_from_spawn_marker * min_spawn_distance_from_spawn_marker

	for child in cells_root.get_children():
		if not (child is Node3D):
			continue

		var cell := child as Node3D
		var pos: Vector3 = cell.global_position

		if has_spawn_marker:
			var dx: float = pos.x - spawn_marker_pos.x
			var dz: float = pos.z - spawn_marker_pos.z
			var dist_sq: float = dx * dx + dz * dz
			if dist_sq < min_dist_sq:
				continue

		result.append(cell)

	return result

func _has_spawn_marker() -> bool:
	if world == null:
		return false

	var marker := world.get_node_or_null("SpawnMarker")
	return marker is Node3D

func _get_spawn_marker_position() -> Vector3:
	if world == null:
		return Vector3.ZERO

	var marker := world.get_node_or_null("SpawnMarker")
	if marker is Node3D:
		return (marker as Node3D).global_position

	return Vector3.ZERO

func _spawn_supply_item_in_cell(cell: Node3D, index: int) -> RigidBody3D:
	if world == null:
		return null

	var body := RigidBody3D.new()
	body.name = "SupplyBall_%03d" % index
	body.freeze = true
	body.gravity_scale = 0.0
	body.linear_damp = 5.0
	body.angular_damp = 5.0

	var half_range: float = maxf(0.1, (2.75 - supply_spawn_margin_in_cell))
	var local_x: float = _rng.randf_range(-half_range, half_range)
	var local_z: float = _rng.randf_range(-half_range, half_range)

	body.global_position = cell.global_position + Vector3(local_x, supply_ball_height_offset, local_z)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = supply_ball_radius
	collision.shape = shape
	body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = supply_ball_radius
	sphere.height = supply_ball_radius * 2.0
	mesh_instance.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = supply_ball_color
	mat.emission_enabled = true
	mat.emission = supply_ball_color * supply_ball_emission_strength
	mat.roughness = 0.55
	mesh_instance.material_override = mat
	body.add_child(mesh_instance)

	body.add_to_group("pickupable")
	world.add_child(body)

	return body

# =========================================================
# Highlight
# =========================================================

func _update_highlight_hint() -> void:
	if not enable_highlight_hint:
		_clear_highlight_hint()
		return

	var candidate := _find_nearest_pickupable()
	_set_highlight_target(candidate)

func _set_highlight_target(target: RigidBody3D) -> void:
	if _highlighted_object == target:
		return

	if _highlighted_object != null and is_instance_valid(_highlighted_object):
		_apply_highlight_to_object(_highlighted_object, false)

	_highlighted_object = target

	if _highlighted_object != null and is_instance_valid(_highlighted_object):
		_apply_highlight_to_object(_highlighted_object, true)

func _clear_highlight_hint() -> void:
	if _highlighted_object != null and is_instance_valid(_highlighted_object):
		_apply_highlight_to_object(_highlighted_object, false)
	_highlighted_object = null

func _apply_highlight_to_object(body: RigidBody3D, enabled: bool) -> void:
	if body == null:
		return
	for child in body.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var mat := mi.material_override as StandardMaterial3D
			if mat == null:
				continue
			if enabled:
				mat.emission_enabled = true
				mat.emission = mat.albedo_color * 1.2
			else:
				mat.emission_enabled = true
				mat.emission = mat.albedo_color * supply_ball_emission_strength

# =========================================================
# Input / debug
# =========================================================

func _is_button_pressed(controller: XRController3D, action_name: String) -> bool:
	if controller == null:
		return false

	if controller.has_method("is_button_pressed"):
		var candidates = [action_name, action_name.to_lower(), action_name.to_upper()]
		for c in candidates:
			var r = controller.is_button_pressed(c)
			if typeof(r) == TYPE_BOOL and r:
				return true

	if controller.has_method("get_float"):
		var v = controller.get_float(action_name)
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			return float(v) > 0.5

	return Input.is_action_pressed(action_name)

func _debug_nearest_status() -> void:
	var info: Dictionary = _find_nearest_pickupable_any_distance()
	var nearest: RigidBody3D = info["node"] as RigidBody3D
	var dist: float = float(info["distance"])

	if nearest == null:
		_debug_print("NEAREST none")
		return

	var within: bool = dist <= pickup_radius
	_debug_print("NEAREST object=%s dist=%.3f within_radius=%s" % [nearest.name, dist, str(within)])

func _debug_print(msg: String) -> void:
	if enable_debug_print:
		print(msg)

func _log_event(event_name: String, payload: Dictionary = {}) -> void:
	if logger_node != null and logger_node.has_method("mark_event"):
		logger_node.call("mark_event", event_name, payload)
