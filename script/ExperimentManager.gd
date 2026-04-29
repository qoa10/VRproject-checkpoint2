extends Node

@export var explore_duration_sec: float = 100
@export var auto_start_on_setup: bool = true
@export var show_phase_text_on_hint_label: bool = true

var spawn_manager: Node = null
var pickup_manager: Node = null
var logger_node: Node = null
var hint_label: Label3D = null
var user_marker_manager: Node = null
var hint_manager: Node = null

var state: String = "IDLE"
var phase_time_sec: float = 0.0
var total_time_sec: float = 0.0
var experiment_running: bool = false
var has_left_spawn_once: bool = false
var trial_index: int = 0

var _return_phase_start_total_time: float = 0.0

var _summary_log_path: String = ""
var _summary_header_written: bool = false


func setup(
	p_spawn_manager: Node,
	p_pickup_manager: Node,
	p_logger_node: Node,
	p_hint_label: Label3D,
	p_user_marker_manager: Node = null,
	p_hint_manager: Node = null
) -> void:
	spawn_manager = p_spawn_manager
	pickup_manager = p_pickup_manager
	logger_node = p_logger_node
	hint_label = p_hint_label
	user_marker_manager = p_user_marker_manager
	hint_manager = p_hint_manager

	_prepare_summary_log()

	print("EXPERIMENT_MANAGER_READY")

	_log_event("experiment_manager_ready", {
		"explore_duration_sec": explore_duration_sec
	})

	if auto_start_on_setup:
		start_experiment()


func _process(delta: float) -> void:
	if not experiment_running:
		return

	total_time_sec += delta

	if state == "WAIT_LEAVE_SPAWN":
		_update_hint_label("Leave the spawn area to start")

		if not _is_player_in_spawn_zone():
			_start_explore_phase()

	elif state == "EXPLORE":
		phase_time_sec += delta
		var remain := maxf(0.0, explore_duration_sec - phase_time_sec)
		_update_hint_label("Explore: %.1fs" % remain)

		if phase_time_sec >= explore_duration_sec:
			_start_return_phase()

	elif state == "RETURN":
		_update_hint_label("Return to the spawn point")

		if _is_player_in_spawn_zone():
			_complete_trial_and_restart_wait()


func start_experiment() -> void:
	if experiment_running:
		return

	experiment_running = true
	total_time_sec = 0.0
	phase_time_sec = 0.0
	has_left_spawn_once = false
	trial_index = 1
	state = "WAIT_LEAVE_SPAWN"
	_return_phase_start_total_time = 0.0

	print("EXPERIMENT_STARTED")

	_prepare_trial_resources(trial_index)

	_log_event("experiment_start", {
		"explore_duration_sec": explore_duration_sec
	})

	_update_hint_label("Leave the spawn area to start")


func _start_explore_phase() -> void:
	state = "EXPLORE"
	phase_time_sec = 0.0
	has_left_spawn_once = true

	print("EXPLORE_PHASE_STARTED trial=", trial_index)

	_log_event("explore_start", {
		"trial_index": trial_index,
		"total_time_sec": snappedf(total_time_sec, 0.001)
	})

	_update_hint_label("Explore: %.1fs" % explore_duration_sec)


func _start_return_phase() -> void:
	state = "RETURN"
	phase_time_sec = 0.0
	_return_phase_start_total_time = total_time_sec

	print("RETURN_PHASE_STARTED trial=", trial_index)

	_log_event("return_start", {
		"trial_index": trial_index,
		"total_time_sec": snappedf(total_time_sec, 0.001)
	})

	_update_hint_label("Return to the spawn point")


func _complete_trial_and_restart_wait() -> void:
	print("TRIAL_COMPLETED trial=", trial_index)

	var return_time_sec: float = maxf(0.0, total_time_sec - _return_phase_start_total_time)
	var marker_used_count: int = _get_marker_used_count_current_trial()
	var hints_enabled: bool = _get_hints_enabled()

	_write_trial_summary_row(
		trial_index,
		hints_enabled,
		marker_used_count,
		return_time_sec,
		true
	)

	_log_event("trial_complete", {
		"trial_index": trial_index,
		"total_time_sec": snappedf(total_time_sec, 0.001),
		"return_time_sec": snappedf(return_time_sec, 0.001),
		"hints_enabled": hints_enabled,
		"marker_used_count": marker_used_count
	})

	trial_index += 1
	phase_time_sec = 0.0
	has_left_spawn_once = false
	state = "WAIT_LEAVE_SPAWN"
	_return_phase_start_total_time = 0.0

	_prepare_trial_resources(trial_index)

	_update_hint_label("Leave the spawn area to start")


func stop_experiment() -> void:
	if not experiment_running:
		return

	experiment_running = false
	state = "IDLE"

	_log_event("experiment_stop_manual", {
		"total_time_sec": snappedf(total_time_sec, 0.001),
		"trial_index": trial_index
	})

	_update_hint_label("Experiment stopped")


func reset_experiment() -> void:
	experiment_running = false
	state = "IDLE"
	phase_time_sec = 0.0
	total_time_sec = 0.0
	has_left_spawn_once = false
	trial_index = 0
	_return_phase_start_total_time = 0.0

	if pickup_manager != null:
		if pickup_manager.has_method("clear_supply_items"):
			pickup_manager.call("clear_supply_items")
		if pickup_manager.has_method("reset_trial_pickup_count"):
			pickup_manager.call("reset_trial_pickup_count")

	if user_marker_manager != null and user_marker_manager.has_method("clear_all_markers"):
		user_marker_manager.call("clear_all_markers")

	_update_hint_label("")

	_log_event("experiment_reset", {})


func _prepare_trial_resources(new_trial_index: int) -> void:
	if pickup_manager != null:
		if pickup_manager.has_method("reset_trial_pickup_count"):
			pickup_manager.call("reset_trial_pickup_count")

		if pickup_manager.has_method("respawn_supply_items_for_trial"):
			pickup_manager.call("respawn_supply_items_for_trial", new_trial_index)

	if user_marker_manager != null and user_marker_manager.has_method("clear_all_markers"):
		user_marker_manager.call("clear_all_markers")


func _get_marker_used_count_current_trial() -> int:
	if user_marker_manager == null:
		return 0

	if user_marker_manager.has_method("get_used_marker_count_current_trial"):
		var result = user_marker_manager.call("get_used_marker_count_current_trial")
		if typeof(result) == TYPE_INT:
			return result

	return 0


func _get_hints_enabled() -> bool:
	if hint_manager == null:
		return false

	if hint_manager.has_method("get_hints_visible"):
		var result = hint_manager.call("get_hints_visible")
		if typeof(result) == TYPE_BOOL:
			return result

	return false


func _is_player_in_spawn_zone() -> bool:
	if spawn_manager == null:
		return false

	var value = spawn_manager.get("player_inside_spawn_zone")
	if typeof(value) == TYPE_BOOL:
		return value

	if spawn_manager.has_method("_is_player_in_spawn_zone"):
		var result = spawn_manager.call("_is_player_in_spawn_zone")
		if typeof(result) == TYPE_BOOL:
			return result

	return false


func _update_hint_label(msg: String) -> void:
	if not show_phase_text_on_hint_label:
		return
	if hint_label == null:
		return
	hint_label.text = msg


func _prepare_summary_log() -> void:
	var dir_path := "/storage/emulated/0/Documents/tao-final"
	DirAccess.make_dir_recursive_absolute(dir_path)

	var timestamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	_summary_log_path = "%s/trial_summary_%s.csv" % [dir_path, timestamp]

	var f := FileAccess.open(_summary_log_path, FileAccess.WRITE)
	if f != null:
		f.store_line("trial_index,hints_enabled,marker_used_count,return_time_sec,trial_complete")
		f.close()
		_summary_header_written = true
		print("TRIAL_SUMMARY_LOG=", _summary_log_path)


func _write_trial_summary_row(
	p_trial_index: int,
	p_hints_enabled: bool,
	p_marker_used_count: int,
	p_return_time_sec: float,
	p_trial_complete: bool
) -> void:
	if _summary_log_path == "":
		return

	var f := FileAccess.open(_summary_log_path, FileAccess.READ_WRITE)
	if f == null:
		return

	f.seek_end()

	var row := "%d,%s,%d,%.3f,%s" % [
		p_trial_index,
		"true" if p_hints_enabled else "false",
		p_marker_used_count,
		p_return_time_sec,
		"true" if p_trial_complete else "false"
	]
	f.store_line(row)
	f.close()


func _log_event(event_name: String, payload: Dictionary = {}) -> void:
	if logger_node == null:
		return
	if logger_node.has_method("mark_event"):
		logger_node.call("mark_event", event_name, payload)
