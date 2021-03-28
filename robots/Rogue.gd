class_name Rogue
extends Robot


func _ready():
	weapons = $Weapons
	set_state(DONE)
	stats = Stats.new()
	add_to_group("rogue")


func turn() -> bool:
	if .turn():
		return true
	while moves > 0:
		match behaviour():
			Level.FLOOR, Level.PLAYER:
				while get_state() == WAIT:
					yield(self, "end_move")
					signalled = true
				if get_state() == DONE:
					break
				else:
					pass
			_:
				moves -= 1
		equip()
	end_move()
	return false


func generate(level: Level, location: Vector2):
	self.level = level
	set_location(location)
	stats.create(level)
	stats.equipment.extras.append("none")
	new_direction()
	equip()


func equip(_auto=true):
	combat = len(stats.equipment.weapons) - 1
	.equip(combat >= WEAPON)


func new_direction():
	# By including NONE here, a change of direction can lead to
	# a pause. target_type in behaviour will be ROGUE (us) and
	# so trigger a new direction for next turn.
	facing = facing_map.keys()[level.rng.randi_range(0, 4)]


func behaviour() -> int: # -> enum
	# 10 % chance of doing nothing
	if level.rng.randf() < 0.1:
		return Level.WALL
	var target_type = action(facing, false)
	match target_type:
		Level.FLOOR:
			target_type = try_target()
		Level.PLAYER:
			# Automatic attack
			if moves > 0:
				set_state(IDLE)
		_:
			new_direction()
	equip()
	return target_type


func try_target() -> int: # -> enum
	var location_type = Level.FLOOR
	var weapon_range = weapons.get_range()
	if weapon_range > 1 && location.distance_squared_to(level.world.player.location) < weapon_range * weapon_range:
		var target = target()
		for _i in range(weapons.get_range() - 3):
			match level.location_type(target):
				Level.FLOOR:
					target += facing
				Level.PLAYER:
					location_type = Level.PLAYER
				_:
					break
	if location_type == Level.FLOOR:
		var ahead = target()
		var nearby = level.check_nearby(ahead.x, ahead.y, 1)
		if nearby[Level.ROGUE] > 1:
			new_direction()
			return Level.ROGUE
		var floors = nearby[Level.FLOOR] # bit heuristic
		if 3 < floors and floors < 6:
			check_turn()
		# 10% of changing direction in the middle of an empty space
		if floors == 8 and level.rng.randf() < 0.1:
			new_direction()
			return Level.WALL
	return action(facing, true, location_type == Level.PLAYER)


func check_turn():
	var side = Vector2(1 - facing.x * facing.x, 1 - facing.y * facing.y)
	var floors = [ # we know facing is a floor
		level.location_type(-facing) == Level.FLOOR,
		level.location_type(side) == Level.FLOOR,
		level.location_type(-side) == Level.FLOOR,
	]
	if floors[1] and floors[2]:
		if not floors[0]:
			return
		# 25% chance of taking a turn
		if level.rng.randf() < 0.5:
			facing = side if level.rng.randf() < 0.5 else -side

	else:
		if floors[1] and level.rng.randf() < 0.25:
			facing = side
		if floors[2] and level.rng.randf() < 0.25:
			facing = -side
