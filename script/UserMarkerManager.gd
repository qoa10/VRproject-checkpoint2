extends Node

@export var place_button: String = "trigger"
@export var trigger_threshold: float = 0.55

@export var min_marker_distance: float = 1.2
@export var fallback_marker_distance: float = 1.8
@export var max_marker_distance: float = 3.0

@export var marker_ground_y: float = 0.02
@export var marker_max_count: int = 12
@export var marker_radius: float = 0.28
@export var marker_height: float = 0.06
@export var marker_color: Color = Color(1.0, 0.9, 0.15, 0.95)

@export var preview_marker_color: Color = Color(0.15, 0.9, 1.0, 0.55)
@export var preview_dash_color: Color = Color(0.15, 0.9, 1.0, 0.85)
@export var preview_dash_count: int = 12
@export var preview_dash_thickness: float = 0.025

@export var info_label_local_position: Vector3 = Vector3(0.35, 0.18, -1.1)

var xr_camera: XRCamera3D = null
var left_controller: XRController3D = null
var logger_node: Node = null
var world: Node3D = null

var is_ready: bool = false
var _place_button_prev: bool = false

var _markers_root: Node3D = null
var _markers: Array[Node3D] = []

var _preview_root: Node3D = null
var _preview_marker: MeshInstance3D = null
var _preview_dashes: Array[MeshInstance3D] = []

var _has_preview_target: bool = false
var _last_preview_target: Vector3 = Vector3.ZERO

var _info_label: Label3D = null
var _status_timer: float = 0.0
var _status_override_text: String = ""


func setup(
	p_xr_camera: XRCamera3D,
	p_left_controller: XRController3D,
	p_logger_node: Node,
	p_world: Node3D
) -> void:
	xr_camera = p_xr_camera
	left_controller = p_left_controller
	logger_node = p_logger_node
	world = p_world

	_ensure_markers_root()
	_ensure_preview_visuals()
	_ensure_info_label()

	_hide_preview()
	_refresh_info_label()

	is_ready = true
	print("USER_MARKER_MANAGER_READY")


func _physics_process(delta: float) -> void:
	if not is_ready:
		return

	_update_status_timer(delta)

	var pressed := _is_button_pressed(left_controller, place_button)
	var remaining: int = get_remaining_markers()

	if pressed:
		if remaining <= 0:
			_hide_preview()
			_show_status("No markers left")
		else:
			if _update_preview():
				pass
			else:
				_hide_preview()

	if (not pressed) and _place_button_prev:
		if remaining <= 0:
			_hide_preview()
			_show_status("No markers left")
		else:
			if _has_preview_target:
				_place_marker_at(_last_preview_target)
		_hide_preview()

	if not pressed and not _place_button_prev:
		_hide_preview()

	_place_button_prev = pressed

func get_used_marker_count_current_trial() -> int:
	return _markers.size()

func clear_all_markers() -> void:
	for marker in _markers:
		if marker != null and is_instance_valid(marker):
			marker.queue_free()
	_markers.clear()

	_hide_preview()
	_refresh_info_label()
	_show_status("Markers reset")

	_log_event("user_markers_cleared", {})


func get_remaining_markers() -> int:
	return marker_max_count - _markers.size()


func _ensure_markers_root() -> void:
	if world == null:
		return

	var existing := world.get_node_or_null("UserMarkers")
	if existing != null and existing is Node3D:
		_markers_root = existing as Node3D
		return

	_markers_root = Node3D.new()
	_markers_root.name = "UserMarkers"
	world.add_child(_markers_root)


func _ensure_preview_visuals() -> void:
	if world == null:
		return

	var existing_root := world.get_node_or_null("UserMarkerPreviewRoot")
	if existing_root != null and existing_root is Node3D:
		existing_root.queue_free()

	_preview_root = Node3D.new()
	_preview_root.name = "UserMarkerPreviewRoot"
	world.add_child(_preview_root)

	_preview_marker = MeshInstance3D.new()
	_preview_marker.name = "UserMarkerPreview"

	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = marker_radius
	marker_mesh.bottom_radius = marker_radius
	marker_mesh.height = marker_height
	_preview_marker.mesh = marker_mesh

	var marker_mat := StandardMaterial3D.new()
	marker_mat.albedo_color = preview_marker_color
	marker_mat.emission_enabled = true
	marker_mat.emission = preview_marker_color * 0.5
	marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_marker.material_override = marker_mat
	_preview_root.add_child(_preview_marker)

	_preview_dashes.clear()

	for i in range(preview_dash_count):
		var dash := MeshInstance3D.new()
		dash.name = "Dash_%d" % i

		var dash_mesh := BoxMesh.new()
		dash_mesh.size = Vector3(preview_dash_thickness, preview_dash_thickness, 0.1)
		dash.mesh = dash_mesh

		var dash_mat := StandardMaterial3D.new()
		dash_mat.albedo_color = preview_dash_color
		dash_mat.emission_enabled = true
		dash_mat.emission = preview_dash_color * 0.65
		dash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dash.material_override = dash_mat

		_preview_root.add_child(dash)
		_preview_dashes.append(dash)


func _ensure_info_label() -> void:
	if xr_camera == null:
		return

	var existing := xr_camera.get_node_or_null("MarkerInfoLabel")
	if existing != null and existing is Label3D:
		_info_label = existing as Label3D
		_info_label.position = info_label_local_position
		return

	_info_label = Label3D.new()
	_info_label.name = "MarkerInfoLabel"
	_info_label.position = info_label_local_position
	_info_label.font_size = 28
	_info_label.pixel_size = 0.0025
	_info_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_info_label.no_depth_test = true
	_info_label.modulate = Color(1.0, 1.0, 1.0)
	xr_camera.add_child(_info_label)


func _update_preview() -> bool:
	if left_controller == null and xr_camera == null:
		return false

	var origin := _get_pointer_origin()
	var direction := _get_pointer_direction()

	if direction.length() < 0.001:
		return false

	var target: Vector3 = _compute_target(origin, direction)

	_last_preview_target = target
	_has_preview_target = true

	_show_preview(origin, target)
	_refresh_info_label()
	return true


func _get_pointer_origin() -> Vector3:
	if left_controller != null:
		return left_controller.global_position
	if xr_camera != null:
		return xr_camera.global_position
	return Vector3.ZERO


func _get_pointer_direction() -> Vector3:
	if left_controller != null:
		return -left_controller.global_transform.basis.z
	if xr_camera != null:
		return -xr_camera.global_transform.basis.z
	return Vector3.FORWARD


func _compute_target(origin: Vector3, direction: Vector3) -> Vector3:
	var dir: Vector3 = direction.normalized()
	var ground_y: float = marker_ground_y + marker_height * 0.5

	if dir.y < -0.08:
		var t: float = (ground_y - origin.y) / dir.y
		if t > 0.0:
			var raw_dist: float = clamp(t, min_marker_distance, max_marker_distance)
			var dist: float = lerpf(fallback_marker_distance, raw_dist, 0.55)
			var target_ray: Vector3 = origin + dir * dist
			target_ray.y = ground_y
			return target_ray

	var flat_dir: Vector3 = Vector3(dir.x, 0.0, dir.z)

	if flat_dir.length() < 0.001:
		if xr_camera != null:
			var cam_forward: Vector3 = -xr_camera.global_transform.basis.z
			flat_dir = Vector3(cam_forward.x, 0.0, cam_forward.z)

	if flat_dir.length() < 0.001:
		flat_dir = Vector3(0.0, 0.0, -1.0)

	flat_dir = flat_dir.normalized()

	var target: Vector3 = origin + flat_dir * fallback_marker_distance
	target.y = ground_y
	return target


func _show_preview(origin: Vector3, target: Vector3) -> void:
	if _preview_root == null:
		return

	_preview_root.visible = true

	if _preview_marker != null:
		_preview_marker.visible = true
		_preview_marker.global_position = target

	_update_preview_dashes(origin, target)


func _update_preview_dashes(origin: Vector3, target: Vector3) -> void:
	if _preview_dashes.is_empty():
		return

	var total_units := preview_dash_count * 2 - 1
	if total_units <= 0:
		return

	for i in range(_preview_dashes.size()):
		var dash := _preview_dashes[i]
		if dash == null:
			continue

		var a_t: float = float(i * 2) / float(total_units)
		var b_t: float = float(i * 2 + 1) / float(total_units)

		var p0: Vector3 = origin.lerp(target, a_t)
		var p1: Vector3 = origin.lerp(target, b_t)

		_place_dash(dash, p0, p1)


func _place_dash(dash: MeshInstance3D, p0: Vector3, p1: Vector3) -> void:
	var seg_len: float = p0.distance_to(p1)
	if seg_len < 0.001:
		dash.visible = false
		return

	dash.visible = true
	dash.global_position = (p0 + p1) * 0.5
	dash.look_at(p1, Vector3.UP)

	var dash_mesh := dash.mesh as BoxMesh
	if dash_mesh != null:
		dash_mesh.size = Vector3(preview_dash_thickness, preview_dash_thickness, seg_len)


func _hide_preview() -> void:
	_has_preview_target = false

	if _preview_root != null:
		_preview_root.visible = false

	if _preview_marker != null:
		_preview_marker.visible = false

	for dash in _preview_dashes:
		if dash != null:
			dash.visible = false

	_refresh_info_label()


func _place_marker_at(target: Vector3) -> void:
	if _markers_root == null:
		return

	var marker := _build_marker()
	marker.global_position = target
	_markers_root.add_child(marker)
	_markers.append(marker)

	if _markers.size() > marker_max_count:
		var oldest := _markers[0]
		_markers.remove_at(0)
		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()

	_refresh_info_label()

	_log_event("user_marker_placed", {
		"x": snappedf(target.x, 0.001),
		"y": snappedf(target.y, 0.001),
		"z": snappedf(target.z, 0.001),
		"count": _markers.size(),
		"remaining": get_remaining_markers()
	})


func _build_marker() -> Node3D:
	var root := Node3D.new()
	root.name = "UserMarker"

	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = marker_radius
	mesh.bottom_radius = marker_radius
	mesh.height = marker_height
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3.ZERO

	var mat := StandardMaterial3D.new()
	mat.albedo_color = marker_color
	mat.emission_enabled = true
	mat.emission = marker_color * 0.45
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = mat

	root.add_child(mesh_instance)
	return root


func _refresh_info_label() -> void:
	if _info_label == null:
		return

	if _status_timer > 0.0 and _status_override_text != "":
		_info_label.text = _status_override_text
		return

	_info_label.text = "Markers Left: %d" % get_remaining_markers()


func _show_status(msg: String, duration: float = 1.0) -> void:
	_status_override_text = msg
	_status_timer = duration
	_refresh_info_label()


func _update_status_timer(delta: float) -> void:
	if _status_timer > 0.0:
		_status_timer -= delta
		if _status_timer <= 0.0:
			_status_timer = 0.0
			_status_override_text = ""
			_refresh_info_label()


func _is_button_pressed(controller: XRController3D, action_name: String) -> bool:
	if controller == null:
		return false

	if controller.has_method("get_float"):
		var analog_names := [action_name]
		if action_name == "trigger":
			analog_names.append("trigger_click")

		for n in analog_names:
			var v = controller.get_float(n)
			if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
				if float(v) >= trigger_threshold:
					return true

	if controller.has_method("is_button_pressed"):
		var button_names := [action_name]
		if action_name == "trigger":
			button_names.append("trigger_click")

		for n in button_names:
			var r = controller.is_button_pressed(n)
			if typeof(r) == TYPE_BOOL and r:
				return true

	return Input.is_action_pressed(action_name)


func _log_event(event_name: String, payload: Dictionary = {}) -> void:
	if logger_node == null:
		return
	if logger_node.has_method("mark_event"):
		logger_node.call("mark_event", event_name, payload)
