extends CharacterBody3D

signal died

@export var speed := 2.0
@export var attack_power := 10
@export var attack_cooldown := 1.5
@export var max_hp := 100

var team:String
var rarity:int

var hp:int
var cooldown := 0.0
var target = null

var statuses = []

func setup(t, r):
	team = t
	rarity = r
	hp = max_hp * r
	attack_power *= r
	# 头上カラー変更（例: rarity 1=赤, 6=青）
	var color = Color(1, 0, 0).lerp(Color(0, 0, 1), (r - 1)/5)
	#$HeadMesh.material_override.color = color
	print("")

func _ready():
	# ダイスロールマネージャーに接続
	var dice_roll_manager = get_node("/root/ShowcaseMain/DiceRollManager")
	dice_roll_manager.connect("die_stopped", Callable(self, "_on_die_stopped"))
	
func _physics_process(delta):
	if hp <= 0:
		return

	_update_status(delta)

	if target == null:
		_move_forward(delta)
	else:
		_attack_logic(delta)

func _move_forward(delta):
	velocity = Vector3(0,0,-1) * speed
	move_and_slide()

func _attack_logic(delta):
	cooldown -= delta
	if cooldown <= 0:
		cooldown = attack_cooldown * _get_speed_modifier()
		_attack()

func _attack():
	if target == null:
		return
	target.take_damage(attack_power)
	_try_skill()

func take_damage(dmg):
	hp -= dmg
	if hp <= 0:
		die()

func die():
	emit_signal("died")
	queue_free()

# ------------------------
# スキル（確率発動）
# ------------------------
func _try_skill():
	if randf() < 0.2:
		_apply_random_effect()

func _apply_random_effect():
	if randf() < 0.5:
		add_status("haste", 2.0)
	else:
		if target:
			target.add_status("poison", 3.0)

# ------------------------
# 状態異常
# ------------------------
func add_status(type:String, duration:float):
	statuses.append({
		"type": type,
		"time": duration
	})
	_spawn_status_icon(type)

func _update_status(delta):
	var new_list = []
	for s in statuses:
		s.time -= delta
		if s.time > 0:
			_apply_status_effect(s, delta)
			new_list.append(s)
	statuses = new_list

func _apply_status_effect(s, delta):
	match s.type:
		"poison":
			hp -= delta * 2
		"haste":
			pass

func _get_speed_modifier():
	var mod = 1.0
	for s in statuses:
		if s.type == "slow":
			mod *= 1.5
		if s.type == "haste":
			mod *= 0.7
	return mod

func _spawn_status_icon(type):
	# tscn差し替え前提
	pass

func _on_die_stopped(result):
	# ダイスの結果を受け取ってモンスターを初期化
	setup(team, result["rarity"])
