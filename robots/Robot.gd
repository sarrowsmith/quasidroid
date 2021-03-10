class_name Robot
extends Node2D


enum {DEAD, IDLE, WAIT, DONE}

var location = Vector2.ZERO
var level = null
var base = "2"
var mode = "Idle"
var firing = "Idle"
var facing = Vector2.DOWN
var destination = Vector2.ZERO
var sprite = null
var weapon = null
var fire = Vector2.ZERO
var equipment = {
	weapon = null,
	extras = [],
}
var stats = {
	speed = 1,
	weapon = 12,
	sight = 12,
}
var moves = 0
var state = DEAD


func _process(_delta):
	if level == null:
		return
	if mode == "Move":
		position += facing
		if position == level.location_to_position(destination):
			location = destination
			mode = "Idle"
			set_sprite()
			if not moves:
				state = DONE
			level.set_cursor()
			return
	if firing == "Fire":
		weapon.position += facing
		var target = level.position_to_location(weapon.global_position)
		if level.position_to_location(weapon.position) == fire:
			return
		fire = target
		match level.location_type(fire):
			Level.FLOOR:
				if position.distance_squared_to(weapon.position) > stats["weapon"] * stats["weapon"]:
					return
		firing = "Idle"
		weapon.position = position
		fire = location
		equip(true)
		if not moves:
			state = DONE


func turn():
	state = IDLE
	moves = stats["speed"]


const facing_map = {
	Vector2.DOWN: "Down",
	Vector2.UP: "Up",
	Vector2.LEFT: "Left",
	Vector2.RIGHT: "Right",
}
func set_sprite():
	if sprite:
		sprite.set_visible(false)
	if weapon:
		weapon.set_visible(false)
	var dead = state == DEAD
	var path = "Robot/Dead" if dead else base
	if equipment.extras:
		path += "-X"
	if not dead:
		path = "Robot/%s/%s/%s" % [path, mode, facing_map[facing]]
	sprite = get_node(path)
	sprite.set_visible(true)
	if dead or equipment["weapon"] == null:
		if weapon:
			weapon.set_visible(false)
			weapon = null
		return
	weapon = get_node("Weapons/%s/%s/%s" % [equipment["weapon"], firing, facing_map[facing]])


func equip(on):
	set_sprite()
	if weapon:
		weapon.set_visible(on)


func set_location(destination):
	self.destination = destination
	location = destination
	position = level.location_to_position(location)


func move(direction):
	facing = direction
	var target = location + direction
	match level.location_type(target):
		Level.FLOOR, Level.ACCESS:
			var debug = position
			mode = "Move"
			state = WAIT
			moves -= 1
			destination = target
	set_sprite()


func fire(direction):
	facing = direction
	firing = "Fire"
	fire = location + direction
	weapon.position = level.location_to_position(fire)
	state = WAIT
	moves -= 1
	equip(true)


func item_to_string(item):
	if equipment[item]:
		return equipment[item]
	return "none"


func show_stats(visible=false):
	if not level:
		return
	var is_player = self == level.world.player
	for stat in stats:
		level.world.set_value(stat, stats[stat], is_player)
	for item in equipment:
		level.world.set_value(item, item_to_string(item), is_player)
	level.world.set_value("Moves", moves, is_player)
	level.world.set_value("Position", location, is_player)
	if visible:
		level.world.show_stats(is_player)
	
