extends Node2D


export(int) var game_seed
export(int) var pan_speed = 8
export(Vector2) var world_size = Vector2(2880, 2880)
onready var panel = $Overlay.get_node("Panel")
onready var view_size = Vector2(panel.rect_position.x, panel.rect_size.y)


func _ready():
	seed(game_seed)
	$World.position = 0.5 * (view_size - world_size)
	$World.create()


const input_map = {
	"ui_up": Vector2(0, -1),
	"ui_down": Vector2(0, 1),
	"ui_left": Vector2(-1, 0),
	"ui_right": Vector2(1, 0)
}
func _physics_process(delta):
	var position = $World.position
	for e in input_map:
		if Input.is_action_pressed(e):
			position += pan_speed * input_map[e]
	$World.position = Vector2(
		clamp(position.x, -world_size.x + view_size.x, -48),
		clamp(position.y, -world_size.y + view_size.y, -48))


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
