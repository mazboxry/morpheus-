extends Node
class_name  SpawnManager
var layer_names=["EnemyUnit","PlayerUnit","Dice","BattleField"]
var layers={}
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var stage=Game.main_stage
	
	for n in layer_names:
		layers[n]=Game.main_stage
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func spawn(obj:Node3D,layer:String):
	pass
	
