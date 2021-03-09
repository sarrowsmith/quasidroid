extends Node2D


onready var current = $Default

var mode = null
var location = Vector2.ZERO


func set_mode(mode):
	self.mode = mode
	current.set_visible(false)
	if mode:
		current = get_node(mode)
		current.set_visible(true)
