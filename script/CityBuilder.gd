extends Node

@export var cell_size: float = 5.5
@export var wall_height: float = 4.8
@export var pillar_size: float = 0.55
@export var add_pillars: bool = true
@export var pillar_spacing_cells: int = 2
@export var environment_collision_layer: int = 1

@export var wall_thickness: float = 0.2
@export var floor_thickness: float = 0.15
@export var ceiling_thickness: float = 0.15

@export var add_ceiling: bool = true
@export var add_lights: bool = true
@export var add_landmarks: bool = true
@export var add_sign_boards: bool = true
@export var light_every_n_cells: int =3

@export var build_parent_path: NodePath = NodePath("../../World")
@export var world_y_offset: float = 0.05

var root_generated: Node3D
var spawn_position: Vector3 = Vector3.ZERO

var wall_material: StandardMaterial3D
var floor_material: StandardMaterial3D
var ceiling_material: StandardMaterial3D
var sign_material: StandardMaterial3D
var landmark_red: StandardMaterial3D
var landmark_blue: StandardMaterial3D
var landmark_green: StandardMaterial3D
var pillar_material: StandardMaterial3D
var light_fixture_material: StandardMaterial3D

var occupied := {}

func _ready() -> void:
	_build_materials()
	_generate_backrooms_layout()

func _generate_backrooms_layout() -> void:
	var build_parent := _get_build_parent()
	if build_parent == null:
		push_error("CityBuilder: build parent not found. Check build_parent_path.")
		return

	_clear_old(build_parent)

	root_generated = Node3D.new()
	root_generated.name = "GeneratedBackrooms"
	root_generated.position.y = world_y_offset
	build_parent.add_child(root_generated)

	_build_layout_map()

	# Spawn point in the room you selected.
	spawn_position = _cell_center(6, 44)

	_build_from_cells()
	_add_props()

func get_spawn_position() -> Vector3:
	return spawn_position

func _get_build_parent() -> Node3D:
	var node := get_node_or_null(build_parent_path)
	if node == null:
		return null
	if node is Node3D:
		return node as Node3D
	return null

func _clear_old(build_parent: Node3D) -> void:
	var old := build_parent.get_node_or_null("GeneratedBackrooms")
	if old:
		old.queue_free()

func _build_materials() -> void:
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.77, 0.74, 0.55)
	wall_material.roughness = 0.98
	wall_material.metallic = 0.0

	floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.32, 0.28, 0.18)
	floor_material.roughness = 1.0
	floor_material.metallic = 0.0

	ceiling_material = StandardMaterial3D.new()
	ceiling_material.albedo_color = Color(0.87, 0.86, 0.78)
	ceiling_material.roughness = 0.96

	light_fixture_material = StandardMaterial3D.new()
	light_fixture_material.albedo_color = Color(0.95, 0.94, 0.88)
	light_fixture_material.emission_enabled = true
	light_fixture_material.emission = Color(1.0, 0.96, 0.84) * 0.10
	light_fixture_material.roughness = 0.75

	sign_material = StandardMaterial3D.new()
	sign_material.albedo_color = Color(0.92, 0.91, 0.84)
	sign_material.roughness = 0.85

	pillar_material = StandardMaterial3D.new()
	pillar_material.albedo_color = Color(0.71, 0.69, 0.52)
	pillar_material.roughness = 0.98

	landmark_red = StandardMaterial3D.new()
	landmark_red.albedo_color = Color(0.62, 0.18, 0.18)

	landmark_blue = StandardMaterial3D.new()
	landmark_blue.albedo_color = Color(0.20, 0.33, 0.70)

	landmark_green = StandardMaterial3D.new()
	landmark_green.albedo_color = Color(0.21, 0.52, 0.24)

# =========================================================
# Grid layout
# =========================================================

func _build_layout_map() -> void:
	occupied.clear()

	# -----------------------------------------------------
	# 1) Spawn hall
	# -----------------------------------------------------
	_fill_rect(-4, -4, 8, 8)

	# multiple narrow exits
	_fill_v_corridor(0, 4, 8, 1)
	_fill_v_corridor(-2, 4, 7, 1)
	_fill_v_corridor(2, 4, 7, 1)

	# -----------------------------------------------------
	# 2) central spine and nearby offsets
	# -----------------------------------------------------
	_fill_v_corridor(0, 8, 42, 1)
	_fill_v_corridor(1, 10, 36, 1)

	_fill_h_corridor(-3, 4, 16, 1)
	_fill_h_corridor(-5, 6, 24, 1)
	_fill_h_corridor(-4, 5, 32, 1)

	# -----------------------------------------------------
	# 3) left region A
	# -----------------------------------------------------
	_fill_rect(-10, 8, 7, 7)
	_fill_h_corridor(-1, -3, 9, 1)
	_fill_h_corridor(-1, -3, 11, 1)
	_fill_h_corridor(-1, -3, 13, 1)

	_fill_h_corridor(-10, -14, 10, 1)
	_fill_rect(-18, 8, 4, 5)

	_fill_h_corridor(-10, -14, 13, 1)
	_fill_rect(-18, 12, 4, 5)

	# left region B
	_fill_rect(-11, 18, 8, 8)
	_fill_h_corridor(-1, -2, 19, 1)
	_fill_h_corridor(-1, -2, 22, 1)
	_fill_h_corridor(-1, -2, 24, 1)

	_fill_v_corridor(-8, 26, 31, 1)
	_fill_rect(-11, 31, 7, 5)

	_fill_v_corridor(-5, 26, 30, 1)
	_fill_rect(-8, 30, 5, 4)

	# left side extra loop
	_fill_h_corridor(-6, -1, 28, 1)
	_fill_h_corridor(-9, -4, 35, 1)

	# -----------------------------------------------------
	# 4) right region A
	# -----------------------------------------------------
	_fill_rect(4, 10, 7, 8)
	_fill_h_corridor(2, 3, 11, 1)
	_fill_h_corridor(2, 3, 14, 1)
	_fill_h_corridor(2, 3, 16, 1)

	_fill_h_corridor(10, 14, 12, 1)
	_fill_rect(14, 10, 4, 5)

	_fill_h_corridor(10, 14, 16, 1)
	_fill_rect(14, 15, 5, 4)

	# right region B
	_fill_rect(4, 22, 9, 8)
	_fill_h_corridor(2, 3, 23, 1)
	_fill_h_corridor(2, 3, 26, 1)
	_fill_h_corridor(2, 3, 28, 1)

	_fill_v_corridor(8, 30, 35, 1)
	_fill_rect(5, 35, 7, 5)

	_fill_v_corridor(11, 30, 34, 1)
	_fill_rect(9, 34, 5, 4)

	# right side extra loop
	_fill_h_corridor(2, 8, 33, 1)
	_fill_h_corridor(5, 11, 39, 1)

	# -----------------------------------------------------
	# 5) central late maze
	# -----------------------------------------------------
	_fill_rect(-3, 36, 8, 5)

	_fill_v_corridor(-2, 41, 45, 1)
	_fill_v_corridor(0, 41, 46, 1)
	_fill_v_corridor(2, 41, 50, 1)
	_fill_v_corridor(4, 41, 50, 1)

	_fill_rect(-10, 44, 7, 7)
	_fill_h_corridor(-2, -3, 45, 1)
	_fill_h_corridor(-2, -3, 48, 1)

	_fill_rect(5, 44, 8, 7)
	_fill_h_corridor(4, 5, 46, 1)
	_fill_h_corridor(4, 5, 49, 1)

	# additional cross-links to create uncertainty
	_fill_h_corridor(-4, 4, 43, 1)
	_fill_h_corridor(-6, 6, 50, 1)

	# -----------------------------------------------------
	# 6) end hall
	# -----------------------------------------------------
	_fill_rect(-6, 52, 14, 10)

	_fill_v_corridor(-3, 47, 51, 1)
	_fill_v_corridor(0, 47, 51, 1)
	_fill_v_corridor(3, 47, 51, 1)

	_fill_h_corridor(-7, -11, 55, 1)
	_fill_rect(-15, 53, 4, 5)

	_fill_h_corridor(8, 12, 57, 1)
	_fill_rect(12, 55, 5, 5)

	_fill_v_corridor(0, 62, 67, 1)
	_fill_rect(-3, 67, 7, 6)

	_fill_h_corridor(-3, -7, 69, 1)
	_fill_rect(-11, 67, 4, 4)

	_fill_h_corridor(3, 7, 71, 1)
	_fill_rect(7, 69, 4, 4)

	# extra final side ambiguity
	_fill_v_corridor(-7, 58, 63, 1)
	_fill_rect(-11, 63, 4, 4)

	_fill_v_corridor(8, 59, 64, 1)
	_fill_rect(7, 64, 5, 4)

func _fill_rect(start_x: int, start_z: int, w: int, h: int) -> void:
	for x in range(start_x, start_x + w):
		for z in range(start_z, start_z + h):
			occupied[_cell_key(x, z)] = true

func _fill_h_corridor(x1: int, x2: int, z: int, thickness: int = 1) -> void:
	var min_x := mini(x1, x2)
	var max_x := maxi(x1, x2)
	var start_z := z - int(thickness / 2)
	_fill_rect(min_x, start_z, max_x - min_x + 1, thickness)

func _fill_v_corridor(x: int, z1: int, z2: int, thickness: int = 1) -> void:
	var min_z := mini(z1, z2)
	var max_z := maxi(z1, z2)
	var start_x := x - int(thickness / 2)
	_fill_rect(start_x, min_z, thickness, max_z - min_z + 1)

func _cell_key(x: int, z: int) -> String:
	return str(x) + "," + str(z)

func _has_cell(x: int, z: int) -> bool:
	return occupied.has(_cell_key(x, z))

# =========================================================
# Geometry from cells
# =========================================================

func _build_from_cells() -> void:
	var cells_root := Node3D.new()
	cells_root.name = "Cells"
	root_generated.add_child(cells_root)

	for key_variant in occupied.keys():
		var key: String = str(key_variant)
		var parts: PackedStringArray = key.split(",")
		var gx: int = int(parts[0])
		var gz: int = int(parts[1])
		_build_cell(cells_root, gx, gz)

func _build_cell(parent: Node3D, gx: int, gz: int) -> void:
	var cell := Node3D.new()
	cell.name = "Cell_%d_%d" % [gx, gz]
	cell.position = Vector3(gx * cell_size, 0, gz * cell_size)
	parent.add_child(cell)

	_create_box_static(
		cell,
		Vector3(cell_size, floor_thickness, cell_size),
		Vector3(0, -floor_thickness * 0.5, 0),
		floor_material,
		"Floor"
	)

	if add_ceiling:
		_create_box_static(
			cell,
			Vector3(cell_size, ceiling_thickness, cell_size),
			Vector3(0, wall_height + ceiling_thickness * 0.5, 0),
			ceiling_material,
			"Ceiling"
		)

	if not _has_cell(gx, gz - 1):
		_create_box_static(
			cell,
			Vector3(cell_size, wall_height, wall_thickness),
			Vector3(0, wall_height * 0.5, -cell_size * 0.5),
			wall_material,
			"Wall_N"
		)

	if not _has_cell(gx, gz + 1):
		_create_box_static(
			cell,
			Vector3(cell_size, wall_height, wall_thickness),
			Vector3(0, wall_height * 0.5, cell_size * 0.5),
			wall_material,
			"Wall_S"
		)

	if not _has_cell(gx - 1, gz):
		_create_box_static(
			cell,
			Vector3(wall_thickness, wall_height, cell_size),
			Vector3(-cell_size * 0.5, wall_height * 0.5, 0),
			wall_material,
			"Wall_W"
		)

	if not _has_cell(gx + 1, gz):
		_create_box_static(
			cell,
			Vector3(wall_thickness, wall_height, cell_size),
			Vector3(cell_size * 0.5, wall_height * 0.5, 0),
			wall_material,
			"Wall_E"
		)

	if add_pillars:
		_try_add_pillar(cell, gx, gz)

	if add_lights and _should_place_light(gx, gz):
		_add_one_light(cell, Vector3(0, wall_height - 0.20, 0))

func _should_place_light(gx: int, gz: int) -> bool:
	if not _is_dense_3x3(gx, gz):
		return false
	return (gx % light_every_n_cells == 0) and (gz % light_every_n_cells == 0)

# =========================================================
# Props
# =========================================================

func _add_props() -> void:
	if add_landmarks:
		_add_landmark(_cell_center(-1, -1) + Vector3(-1.0, 1.0, -1.0), landmark_green, "SpawnLandmark")
		_add_landmark(_cell_center(-16, 14) + Vector3(0.0, 1.0, 0.0), landmark_red, "LeftLandmark")
		_add_landmark(_cell_center(16, 16) + Vector3(0.0, 1.0, 0.0), landmark_blue, "RightLandmark")

	if add_sign_boards:
		_add_sign_board(_cell_center(1, -2) + Vector3(1.2, 1.9, -1.5), "HintBoard_Spawn")
		_add_sign_board(_cell_center(-6, 10) + Vector3(0.0, 1.9, -1.5), "HintBoard_Left")
		_add_sign_board(_cell_center(6, 12) + Vector3(0.0, 1.9, -1.5), "HintBoard_Right")
		_add_sign_board(_cell_center(0, 54) + Vector3(0.0, 1.9, -1.5), "HintBoard_Final")

func _cell_center(gx: int, gz: int) -> Vector3:
	return Vector3(gx * cell_size, 0, gz * cell_size)

func _is_dense_3x3(gx: int, gz: int) -> bool:
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if not _has_cell(gx + dx, gz + dz):
				return false
	return true

func _try_add_pillar(parent: Node3D, gx: int, gz: int) -> void:
	if not _is_dense_3x3(gx, gz):
		return

	if gx % pillar_spacing_cells != 0:
		return
	if gz % pillar_spacing_cells != 0:
		return

	var pillar := Node3D.new()
	pillar.name = "Pillar"
	parent.add_child(pillar)

	_create_box_static(
		pillar,
		Vector3(pillar_size, wall_height, pillar_size),
		Vector3(0, wall_height * 0.5, 0),
		pillar_material,
		"PillarMesh"
	)

func _add_sign_board(pos: Vector3, board_name: String) -> void:
	var holder := Node3D.new()
	holder.name = board_name
	holder.position = pos
	root_generated.add_child(holder)

	var board := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.4, 0.7, 0.08)
	board.mesh = mesh
	board.material_override = sign_material
	holder.add_child(board)

func _add_landmark(pos: Vector3, mat: Material, landmark_name: String) -> void:
	var landmark := MeshInstance3D.new()
	landmark.name = landmark_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.45, 1.2, 0.08)
	landmark.mesh = mesh
	landmark.material_override = mat
	landmark.position = pos
	root_generated.add_child(landmark)

func _add_one_light(parent: Node3D, pos: Vector3) -> void:
	var fixture := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.6, 0.08, 0.50)
	fixture.mesh = box
	fixture.material_override = light_fixture_material
	fixture.position = pos
	parent.add_child(fixture)

	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, -0.18, 0)
	light.light_energy = 3.1
	light.omni_range = 15.0
	light.light_color = Color(1.0, 0.96, 0.86)
	light.shadow_enabled = false
	parent.add_child(light)

# =========================================================
# Core helper
# =========================================================

func _create_box_static(
	parent: Node,
	size: Vector3,
	pos: Vector3,
	mat: Material,
	node_name: String
) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = pos
	parent.add_child(root)

	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

	var body := StaticBody3D.new()
	body.collision_layer = environment_collision_layer
	body.collision_mask = 0
	root.add_child(body)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	return root
