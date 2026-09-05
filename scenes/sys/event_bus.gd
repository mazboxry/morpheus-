extends Node
class_name EventBus
# Called when the node enters the scene tree for the first time.
signal Boot

var signal_handler={Boot:[_on_boot]} 
func _ready() -> void:
	_register_signal_handlers()
	pass # Replace with function body.

func _on_boot():
	pass
func _register_signal_handlers():
	Boot.connect(_on_boot)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
