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


var rng = RandomNumberGenerator.new()
# This the "official" refrence to the player object, the Node is a sibling
# to make render order easier
var player = null
var active_level = null
var combat_turn = 0
var turn = 1
var target = 0


func _ready():
	upper_panel.current_tab = MAP


# TODO: need to instantiate Level 1 on demand so that starting anew works
# warning-ignore:shadowed_variable
func create(player):
	self.player = player
	world_seed = randi()
	rng.seed = world_seed
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


static func first_capital(string):
	return string.substr(0, 1).capitalize() + string.substr(1)


func report_death(display_name, is_player):
	var past = "have" if is_player else "has"
	show_info("%s %s been deactivated!" % [first_capital(display_name), past], true)


func report_attack(attacker, defender, attackers, defenders):
	combat_turn = turn
	var a_name = first_capital("you" if attacker.is_player else ("the " + attacker.stats.type_name))
	var d_name = "you" if defender.is_player else ("the " + defender.stats.type_name)
	var weapon = attacker.weapons.get_weapon_name()
	var with = " with a " + weapon
	var attack = "shoot"
	var damages = PoolStringArray()
	for stat in defenders:
		var delta = defenders[stat] - defender.stats.stats[stat]
		if delta:
			damages.append("\t%s: %d" % [stat, round(delta)])
	if not len(damages):
		damages.append("\tnone")
	if attackers:
		damages.append("\nDamage received:")
		var count = 0
		for stat in attackers:
			var delta = attackers[stat] - attacker.stats.stats[stat]
			if delta:
				damages.append("\t%s: %d", round(delta))
				count += 1
		if not count:
			damages.append("\tnone")
	if attacker.weapons.get_range() == 1:
		if attacker.combat >= Robot.WEAPON:
			attack = "attack"
		else:
			attack = weapon
			with = ""
	if defender.is_player:
		attack += "s"
	var text = """%s %s %s%s!

Damage inflicted:
%s
""" % [first_capital(a_name), attack, d_name, with, damages.join("\n")]
	show_info(text)
	if defender.check_stats():
		report_death(first_capital(d_name), defender.is_player)
	if attacker.check_stats():
		report_death(a_name, attacker.is_player)


func check_end():
	show_info("""Level %s has been cleared""" % active_level.map_name)
	if not level_one.is_clear():
		return
	target = turn + 25 * world_depth
	level_one.lifts[0].unlock()
	show_info("""All the levels have now been cleared.

Make your way to the surface before the systems reboot in on turn %d.""" % target, true)
