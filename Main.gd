extends Node2D


export(int) var game_seed
export(int) var pan_speed = 8

onready var world_size = $World.world_size

var turn = 1


func _ready():
	seed(game_seed)
	change_level($World.create($Player))
	$World.set_value("Turn", 1, true)


const view_map = {
	"ui_up": Vector2(0, -1),
	"ui_down": Vector2(0, 1),
	"ui_left": Vector2(-1, 0),
	"ui_right": Vector2(1, 0)
}
# warning-ignore:unused_argument
func _process(delta):
	var position = $View.position
	for e in view_map:
		if Input.is_action_pressed(e):
			position += pan_speed * view_map[e]
	view_to(position)
	if turn % 2:
		if $Player.state == Robot.State.DONE:
			turn += 1
			for r in $World.active_level.rogues:
				if r.state != Robot.State.DEAD:
					r.turn()
	else:
		for r in $World.active_level.rogues:
			if r.state == Robot.State.IDLE or r.state == Robot.State.WAIT:
				return
		$Player.turn()
		turn += 1
		$World.set_value("Turn", (turn + 1) / 2, true)


const cursor_map = {
	"cursor_up": Vector2(0, -1),
	"cursor_down": Vector2(0, 1),
	"cursor_left": Vector2(-1, 0),
	"cursor_right": Vector2(1, 0)
}
func _unhandled_input(event):
	var move = Vector2.ZERO
	for e in cursor_map:
		if InputMap.event_is_action(event, e):
			move += cursor_map[e]
	if move != Vector2.ZERO:
		$World.active_level.move_cursor(move)
	if InputMap.event_is_action(event, "map_reset"):
		view_to($Player.position)
		return
	if event is InputEventKey and event.pressed:
		var level = null
		match event.scancode:
			KEY_U:
				level = $World.active_level.parent
			KEY_O:
				level = $World.active_level.children[0]
			KEY_P:
				level = $World.active_level.children[1]
		change_level(level)


func change_level(level):
	if not level:
		return
	if level != $World.active_level:
		$World.change_level(level)
	$Player.change_level(level)
	view_to($Player.position)
	#$World.set_value("Level", level.map_name)


func view_to(position):
	$View.position = Vector2(
		clamp(position.x, 0, world_size.x),
		clamp(position.y, 0, world_size.y))
