extends Node2D


enum ViewMode {TRACK, FREE, RESET, DIALOG}
enum {WIN, LOSE}
enum {MAIN, LOOP, INTERSTITIAL, BLANK}

const success = ["Win", "Lose"]

export(String) var game_seed = ""
export(float) var pan_speed = 0.5
export(Vector2) var half_view = Vector2(960, 540)

var view_mode = ViewMode.TRACK
var save = false

onready var world = $World
onready var world_size = world.world_size
onready var saved_games = $Dialogs.find_node("SavedGames")
onready var sfx = $SFXBankPlayer
onready var music = $MainMusicBankPlayer
onready var accent = $AccentMusicBankPlayer
onready var time_delay = AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()


func _ready():
	OS.window_fullscreen = !OS.window_fullscreen
	if game_seed:
		$Dialogs.find_node("Seed").text = game_seed
	start_dialog()


func start_dialog():
	saved_games.clear()
	for game in list_games():
		saved_games.add_item(game)
	var resume = $Dialogs.find_node("ResumeButton")
	$Dialogs.find_node("NewButton").disabled = not $Dialogs.find_node("Seed").text
	show_named_dialog("Start")
	if saved_games.get_item_count():
		resume.disabled = false
		resume.grab_focus()
	else:
		resume.disabled = true


func show_named_dialog(dialog: String):
	show_dialog($Dialogs.get_node(dialog))


func show_dialog(dialog: Popup):
	music.fade(MAIN, 0.2)
	accent.fade(-1, 0.2)
	world.set_visible(false)
	$Frame.set_visible(false)
	view_to(half_view, ViewMode.DIALOG)
	dialog.popup_centered()


func hide_dialog(dialog: Popup):
	music.fade(LOOP, 0.2)
	accent.fade(0, 0.2)
	world.set_visible(true)
	$Frame.set_visible(true)
	if dialog:
		dialog.set_visible(false)
	if world.player:
		view_to(world.player.position, ViewMode.TRACK)


func new():
	game_seed = $Dialogs.find_node("Seed").text
	seed(seed_text_to_int(game_seed))
	world.world_depth = $Dialogs.find_node("Depth").value
	hide_dialog($"Dialogs/Start")
	world.log_info("[b]%s[/b]\n" % game_seed)
	world.create()
	world.level_one.create(null, true)
	change_level(world.level_one, false)
	world.turn = 1
	start()


func resume():
	if world.active_level and world.active_level.is_connected("rogues_move_end", self, "rogues_move_end"):
		world.active_level.disconnect("rogues_move_end", self, "rogues_move_end")
	game_seed = saved_games.get_item_text(saved_games.get_item_index(saved_games.get_selected_id()))
	seed(seed_text_to_int(game_seed))
	hide_dialog($"Dialogs/Start")
	load_game()
	world.active_level.connect("rogues_move_end", self, "rogues_move_end")
	view_to(world.player.position, ViewMode.TRACK)
	start()


func start():
	set_zoom(false)
	$View.find_node("Seed").set_value(game_seed)
	connect_player()
	world.set_turn(0)
	world.player.turn()
	world.player.start()
	world.player.show_stats(true)
	$Fader.interpolate_property(world, "modulate", Color(1.0, 1.0, 1.0, 0.0), Color(1.0, 1.0, 1.0, 1.0), 0.5)
	$Fader.start()
	world.level_one.lifts[0].audio.play()
	yield($Fader, "tween_all_completed")


func connect_player():
	world.player.connect("move", self, "_on_Player_move", [], CONNECT_DEFERRED)
	world.player.connect("change_level", self, "change_level", [true], CONNECT_DEFERRED)
	world.player.connect("end_move", self, "player_end_move", [], CONNECT_DEFERRED)


const view_map = {
	ui_up = Vector2(0, -1),
	ui_down = Vector2(0, 1),
	ui_left = Vector2(-1, 0),
	ui_right = Vector2(1, 0)
}
# warning-ignore:unused_argument
func _process(_delta):
	if not world.active_level:
		return
	var view_position = $View.position
	var player_position = world.player.position
	if view_mode == ViewMode.RESET:
		var gap = view_position.distance_squared_to(world.player.position)
		if (gap < 16):
			view_position = world.player.position
			view_mode = ViewMode.TRACK
		else:
			var delta = pan_speed
			if gap > half_view.y * half_view.y:
				delta *= 8
			view_position = view_position.move_toward(world.player.position, delta)
	else:
		for e in view_map:
			if Input.is_action_pressed(e):
				view_mode = ViewMode.FREE
				view_position += pan_speed * view_map[e]
		if view_mode == ViewMode.TRACK:
			view_position = player_position
	view_to(view_position, view_mode)
	if world.target and world.turn > world.target:
		timed_out()


const cursor_map = {
	cursor_up = Vector2(0, -1),
	cursor_down = Vector2(0, 1),
	cursor_left = Vector2(-1, 0),
	cursor_right = Vector2(1, 0)
}
func _unhandled_input(event: InputEvent):
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
			KEY_F:
				OS.window_fullscreen = !OS.window_fullscreen
			KEY_U:
				level = world.active_level.parent
			KEY_O:
				level = world.active_level.children[0]
			KEY_P:
				level = world.active_level.children[1]
		if level and world.player.get_state() == Robot.IDLE:
			change_level(level, false)
	if world.active_level == null:
		return
	var move = Vector2.ZERO
	for e in cursor_map:
		if event.is_action_pressed(e, true):
			move += cursor_map[e]
	if move != Vector2.ZERO:
		world.active_level.move_cursor(move)
	if event.is_action_pressed("map_zoom"):
		set_zoom(!world.zoomed)
	if event.is_action_pressed("map_reset"):
		if world.zoomed:
			set_zoom(true)
		else:
			view_mode = ViewMode.RESET
		return
	if event.is_action_pressed("cursor_reset"):
		var view_position = $View.position
		var view_location = world.active_level.position_to_location(view_position)
		world.active_level.set_cursor(view_location + Vector2.ONE)
		return
	if view_mode == ViewMode.DIALOG and event.is_action_pressed("ui_cancel"):
		for popup in $Dialogs.get_children():
			if popup.visible:
				hide_dialog(popup)
				break


func player_end_move(player):
	if save:
		save_game()
	if player.get_state() != Robot.DONE:
		return
	world.set_turn(1)
	world.set_value("Moves", 0, true)
	world.active_level.await_rogues()
	var dead = 0
	for r in world.active_level.rogues:
		if not r.turn():
			dead += 1
	if dead == len(world.active_level.rogues):
		if not world.active_level.state & Level.CLEAR:
			world.active_level.state |= Level.CLEAR
			world.update_minimap()
			world.check_end()


func rogues_move_end():
	if world.player.turn():
		world.player.start()
		world.set_turn(1)
		if save:
			save_game()


func change_level(level: Level, fade: bool):
	if not level:
		if world.level_one.is_clear():
			game_over(WIN)
		return
	if level == world.player.level:
		# Player resignals when finished arrival animation
		world.player.end_move(true, true)
		return
	if level != world.active_level:
		if fade:
			$Fader.interpolate_property(world, "modulate", Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0), 0.5)
			$Fader.start()
			music.fade(-1, 0.2)
			accent.fade(-1, 0.2)
		if world.active_level and world.active_level.is_connected("rogues_move_end", self, "rogues_move_end"):
			world.active_level.disconnect("rogues_move_end", self, "rogues_move_end")
		world.change_level(level)
		world.active_level.connect("rogues_move_end", self, "rogues_move_end")
		if fade:
			yield($Fader, "tween_all_completed")
	world.player.change_level(level, fade)
	set_zoom(world.zoomed)
	if fade:
		$Fader.interpolate_property(world, "modulate", Color(1.0, 1.0, 1.0, 0.0), Color(1.0, 1.0, 1.0, 1.0), 0.5)
		$Fader.start()
		music.fade(LOOP, 0.5)
		accent.fade(BLANK, 0.5)
		yield($Fader, "tween_all_completed")


func view_to(view_position: Vector2, mode):
	var offset = 48 if mode == ViewMode.TRACK else 0
	$View.position = Vector2(
		clamp(view_position.x + offset, 0, world_size.x + 0.5 * half_view.x),
		clamp(view_position.y + offset, 0, world_size.y + 0.5 * half_view.y))
	view_mode = mode


func set_zoom(out: bool):
	world.zoomed = out
	var scale = Vector2.ONE / (3.0 if out else 1.0)
	world.scale = scale
	$Frame.scale = scale
	if out:
		view_to(world.world_size / 6.0, ViewMode.FREE)
	else:
		view_to(world.player.position, ViewMode.TRACK)


func list_games() -> Array:
	var dir = Directory.new()
	if dir.open("user://"):
		return []
	var file = File.new()
	var games = []
	var latest = 0
	dir.list_dir_begin(true, true)
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "save":
			var game_name = file_name.get_basename()
			var current = file.get_modified_time("user://"+file_name)
			if current > latest:
				games.insert(0, game_name)
				latest = current
			else:
				games.append(game_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return games


func save_name() -> String:
	var save_name = game_seed
	if not save_name.is_valid_filename():
		save_name = save_name.hash()
	return "user://%s.save" % save_name


func load_game():
	var save_game = File.new()
	if save_game.open(save_name(), File.READ) == OK:
		game_seed = world.load(save_game)
		save_game.close()


func save_game():
	var save_game = File.new()
	if save_game.open(save_name(), File.WRITE) == OK:
		save = false
		world.save(save_game, game_seed)
		save_game.close()


func game_over(how: int, title=""):
	music.fade(-1, 1.0)
	accent.fade(-1, 1.0)
	if how == LOSE:
		$Fader.interpolate_property(world, "modulate", Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.25), 4.0)
		$Fader.start()
		yield($Fader, "tween_all_completed")
		if world.player.audio.playing:
			yield(world.player.audio, "finished")
		$Fader.interpolate_property(world, "modulate", Color(1.0, 1.0, 1.0, 0.25), Color(1.0, 1.0, 1.0, 0.0), 1.0)
	else:
		$Fader.interpolate_property(world, "modulate", Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0), 1.0)
	$Fader.start()
	sfx.play_from_bank(how)
	yield($Fader, "tween_all_completed")
	var popup = $Dialogs.get_node(success[how])
	if title:
		popup.window_title = title
	var messages = PoolStringArray()
	match how:
		WIN:
			messages.append("You succeeded!\n")
		LOSE:
			messages.append("You failed\n")
	var stats = gather_stats()
	for stat in stats:
		messages.append("%s: %s" % [stat, stats[stat]])
	messages.append("\n")
	popup.dialog_text = messages.join("\n")
	show_dialog(popup)


func gather_stats() -> Dictionary:
	var game_stats = {
		"levels opened": 0,
		"levels reset": 0,
		"levels cleared": 0,
		"rogues deactivated": 0,
	}
	var level_stats = world.level_one.gather_stats()
	for level in level_stats:
		for stat in game_stats:
			game_stats[stat] += level_stats[level][stat]
	return game_stats


func timed_out():
	world.show_info("""Turn %d

Systems rebooting ...

All robots in the facility will be wiped.
""" % ((world.turn + 1) / 2))
	game_over(LOSE, "Facility systems reboot!")


# Generate a seed text of the form CVCVC CVCV which can be directly
# converted to a 32-bit int by seed_text_to_int
const vowels = "aeiouyäö"
const consonants = "bdfghklmnprstvwz"
func create_seed_text() -> String:
	var seed_text = "          "
	for i in 10:
		if i == 5:
			continue
		var letters = vowels if i % 2 else consonants
		seed_text[i] = letters[randi() % len(letters)]
	return seed_text.capitalize()


func seed_text_to_int(seed_text: String) -> int:
	if seed_text.is_valid_integer():
		return seed_text.to_int()
	if len(seed_text) == 10 and seed_text[5] == " ":
		var as_int = 0
		var count = 0
		for pair in seed_text.to_lower().bigrams():
			var c = consonants.find(pair[0])
			if c == -1:
				break
			as_int = (as_int << 4) | c
			if c != 2:
				var v = vowels.find(pair[1])
				if v == -1:
					break
				as_int = (as_int << 3) | v
			count += 1
		if count == 6:
			return as_int
	return seed_text.hash()


func _on_Player_move(alive):
	set_zoom(false)
	if alive:
		if view_mode == ViewMode.FREE:
			view_mode = ViewMode.RESET
	else:
		game_over(LOSE, "You have been deactivated!")


func _on_Resume_pressed():
	resume()


func _on_New_pressed():
	new()


func _on_Random_pressed():
	randomize()
	var seed_text = create_seed_text()
	$Dialogs.find_node("Seed").text = seed_text
	_on_Seed_text_changed(seed_text)


func _on_Save_pressed():
	if world.player.get_state() == Robot.IDLE:
		save_game()
	else:
		save = true


func _on_Restart_pressed():
	start_dialog()


func _on_Quit_pressed():
	show_named_dialog("Quit")


func _on_Quit_confirmed():
	get_tree().quit()


func _on_Quit_popup_hide():
	hide_dialog(null)


func _on_game_over(success):
	$Dialogs.get_node(success).set_visible(false)
	start_dialog()


func _on_Fullscreen_toggled(button_pressed):
	OS.window_fullscreen = button_pressed


func _on_Game_Stats_pressed():
	world.show_game_stats(game_seed)


func _on_Seed_text_changed(new_text):
	$Dialogs.find_node("NewButton").disabled = new_text.empty()


func _on_MainMusicBankPlayer_finished():
	match music.last_played:
		MAIN:
			pass # imported as a loop
		LOOP:
			music.play_from_bank(INTERSTITIAL if accent.last_played < 0 or randf() < 0.5 else BLANK, time_delay)
		INTERSTITIAL:
			music.play_from_bank(LOOP if accent.last_played < 0 or randf() < 0.5 else BLANK, time_delay)
		BLANK:
			music.play_from_bank(LOOP if randf() < 0.5 else INTERSTITIAL, time_delay)


func _on_AccentMusicBankPlayer_finished():
	accent.play_random(time_delay)


func _on_Effects_toggled(button_pressed):
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not button_pressed)


func _on_Music_toggled(button_pressed):
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not button_pressed)
