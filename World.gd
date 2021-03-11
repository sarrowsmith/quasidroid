extends Node2D


export(int) var world_seed
export(Vector2) var world_size = Vector2(1440, 1440)
export(int) var world_depth = 7
export(NodePath) var upper_panel_path
export(NodePath) var lower_panel_path
export(NodePath) var player_status_path
export(NodePath) var rogue_status_path

enum {INFO, STATUS, LEVELS, MAP}

onready var upper_panel = get_node(upper_panel_path)
onready var lower_panel = get_node(lower_panel_path)
onready var player_status_box = get_node(player_status_path)
onready var rogue_status_box = get_node(rogue_status_path)
onready var level_one = $Level


# This the "official" refrence to the player object, the Node is a sibling
# to make render order easier
var player = null
var active_level = null


func _ready():
	upper_panel.current_tab = MAP


# TODO: need to instantiate Level 1 on demand so that starting anew works
# warning-ignore:shadowed_variable
func create(player):
	self.player = player
	world_seed = randi()
	level_one.create(null, true)
	change_level(level_one)
	return active_level


func change_level(level):
	if active_level:
		active_level.set_visible(false)
	level.generate()
	active_level = level


func set_value(name, value, is_player):
	var lv = (player_status_box if is_player else rogue_status_box).get_node(name)
	if lv:
		lv.set_value(value)


func show_info(text, append=false):
	var info_box = lower_panel.get_tab_control(INFO)
	if append:
		var new_text = "%s\n%s" % [info_box.text, text]
		info_box.text = new_text
	else:
		info_box.text = text
	lower_panel.current_tab = INFO


func show_stats(is_player):
	var p = (upper_panel if is_player else lower_panel)
	p.current_tab = STATUS
