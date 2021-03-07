class_name Level
extends Node2D


export(int) var level_seed = 0
export(bool) var rooms = false
export(int) var level = 0
var root = null
var parent = null
var children = null
var prototypes = null


func _ready():
	prototypes = [
		load("res://levels/CavesLevel.tscn"),
		load("res://levels/RoomsLevel.tscn")
	]


func create(from):
	set_visible(false)
	parent = from
	if parent == null:
		level = 1
		root = owner
	else:
		level = parent.level + 1
		prototypes = parent.prototypes
		root = parent.root
	level_seed = randi()


func generate():
	set_visible(true)
	if children != null:
		return
	seed(level_seed)
	$Map.generate()
	children = [null, null]
	if level < 7:
		for i in 2:
			var child = prototypes[i].instance()
			child.rooms = rooms && i > 0
			child.create(self)
			root.add_child(child)
			children[i] = child
			if not rooms:
				break
