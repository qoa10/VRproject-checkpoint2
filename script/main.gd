extends Node3D

@onready var player_body: CharacterBody3D = $CharacterBody3D
@onready var xr_origin: XROrigin3D = $CharacterBody3D/XROrigin3D
@onready var xr_camera: XRCamera3D = $CharacterBody3D/XROrigin3D/XRCamera3D
@onready var left_controller: XRController3D = $CharacterBody3D/XROrigin3D/LeftController
@onready var right_controller: XRController3D = $CharacterBody3D/XROrigin3D/RightController

@onready var world: Node3D = $World
@onready var systems: Node = $Systems
@onready var ui: Node3D = $UI
@onready var debug_label: Label3D = $UI/DebugLabel
@onready var hint_label: Label3D = $CharacterBody3D/XROrigin3D/XRCamera3D/HintLabel
@onready var pickup_count_label: Label3D = $CharacterBody3D/XROrigin3D/XRCamera3D/PickupCountLabel
@onready var floating_hint_label: Label3D = $UI/FloatingHintLabel

@onready var player_controller: Node = $Systems/PlayerController
@onready var city_builder: Node = $Systems/CityBuilder
@onready var logger_node: Node = $Systems/Logger
@onready var pickup_manager: Node = $Systems/PickupManager
@onready var spawn_manager: Node = $Systems/SpawnManager
@onready var experiment_manager: Node = $Systems/ExperimentManager
@onready var hint_manager: Node = $Systems/HintManager
@onready var user_marker_manager: Node = $Systems/UserMarkerManager
@onready var action_status_label: Label3D = $CharacterBody3D/XROrigin3D/XRCamera3D/ActionStatusLabel

@onready var sun: DirectionalLight3D = $DirectionalLight3D


func _ready() -> void:
	_start_openxr()
	_validate_scene_tree()
	_setup_light()

	if debug_label != null:
		debug_label.text = ""
		debug_label.visible = false
		debug_label.queue_free()

	if hint_label != null:
		hint_label.position = Vector3(0.0, 0.15, -1.2)

	if pickup_count_label != null:
		pickup_count_label.position = Vector3(-0.35, 0.28, -1.2)
		pickup_count_label.text = "Collected: 0"

	_setup_systems()


func _setup_light() -> void:
	if sun == null:
		return

	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_energy = 0.35
	sun.shadow_enabled = false


func _start_openxr() -> void:
	var xr_interface := XRServer.find_interface("OpenXR")
	if xr_interface == null:
		print("OPENXR_INTERFACE_NOT_FOUND")
		_set_debug_text("OPENXR_INTERFACE_NOT_FOUND")
		return

	print("OPENXR_INTERFACE_FOUND")
	var ok := xr_interface.initialize()
	print("OPENXR_INITIALIZE_RESULT=", ok)

	if ok:
		get_viewport().use_xr = true
		print("OPENXR_STARTED")
		_set_debug_text("OPENXR_STARTED")
	else:
		print("OPENXR_FAILED")
		_set_debug_text("OPENXR_FAILED")


func _validate_scene_tree() -> void:
	if player_body == null:
		push_error("Missing node: CharacterBody3D")
	if xr_origin == null:
		push_error("Missing node: CharacterBody3D/XROrigin3D")
	if xr_camera == null:
		push_error("Missing node: CharacterBody3D/XROrigin3D/XRCamera3D")
	if left_controller == null:
		push_error("Missing node: CharacterBody3D/XROrigin3D/LeftController")
	if right_controller == null:
		push_error("Missing node: CharacterBody3D/XROrigin3D/RightController")

	if world == null:
		push_error("Missing node: World")
	if systems == null:
		push_error("Missing node: Systems")
	if ui == null:
		push_error("Missing node: UI")

	if debug_label == null:
		push_error("Missing node: UI/DebugLabel")
	if hint_label == null:
		push_error("Missing node: CharacterBody3D/XROrigin3D/XRCamera3D/HintLabel")
	if pickup_count_label == null:
		push_error("Missing node: CharacterBody3D/XROrigin3D/XRCamera3D/PickupCountLabel")
	if floating_hint_label == null:
		push_error("Missing node: UI/FloatingHintLabel")

	if player_controller == null:
		push_error("Missing node: Systems/PlayerController")
	if city_builder == null:
		push_error("Missing node: Systems/CityBuilder")
	if logger_node == null:
		push_error("Missing node: Systems/Logger")
	if pickup_manager == null:
		push_error("Missing node: Systems/PickupManager")
	if spawn_manager == null:
		push_error("Missing node: Systems/SpawnManager")
	if experiment_manager == null:
		push_error("Missing node: Systems/ExperimentManager")
	if hint_manager == null:
		push_error("Missing node: Systems/HintManager")
	if user_marker_manager == null:
		push_error("Missing node: Systems/UserMarkerManager")

	print("SCENE_TREE_VALIDATED")


func _setup_systems() -> void:
	if logger_node != null and logger_node.has_method("setup"):
		logger_node.call("setup", xr_origin, xr_camera, self)
		print("Logger setup done.")
	else:
		print("Logger has no setup() yet.")

	if player_controller != null and player_controller.has_method("setup"):
		player_controller.call(
			"setup",
			player_body,
			xr_origin,
			xr_camera,
			left_controller,
			right_controller,
			debug_label,
			logger_node,
			hint_manager,
			action_status_label
		)
		print("PlayerController setup done.")
	else:
		print("PlayerController has no setup() yet.")

	if city_builder != null and city_builder.has_method("setup"):
		city_builder.call("setup", world)
		print("CityBuilder setup done.")
	else:
		print("CityBuilder has no setup() yet.")

	if spawn_manager != null and spawn_manager.has_method("setup"):
		spawn_manager.call(
			"setup",
			city_builder,
			player_body,
			xr_camera,
			logger_node,
			world
		)
		print("SpawnManager setup done.")
	else:
		print("SpawnManager has no setup() yet.")

	if hint_manager != null and hint_manager.has_method("setup"):
		hint_manager.call(
			"setup",
			city_builder,
			spawn_manager,
			logger_node,
			world,
			xr_camera
		)
		print("HintManager setup done.")
	else:
		print("HintManager has no setup() yet.")

	if pickup_manager != null and pickup_manager.has_method("setup"):
		pickup_manager.call(
			"setup",
			xr_origin,
			xr_camera,
			left_controller,
			right_controller,
			logger_node,
			world,
			floating_hint_label,
			pickup_count_label
		)
		print("PickupManager setup done.")
	else:
		print("PickupManager has no setup() yet.")

	if experiment_manager != null and experiment_manager.has_method("setup"):
		experiment_manager.call(
			"setup",
			spawn_manager,
			pickup_manager,
			logger_node,
			hint_label,
			user_marker_manager,
			hint_manager
		)
		print("ExperimentManager setup done.")
	else:
		print("ExperimentManager has no setup() yet.")

	if user_marker_manager != null and user_marker_manager.has_method("setup"):
		user_marker_manager.call(
			"setup",
			xr_camera,
			left_controller,
			logger_node,
			world
		)
		print("UserMarkerManager setup done.")
	else:
		print("UserMarkerManager has no setup() yet.")


func _set_debug_text(msg: String) -> void:
	return
