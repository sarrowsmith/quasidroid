extends Node2D


export(int) var world_seed
export(Vector2) var world_size = Vector2(2880, 2880)
onready var active_level = $Level


func create():
	world_seed = randi()
	active_level.create(null, true)
	change_level(active_level)
	return active_level


func change_level(level):
	active_level.set_visible(false)
	level.generate()
	active_level = level
