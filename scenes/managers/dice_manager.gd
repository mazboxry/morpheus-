extends EventBus
class_name DiceManager

## Receives a *physical* result from every RigidBody3D die.
signal roll_start(dice_set: Array[Dice])
signal die_stopped(gpos:Vector3,face:int)
signal roll_finished(results: Array[Dictionary])

var _results: Array[Dictionary] = []
var _expected_count := 0
@export var dice_dome_scene:PackedScene
@export var dice_domes=[]
func _ready() -> void:
	doce_dome=load("res://scenes/dice/dice_dome.tscn")

func begin_roll(expected_count: int) -> void:
	_expected_count = expected_count
	_results.clear()
func _on_dice_dome_requested(gpos:Vector3,player_idx:int):
	var dome=dice_dome_scene.instantiagte()
	dome.player_idx=player_idx
	
func report_physical_die(die_index: int, top_face: int, landing_position: Vector3) -> void:
	if _results.any(func(result: Dictionary) -> bool: return result["die_index"] == die_index):
		return
	var result := {
		"die_index": die_index,
		"top_face_index": top_face - 1,
		"rarity": top_face,
		"position": Vector2(clampf(landing_position.x / 10.0 + 0.5, 0.12, 0.72), clampf(landing_position.z / 8.0 + 0.5, 0.30, 0.72)),
		"landing_position": landing_position,
	}
	_results.append(result)
	die_stopped.emit(result)
	if _results.size() == _expected_count:
		_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["die_index"] < b["die_index"])
		roll_finished.emit(_results.duplicate(true))
		Game.report_dice_results(_results)
