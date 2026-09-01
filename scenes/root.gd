extends Node
## Owns root-level scene replacement for the global Game flow.

@onready var modal_host: Node = $ModalHost

var _active_modal: Node


func _ready() -> void:
	Game.root_modal_requested.connect(_show_root_modal)
	# Game enters BOOT before this scene has connected to its signal.
	# Advance on the next frame so the first visible screen is always the title.
	if Game.state == Game.State.BOOT:
		call_deferred("_open_title_after_boot")
	else:
		_show_root_modal(Game.state, {})


func _open_title_after_boot() -> void:
	Game.open_title()


func _show_root_modal(state: Game.State, _payload: Dictionary) -> void:
	var scene_path: String = Game.ROOT_MODAL_SCENES.get(state, "")
	if scene_path.is_empty():
		push_error("No root scene is registered for state %s." % state)
		return

	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("Unable to load root scene: %s" % scene_path)
		return

	if is_instance_valid(_active_modal):
		_active_modal.queue_free()
	_active_modal = packed_scene.instantiate()
	modal_host.add_child(_active_modal)
