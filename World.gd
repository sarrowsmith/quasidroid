extends Node2D


export(int) var world_seed
export(Vector2) var world_size = Vector2(2880, 2880)
export(int) var world_depth = 7
export(NodePath) var upper_panel_path
export(NodePath) var lower_panel_path
export(NodePath) var player_status_path
export(NodePath) var rogue_status_path
export(NodePath) var log_path


enum {INFO, STATUS, ABOUT, MAP}

var Level_prototype = preload("res://levels/Level.tscn")
var Player_prototype = preload("res://robots/Player.tscn")

onready var upper_panel = get_node(upper_panel_path)
onready var lower_panel = get_node(lower_panel_path)
onready var player_status_box = get_node(player_status_path)
onready var rogue_status_box = get_node(rogue_status_path)
onready var log_box = get_node(log_path)


var rng = RandomNumberGenerator.new()
# This the "official" refrence to the player object, the Node is a sibling
# to make render order easier
var player: Player = null
var level_one: Level = null
var active_level: Level = null
var turn = 1
var target = 0


func _ready():
	upper_panel.current_tab = ABOUT
	lower_panel.current_tab = ABOUT


# warning-ignore:shadowed_variable
func create():
	if player:
		remove_child(player)
		player.queue_free()
	for existing_level in get_children():
		remove_child(existing_level)
		existing_level.queue_free()
	player = Player_prototype.instance()
	add_child(player)
	world_seed = randi()
	rng.seed = world_seed
	level_one = Level_prototype.instance()
	add_child(level_one)


func change_level(level: Level):
	if active_level:
		active_level.set_visible(false)
	level.generate()
	active_level = level


func set_value(name: String, value, is_player: bool):
	var lv = (player_status_box if is_player else rogue_status_box).get_node(name)
	if lv:
		lv.set_value(value)


func set_turn(inc: int):
	turn += inc
	set_value("Turn", (turn + 1) / 2, true)


func log_info(text: String):
	log_box.text += text + "\n"


func show_info(text: String):
	var info_box = lower_panel.get_tab_control(INFO)
	info_box.text = text
	lower_panel.current_tab = INFO


func show_stats(is_player: bool):
	var p = (upper_panel if is_player else lower_panel)
	p.current_tab = STATUS


static func first_capital(string: String) -> String:
	return string.substr(0, 1).to_upper() + string.substr(1)


func report_state(display_name: String, is_player: bool, state: String):
	var past = "have" if is_player else "has"
	log_info("%s %s been %sd!" % [first_capital(display_name), past, state])


func report_attack(attacker: Robot, defender: Robot, attackers: Dictionary, defenders: Dictionary, damages: Array):
	var a_name = first_capital("you" if attacker.is_player else ("the " + attacker.stats.type_name))
	var d_name = "you" if defender.is_player else ("the " + defender.stats.type_name)
	var weapon = attacker.weapons.get_weapon_name()
	var with = " with a " + weapon
	var attack = "shoot"
	var report = PoolStringArray()
	var preamble = "Turn %d" % ((turn + 1) / 2)
	for stat in defenders:
		var delta = defenders[stat] - defender.stats.stats[stat]
		if delta:
			report.append("\t%s: %d" % [stat, round(delta)])
	for damage in damages:
		report.append("\t"+damage)
	if not len(report):
		report.append("\tnone")
	if attackers:
		report.append("\nDamage received:")
		var count = 0
		for stat in attackers:
			var delta = attackers[stat] - attacker.stats.stats[stat]
			if delta:
				report.append("\t%s: %d" % [stat, round(delta)])
				count += 1
		if not count:
			report.append("\tnone")
	if attacker.weapons.get_range() == 1:
		if attacker.combat >= Robot.WEAPON:
			attack = "attack"
		else:
			attack = weapon
			with = ""
	if defender.is_player:
		attack += "s"
	var text = """%s
%s %s %s%s!

Damage inflicted:
%s
""" % [preamble, first_capital(a_name), attack, d_name, with, report.join("\n")]
	log_info(text)
	if defender.check_stats():
		report_state(first_capital(d_name), defender.is_player, "deactivate")
	elif defender.stats.stats.speed == 0:
		report_state(first_capital(d_name), defender.is_player, "disable")
	if attacker.check_stats():
		report_state(a_name, attacker.is_player, "deactivate")
	elif attacker.stats.stats.speed == 0:
		report_state(a_name, attacker.is_player, "disable")


func check_end():
	log_info("""Level %s has been cleared""" % active_level.map_name)
	if not level_one.is_clear():
		return
	target = turn + 75 * world_depth
	level_one.lifts[0].unlock()
	log_info("""All the levels have now been cleared.

Make your way to the surface before the systems reboot in on turn %d.""" % target)


func load(file: File) -> String:
	world_depth = file.get_32()
	var game_seed = file.get_pascal_string()
	world_seed = file.get_64()
	turn = file.get_32()
	target = file.get_32()
	var level_name = file.get_pascal_string()
	create()
	level_one.load(file)
	active_level = level_one.find_level(level_name)
	player.level = active_level
	player.load(file)
	log_box.text = file.get_as_text()
	active_level.set_visible(true)
	return game_seed


func save(file: File, game_seed: String):
	file.store_32(world_depth)
	file.store_pascal_string(game_seed)
	file.store_64(world_seed)
	file.store_32(turn)
	file.store_32(target)
	file.store_pascal_string(active_level.map_name)
	level_one.save(file)
	player.save(file)
	file.store_string(log_box.text)
