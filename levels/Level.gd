class_name Level
extends Node2D


export(int) var level_seed = 0
export(bool) var rooms = false
var parent = null
var children = [null, null]
var prototypes = null


func _ready():
	prototypes = [
		load("res://levels/CavesLevel.tscn"),
		load("res://levels/RoomsLevel.tscn")
	]


func create(from, level):
	set_visible(false)
	parent = from
	if prototypes == null and parent != null :
		prototypes = parent.prototypes
	level_seed = randi()
	if level < 7:
		for i in 2:
			var child = prototypes[i].instance()
			child.rooms = rooms && i > 0
			child.create(self, level+1)
			add_child(child)
			children[i] = child
			if not rooms:
				break


func generate():
	seed(level_seed)
	$Rooms.generate()
	set_visible(true)
