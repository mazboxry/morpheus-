extends RigidBody3D
class_name Dice #本は　単数は DIEですが
#将来には６ダイ以も使えようにしたい

var indexes={Vector3.UP:1,
	Vector3.DOWN:1,
	Vector3.RIGHT:1,
	Vector3.LEFT:3,
	Vector3.FORWARD:2,
	Vector3.BACK:2	
}
var dice_manager:DiceManager
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if is_instance_valid(Game.dice_manager):
		dice_manager=Game.dice_manager
	else:
		print("ERRPR Game.dice_manager")
	pass # Replace with function body.

var SPEED_MIN=0.1


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if linear_velocity.length()<SPEED_MIN:
		_on_die_stopped()
	pass

func _on_dice_rolled():
	pass
func _on_die_stopped():
	return Game.dice_manager.die_stopped(global_position,_read_top_face)
		
	pass
func _read_top_face(die: RigidBody3D) -> int:
	var best_dot := -2.0
	var best_index := 0
	for index in FACE_DIRECTIONS.size():
		var face_normal: Vector3 = die.global_transform.basis * FACE_DIRECTIONS[index]
		var up_alignment: float = face_normal.dot(Vector3.UP)
		if up_alignment > best_dot:
			best_dot = up_alignment
			best_index = index
	return FACE_VALUES[best_index]
