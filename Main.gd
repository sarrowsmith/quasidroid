extends Node2D


export(int) var game_seed = 0
export(int) var pan_speed = 8
export(Vector2) var half_view = Vector2(640, 360)

onready var player = $Player
onready var world = $World
onready var world_size = $World.world_size

var turn = 1
var target = 0


func _ready():
	if game_seed:
		$Start.find_node("Seed").text = String(game_seed)
	show_dialog($Start)


func show_dialog(dialog):
	world.set_visible(false)
	view_to(half_view, 0)
	dialog.popup_centered()


# TODO: need to instantiate Player here, taking care with render order
func new(depth=0):
	$Start.set_visible(false)
	world.set_visible(true)
	if depth:
		world.world_depth = depth
	seed(game_seed)
	$View.find_node("Seed").set_value(game_seed)
	change_level(world.create(player))
	world.set_value("Turn", 1, true)
	player.turn()
	world.upper_panel.current_tab = world.LEVELS
	world.lower_panel.current_tab = world.LEVELS


const view_map = {
	ui_up = Vector2(0, -1),
	ui_down = Vector2(0, 1),
	ui_left = Vector2(-1, 0),
	ui_right = Vector2(1, 0)
}
# warning-ignore:unused_argument
func _process(_delta):
	var position = $View.position
	for e in view_map:
		if Input.is_action_pressed(e):
			position += pan_speed * view_map[e]
	view_to(position, 0)
	if turn % 2:
		if player.state == Robot.DONE:
			turn += 1
			var dead = 0
			for r in world.active_level.rogues:
				if r.state == Robot.DEAD:
					dead += 1
				else:
					r.turn()
			if dead == len(world.active_level.rogues):
				if world.active_level.state != Level.CLEAR:
					world.active_level.state = Level.CLEAR
					check_end()
	else:
		for r in world.active_level.rogues:
			if r.state == Robot.IDLE or r.state == Robot.WAIT:
				return
		player.turn()
		turn += 1
		world.set_value("Turn", (turn + 1) / 2, true)


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
		world.active_level.move_cursor(move)
	if event.is_action_pressed("map_reset"):
		view_to(player.position)
		return
	if event.is_action_pressed("cursor_reset"):
		world.active_level.set_cursor(player.location)
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
				level = world.active_level.parent
			KEY_O:
				level = world.active_level.children[0]
			KEY_P:
				level = world.active_level.children[1]
		if level:
			change_level(level)


func change_level(level):
	if not level:
		if world.level_one.is_clear():
			game_over()
	if level != world.active_level:
		world.change_level(level)
	player.change_level(level)
	view_to(player.position)


func view_to(position, offset=180):
	$View.position = Vector2(
		clamp(position.x + offset, 0, world_size.x),
		clamp(position.y, 0, world_size.y))


func load_game():
	new()


func save_game():
	pass


func check_end():
	world.set_info("""Level %s has been cleared""" % world.active_level.map_name)
	if not world.level_one.is_clear():
		return
	target = turn + 25 * world.world_depth
	world.level_one.lifts[0].unlock()
	world.set_info("""All the levels have now been cleared.

Make your way to the surface before the systems reboot in on turn %d.""" % target, true)


func game_over():
	# TODO: something better than this
	_on_Restart_pressed()


func _on_Resume_pressed():
	load_game()


func _on_New_pressed():
	var seed_text = $Start.find_node("Seed").text
	game_seed = seed_text.to_int() if seed_text.is_valid_integer() else seed_text.hash()
	var depth = $Start.find_node("Depth").value
	new(depth)


func _on_Random_pressed():
	randomize()
	$Start.find_node("Seed").text = String(randi())


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
	view_to(player.position)
	world.set_visible(true)
