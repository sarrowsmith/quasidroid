extends Node2D


export(int) var game_seed


func _ready():
	seed(game_seed)
	$World.create()


func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		var level = null
		match event.scancode:
			KEY_U:
				level = $World.active_level.parent
			KEY_Z:
				level = $World.active_level.children[0]
			KEY_X:
				level = $World.active_level.children[1]
		$World.change_level(level)
