extends Node2D


onready var current = $Default


func set_mode(mode):
	current.set_visible(false)
	if mode:
		current = get_node(mode)
		current.set_visible(true)
