extends Robot


func _ready():
	state = DONE


func turn():
	.turn()
	# AI goes here
	state = DONE


func generate(level, location):
	self.level = level
	set_location(location)
	facing = Util.choose(facing_map.keys())

	equip(true)
