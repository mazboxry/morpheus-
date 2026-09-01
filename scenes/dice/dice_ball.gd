class_name DiceBall
extends Node3D
## A reusable 3D dice tray.  The top face is read from the RigidBody3D basis,
## rather than being chosen by the manager.

signal die_settled(die_index: int, top_face: int, landing_position: Vector3)

const DIE_COUNT := 4
const FACE_DIRECTIONS := [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]
const FACE_VALUES := [1, 6, 3, 4, 2, 5]
const DIE_COLORS := [Color("7ee7ff"), Color("aa94ff"), Color("ffd56e"), Color("ff91b5")]

var _dice: Array[RigidBody3D] = []
var _settled: Array[bool] = [false, false, false, false]
var _quiet_time: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _rolling := false

func _ready() -> void:
	_build_tray()
	for index in DIE_COUNT:
		var die := get_node("PhysicalDie%d" % (index + 1)) as RigidBody3D
		_configure_die(die, index)
		_dice.append(die)

func roll() -> void:
	_rolling = true
	_settled = [false, false, false, false]
	_quiet_time = [0.0, 0.0, 0.0, 0.0]
	for index in _dice.size():
		var die := _dice[index]
		die.freeze = false
		die.position = Vector3(-2.2 + index * 1.45, 3.2 + index * 0.25, randf_range(-0.7, 0.7))
		die.rotation = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
		die.linear_velocity = Vector3(randf_range(-1.8, 1.8), randf_range(0.5, 2.8), randf_range(-1.5, 1.5))
		die.angular_velocity = Vector3(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))

func _physics_process(delta: float) -> void:
	if not _rolling:
		return
	for index in _dice.size():
		if _settled[index]:
			continue
		var die := _dice[index]
		if die.linear_velocity.length() < 0.13 and die.angular_velocity.length() < 0.22 and die.position.y < 0.75:
			_quiet_time[index] += delta
			if _quiet_time[index] > 0.55:
				_settled[index] = true
				die.freeze = true
				die_settled.emit(index, _read_top_face(die), die.global_position)
		else:
			_quiet_time[index] = 0.0
	if not _settled.has(false):
		_rolling = false

func _read_top_face(die: RigidBody3D) -> int:
	var best_dot := -2.0
	var best_index := 0
	for index in FACE_DIRECTIONS.size():
		var face_normal: Vector3 = die.global_transform.basis * FACE_DIRECTIONS[index]
		var up_alignment: float = face_normal.dot(Vector3.UP)
		if up_alignment > best_dot:
			best_dot = up_alignment
			best_index = index
	return FACE_VALUES[best_index]

func _configure_die(die: RigidBody3D, index: int) -> void:
	die.mass = 1.2
	die.physics_material_override = _physics_material(0.62, 0.20)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.82
	mesh.mesh = cube
	mesh.material_override = _material(DIE_COLORS[index], 0.25)
	die.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * 0.82
	collision.shape = shape
	die.add_child(collision)
	_add_pips(die)

func _add_pips(die: RigidBody3D) -> void:
	var layouts := {1: [Vector2.ZERO], 2: [Vector2(-1, -1), Vector2(1, 1)], 3: [Vector2(-1, -1), Vector2.ZERO, Vector2(1, 1)], 4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)], 5: [Vector2(-1, -1), Vector2(1, -1), Vector2.ZERO, Vector2(-1, 1), Vector2(1, 1)], 6: [Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1)]}
	for face in FACE_DIRECTIONS.size():
		var normal: Vector3 = FACE_DIRECTIONS[face]
		var tangent := Vector3.RIGHT if absf(normal.y) > 0.5 else Vector3.UP
		var bitangent := normal.cross(tangent).normalized()
		for point: Vector2 in layouts[FACE_VALUES[face]]:
			var pip := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.052
			sphere.height = 0.104
			pip.mesh = sphere
			pip.material_override = _material(Color("17233d"), 0.5)
			pip.position = normal * 0.421 + tangent * point.x * 0.16 + bitangent * point.y * 0.16
			die.add_child(pip)

func _build_tray() -> void:
	var floor := StaticBody3D.new()
	floor.name = "DiceTrayFloor"
	floor.physics_material_override = _physics_material(0.86, 0.08)
	add_child(floor)
	_add_box(floor, Vector3(8.8, 0.22, 6.0), Vector3(0, -0.12, 0), Color("183158"))
	for wall in [[Vector3(9.1, 1.0, 0.24), Vector3(0, 0.48, -3.0)], [Vector3(9.1, 1.0, 0.24), Vector3(0, 0.48, 3.0)], [Vector3(0.24, 1.0, 6.0), Vector3(-4.45, 0.48, 0)], [Vector3(0.24, 1.0, 6.0), Vector3(4.45, 0.48, 0)]]:
		_add_box(floor, wall[0], wall[1], Color("345985"))

func _add_box(parent: Node3D, box_size: Vector3, local_position: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh.mesh = box
	mesh.position = local_position
	mesh.material_override = _material(color, 0.15)
	parent.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape
	collision.position = local_position
	parent.add_child(collision)

func _material(color: Color, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.36
	return material

func _physics_material(friction: float, bounce: float) -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = friction
	material.bounce = bounce
	return material
