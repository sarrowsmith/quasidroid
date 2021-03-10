extends Node2D


export(int) var game_seed
export(int) var pan_speed = 8
export(Vector2) var half_view = Vector2(640, 360)

onready var world_size = $World.world_size

var turn = 1


func _ready():
	show_dialog($Start)


func show_dialog(dialog):
	$World.set_visible(false)
	view_to(half_view)
	dialog.popup_centered()


func new():
	$Start.set_visible(false)
	$World.set_visible(true)
	seed(game_seed)
	change_level($World.create($Player))
	$World.set_value("Turn", 1, true)
	$Player.turn()


const view_map = {
	ui_up = Vector2(0, -1),
	ui_down = Vector2(0, 1),
	ui_left = Vector2(-1, 0),
	ui_right = Vector2(1, 0)
}
# warning-ignore:unused_argument
func _process(delta):
	var position = $View.position
	for e in view_map:
		if Input.is_action_pressed(e):
			position += pan_speed * view_map[e]
	view_to(position)
	if turn % 2:
		if $Player.state == Robot.DONE:
			turn += 1
			for r in $World.active_level.rogues:
				if r.state != Robot.DEAD:
					r.turn()
	else:
		for r in $World.active_level.rogues:
			if r.state == Robot.IDLE or r.state == Robot.WAIT:
				return
		$Player.turn()
		turn += 1
		$World.set_value("Turn", (turn + 1) / 2, true)


const cursor_map = {
	cursor_up = Vector2(0, -1),
	cursor_down = Vector2(0, 1),
	cursor_left = Vector2(-1, 0),
	cursor_right = Vector2(1, 0)
}
func _unhandled_input(event):
	var move = Vector2.ZERO
	for e in cursor_map:
		if event.is_action_pressed(e, true):
			move += cursor_map[e]
	if move != Vector2.ZERO:
		$World.active_level.move_cursor(move)
	if event.is_action_pressed("map_reset"):
		view_to($Player.position)
		return
	if event.is_action_pressed("cursor_reset"):
		$World.active_level.set_cursor($Player.location)
		return
	if event is InputEventKey and event.pressed:
		var level = null
		if event.control:
			match event.scancode:
				KEY_S:
					_on_Save_pressed()
				KEY_R:
					_on_Restart_pressed()
				KEY_Q:
					_on_Quit_pressed()
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


# warning-ignore:shadowed_variable
func load_game(game_seed):
	self.game_seed = game_seed
	new()


func save_game():
	pass


func _on_Resume_pressed():
	load_game(game_seed)


func _on_New_pressed():
	new()


func _on_Random_pressed():
	pass # Replace with function body.


func _on_Save_pressed():
	save_game()


func _on_Restart_pressed():
	save_game()
	show_dialog($Start)


func _on_Quit_pressed():
	show_dialog($Quit)


func _on_Quit_confirmed():
	get_tree().quit()


func _on_Quit_popup_hide():
	view_to($Player.position)
	$World.set_visible(true)
