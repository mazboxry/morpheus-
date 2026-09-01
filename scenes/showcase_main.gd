extends Control
## A presentation-first vertical slice for title -> physical-die result -> summon -> march.

enum MatchState { DICE_ROLL, SUMMON_DEMO, MARCH_START, MARCH_MAIN }

@onready var roll_button: Button = $HUD/RollButton
@onready var status_label: Label = $HUD/Status
@onready var result_label: Label = $HUD/Results
@onready var dice_manager: DiceRollManager = $DiceRollManager
@onready var summoner: MonsterSummoner = $MonsterSummoner
@onready var summon_demo: SummonDemo = $SummonDemo

var state := MatchState.DICE_ROLL
var dice_angles := [0.0, 0.0, 0.0, 0.0]
var dice_values := [0, 0, 0, 0]
var summon_units: Array[Dictionary] = []
var elapsed := 0.0

func _ready() -> void:
	Game.dice_results_ready.connect(_on_dice_results_ready)
	dice_manager.die_stopped.connect(_on_die_stopped)
	summoner.monsters_summoned.connect(_on_monsters_summoned)
	summon_demo.completed.connect(_start_march)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if state == MatchState.DICE_ROLL and not roll_button.disabled:
		for index in dice_angles.size():
			dice_angles[index] += delta * (2.5 + index * 0.8)
	if state == MatchState.MARCH_MAIN:
		for unit in summon_units:
			unit["progress"] = minf(float(unit.get("progress", 0.0)) + delta * 0.055, 0.76)
	queue_redraw()

func _on_roll_pressed() -> void:
	state = MatchState.SUMMON_DEMO
	roll_button.disabled = true
	roll_button.text = "ダイス判定中…"
	status_label.text = "4つのダイスが停止するのを待っています"
	result_label.text = ""
	dice_values = [0, 0, 0, 0]
	dice_manager.roll([Vector2(0.23, 0.67), Vector2(0.40, 0.56), Vector2(0.58, 0.64), Vector2(0.73, 0.53)])

func _on_die_stopped(result: Dictionary) -> void:
	var index: int = result["die_index"]
	dice_values[index] = result["rarity"]
	dice_angles[index] = 0.0
	status_label.text = "ダイス %d が停止：上面 ☆%d を検出" % [index + 1, dice_values[index]]

func _on_dice_results_ready(results: Array[Dictionary]) -> void:
	# The Game notification is intentionally only a bridge to this local summoner.
	summoner.summon_from_dice(results)

func _on_monsters_summoned(summons: Array[Dictionary]) -> void:
	summon_units = summons
	var summary: Array[String] = []
	for summon in summons:
		summary.append("☆%d" % summon["rarity"])
	result_label.text = "判定結果  " + "  ".join(summary)
	summon_demo.present(summons)

func _start_march() -> void:
	state = MatchState.MARCH_START
	status_label.text = "召喚演出完了。味方部隊、進軍開始！"
	await get_tree().create_timer(0.7).timeout
	state = MatchState.MARCH_MAIN
	status_label.text = "進軍中 — 城を目指して自動戦闘を開始しました"

func _draw() -> void:
	var area := Rect2(Vector2(28, 115), size - Vector2(56, 225))
	draw_rect(area, Color("101d35"), true)
	draw_rect(area, Color("4479a3"), false, 2.0)
	# lane, castles, and luminous deployment points
	draw_rect(Rect2(area.position + Vector2(0, area.size.y * .44), Vector2(area.size.x, area.size.y * .15)), Color("1c3650"), true)
	_draw_castle(area.position + Vector2(34, area.size.y * .37), Color("5aaeff"), "味方の城")
	_draw_castle(area.position + Vector2(area.size.x - 106, area.size.y * .37), Color("ff707b"), "敵の城")
	for index in 4:
		var p := Vector2(area.position.x + area.size.x * (0.20 + index * .18), area.position.y + area.size.y * (0.68 - (index % 2) * .12))
		_draw_die(p, index)
	for unit in summon_units:
		var original: Vector2 = unit["position"]
		var progress := float(unit.get("progress", 0.0))
		var p := area.position + Vector2(area.size.x * (original.x + progress), area.size.y * original.y)
		_draw_monster(p, int(unit["rarity"]))

func _draw_castle(p: Vector2, color: Color, caption: String) -> void:
	draw_rect(Rect2(p, Vector2(72, 72)), color.darkened(.35), true)
	draw_rect(Rect2(p, Vector2(72, 72)), color, false, 3.0)
	draw_string(ThemeDB.fallback_font, p + Vector2(6, 98), caption, HORIZONTAL_ALIGNMENT_CENTER, 100, 16, color)

func _draw_die(p: Vector2, index: int) -> void:
	var value := dice_values[index]
	var rotation := 0.0 if value > 0 else dice_angles[index]
	draw_set_transform(p + Vector2(29, 29), rotation)
	var color := Color("f5f6ff") if value == 0 else Color("bfeaff")
	draw_rect(Rect2(-29, -29, 58, 58), color, true)
	draw_rect(Rect2(-29, -29, 58, 58), Color("27476b"), false, 3.0)
	if value > 0:
		draw_string(ThemeDB.fallback_font, Vector2(-11, 12), "☆%d" % value, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("11375b"))
	else:
		draw_circle(Vector2.ZERO, 5, Color("27517a"))
	draw_set_transform(Vector2.ZERO, 0.0)

func _draw_monster(p: Vector2, rarity: int) -> void:
	var color := [Color("8de4ff"), Color("a98cff"), Color("ffd667")][rarity - 1]
	draw_circle(p, 19.0 + rarity * 2.0, color.darkened(.35))
	draw_circle(p, 15.0 + rarity * 2.0, color)
	draw_string(ThemeDB.fallback_font, p + Vector2(-15, 6), "☆%d" % rarity, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("10203c"))
