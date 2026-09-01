extends Node3D
## The playable vertical slice: real RigidBody3D dice -> per-die result ->
## 3D summon -> marching 3D units.

enum MatchState { READY, ROLLING, SUMMONING, MARCHING }

@onready var roll_button: Button = $CanvasLayer/HUD/RollButton
@onready var status_label: Label = $CanvasLayer/HUD/Status
@onready var result_label: Label = $CanvasLayer/HUD/Results
@onready var dice_manager: DiceRollManager = $DiceRollManager
@onready var dice_ball: DiceBall = $DiceBall
@onready var army: Node3D = $Army

var state := MatchState.READY
var _units: Array[Node3D] = []

func _ready() -> void:
	Game.dice_results_ready.connect(_on_dice_results_ready)
	dice_ball.die_settled.connect(_on_die_settled)
	dice_manager.roll_finished.connect(_on_roll_finished)
	_build_battlefield()
	$Camera3D.look_at(Vector3(0, 0, 0), Vector3.UP)

func _on_roll_pressed() -> void:
	if state != MatchState.READY:
		return
	state = MatchState.ROLLING
	roll_button.disabled = true
	roll_button.text = "物理判定中…"
	result_label.text = ""
	status_label.text = "4つの RigidBody3D ダイスがトレイの中で転がっています"
	dice_manager.begin_roll(DiceBall.DIE_COUNT)
	dice_ball.roll()

func _on_die_settled(die_index: int, top_face: int, landing_position: Vector3) -> void:
	dice_manager.report_physical_die(die_index, top_face, landing_position)
	status_label.text = "D%d 着地  (%+.1f, %+.1f)  /  上面: %d" % [die_index + 1, landing_position.x, landing_position.z, top_face]

func _on_roll_finished(_results: Array[Dictionary]) -> void:
	status_label.text = "全ダイスの上面と着地点をマネージャーへ報告しました"

func _on_dice_results_ready(results: Array[Dictionary]) -> void:
	state = MatchState.SUMMONING
	var faces: Array[String] = []
	for result in results:
		faces.append("D%d: %d" % [int(result["die_index"]) + 1, result["rarity"]])
	result_label.text = "物理ダイス判定  " + "    ".join(faces)
	status_label.text = "3D召喚開始 — 着地点から部隊を具現化しています"
	for unit in _units:
		unit.queue_free()
	_units.clear()
	for result in results:
		var unit := _make_unit(int(result["rarity"]), result["landing_position"])
		army.add_child(unit)
		_units.append(unit)
		var destination := Vector3(2.2 + int(result["die_index"]) * 0.7, 0.35, -1.65 + int(result["die_index"]) * 1.1)
		unit.scale = Vector3.ZERO
		var tween := create_tween()
		tween.tween_property(unit, "scale", Vector3.ONE, 0.38).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(unit, "position", destination, 0.75).set_trans(Tween.TRANS_QUAD)
	await get_tree().create_timer(1.45).timeout
	_start_march()

func _start_march() -> void:
	state = MatchState.MARCHING
	status_label.text = "3D進軍開始！ 召喚部隊が敵の要塞へ前進しています"
	roll_button.text = "進軍中"
	for unit in _units:
		var tween := create_tween()
		tween.set_loops()
		tween.tween_property(unit, "position:z", 1.0, 1.15).set_trans(Tween.TRANS_SINE)
		tween.tween_property(unit, "position:z", -1.0, 1.15).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(unit, "position:x", 3.6, 2.6).set_trans(Tween.TRANS_QUAD)

func _make_unit(rarity: int, start: Vector3) -> Node3D:
	var unit := Node3D.new()
	unit.name = "SummonedUnit%d" % rarity
	unit.position = Vector3(start.x, 0.35, start.z)
	var body := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22 + rarity * 0.035
	mesh.bottom_radius = 0.29 + rarity * 0.045
	mesh.height = 0.65 + rarity * 0.08
	body.mesh = mesh
	body.material_override = _glow_material([Color("62dcff"), Color("af83ff"), Color("ffcc5d"), Color("ff779e"), Color("78efae"), Color("ffa85e")][rarity - 1])
	body.position.y = 0.32
	unit.add_child(body)
	var halo := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.32
	ring.outer_radius = 0.38
	halo.mesh = ring
	halo.material_override = _glow_material(Color("dffaff"))
	halo.position.y = 0.05
	unit.add_child(halo)
	return unit

func _build_battlefield() -> void:
	_add_box(Vector3(18, 0.18, 10), Vector3(0, -0.42, 0), Color("102a45"))
	_add_box(Vector3(0.45, 0.35, 8.8), Vector3(5.45, -0.22, 0), Color("4c315e"))
	_add_fortress(Vector3(4.55, 0, 0), Color("ff617e"))
	_add_fortress(Vector3(-7.2, 0, 0), Color("58baff"))
	for z in [-2.5, 0.0, 2.5]:
		_add_box(Vector3(0.08, 0.04, 1.35), Vector3(2.2, -0.28, z), Color("62c7e6"))

func _add_fortress(at: Vector3, color: Color) -> void:
	_add_box(Vector3(1.05, 1.25, 1.7), at + Vector3(0, 0.35, 0), color)
	_add_box(Vector3(1.45, 0.25, 2.05), at + Vector3(0, 1.05, 0), color.lightened(0.18))

func _add_box(box_size: Vector3, at: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _glow_material(color)
	$Battlefield.add_child(instance)

func _glow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.25
	material.roughness = 0.33
	material.emission_enabled = true
	material.emission = color.darkened(0.45)
	return material
