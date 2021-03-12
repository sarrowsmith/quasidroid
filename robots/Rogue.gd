extends Robot


func _ready():
	weapons = $Weapons
	state = DONE
	add_to_group("rogue")


func turn():
	if .turn():
		return true
	# AI goes here, asynchronously
	state = DONE
	return false


func generate(level, location):
	self.level = level
	set_location(location)

	stats = Stats.new()
	stats.create(level.level, level.rng)
	stats.equipment.extras.append("none")
	combat = len(stats.equipment.weapons) - 1

	facing = facing_map.keys()[level.rng.randi_range(1, 5)]
	equip(true)
