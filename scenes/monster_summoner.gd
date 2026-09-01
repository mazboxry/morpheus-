class_name MonsterSummoner
extends Node
## Converts the narrow Game dice-result notification into presentation data.

signal monsters_summoned(summons: Array[Dictionary])

func summon_from_dice(results: Array[Dictionary]) -> void:
	var summons: Array[Dictionary] = []
	for result in results:
		summons.append({"rarity": result["rarity"], "position": result["position"]})
	monsters_summoned.emit(summons)
