extends Control

signal closed

func show_result(text):
	$Label.text = text
	visible = true
	get_tree().paused = true

func _on_button_pressed():
	get_tree().paused = false
	emit_signal("closed")
	queue_free()
