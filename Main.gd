extends Node2D


export(int) var game_seed


func _ready():
	seed(game_seed)
	$World.create()
