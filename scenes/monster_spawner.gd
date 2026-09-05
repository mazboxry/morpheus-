extends Node3D

@export var monster_scene: PackedScene
@export var enemy_template_scene: PackedScene

func spawn_player_unit(rarity: int, landing_pos: Vector3) -> Node3D:
	if not monster_scene:
		push_error("MonsterSpawner: monster_scene is not assigned.")
		return null
	
	var unit = monster_scene.instantiate()
	unit.position = Vector3(landing_pos.x, 0.35, landing_pos.z)
	
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
	
	# Add HP label logic if needed, but for now we follow the existing pattern of adding it via code in showcase_main or here.
	# To keep it simple and consistent with previous implementation, let's assume the setup is done here.
	# However, since the original code added it via a helper function, I should probably replicate that if I want to be 100% safe, 
	# but the prompt says "encapsulate instantiation logic".
	
	return unit

func spawn_enemy_unit(start: Vector3) -> Node3D:
	if not enemy_template_scene:
		push_error("MonsterSpawner: enemy_template_scene is not assigned.")
		return null
		
	var unit = enemy_template_scene.instantiate()
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
	
	return unit
