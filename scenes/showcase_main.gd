extends Node3D
## The playable vertical slice: real RigidBody3D dice -> per-die result ->
## 3D summon -> marching 3D units -> engage on contact.

enum MatchState { READY, ROLLING, SUMMONING, MARCHING, ENGAGED }

@onready var roll_button: Button = %RollButton
@onready var reset_button: Button = %ResetButton
@onready var status_label: Label = %Status
@onready var result_label: Label = %Results
@onready var dice_manager: DiceRollManager = $DiceRollManager
@onready var dice_ball: DiceBall = $DiceBall
@onready var army: Node3D = $Army
@onready var battlefield: Node3D = $Battlefield

var state := MatchState.READY
var _units: Array[Node3D] = []
var _enemy_units: Array[Node3D] = []
var _active_tweens: Array[Tween] = []

func _ready() -> void:
	Game.dice_results_ready.connect(_on_dice_results_ready)
	dice_ball.die_settled.connect(_on_die_settled)
	dice_manager.roll_finished.connect(_on_roll_finished)
	$Camera3D.look_at(Vector3(0, 0, 0), Vector3.UP)
	_spawn_test_enemy()

func _physics_process(_delta: float) -> void:
	if state == MatchState.MARCHING:
		_check_engagement()

func _check_engagement() -> void:
	for unit in _units:
		if not is_instance_valid(unit):
			continue
		for enemy in _enemy_units:
			if not is_instance_valid(enemy):
				continue
			if unit.global_position.distance_to(enemy.global_position) < 1.2:
				_trigger_engagement()
				return

func _trigger_engagement() -> void:
	state = MatchState.ENGAGED
	_kill_active_tweens()
	status_label.text = "会敵！ 味方部隊と敵モンスターが接触しました"
	roll_button.text = "会敵中"

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

func _on_reset_pressed() -> void:
	_kill_active_tweens()
	for unit in _units:
		if is_instance_valid(unit):
			unit.queue_free()
	_units.clear()
	_spawn_test_enemy()
	dice_ball.reset_dome()
	state = MatchState.READY
	roll_button.disabled = false
	roll_button.text = "ダイスをふる / ROLL"
	status_label.text = "ダイスを振って、3D召喚部隊を出撃させよう"
	result_label.text = ""

func _on_die_settled(die_index: int, top_face: int, landing_position: Vector3) -> void:
	dice_manager.report_physical_die(die_index, top_face, landing_position)
	status_label.text = "D%d 着地  (%+.1f, %+.1f)  /  上面: %d" % [die_index + 1, landing_position.x, landing_position.z, top_face]

func _on_roll_finished(_results: Array[Dictionary]) -> void:
	status_label.text = "全ダイスの上面と着地点をマネージャーへ報告しました"

func _on_dice_results_ready(results: Array[Dictionary]) -> void:
	state = MatchState.SUMMONING
	dice_ball.clear_dice()
	var faces: Array[String] = []
	for result in results:
		faces.append("D%d: %d" % [int(result["die_index"]) + 1, result["rarity"]])
	result_label.text = "物理ダイス判定  " + "    ".join(faces)
	status_label.text = "3D召喚開始 — ダイスの位置から部隊を具現化しています"
	for unit in _units:
		if is_instance_valid(unit):
			unit.queue_free()
	_units.clear()
	for result in results:
		var landing_pos: Vector3 = result["landing_position"]
		var unit := _make_unit(int(result["rarity"]), landing_pos)
		army.add_child(unit)
		_units.append(unit)
		unit.scale = Vector3.ZERO
		var tween := create_tween()
		tween.tween_property(unit, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK)
	_spawn_test_enemy()
	await get_tree().create_timer(1.0).timeout
	_start_march()

func _start_march() -> void:
	state = MatchState.MARCHING
	status_label.text = "3D進軍開始！ 召喚部隊が敵の要塞へ前進しています"
	roll_button.text = "進軍中"
	_kill_active_tweens()
	var target_x := 7.0
	if battlefield and battlefield.has_node("Castles/EnemyCastle"):
		var enemy_castle: Node3D = battlefield.get_node("Castles/EnemyCastle")
		target_x = enemy_castle.global_position.x - 0.8
	for unit in _units:
		var start_z := unit.position.z
		var tween := create_tween()
		tween.set_loops()
		tween.tween_property(unit, "position:z", start_z + 0.5, 1.6).set_trans(Tween.TRANS_SINE)
		tween.tween_property(unit, "position:z", start_z - 0.5, 1.6).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(unit, "position:x", target_x, 6.5).set_trans(Tween.TRANS_QUAD)
		_active_tweens.append(tween)
	
	# 敵モンスターの進軍（味方城方向：-X方向）
	var player_target_x := -6.4
	if battlefield and battlefield.has_node("Castles/PlayerCastle"):
		var player_castle: Node3D = battlefield.get_node("Castles/PlayerCastle")
		player_target_x = player_castle.global_position.x + 0.8
	for enemy in _enemy_units:
		var tween := create_tween()
		tween.set_loops()
		tween.tween_property(enemy, "position:z", -0.5, 1.6).set_trans(Tween.TRANS_SINE)
		tween.tween_property(enemy, "position:z", 0.5, 1.6).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(enemy, "position:x", player_target_x, 7.5).set_trans(Tween.TRANS_QUAD)
		_active_tweens.append(tween)

func _kill_active_tweens() -> void:
	for tween in _active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_active_tweens.clear()

func _spawn_test_enemy() -> void:
	for enemy in _enemy_units:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemy_units.clear()
	
	var spawn_pos := Vector3(7.75, 0.35, 0.0)
	if battlefield and battlefield.has_node("Castles/EnemyCastle"):
		var enemy_castle: Node3D = battlefield.get_node("Castles/EnemyCastle")
		spawn_pos = enemy_castle.global_position
		spawn_pos.y = 0.35
	elif battlefield and battlefield.has_node("SpawnMarkers/EnemySpawn"):
		var marker: Marker3D = battlefield.get_node("SpawnMarkers/EnemySpawn")
		spawn_pos = marker.global_position
		spawn_pos.y = 0.35
	
	var enemy := _make_enemy_unit(spawn_pos)
	army.add_child(enemy)
	_enemy_units.append(enemy)

func _make_enemy_unit(start: Vector3) -> Node3D:
	var unit := Node3D.new()
	unit.name = "TestEnemyUnit"
	unit.position = start
	var body := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.28
	mesh.bottom_radius = 0.35
	mesh.height = 0.75
	body.mesh = mesh
	body.material_override = _glow_material(Color("ff4565"))
	body.position.y = 0.32
	unit.add_child(body)
	var halo := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.32
	ring.outer_radius = 0.38
	halo.mesh = ring
	halo.material_override = _glow_material(Color("ffa5b8"))
	halo.position.y = 0.05
	unit.add_child(halo)
	return unit

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

func _glow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.25
	material.roughness = 0.33
	material.emission_enabled = true
	material.emission = color.darkened(0.45)
	return material
