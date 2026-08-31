extends Node3D

@export var monster_scene:PackedScene

func _ready():
	Game.spawn_request.connect(_on_spawn_request)

func _on_spawn_request(team, rarity, pos):
	var m = monster_scene.instantiate()
	add_child(m)
	m.global_position = pos
	m.setup(team, rarity)
	Game.unit_spawned.emit(m)
