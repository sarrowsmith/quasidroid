class_name Lift
extends Node2D


enum {LOCKED, CLOSED, OPEN}
enum {DOWN, UP}

const state_name = ["locked", "closed", "open"]
const directions = ["Down", "Up"]

export(Array, AudioStream) var effects

var location = Vector2.ZERO
var from: Level = null
var to: Level = null
var direction = DOWN
var state = LOCKED

onready var anim = $AnimationPlayer
onready var audio = $Audio


func set_up(up: Level, unlocked: bool):
	direction = UP
	to = up
	if unlocked:
		unlock()
	else:
		$No.set_visible(false)
		$Exit.set_visible(true)


func level_name(level: Level) -> String:
	if level:
		return "level "+level.map_name
	return "the surface"


func get_info() -> String:
	return """[b][i]A lift [/i]%s[i] from %s to [/i]%s[i].[/i][/b]

It is currently [b]%s[/b].""" % [directions[direction].to_lower(), level_name(from), level_name(to), state_name[state]]


func unlock(force=false):
	if state == LOCKED or force:
		$No.set_visible(false)
		$Exit.set_visible(false)
		get_node(directions[direction]).set_visible(true)
		if force:
			return state != LOCKED
		state = CLOSED
		anim.play("unlock")


func open() -> bool:
	if state != CLOSED:
		return false
	anim.play("open")
	state = OPEN
	return true


func close() -> bool:
	if state != OPEN:
		return false
	anim.play("close")
	state = CLOSED
	return true


func play_audio():
	if not audio.playing:
		audio.stream = effects[direction]
		audio.play()


func load(file: File) -> String:
	location = file.get_var()
	position = from.location_to_position(location)
	direction = file.get_8()
	state = file.get_8()
	if state == LOCKED:
		if from.level == 1 and direction == UP:
			$No.set_visible(false)
			$Exit.set_visible(true)
	else:
		unlock(true)
	return file.get_pascal_string()


func save(file: File):
	file.store_var(location)
	file.store_8(direction)
	file.store_8(state)
	file.store_pascal_string(to.map_name if to else "^")
