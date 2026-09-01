extends Button

@export var team := "player"

func _pressed():
	# The MainGame-local DiceRoll state owns the physical dice and result flow.
	# This UI only asks that state to begin; it must not invent spawn positions.
	Game.dice_roll_requested.emit()
