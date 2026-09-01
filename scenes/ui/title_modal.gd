extends Control


func _on_start_pressed() -> void:
	Game.start_main_game()


func _on_tutorial_pressed() -> void:
	Game.open_tutorial()


func _on_config_pressed() -> void:
	Game.open_config()


func _on_quit_pressed() -> void:
	get_tree().quit()
