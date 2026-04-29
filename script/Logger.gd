extends Node

# Minimal VR experiment logger
# Writes JSONL records to user://logs/
# One JSON object per line for easy later parsing.

@export var auto_start_on_ready: bool = true
@export var sample_interval_sec: float = 0.5
@export var log_position: bool = true
@export var log_rotation: bool = true
@export var flush_every_n_records: int = 1

var player_node: Node3D = null
var xr_camera: Node3D = null
var scene_root: Node = null

var _session_id: String = ""
var _log_dir: String = "user://logs"
var _external_log_dir: String = "/storage/emulated/0/Documents/ass2_logs"
var _log_path: String = ""
var _file: FileAccess = null
var _timer_accum: float = 0.0
var _running: bool = false
var _record_count: int = 0
var _last_position: Vector3 = Vector3.ZERO
var _last_yaw_deg: float = 0.0
var _has_last_pose: bool = false

func _ready() -> void:
	if auto_start_on_ready:
		start_logging()

func setup(p_player_node: Node3D, p_xr_camera: Node3D = null, p_scene_root: Node = null) -> void:
	player_node = p_player_node
	xr_camera = p_xr_camera
	scene_root = p_scene_root

func start_logging() -> void:
	if _running:
		return

	_session_id = _make_session_id()
	_prepare_log_file()
	if _file == null:
		push_error("Logger failed to open both external and fallback paths")
		return

	_running = true
	_timer_accum = 0.0
	_record_count = 0
	_has_last_pose = false

	_write_event("session_start", {
		"session_id": _session_id,
		"scene_name": _get_scene_name(),
		"sample_interval_sec": sample_interval_sec
	})

	print("LOGGER_STARTED: %s" % _log_path)
	print("LOGGER_ABS_PATH: %s" % ProjectSettings.globalize_path(_log_path))

func stop_logging() -> void:
	if not _running:
		return

	_write_event("session_end", {
		"session_id": _session_id,
		"total_records": _record_count
	})

	if _file != null:
		_file.flush()
		_file.close()
		_file = null

	_running = false
	print("LOGGER_STOPPED")

func mark_event(event_name: String, payload: Dictionary = {}) -> void:
	if not _running:
		return
	_write_event(event_name, payload)

func _process(delta: float) -> void:
	if not _running:
		return

	_timer_accum += delta
	if _timer_accum < sample_interval_sec:
		return
	_timer_accum = 0.0

	var pose := _read_pose()
	if pose.is_empty():
		return

	var payload := {
		"session_id": _session_id,
		"scene_name": _get_scene_name()
	}

	if log_position:
		payload["position"] = pose["position"]
	if log_rotation:
		payload["yaw_deg"] = pose["yaw_deg"]

	if _has_last_pose:
		payload["delta_distance"] = _last_position.distance_to(Vector3(
			pose["position"]["x"],
			pose["position"]["y"],
			pose["position"]["z"]
		))
		payload["delta_yaw_deg"] = abs(pose["yaw_deg"] - _last_yaw_deg)
	else:
		payload["delta_distance"] = 0.0
		payload["delta_yaw_deg"] = 0.0

	_last_position = Vector3(
		pose["position"]["x"],
		pose["position"]["y"],
		pose["position"]["z"]
	)
	_last_yaw_deg = pose["yaw_deg"]
	_has_last_pose = true

	_write_event("pose_sample", payload)

func _read_pose() -> Dictionary:
	var source: Node3D = null
	if xr_camera != null:
		source = xr_camera
	elif player_node != null:
		source = player_node
	else:
		return {}

	var origin := source.global_transform.origin
	var basis := source.global_transform.basis
	var euler := basis.get_euler()
	var yaw_deg := rad_to_deg(euler.y)

	return {
		"position": {
			"x": snappedf(origin.x, 0.001),
			"y": snappedf(origin.y, 0.001),
			"z": snappedf(origin.z, 0.001)
		},
		"yaw_deg": snappedf(yaw_deg, 0.01)
	}

func _write_event(event_name: String, payload: Dictionary) -> void:
	if _file == null:
		return

	var record := {
		"ts_unix": Time.get_unix_time_from_system(),
		"ts_text": Time.get_datetime_string_from_system(),
		"event": event_name,
		"data": payload
	}

	_file.store_line(JSON.stringify(record))
	_record_count += 1

	if flush_every_n_records > 0 and (_record_count % flush_every_n_records == 0):
		_file.flush()

func _prepare_log_file() -> void:
	_file = null

	# Try public/export-friendly directory first on Android/Quest.
	# If it fails, fall back to user://logs.
	DirAccess.make_dir_recursive_absolute(_external_log_dir)
	var ext_path := "%s/session_%s.jsonl" % [_external_log_dir, _session_id]
	var ext_file := FileAccess.open(ext_path, FileAccess.WRITE)
	if ext_file != null:
		_log_path = ext_path
		_file = ext_file
		return

	var abs_dir := ProjectSettings.globalize_path(_log_dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var fallback_path := "%s/session_%s.jsonl" % [_log_dir, _session_id]
	var fallback_file := FileAccess.open(fallback_path, FileAccess.WRITE)
	if fallback_file != null:
		_log_path = fallback_path
		_file = fallback_file
		return

func _get_scene_name() -> String:
	if scene_root != null:
		return scene_root.name
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene.name
	return "unknown_scene"

func _make_session_id() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [
		dt.year, dt.month, dt.day,
		dt.hour, dt.minute, dt.second
	]

func get_log_path() -> String:
	return _log_path
