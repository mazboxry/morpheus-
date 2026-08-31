extends Node3D

var dice_list=[]
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Game.dice_ball=self
	snow_dome.collision_mask=1
	in_dome=true	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
@onready var dice1=$dice1
@onready var dice2=$dice2
@onready var dice3=$dice3
@onready var dice4=$dice4

const MIN_ANGULAR_SPEED = 2.0
const MIN_LINEAR_SPEED = 1.0
var in_dome=false
func _process(delta: float) -> void:
	return
	if in_dome:
		for dice in [dice1, dice2, dice3, dice4]:
			if dice.angular_velocity.length() < MIN_ANGULAR_SPEED:
				dice.apply_torque_impulse(Vector3(
					randf_range(-2, 2),
					randf_range(-2, 2),
					randf_range(-2, 2)
				))
			if dice.linear_velocity.length() < MIN_LINEAR_SPEED:
				dice.apply_central_impulse(Vector3(
					randf_range(-1.5, 1.5),
					randf_range(-1.5, 1.5),
					randf_range(-1.5, 1.5)
				))

@onready var snow_dome=$SnowDome

func _on_dice_start() -> void:
	snow_dome.show()
	snow_dome.collision_mask=1
	snow_dome.process_mode=Node.PROCESS_MODE_INHERIT


func _on_dice_throw() -> void:
	snow_dome.hide()
	
	#snow_dome.collision_mask=0
	snow_dome.process_mode=Node.PROCESS_MODE_DISABLED
	pass # Replace with function body.
