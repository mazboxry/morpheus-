extends Control
## Brief boot screen. It deliberately owns no global state beyond requesting
## the next root screen through Game.

@export var display_duration := 0.35


func _ready() -> void:
	await get_tree().create_timer(display_duration).timeout
	if Game.state == Game.State.BOOT:
		Game.open_title()
