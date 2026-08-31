extends Node

signal spawn_request(team, rarity, position)
signal unit_spawned(unit)
signal battle_started
signal battle_ended(winner)
signal dice_rolled()
var dice_ball:Node3D
var rng := RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	dice_rolled.connect(roll_dice)
func roll_dice():
	if dice_ball.has_method("_on_dice_throw"):
		dice_ball._on_dice_throw()

func request_spawn(team, rarity, pos):
	emit_signal("spawn_request", team, rarity, pos)
