class_name Lift
extends Node2D


enum {LOCKED, CLOSED, OPEN}

const state_name = ["locked", "closed", "open"]

var location = Vector2.ZERO
var from = null
var to = null
var direction = "down"
var state = LOCKED


func level_name(level):
	if level:
		return "level "+level.map_name
	return "the surface"


func get_info():
	return """A lift %s from %s to %s.

It is currently %s.""" % [direction, level_name(from), level_name(to), state_name[state]]


func unlock():
	if state != LOCKED:
		return
	$Unlock.play()
	state = CLOSED


func open():
	if state != CLOSED:
		return
	$Open.set_visible(true)
	$Unlock.set_visible(false)
	$Open.play()
	state = OPEN


func close():
	if state != OPEN:
		return
	$Open.play("default", true)
