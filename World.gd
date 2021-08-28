extends Node2D


export(int) var world_seed
export(Vector2) var world_size = Vector2(2880, 2880)
export(int) var world_depth = 7
export(NodePath) var upper_panel_path
export(NodePath) var lower_panel_path
export(NodePath) var player_status_path
export(NodePath) var rogue_status_path
export(NodePath) var log_path
export(NodePath) var map_panel_path
export(int) var map_scale = 10


enum {INFO, STATUS, HELP}

const Level_prototype = preload("res://levels/Level.tscn")
const Player_prototype = preload("res://robots/Player.tscn")

onready var upper_panel = get_node(upper_panel_path)
onready var lower_panel = get_node(lower_panel_path)
onready var player_status_box = get_node(player_status_path)
onready var rogue_status_box = get_node(rogue_status_path)
onready var log_box = get_node(log_path)
onready var map_label = get_node(map_panel_path).find_node("MapLabel")
onready var map_control = get_node(map_panel_path).find_node("MapImage")
onready var level_map = map_control.get_node("LevelMap")
onready var level_fog = map_control.get_node("LevelFog")
onready var info_box = lower_panel.get_tab_control(INFO)
onready var weapon_options = upper_panel.get_tab_control(INFO).find_node("Weapon")


var rng = RandomNumberGenerator.new()
# This the "official" refrence to the player object, the Node is a sibling
# to make render order easier
var player: Player = null
var level_one: Level = null
var active_level: Level = null
var turn = 1
var target = 0
var zoomed = false
var last_rogue: Robot = null


func _ready():
	upper_panel.current_tab = HELP
	lower_panel.current_tab = HELP
	var menu = weapon_options.get_popup()
	menu.connect("index_pressed", self, "_on_Weapon_selected")
	menu.show_on_top = true
	level_fog.scale *= map_scale
	level_map.scale *= map_scale


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
	update_minimap()


func set_value(name: String, value, is_player: bool):
	var lv = (player_status_box if is_player else rogue_status_box).get_node(name)
	if lv:
		lv.set_value(value)


func set_weapon():
	set_value("weapons", player.weapons.get_weapon_name(), true)
	var menu = weapon_options.get_popup()
	menu.clear()
	for weapon in player.stats.equipment.weapons:
		menu.add_radio_check_item(player.weapons.get_weapon_name(weapon))
	menu.set_item_checked(player.combat, true)


func set_turn(inc: int):
	turn += inc
	var display_turn = (turn + 1) / 2
	set_value("Turn", display_turn , true)
	if turn % 2:
		log_info("\n[i]Turn %d[/i]" % display_turn)
	update_minimap()


func log_info(text: String):
	log_box.bbcode_text += text + "\n"


func show_info(text: String, optional=false):
	info_box.bbcode_text = text
	if not optional:
		lower_panel.current_tab = INFO


func show_stats(is_player: bool):
	var p = (upper_panel if is_player else lower_panel)
	p.current_tab = STATUS


static func first_capital(string: String) -> String:
	return string.substr(0, 1).to_upper() + string.substr(1)


func display_name(robot: Robot) -> String:
	if robot.is_player:
		return "You"
	var article = "The " if robot == last_rogue else "A "
	return article +  robot.stats.type_name


func report_deactivated(robot: Robot):
	var past = "have" if robot.is_player else "has"
	log_info("[b]%s %s been deactivated![/b]" % [display_name(robot), past])


func report_disabled(robot: Robot):
	var verb = "are" if robot.is_player else "is"
	log_info("[b]%s %s disabled.[/b]" % [display_name(robot), verb])


func report_damaged(robot: Robot, component: String):
	var possessive = "have" if robot.is_player else "has"
	log_info("%s %s a damaged %s." % [display_name(robot), possessive, component])


func report_attack(attacker: Robot, defender: Robot, attackers: Dictionary, defenders: Dictionary, damages: Array):
	last_rogue = defender if attacker.is_player else attacker
	var a_name = first_capital("you" if attacker.is_player else ("the " + attacker.stats.type_name))
	var d_name = "you" if defender.is_player else ("the " + defender.stats.type_name)
	var weapon = attacker.weapons.get_weapon_name()
	var with = " with a%s %s" % ["n" if ".iE".find(weapon[0]) > 0 else "", weapon]
	var attack = "shoot"
	var report = PoolStringArray()
	for stat in defenders:
		var delta = defenders[stat] - defender.stats.stats[stat]
		if delta:
			report.append("\t%s: [b][i]%d[/i][/b]" % [stat, round(delta)])
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
				report.append("\t%s: [b][i]%d[/i][/b]" % [stat, round(delta)])
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
	var text = """%s %s %s%s!

Damage inflicted:
%s
""" % [first_capital(a_name), attack, d_name, with, report.join("\n")]
	log_info(text)
	if defender.check_stats():
		report_deactivated(defender)
	elif defender.stats.stats.speed == 0:
		report_disabled(defender)
	if attacker.check_stats():
		report_deactivated(attacker)
	elif attacker.stats.stats.speed == 0:
		report_disabled(attacker)


const state_colours = [
	"#ff8080",
	"#ff8080",
	"#ffff00",
	"#ffff00",
	"#80ff80",
	"#80ff80",
	"#80ff80",
	"#80ff80",
]
const stat_map = {
	"levels opened": Level.OPEN,
	"levels reset": Level.RESET,
	"levels cleared": Level.CLEAR,
}
func show_game_stats(game_seed: String):
	var messages = PoolStringArray()
	messages.append("[b]%s[/b]" % game_seed)
	var stats = {
		# I don't know why these can't be PoolStringArrays, but if they are
		# then the append() call doesn't stick.
		"levels opened": [],
		"levels reset": [],
		"levels cleared": [],
		"rogues deactivated": 0,
	}
	var all_stats = level_one.gather_stats()
	var level_name = active_level.map_name
	var active_stats = all_stats[level_name]
	var display_status = ""
	for status in ["cleared", "reset", "opened"]:
		var key = "levels " + status
		if active_stats[key] > 0:
			display_status = " [color=%s]%s[/color]" % [state_colours[stat_map[key]], status]
			break
	messages.append("Level %s:%s\n" % [level_name, display_status])
	for level in all_stats:
		var level_stats = all_stats[level]
		for k in stats:
			match k:
				"rogues deactivated":
					stats[k] += level_stats[k]
				_:
					if level_stats[k]:
						stats[k].append(level)
	for k in stats:
		match k:
			"rogues deactivated":
				messages.append("Rogues deactivated: [b]%d[/b]" % stats["rogues deactivated"])
			_:
				messages.append("[color=%s]%s[/color]: [b]%s[/b]" % [state_colours[stat_map[k]], k.capitalize(), PoolStringArray(stats[k]).join(", ")])
	show_info(messages.join("\n"))


func check_end():
	log_info("""[b]Level %s has been cleared[/b]""" % active_level.map_name)
	if not level_one.is_clear():
		return
	target = turn + 75 * world_depth
	level_one.lifts[0].unlock()
	log_info("""All the levels have now been cleared.

[b]Make your way to the surface before the systems reboot on turn %d.[/b]""" % target)


func update_minimap():
	map_label.bbcode_text = "[color=%s]Level %s[/color]" % [state_colours[active_level.state], active_level.map_name]
	active_level.update_level_map(player.location)
	level_map.texture.create_from_image(active_level.map_image, 0)
	level_fog.texture.create_from_image(active_level.fog_image, 0)


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
	log_box.bbcode_text = file.get_pascal_string()
	active_level.set_visible(true)
	update_minimap()
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
	file.store_pascal_string(log_box.bbcode_text)


func _on_Weapon_selected(idx):
	player.combat = idx
	player.equip()


func _on_Weapon_about_to_show():
	var menu = weapon_options.get_popup()
	menu.light_mask = 2
	menu.set_global_position(player.position + Vector2.RIGHT * 96)
