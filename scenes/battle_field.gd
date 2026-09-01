extends Node3D

@export var monster_scene:PackedScene


func spawn_monster(team: String, rarity: int, pos: Vector3) -> Node3D:
	# Called by the future SpawnManager.  BattleField deliberately does not
	# subscribe to Game: spawning is not global-flow responsibility.
	if monster_scene == null:
		push_error("BattleField needs a monster_scene before spawning units.")
		return null
	var m = monster_scene.instantiate()
	add_child(m)
	m.global_position = pos
	m.setup(team, rarity)
	return m
