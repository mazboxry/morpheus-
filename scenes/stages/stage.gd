class_name BattleStage
extends Node3D
## Contract for hand-authored stage scenes.
## Designers may add art and obstacles freely while preserving these anchors.

signal player_castle_destroyed
signal enemy_castle_destroyed

@export var stage_id: StringName
@export var is_final_stage := false

@onready var player_spawn_zone: Marker3D = $PlayerSpawnZone
@onready var enemy_spawn_zone: Marker3D = $EnemySpawnZone
@onready var player_castle: Node3D = $PlayerCastle
@onready var enemy_castle: Node3D = $EnemyCastle


func _ready() -> void:
	if player_castle.has_signal("destroyed"):
		player_castle.connect("destroyed", player_castle_destroyed.emit)
	if enemy_castle.has_signal("destroyed"):
		enemy_castle.connect("destroyed", enemy_castle_destroyed.emit)
