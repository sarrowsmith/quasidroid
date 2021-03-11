extends Node2D


export(int) var world_seed
export(Vector2) var world_size = Vector2(1440, 1440)
export(NodePath) var player_status_path
export(NodePath) var rogue_status_path
export(NodePath) var info_path

onready var player_status_box = get_node(player_status_path)
onready var rogue_status_box = get_node(rogue_status_path)
onready var info_box = get_node(info_path)
onready var active_level = $Level


# This the "official" refrence to the player object, the Node is a sibling
# to make render order easier
var player = null


# TODO: need to instantiate Level 1 on demand so that starting anew works
# warning-ignore:shadowed_variable
func create(player):
	self.player = player
	world_seed = randi()
	active_level.create(null, true)
	change_level(active_level)
	return active_level


func change_level(level):
	active_level.set_visible(false)
	level.generate()
	active_level = level


func set_value(name, value, is_player):
	var lv = (player_status_box if is_player else rogue_status_box).get_node(name)
	if lv:
		lv.set_value(value)


func show_position():
	rogue_status_box.get_node("Position").set_value(active_level.cursor.location)
	# set other items invisible
	show_stats(false)


func show_info(text):
	info_box.text = text
	rogue_status_box.find_parent("*").current_tab = 0


func show_stats(is_player):
	var status_box = player_status_box if is_player else rogue_status_box
	status_box.find_parent("*").current_tab = 1
