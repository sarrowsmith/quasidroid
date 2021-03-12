extends Robot


func _ready():
	weapons = $Weapons
	state = DONE
	add_to_group("rogue")


func turn():
	.turn()
	# AI goes here, asynchronously
	state = DONE


func generate(level, location):
	self.level = level
	set_location(location)

	stats = Stats.new()
	stats.create(level.level, level.rng)
	stats.equipment.extras.append("none")
	combat = len(stats.equipment.weapons) - 1

	facing = Stats.choose(facing_map.keys(), level.rng)
	equip(true)
