class_name Lift
extends Node2D


enum {LOCKED, CLOSED, OPEN}

const state_name = ["locked", "closed", "open"]

var location = Vector2.ZERO
var from: Level = null
var to: Level = null
var direction = "Down"
var state = LOCKED


func level_name(level: Level) -> String:
	if level:
		return "level "+level.map_name
	return "the surface"


func get_info() -> String:
	return """A lift %s from %s to %s.

It is currently %s.""" % [direction.to_lower(), level_name(from), level_name(to), state_name[state]]


func unlock(force=false):
	if state == LOCKED or force:
		$No.set_visible(false)
		$Exit.set_visible(false)
		get_node(direction).set_visible(true)
		if force:
			return state != LOCKED
		state = CLOSED


func open() -> bool:
	if state != CLOSED:
		return false
	$Open.set_visible(true)
	$Unlock.set_visible(false)
	$Open.play()
	state = OPEN
	return true


func close():
	if state == OPEN:
		$Open.play("default", true)
		state = CLOSED


func load(file: File) -> String:
	location = file.get_var()
	position = from.location_to_position(location)
	direction = file.get_pascal_string()
	state = file.get_8()
	if state == LOCKED:
		if from.level == 1 and direction == "Up":
			$No.set_visible(false)
			$Exit.set_visible(true)
	else:
		unlock(true)
	return file.get_pascal_string()


func save(file: File):
	file.store_var(location)
	file.store_pascal_string(direction)
	file.store_8(state)
	file.store_pascal_string(to.map_name if to else "^")
