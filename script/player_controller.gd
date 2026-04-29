extends Node

@export var move_speed: float = 5.0
@export var turn_speed_deg: float = 90.0
@export var move_deadzone: float = 0.12
@export var turn_deadzone: float = 0.20

@export var teleport_max_distance: float = 20.0
@export var teleport_ground_y: float = 0.0
@export var teleport_hold_button: String = "trigger"
@export var hint_toggle_button: String = "by_button"

@export var show_teleport_visuals: bool = true
@export var log_move_interval_sec: float = 0.25
@export var log_turn_interval_sec: float = 0.25

var player_body: CharacterBody3D = null
var xr_origin: XROrigin3D = null
var xr_camera: XRCamera3D = null
var left_controller: XRController3D = null
var right_controller: XRController3D = null
var debug_label: Label3D = null
var logger_node: Node = null
var hint_manager: Node = null
var action_status_label: Label3D = null

var is_ready: bool = false
var _move_log_timer: float = 0.0
var _turn_log_timer: float = 0.0

var _teleport_hold_prev: bool = false
var _hint_toggle_button_prev: bool = false
var _action_status_timer: float = 0.0

var _teleport_ray_visual: MeshInstance3D = null
var _teleport_marker_visual: MeshInstance3D = null

func setup(
	p_player_body: CharacterBody3D,
	p_xr_origin: XROrigin3D,
	p_xr_camera: XRCamera3D,
	p_left_controller: XRController3D,
	p_right_controller: XRController3D,
	p_debug_label: Label3D,
	p_logger_node: Node = null,
	p_hint_manager: Node = null,
	p_action_status_label: Label3D = null
) -> void:
	player_body = p_player_body
	xr_origin = p_xr_origin
	xr_camera = p_xr_camera
	left_controller = p_left_controller
	right_controller = p_right_controller
	debug_label = p_debug_label
	logger_node = p_logger_node
	hint_manager = p_hint_manager
	action_status_label = p_action_status_label

	if player_body != null:
		player_body.velocity = Vector3.ZERO

	if action_status_label != null:
		action_status_label.text = ""
		action_status_label.visible = false

	_ensure_teleport_visuals()
	_hide_teleport_visuals()

	is_ready = true
	print("PLAYER_CONTROLLER_READY")
	_log_event("locomotion_mode_set", {"mode": "smooth_with_hold_teleport"})

func _physics_process(delta: float) -> void:
	if not is_ready:
		return

	_move_log_timer += delta
	_turn_log_timer += delta

	var move_input: Vector2 = _get_left_stick_vector()
	var turn_input: Vector2 = _get_right_stick_vector()

	_handle_hint_toggle()
	_handle_hold_teleport()

	_apply_smooth_move(move_input, delta)
	_apply_smooth_turn(turn_input, delta)

	_update_action_status_timer(delta)
	#_update_debug(move_input, turn_input)

func _handle_hint_toggle() -> void:
	var pressed := _is_button_pressed(right_controller, hint_toggle_button)
	if pressed and not _hint_toggle_button_prev:
		if hint_manager != null and hint_manager.has_method("toggle_hints"):
			hint_manager.call("toggle_hints")

			if hint_manager.has_method("get_hints_visible"):
				var visible = hint_manager.call("get_hints_visible")
				if typeof(visible) == TYPE_BOOL and visible:
					_show_action_status("Hints ON")
				else:
					_show_action_status("Hints OFF")
			else:
				_show_action_status("Hints Toggled")

			_log_event("hint_toggle_button_pressed", {
				"button": hint_toggle_button
			})
	_hint_toggle_button_prev = pressed

func _handle_hold_teleport() -> void:
	if right_controller == null or player_body == null:
		return

	var pressed := _is_trigger_held(right_controller)

	if pressed:
		var hit := _compute_teleport_target()
		if not hit.is_empty():
			_update_teleport_visuals()
		else:
			_hide_teleport_visuals()
			_show_action_status("Aim at the floor", 0.15)
	else:
		_hide_teleport_visuals()

	# Release to teleport
	if (not pressed) and _teleport_hold_prev:
		var hit := _compute_teleport_target()
		if not hit.is_empty():
			var target: Vector3 = hit["target"]

			var head_offset := Vector3.ZERO
			if xr_camera != null:
				head_offset = xr_camera.global_position - player_body.global_position
				head_offset.y = 0.0

			player_body.global_position = target - head_offset
			player_body.velocity = Vector3.ZERO

			_show_action_status("Teleported")
			_log_event("teleport", {
				"target_x": snappedf(target.x, 0.001),
				"target_y": snappedf(target.y, 0.001),
				"target_z": snappedf(target.z, 0.001),
				"button": teleport_hold_button
			})
		else:
			_show_action_status("Teleport Invalid")

	_teleport_hold_prev = pressed

func _apply_smooth_move(input_vec: Vector2, delta: float) -> void:
	if player_body == null or xr_camera == null:
		return

	if input_vec.length() < move_deadzone:
		player_body.velocity.x = 0.0
		player_body.velocity.z = 0.0
		player_body.velocity.y = 0.0
		player_body.move_and_slide()
		return

	var basis := xr_camera.global_transform.basis
	var forward := -basis.z
	var right := basis.x

	forward.y = 0.0
	right.y = 0.0

	if forward.length() > 0.001:
		forward = forward.normalized()
	if right.length() > 0.001:
		right = right.normalized()

	var move_dir := forward * input_vec.y + right * input_vec.x
	if move_dir.length() <= 0.01:
		player_body.velocity.x = 0.0
		player_body.velocity.z = 0.0
		player_body.velocity.y = 0.0
		player_body.move_and_slide()
		return

	move_dir = move_dir.normalized()

	player_body.velocity.x = move_dir.x * move_speed
	player_body.velocity.z = move_dir.z * move_speed
	player_body.velocity.y = 0.0
	player_body.move_and_slide()

	if _move_log_timer >= log_move_interval_sec:
		_move_log_timer = 0.0
		_log_event("smooth_move", {
			"input_x": snappedf(input_vec.x, 0.01),
			"input_y": snappedf(input_vec.y, 0.01),
			"vx": snappedf(player_body.velocity.x, 0.001),
			"vy": snappedf(player_body.velocity.y, 0.001),
			"vz": snappedf(player_body.velocity.z, 0.001),
			"speed": move_speed,
			"delta": snappedf(delta, 0.001)
		})

func _apply_smooth_turn(input_vec: Vector2, delta: float) -> void:
	if xr_origin == null:
		return

	if abs(input_vec.x) < turn_deadzone:
		return

	var yaw_delta_deg := -input_vec.x * turn_speed_deg * delta
	xr_origin.rotate_y(deg_to_rad(yaw_delta_deg))

	if _turn_log_timer >= log_turn_interval_sec:
		_turn_log_timer = 0.0
		_log_event("smooth_turn", {
			"input_x": snappedf(input_vec.x, 0.01),
			"yaw_delta_deg": snappedf(yaw_delta_deg, 0.01),
			"turn_speed_deg": turn_speed_deg
		})

func _ensure_teleport_visuals() -> void:
	if xr_origin == null:
		return

	if _teleport_ray_visual == null:
		_teleport_ray_visual = MeshInstance3D.new()
		_teleport_ray_visual.name = "TeleportRayVisual"
		var ray_mesh := CylinderMesh.new()
		ray_mesh.top_radius = 0.01
		ray_mesh.bottom_radius = 0.01
		ray_mesh.height = 1.0
		_teleport_ray_visual.mesh = ray_mesh

		var ray_mat := StandardMaterial3D.new()
		ray_mat.albedo_color = Color(0.1, 0.9, 1.0, 0.9)
		ray_mat.emission_enabled = true
		ray_mat.emission = Color(0.1, 0.9, 1.0) * 0.4
		ray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_teleport_ray_visual.material_override = ray_mat
		xr_origin.add_child(_teleport_ray_visual)

	if _teleport_marker_visual == null:
		_teleport_marker_visual = MeshInstance3D.new()
		_teleport_marker_visual.name = "TeleportMarkerVisual"
		var marker_mesh := CylinderMesh.new()
		marker_mesh.top_radius = 0.22
		marker_mesh.bottom_radius = 0.22
		marker_mesh.height = 0.03
		_teleport_marker_visual.mesh = marker_mesh

		var marker_mat := StandardMaterial3D.new()
		marker_mat.albedo_color = Color(0.15, 1.0, 0.35, 0.95)
		marker_mat.emission_enabled = true
		marker_mat.emission = Color(0.15, 1.0, 0.35) * 0.45
		marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_teleport_marker_visual.material_override = marker_mat
		xr_origin.add_child(_teleport_marker_visual)

func _update_teleport_visuals() -> void:
	if not show_teleport_visuals:
		_hide_teleport_visuals()
		return
	if right_controller == null:
		_hide_teleport_visuals()
		return
	if _teleport_ray_visual == null or _teleport_marker_visual == null:
		_ensure_teleport_visuals()
		if _teleport_ray_visual == null or _teleport_marker_visual == null:
			return

	var hit := _compute_teleport_target()
	if hit.is_empty():
		_hide_teleport_visuals()
		return

	var source := right_controller.global_transform.origin
	var target: Vector3 = hit["target"]
	var segment := target - source
	var dist := segment.length()
	if dist <= 0.001:
		_hide_teleport_visuals()
		return

	_teleport_ray_visual.visible = true
	_teleport_marker_visual.visible = true

	var ray_mesh := _teleport_ray_visual.mesh as CylinderMesh
	if ray_mesh != null:
		ray_mesh.height = dist

	_teleport_ray_visual.global_position = source + segment * 0.5
	_teleport_ray_visual.look_at(target, Vector3.UP, true)
	_teleport_ray_visual.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))

	_teleport_marker_visual.global_position = target + Vector3(0, 0.03, 0)

func _hide_teleport_visuals() -> void:
	if _teleport_ray_visual != null:
		_teleport_ray_visual.visible = false
	if _teleport_marker_visual != null:
		_teleport_marker_visual.visible = false

func _compute_teleport_target() -> Dictionary:
	var source: Node3D = null
	if right_controller != null:
		source = right_controller
	elif xr_camera != null:
		source = xr_camera
	else:
		return {}

	var origin: Vector3 = source.global_transform.origin
	var forward: Vector3 = -source.global_transform.basis.z.normalized()

	# Slight downward bias so a natural hand pose can still hit the floor.
	forward = (forward + Vector3(0.0, -0.35, 0.0)).normalized()

	if abs(forward.y) < 0.0001:
		return {}

	var t: float = (teleport_ground_y - origin.y) / forward.y
	if t <= 0.0:
		return {}
	if t > teleport_max_distance:
		return {}

	var target := origin + forward * t
	return {"target": Vector3(target.x, teleport_ground_y, target.z)}

func _is_trigger_held(controller: XRController3D) -> bool:
	if controller == null:
		return false

	if controller.has_method("get_float"):
		var v = controller.get_float(teleport_hold_button)
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			return float(v) > 0.20

	if controller.has_method("is_button_pressed"):
		var r = controller.is_button_pressed(teleport_hold_button)
		if typeof(r) == TYPE_BOOL:
			return r

	return false

func _show_action_status(msg: String, duration: float = 1.2) -> void:
	if action_status_label == null:
		return
	action_status_label.text = msg
	action_status_label.visible = true
	_action_status_timer = duration

func _update_action_status_timer(delta: float) -> void:
	if action_status_label == null:
		return
	if _action_status_timer > 0.0:
		_action_status_timer -= delta
		if _action_status_timer <= 0.0:
			action_status_label.visible = false
			action_status_label.text = ""

#func _update_debug(move_input: Vector2, turn_input: Vector2) -> void:
	#if debug_label == null or player_body == null:
		#return
#
	#debug_label.text = (
		#"mode=smooth+holdtp\nL=(%.2f, %.2f)\nR=(%.2f, %.2f)\npos=(%.2f, %.2f, %.2f)" % [
			#move_input.x, move_input.y,
			#turn_input.x, turn_input.y,
			#player_body.global_position.x,
			#player_body.global_position.y,
			#player_body.global_position.z
		#]
	#)

func _get_left_stick_vector() -> Vector2:
	var v := _read_controller_vector2(left_controller)
	if v.length() > 0.001:
		return v

	var x_axis := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var y_axis := Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	return Vector2(x_axis, y_axis)

func _get_right_stick_vector() -> Vector2:
	var v := _read_controller_vector2(right_controller)
	if v.length() > 0.001:
		return v

	var x_axis := Input.get_action_strength("turn_right") - Input.get_action_strength("turn_left")
	return Vector2(x_axis, 0.0)

func _read_controller_vector2(controller: XRController3D) -> Vector2:
	if controller == null:
		return Vector2.ZERO

	if controller.has_method("get_vector2"):
		var names = ["primary", "thumbstick", "joystick"]
		for name in names:
			var v = controller.get_vector2(name)
			if v is Vector2 and v.length() > 0.001:
				return v

	if controller.has_method("get_float"):
		var pairs = [
			["primary_x", "primary_y"],
			["thumbstick_x", "thumbstick_y"],
			["joystick_x", "joystick_y"]
		]
		for pair in pairs:
			var x = controller.get_float(pair[0])
			var y = controller.get_float(pair[1])
			var v2 := Vector2(x, y)
			if v2.length() > 0.001:
				return v2

	return Vector2.ZERO

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

func _log_event(event_name: String, payload: Dictionary = {}) -> void:
	if logger_node == null:
		return
	if logger_node.has_method("mark_event"):
		logger_node.call("mark_event", event_name, payload)
