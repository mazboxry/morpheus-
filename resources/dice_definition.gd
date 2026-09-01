class_name DiceDefinition
extends Resource
## Data-only die definition.  The face list is deliberately independent from
## physics so future dice-set building can replace this resource without
## changing the battle flow.

@export var display_name := "Standard Die"
@export var faces: Array[int] = [1, 1, 1, 2, 2, 3]


func rarity_for_face(face_index: int) -> int:
	if face_index < 0 or face_index >= faces.size():
		push_error("Invalid die face index: %s" % face_index)
		return 1
	return faces[face_index]
