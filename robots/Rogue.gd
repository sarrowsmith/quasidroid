extends Robot


func _ready():
	weapons = $Weapons
	set_state(DONE)
	add_to_group("rogue")


func turn():
	if .turn():
		return true
	behaviour()
	return false


func generate(level, location):
	self.level = level
	set_location(location)

	stats = Stats.new()
	stats.create(level.level, level.rng)
	stats.equipment.extras.append("none")
	new_direction()


func equip(_auto=true):
	combat = len(stats.equipment.weapons) - 1
	.equip(combat >= WEAPON)


func new_direction():
	# By including NONE here, a change of direction can lead to
	# a pause. target_type in behaviour will be ROGUE (us) and
	# so trigger a new direction for next turn.
	facing = facing_map.keys()[level.rng.randi_range(0, 4)]
	equip()


func behaviour():
	var target_type = action(facing, false)
	while combat > MELEE and weapons.get_range() > 1:
		combat -= 1
	match target_type:
		Level.FLOOR:
			try_target()
		Level.PLAYER:
			equip()
			return # Automatic attack
		_:
			new_direction()
			set_state(DONE)
	return target_type


func try_target():
	# TODO: is the player in range?
	#ifso:
#		equip()
	action(facing, true)
