extends Area3D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.has_method("take_damage"):
		if body.team != get_parent().team:
			get_parent().target = body
