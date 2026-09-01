extends Control

@export var heading := ""
@export_multiline var message := ""

@onready var heading_label: Label = $Panel/Margin/Menu/Heading
@onready var message_label: Label = $Panel/Margin/Menu/Message


func _ready() -> void:
	heading_label.text = heading
	message_label.text = message


func _on_back_pressed() -> void:
	Game.open_title()
