class_name DiceRollManager
extends Node
## Local dice controller: each die settles, reads its top face, then reports once.

signal die_stopped(result: Dictionary)
signal roll_finished(results: Array[Dictionary])

const FACES := [1, 1, 1, 2, 2, 3]
var _results: Array[Dictionary] = []

func roll(spawn_positions: Array[Vector2]) -> void:
	_results.clear()
	for index in spawn_positions.size():
		await get_tree().create_timer(0.42).timeout
		var face_index := randi_range(0, FACES.size() - 1)
		var result := {
			"die_index": index,
			"top_face_index": face_index,
			"rarity": FACES[face_index],
			"position": spawn_positions[index],
		}
		_results.append(result)
		die_stopped.emit(result)
	roll_finished.emit(_results.duplicate(true))
	Game.report_dice_results(_results)
