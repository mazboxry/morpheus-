extends Node3D

signal destroyed

@export var max_hp := 500
var hp := 500

func take_damage(dmg):
	hp -= dmg
	if hp <= 0:
		emit_signal("destroyed")
