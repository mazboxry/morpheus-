extends Node3D

@export var monster_scene: PackedScene

@onready var player_spawn: Marker3D = $SpawnMarkers/PlayerSpawn
@onready var enemy_spawn: Marker3D = $SpawnMarkers/EnemySpawn
@onready var player_castle: Node3D = $Castles/PlayerCastle
@onready var enemy_castle: Node3D = $Castles/EnemyCastle
@onready var player_dice_zone: StaticBody3D = $DiceZones/PlayerDiceZone
@onready var enemy_dice_zone: StaticBody3D = $DiceZones/EnemyDiceZone


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
