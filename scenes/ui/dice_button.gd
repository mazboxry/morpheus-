extends Button

@export var team := "player"

func _pressed():
	var value = Game.roll_dice()
	var comment="""var rarity = value # そのまま
	var pos = get_random_spawn_position()
	Game.request_spawn(team, rarity, pos)
	"""
func get_random_spawn_position():
	# 適当：あとで改善可能
	return Vector3(randf()*4-2, 0, randf()*4-2)
