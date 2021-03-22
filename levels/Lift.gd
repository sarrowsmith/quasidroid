class_name Lift
extends Node2D


enum {LOCKED, CLOSED, OPEN}

const state_name = ["locked", "closed", "open"]

var location = Vector2.ZERO
var from = null
var to = null
var direction = "Down"
var state = LOCKED


func level_name(level):
	if level:
		return "level "+level.map_name
	return "the surface"


func get_info():
	return """A lift %s from %s to %s.

It is currently %s.""" % [direction.to_lower(), level_name(from), level_name(to), state_name[state]]


func unlock():
	if state != LOCKED:
		return false
	$Unlock.play()
	state = CLOSED
	$No.set_visible(false)
	$Exit.set_visible(false)
	get_node(direction).set_visible(true)
	return true


func open():
	if state != CLOSED:
		return false
	$Open.set_visible(true)
	$Unlock.set_visible(false)
	$Open.play()
	state = OPEN
	return true


func close():
	if state != OPEN:
		return false
	$Open.play("default", true)
	state = CLOSED
	return true
