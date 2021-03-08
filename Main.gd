extends Node2D


export(int) var game_seed
export(int) var pan_speed = 8
onready var world_size = $World.world_size
onready var panel = $View.get_node("Panel")


func _ready():
	seed(game_seed)
	$Player.change_level($World.create())
	$View.position = $Player.position


const input_map = {
	"ui_up": Vector2(0, -1),
	"ui_down": Vector2(0, 1),
	"ui_left": Vector2(-1, 0),
	"ui_right": Vector2(1, 0)
}
# warning-ignore:unused_argument
func _physics_process(delta):
	var position = $View.position
	for e in input_map:
		if Input.is_action_pressed(e):
			position += pan_speed * input_map[e]
	$View.position = Vector2(
		clamp(position.x, 0, world_size.x),
		clamp(position.y, 0, world_size.y))


func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		var level = null
		match event.scancode:
			KEY_BACKSPACE:
				$View.position = $Player.position
			KEY_U:
				level = $World.active_level.parent
			KEY_Z:
				level = $World.active_level.children[0]
			KEY_X:
				level = $World.active_level.children[1]
		change_level(level)


func change_level(level):
	if not level:
		return
	$World.change_level(level)
	$Player.change_level(level)
	$View.position = $Player.position
