extends Node
## Global entry point for coarse game flow only.
## Scene-local progression (for example MainGame's DiceRoll -> MarchMain)
## intentionally belongs to the scene that owns that flow.

signal state_changed(previous_state: State, current_state: State, payload: Dictionary)
signal root_modal_requested(state: State, payload: Dictionary)
signal stage_requested(stage_id: StringName)
signal dice_roll_requested

enum State {
	BOOT,
	TITLE,
	CONFIG,
	TUTORIAL,
	MAIN_GAME,
	STAGE_CLEAR,
	GAME_OVER,
	GAME_CLEAR,
}

const ROOT_MODAL_SCENES := {
	State.BOOT: "res://scenes/ui/boot_modal.tscn",
	State.TITLE: "res://scenes/ui/title_modal.tscn",
	State.CONFIG: "res://scenes/ui/config_modal.tscn",
	State.TUTORIAL: "res://scenes/ui/tutorial_modal.tscn",
	State.MAIN_GAME: "res://scenes/main_game.tscn",
	State.STAGE_CLEAR: "res://scenes/ui/stage_clear_modal.tscn",
	State.GAME_OVER: "res://scenes/ui/game_over_modal.tscn",
	State.GAME_CLEAR: "res://scenes/ui/game_clear_modal.tscn",
}

var state: State = State.BOOT
var current_stage_id: StringName = &"stage_001"


func _ready() -> void:
	transition_to(State.BOOT)


func transition_to(next_state: State, payload: Dictionary = {}) -> void:
	var previous_state := state
	state = next_state
	state_changed.emit(previous_state, state, payload)
	root_modal_requested.emit(state, payload)


func open_title() -> void:
	transition_to(State.TITLE)


func open_config() -> void:
	transition_to(State.CONFIG)


func open_tutorial() -> void:
	transition_to(State.TUTORIAL)


func start_main_game(stage_id: StringName = current_stage_id) -> void:
	current_stage_id = stage_id
	stage_requested.emit(current_stage_id)
	transition_to(State.MAIN_GAME, {"stage_id": current_stage_id})


func finish_stage(is_final_stage: bool) -> void:
	transition_to(State.GAME_CLEAR if is_final_stage else State.STAGE_CLEAR)


func lose_game() -> void:
	transition_to(State.GAME_OVER)
