class_name Robot
extends Node2D


enum State {DEAD, IDLE, WAIT, DONE}

var location = Vector2.ZERO
var level = null
var base = "2"
var mode = "Idle"
var firing = "Idle"
var facing = Vector2.DOWN
var destination = Vector2.ZERO
var sprite = null
var weapon = null
var equipment = {
	weapon = null,
	extras = []
}
var stats = {
	move = 1
}
var moves = 0
var state = State.DEAD


func _process(_delta):
	if level == null:
		return
	if mode == "Move":
		level.world.set_value("Position", location)
		if position == level.location_to_position(destination):
			location = destination
			mode = "Idle"
			set_sprite()
			if not moves:
				state = State.DONE
			level.set_cursor()
			return
		position += facing
	if firing == "Fire":
		if not moves:
			state = State.DONE


func turn():
	state = State.IDLE
	moves = stats["move"]


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
	var dead = state == State.DEAD
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
		Level.Type.FLOOR, Level.Type.ACCESS:
			var debug = position
			mode = "Move"
			state = State.WAIT
			moves -= 1
			destination = target
	set_sprite()

func fire(direction):
	facing = direction
	var target = location + direction
	firing = "Fire"
	state = State.WAIT
	moves -= 1
	equip(false)
