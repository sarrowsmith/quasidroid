extends Robot


func _ready():
	weapons = $Weapons
	state = DONE


func turn():
	.turn()
	# AI goes here
	state = DONE


func generate(level, location):
	self.level = level
	set_location(location)
	facing = Util.choose(facing_map.keys())

	stats = Stats.new()
	stats.create(level.level)
	combat = len(stats.equipment.weapons) - 1

	equip(true)
