extends Node
## Owns the root-modal stack for the global Game flow.
##
## The bottom entry is always the scene requested by Game. Detail dialogs can
## be pushed above it without inventing another value in Game.State.

@onready var modal_host: Node = $ModalHost

var _modal_stack: Array[Dictionary] = []


func _ready() -> void:
	Game.root_modal_requested.connect(_show_root_modal)
	# Game enters BOOT before this scene has connected to its signal, so render
	# the current state once the host is available.
	_show_root_modal(Game.state, {})


func _show_root_modal(state: Game.State, payload: Dictionary) -> void:
	var scene_path: String = Game.ROOT_MODAL_SCENES.get(state, "")
	if scene_path.is_empty():
		push_error("No root scene is registered for state %s." % state)
		return

	_clear_modal_stack()
	push_modal(scene_path, payload)


## Adds a local detail modal. Each entry is keyed by instance ID rather than
## scene path, allowing the same PackedScene to be pushed recursively.
func push_modal(scene_path: String, payload: Dictionary = {}, pauses_tree := false) -> Node:
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("Unable to load modal scene: %s" % scene_path)
		return null

	var modal := packed_scene.instantiate()
	modal_host.add_child(modal)
	_modal_stack.append({
		"instance_id": modal.get_instance_id(),
		"scene_path": scene_path,
		"payload": payload.duplicate(true),
		"pauses_tree": pauses_tree,
	})
	_update_pause_policy()
	return modal


func pop_modal() -> void:
	if _modal_stack.is_empty():
		return

	var entry: Dictionary = _modal_stack.pop_back()
	var instance_id: int = entry["instance_id"]
	var modal := instance_from_id(instance_id)
	if is_instance_valid(modal):
		modal.queue_free()
	_update_pause_policy()


func _clear_modal_stack() -> void:
	while not _modal_stack.is_empty():
		var entry: Dictionary = _modal_stack.pop_back()
		var modal := instance_from_id(entry["instance_id"])
		if is_instance_valid(modal):
			modal.queue_free()
	get_tree().paused = false


func _update_pause_policy() -> void:
	var should_pause := false
	for entry in _modal_stack:
		if entry["pauses_tree"]:
			should_pause = true
			break
	get_tree().paused = should_pause
