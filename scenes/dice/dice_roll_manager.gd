class_name DiceRollManager
extends Node
## Receives a *physical* result from every RigidBody3D die.

signal die_stopped(result: Dictionary)
signal roll_finished(results: Array[Dictionary])

var _results: Array[Dictionary] = []
var _expected_count := 0

func begin_roll(expected_count: int) -> void:
	_expected_count = expected_count
	_results.clear()

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
