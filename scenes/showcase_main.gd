extends Node3D
## The playable vertical slice: real RigidBody3D dice -> per-die result ->
## 3D summon -> marching 3D units -> auto-aim combat and blocking.

enum MatchState { READY, ROLLING, SUMMONING, MARCHING, ENGAGED, VICTORY, DEFEAT }

@onready var roll_button: Button = %RollButton
@onready var reset_button: Button = %ResetButton
@onready var status_label: Label = %Status
@onready var result_label: Label = %Results
@onready var dice_manager: DiceRollManager = $DiceRollManager
@onready var dice_ball: DiceBall = $DiceBall
@onready var army: Node3D = $Army
@onready var battlefield: Node3D = $Battlefield

const ENEMY_CASTLE_INITIAL_HP := 500
const PLAYER_CASTLE_INITIAL_HP := 500
const ENEMY_COUNT_INITIAL := 3

var state := MatchState.READY
var _units: Array[Node3D] = []
var _enemy_units: Array[Node3D] = []
var _active_tweens: Array[Tween] = []
var _projectiles: Array[Node3D] = []

func _ready() -> void:
	Game.dice_results_ready.connect(_on_dice_results_ready)
	dice_ball.die_settled.connect(_on_die_settled)
	dice_manager.roll_finished.connect(_on_roll_finished)
	$Camera3D.look_at(Vector3(0, 0, 0), Vector3.UP)
	_setup_castles()
	_spawn_test_enemy()

func _setup_castles() -> void:
	if battlefield and battlefield.has_node("Castles/EnemyCastle"):
		var castle: Node3D = battlefield.get_node("Castles/EnemyCastle")
		castle.visible = true
		castle.scale = Vector3.ONE
		castle.set_meta("is_castle", true)
		castle.set_meta("is_player_castle", false)
		castle.set_meta("hp", ENEMY_CASTLE_INITIAL_HP)
		castle.set_meta("max_hp", ENEMY_CASTLE_INITIAL_HP)
		
		var label: Label3D = castle.get_node_or_null("HpLabel")
		if label == null:
			label = Label3D.new()
			label.name = "HpLabel"
			label.position = Vector3(0, 2.0, 0)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 30
			label.outline_size = 6
			label.modulate = Color("ff7799")
			castle.add_child(label)
		label.text = "敵城 HP %d/%d" % [ENEMY_CASTLE_INITIAL_HP, ENEMY_CASTLE_INITIAL_HP]

	if battlefield and battlefield.has_node("Castles/PlayerCastle"):
		var p_castle: Node3D = battlefield.get_node("Castles/PlayerCastle")
		p_castle.visible = true
		p_castle.scale = Vector3.ONE
		p_castle.set_meta("is_castle", true)
		p_castle.set_meta("is_player_castle", true)
		p_castle.set_meta("hp", PLAYER_CASTLE_INITIAL_HP)
		p_castle.set_meta("max_hp", PLAYER_CASTLE_INITIAL_HP)
		
		var p_label: Label3D = p_castle.get_node_or_null("HpLabel")
		if p_label == null:
			p_label = Label3D.new()
			p_label.name = "HpLabel"
			p_label.position = Vector3(0, 2.0, 0)
			p_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			p_label.font_size = 30
			p_label.outline_size = 6
			p_label.modulate = Color("66ccff")
			p_castle.add_child(p_label)
		p_label.text = "味方城 HP %d/%d" % [PLAYER_CASTLE_INITIAL_HP, PLAYER_CASTLE_INITIAL_HP]

func _physics_process(delta: float) -> void:
	if state == MatchState.MARCHING or state == MatchState.ENGAGED:
		_process_combat_and_blocking(delta)

func _process_combat_and_blocking(delta: float) -> void:
	# 1. ブロック判定（接近した敵の進軍を停止させる、その間自身も進軍停止）
	var any_blocked := false
	for unit in _units:
		if not is_instance_valid(unit) or unit.get_meta("hp", 0) <= 0:
			continue
		for enemy in _enemy_units:
			if not is_instance_valid(enemy) or enemy.get_meta("hp", 0) <= 0:
				continue
			
			var dist := unit.global_position.distance_to(enemy.global_position)
			var block_range: float = unit.get_meta("block_range", 1.1)
			
			if dist < block_range:
				var u_blocking: Array = unit.get_meta("blocking", [])
				var e_blocked_by: Node3D = enemy.get_meta("blocked_by", null)
				var max_block: int = unit.get_meta("block_count_max", 1)
				
				if u_blocking.size() < max_block and e_blocked_by == null:
					u_blocking.append(enemy)
					unit.set_meta("blocking", u_blocking)
					enemy.set_meta("blocked_by", unit)
					_pause_unit_movement(unit)
					_pause_unit_movement(enemy)
				
				if not u_blocking.is_empty():
					any_blocked = true

	if any_blocked:
		if state != MatchState.ENGAGED:
			state = MatchState.ENGAGED
			roll_button.text = "交戦中"
			status_label.text = "交戦！ 敵モンスターをブロックして進軍を阻止しています"
	elif state == MatchState.ENGAGED and not _units.is_empty() and not _enemy_units.is_empty():
		state = MatchState.MARCHING
		roll_button.text = "進軍中"
		status_label.text = "進軍再開！ 敵要塞へ向けて前進しています"

	# 2. オートエイム射撃（味方 -> 最寄りの敵、または敵城）
	for unit in _units:
		if not is_instance_valid(unit) or unit.get_meta("hp", 0) <= 0:
			continue
		_update_shooting(unit, _enemy_units, true, delta)
	
	# 3. オートエイム射撃（敵 -> 最寄りの味方）
	for enemy in _enemy_units:
		if not is_instance_valid(enemy) or enemy.get_meta("hp", 0) <= 0:
			continue
		_update_shooting(enemy, _units, false, delta)

func _update_shooting(attacker: Node3D, target_pool: Array[Node3D], is_player: bool, delta: float) -> void:
	var timer: float = attacker.get_meta("attack_timer", 0.0) - delta
	attacker.set_meta("attack_timer", timer)
	
	if timer <= 0.0:
		var range_dist: float = attacker.get_meta("attack_range", 5.0)
		var nearest_target: Node3D = null
		var min_dist := range_dist
		
		# 1. まず生存している敵ユニットを優先探索
		for candidate in target_pool:
			if not is_instance_valid(candidate) or candidate.get_meta("hp", 0) <= 0:
				continue
			var d := attacker.global_position.distance_to(candidate.global_position)
			if d < min_dist:
				min_dist = d
				nearest_target = candidate
		
		# 2. 射程内に敵ユニットがいなければ、城をターゲットとして認識
		if nearest_target == null:
			if is_player:
				if battlefield and battlefield.has_node("Castles/EnemyCastle"):
					var enemy_castle: Node3D = battlefield.get_node("Castles/EnemyCastle")
					if is_instance_valid(enemy_castle) and enemy_castle.get_meta("hp", 0) > 0:
						var dist_to_castle := attacker.global_position.distance_to(enemy_castle.global_position)
						if dist_to_castle < range_dist:
							nearest_target = enemy_castle
			else:
				if battlefield and battlefield.has_node("Castles/PlayerCastle"):
					var player_castle: Node3D = battlefield.get_node("Castles/PlayerCastle")
					if is_instance_valid(player_castle) and player_castle.get_meta("hp", 0) > 0:
						var dist_to_castle := attacker.global_position.distance_to(player_castle.global_position)
						if dist_to_castle < range_dist:
							nearest_target = player_castle
		
		if nearest_target != null:
			var power: int = attacker.get_meta("attack_power", 10)
			_spawn_projectile(attacker.global_position, nearest_target, power, is_player)
			var cooldown: float = attacker.get_meta("attack_cooldown", 1.0)
			attacker.set_meta("attack_timer", cooldown)
		else:
			attacker.set_meta("attack_timer", 0.15)

func _spawn_projectile(from_pos: Vector3, target: Node3D, damage: int, is_player: bool) -> void:
	var proj := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	proj.mesh = mesh
	var color := Color("50e8ff") if is_player else Color("ff4868")
	proj.material_override = _glow_material(color)
	proj.position = from_pos + Vector3(0, 0.4, 0)
	army.add_child(proj)
	_projectiles.append(proj)
	
	var is_target_castle: bool = target.get_meta("is_castle", false)
	var offset_y := 0.7 if is_target_castle else 0.4
	var target_pos := target.global_position + Vector3(0, offset_y, 0)
	var dist := proj.global_position.distance_to(target_pos)
	var duration := clampf(dist / 12.0, 0.12, 0.35)
	
	var tween := create_tween()
	tween.tween_property(proj, "global_position", target_pos, duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func():
		if is_instance_valid(proj):
			_projectiles.erase(proj)
			proj.queue_free()
		if is_instance_valid(target):
			_apply_damage(target, damage, is_player)
	)

func _apply_damage(target: Node3D, damage: int, from_player: bool) -> void:
	if not is_instance_valid(target):
		return
	var current_hp: int = target.get_meta("hp", 0) - damage
	var max_hp: int = target.get_meta("max_hp", 100)
	var is_castle: bool = target.get_meta("is_castle", false)
	var is_player_castle: bool = target.get_meta("is_player_castle", false)
	target.set_meta("hp", current_hp)
	
	if target.has_node("HpLabel"):
		var label: Label3D = target.get_node("HpLabel")
		if is_castle:
			if is_player_castle:
				label.text = "味方城 HP %d/%d" % [max(current_hp, 0), max_hp]
			else:
				label.text = "敵城 HP %d/%d" % [max(current_hp, 0), max_hp]
		else:
			label.text = "HP %d/%d" % [max(current_hp, 0), max_hp]
	
	var hit_tween := create_tween()
	if is_castle:
		hit_tween.tween_property(target, "scale", Vector3(1.04, 0.96, 1.04), 0.05)
		hit_tween.tween_property(target, "scale", Vector3.ONE, 0.06)
		if is_player_castle:
			status_label.text = "警告！ 味方城が攻撃されています！ 残り城HP: %d/%d" % [max(current_hp, 0), max_hp]
			if current_hp <= 0:
				_trigger_defeat(target)
		else:
			status_label.text = "敵城を攻撃中！ 残り城HP: %d/%d" % [max(current_hp, 0), max_hp]
			if current_hp <= 0:
				_trigger_victory(target)
	else:
		hit_tween.tween_property(target, "scale", Vector3(1.15, 0.85, 1.15), 0.05)
		hit_tween.tween_property(target, "scale", Vector3.ONE, 0.06)
		if current_hp <= 0:
			_kill_unit(target, from_player)

func _trigger_victory(enemy_castle: Node3D) -> void:
	if state == MatchState.VICTORY or state == MatchState.DEFEAT:
		return
	state = MatchState.VICTORY
	_kill_active_tweens()
	
	for proj in _projectiles:
		if is_instance_valid(proj):
			proj.queue_free()
	_projectiles.clear()
	
	var destroy_tween := create_tween()
	destroy_tween.tween_property(enemy_castle, "scale", Vector3.ZERO, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	destroy_tween.tween_callback(func():
		if is_instance_valid(enemy_castle):
			enemy_castle.visible = false
	)
	
	status_label.text = "VICTORY！ 敵城を破壊しました"
	roll_button.disabled = true
	roll_button.text = "勝利！"

func _trigger_defeat(player_castle: Node3D) -> void:
	if state == MatchState.DEFEAT or state == MatchState.VICTORY:
		return
	state = MatchState.DEFEAT
	_kill_active_tweens()
	
	for proj in _projectiles:
		if is_instance_valid(proj):
			proj.queue_free()
	_projectiles.clear()
	
	var destroy_tween := create_tween()
	destroy_tween.tween_property(player_castle, "scale", Vector3.ZERO, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	destroy_tween.tween_callback(func():
		if is_instance_valid(player_castle):
			player_castle.visible = false
	)
	
	status_label.text = "DEFEAT… 味方城が破壊されました"
	roll_button.disabled = true
	roll_button.text = "敗北…"

func _kill_unit(unit: Node3D, killed_by_player: bool) -> void:
	if not is_instance_valid(unit):
		return
	
	_release_blocks_for(unit)
	
	if unit.has_meta("move_tween"):
		var move_tween: Tween = unit.get_meta("move_tween")
		if move_tween and move_tween.is_valid():
			move_tween.kill()
	
	var is_enemy := _enemy_units.has(unit)
	_units.erase(unit)
	_enemy_units.erase(unit)
	
	var die_tween := create_tween()
	die_tween.tween_property(unit, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	die_tween.tween_callback(func():
		if is_instance_valid(unit):
			unit.queue_free()
	)
	
	if killed_by_player:
		status_label.text = "敵モンスター撃破！ 味方部隊が進軍を再開します"
		if _enemy_units.is_empty():
			roll_button.text = "進軍中"
			if state == MatchState.ENGAGED:
				state = MatchState.MARCHING
		if is_enemy:
			_schedule_enemy_respawn(3.0)
	else:
		status_label.text = "味方モンスターが撃破されました…"

func _schedule_enemy_respawn(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if state != MatchState.MARCHING and state != MatchState.ENGAGED:
		return
	
	var base_spawn_pos := Vector3(7.75, 0.35, 0.0)
	var player_target_x := -6.4
	if battlefield and battlefield.has_node("Castles/EnemyCastle"):
		var enemy_castle: Node3D = battlefield.get_node("Castles/EnemyCastle")
		if enemy_castle.get_meta("hp", 0) <= 0:
			return
		base_spawn_pos = enemy_castle.global_position
		base_spawn_pos.y = 0.35
	elif battlefield and battlefield.has_node("SpawnMarkers/EnemySpawn"):
		var marker: Marker3D = battlefield.get_node("SpawnMarkers/EnemySpawn")
		base_spawn_pos = marker.global_position
		base_spawn_pos.y = 0.35
	
	if battlefield and battlefield.has_node("Castles/PlayerCastle"):
		var player_castle: Node3D = battlefield.get_node("Castles/PlayerCastle")
		player_target_x = player_castle.global_position.x + 0.8
	
	var spawn_pos := base_spawn_pos + Vector3(0, 0, randf_range(-1.2, 1.2))
	var new_enemy := _make_enemy_unit(spawn_pos)
	army.add_child(new_enemy)
	_enemy_units.append(new_enemy)
	
	new_enemy.scale = Vector3.ZERO
	var spawn_tween := create_tween()
	spawn_tween.tween_property(new_enemy, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	
	_start_enemy_march(new_enemy, player_target_x)

func _pause_unit_movement(unit: Node3D) -> void:
	if not is_instance_valid(unit):
		return
	if unit.has_meta("move_tween"):
		var tween: Tween = unit.get_meta("move_tween")
		if tween and tween.is_valid() and tween.is_running():
			tween.pause()

func _resume_unit_movement(unit: Node3D) -> void:
	if not is_instance_valid(unit):
		return
	if unit.has_meta("move_tween"):
		var tween: Tween = unit.get_meta("move_tween")
		if tween and tween.is_valid():
			tween.play()

func _release_blocks_for(dead_unit: Node3D) -> void:
	var blocking: Array = dead_unit.get_meta("blocking", [])
	for other in blocking:
		if is_instance_valid(other):
			other.set_meta("blocked_by", null)
			_resume_unit_movement(other)
	
	var blocker: Node3D = dead_unit.get_meta("blocked_by", null)
	if is_instance_valid(blocker):
		var blocker_list: Array = blocker.get_meta("blocking", [])
		blocker_list.erase(dead_unit)
		blocker.set_meta("blocking", blocker_list)
		if blocker_list.is_empty():
			_resume_unit_movement(blocker)

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
	for proj in _projectiles:
		if is_instance_valid(proj):
			proj.queue_free()
	_projectiles.clear()
	for unit in _units:
		if is_instance_valid(unit):
			unit.queue_free()
	_units.clear()
	_spawn_test_enemy()
	_setup_castles()
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
		unit.set_meta("move_tween", tween)
		_active_tweens.append(tween)
	
	# 敵モンスターの進軍（味方城方向：-X方向）
	var player_target_x := -6.4
	if battlefield and battlefield.has_node("Castles/PlayerCastle"):
		var player_castle: Node3D = battlefield.get_node("Castles/PlayerCastle")
		player_target_x = player_castle.global_position.x + 0.8
	for enemy in _enemy_units:
		_start_enemy_march(enemy, player_target_x)

func _start_enemy_march(enemy: Node3D, player_target_x: float) -> void:
	if not is_instance_valid(enemy):
		return
	var start_z := enemy.position.z
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(enemy, "position:z", start_z - 0.4, 1.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(enemy, "position:z", start_z + 0.4, 1.6).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(enemy, "position:x", player_target_x, 8.5).set_trans(Tween.TRANS_QUAD)
	enemy.set_meta("move_tween", tween)
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
	
	var base_spawn_pos := Vector3(7.75, 0.35, 0.0)
	if battlefield and battlefield.has_node("Castles/EnemyCastle"):
		var enemy_castle: Node3D = battlefield.get_node("Castles/EnemyCastle")
		base_spawn_pos = enemy_castle.global_position
		base_spawn_pos.y = 0.35
	elif battlefield and battlefield.has_node("SpawnMarkers/EnemySpawn"):
		var marker: Marker3D = battlefield.get_node("SpawnMarkers/EnemySpawn")
		base_spawn_pos = marker.global_position
		base_spawn_pos.y = 0.35
	
	var z_offsets := [-1.2, 0.0, 1.2]
	for i in range(ENEMY_COUNT_INITIAL):
		var z_off: float = z_offsets[i % z_offsets.size()]
		var spawn_pos := base_spawn_pos + Vector3(0, 0, z_off)
		var enemy := _make_enemy_unit(spawn_pos)
		army.add_child(enemy)
		_enemy_units.append(enemy)

func _create_hp_label(max_hp: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.name = "HpLabel"
	label.text = "HP %d/%d" % [max_hp, max_hp]
	label.position = Vector3(0, 0.95, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.outline_size = 6
	label.modulate = color
	return label

func _make_enemy_unit(start: Vector3) -> Node3D:
	var unit := Node3D.new()
	unit.name = "TestEnemyUnit"
	unit.position = start
	
	var max_hp := 120
	unit.set_meta("hp", max_hp)
	unit.set_meta("max_hp", max_hp)
	unit.set_meta("attack_power", 12)
	unit.set_meta("attack_range", 5.0)
	unit.set_meta("attack_cooldown", 1.2)
	unit.set_meta("attack_timer", 0.6)
	unit.set_meta("block_range", 1.1)
	unit.set_meta("block_count_max", 1)
	unit.set_meta("blocking", [])
	unit.set_meta("blocked_by", null)
	unit.add_child(_create_hp_label(max_hp, Color("ff8090")))

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
	
	var max_hp := 40 + rarity * 20
	unit.set_meta("hp", max_hp)
	unit.set_meta("max_hp", max_hp)
	unit.set_meta("attack_power", 8 + rarity * 4)
	unit.set_meta("attack_range", 5.0)
	unit.set_meta("attack_cooldown", 1.0)
	unit.set_meta("attack_timer", randf_range(0.2, 0.5))
	unit.set_meta("block_range", 1.1)
	unit.set_meta("block_count_max", 1)
	unit.set_meta("blocking", [])
	unit.set_meta("blocked_by", null)
	unit.add_child(_create_hp_label(max_hp, Color("80ffb0")))

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
