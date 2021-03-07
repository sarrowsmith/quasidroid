extends Node2D


export(int) var world_seed


func create():
	world_seed = randi()
	$Level.create(null)
	$Level.generate()
