class_name SummonDemo
extends PanelContainer

signal completed

var _label: Label

func _ready() -> void:
	_label = get_node("Margin/VBox/Message")

func present(summons: Array[Dictionary]) -> void:
	var stars: Array[String] = []
	for summon in summons:
		stars.append("☆".repeat(int(summon["rarity"])))
	_label.text = "召喚完了！\n" + "　".join(stars) + " のモンスターが戦場に現れた"
	show()
	await get_tree().create_timer(1.65).timeout
	completed.emit()
