extends Node2D


export(int) var world_seed
onready var active_level = $Level


func create():
	world_seed = randi()
	active_level.create(null)
	change_level(active_level)


func change_level(level):
	if level == null:
		return
	active_level.set_visible(false)
	level.generate()
	active_level = level
