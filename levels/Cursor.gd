extends Node2D


onready var current = $Default

var mode: String = ""
var location = Vector2.ZERO


# warning-ignore:shadowed_variable
func set_mode(mode: String):
	self.mode = mode
	current.set_visible(false)
	if mode:
		current = get_node(mode)
		current.set_visible(true)
