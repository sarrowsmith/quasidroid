class_name Level
extends Node2D


export(int) var level_seed = 0
export(bool) var rooms = false
export(int) var level = 0
var world = null
var parent = null
var children = null
var prototypes = null
var points_of_interest = {
	entry = null,
	exit0 = null,
	exit1 = null,
	charge = []
}


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
		world = owner
	else:
		level = parent.level + 1
		prototypes = parent.prototypes
		world = parent.world
	level_seed = randi()


func generate():
	set_visible(true)
	if children != null:
		return
	seed(level_seed)
	$Map.generate()
	place_points_of_interest()
	children = [null, null]
	if level < 7:
		for i in 2:
			var child = prototypes[i].instance()
			child.rooms = rooms && i > 0
			child.create(self)
			world.add_child(child)
			children[i] = child
			if not rooms:
				break


func place_points_of_interest():
	for p in points_of_interest:
		while points_of_interest[p] == null:
			var probe = Vector2(
				Util.randi_range(1, $Map.map_w - 1),
				Util.randi_range(1, $Map.map_h - 1))
			if check_nearby(probe.x, probe.y, 2) == 0:
				points_of_interest[p] = probe


func check_nearby(x, y, r):
	var count = 0
	for i in 2*r:
		for j in 2*r:
			if $Map.get_cell(x+i-r, y+j-r) != TileMap.INVALID_CELL:
				count += 1
	return count



func _on_Background_click(position, button):
	print($Map.world_to_map(position))


func _on_Background_move(position):
	pass
