class_name Robot
extends Node2D


enum {DEAD, IDLE, WAIT, DONE}
enum {GRAPPLE=-1, MELEE, WEAPON}

var location = Vector2.ZERO
var level = null
var base = "2"
var mode = "Idle"
var firing = "Idle"
var facing = Vector2.DOWN
var destination = Vector2.ZERO
var sprite = null
var weapon = null
var combat = MELEE
var stats = null
var moves = 0
var state = DONE
var is_player = false
# This *must* be overridden by derived classes
var weapons = null

func set_state(value):
	state = value

func get_state():
	return state

func end_move():
	if state == WAIT:
		state = IDLE if moves > 0 else DONE


func _process(_delta):
	if level == null or get_state() == DEAD:
		return
	if mode == "Move":
		position += facing
		if position == level.location_to_position(destination):
			location = destination
			mode = "Idle"
			set_sprite()
			set_state(IDLE if moves > 0 else DONE)
			if is_player and moves > 0:
				show_stats(true)
				# Yes, this is us, but the indirection sorts the type out
				level.world.player.check_location()
			level.set_cursor()
		return
	if firing == "Fire":
		weapon.position += facing * 4
		var target = level.position_to_location(weapon.global_position)
		if level.position_to_location(weapon.position) == weapons.location:
			return
		weapons.location = target
		if not weapons.shoot():
			return
		firing = "Idle"
		weapons.location = location
		equip(true)


func turn():
	match get_state():
		DEAD:
			return true
		DONE:
			set_state(IDLE)
			moves = stats.stats.speed
	return false


const facing_map = {
	Vector2.ZERO: "Down",
	Vector2.DOWN: "Down",
	Vector2.UP: "Up",
	Vector2.LEFT: "Left",
	Vector2.RIGHT: "Right",
	Vector2(1, 1): "Down",
	Vector2(-1, 1): "Down",
	Vector2(1, -1): "Right",
	Vector2(-1, -1): "Left",
}
func get_sprite(path):
	return get_node("%s/%s" % [path, facing_map[facing]])


func set_sprite(equipped=true):
	if sprite:
		sprite.set_visible(false)
	if weapon:
		weapon.set_visible(false)
	var dead = get_state() == DEAD
	var path = "Robot/Dead" if dead else base
	if stats.equipment.extras:
		path += "-X"
	sprite = get_node(path) if dead else get_sprite("Robot/%s/%s" % [path, mode])
	sprite.set_visible(true)
	if dead or combat < WEAPON:
		if weapon:
			weapon.set_visible(false)
			weapon = null
		return
	weapon = get_sprite("Weapons/%s/%s" % [get_weapon(), firing])
	if weapon:
		weapon.position = Vector2.ZERO
		weapon.set_visible(equipped)


func equip(on):
	set_sprite(on)


func get_weapon():
	return stats.equipment.weapons[combat]


# warning-ignore:shadowed_variable
func set_location(destination):
	self.destination = destination
	location = destination
	position = level.location_to_position(location)


func move(target):
	mode = "Move"
	set_state(WAIT)
	destination = target


func action(direction, really=true, truly=true):
	if direction == null:
		if not is_player:
			return Level.WALL
		direction = level.cursor.location - location
	if really and truly and weapons.get_range() > 1:
		if direction == Vector2.ZERO:
			direction = facing
		shoot(direction)
		return Level.WALL
	facing = direction
	var target = location + direction
	if really:
		moves -= 1
	var target_type = level.location_type(target)
	match level.location_type(target):
		Level.FLOOR, Level.ACCESS:
			if really:
				move(target)
		Level.LIFT:
			if is_player:
				var lift = level.lift_at(target)
				if lift:
					if lift._state == Lift.OPEN:
						move(target)
					else:
						set_state(WAIT)
						if lift.open():
							yield(lift.get_node("Open"), "animation_finished")
							end_move()
						else:
							set_state(IDLE)
		Level.PLAYER:
			if is_player:
				if not moves > 0:
					set_state(DONE)
			else:
				while combat > MELEE and weapons.get_range() > 1:
					combat -= 1
				weapons.attack(level.world.player)
				combat = len(weapons) - 1
		Level.ROGUE:
			if is_player:
				var rogue = level.rogue_at(target)
				if rogue:
					if rogue.get_state() == DEAD:
						move(target)
					else:
						weapons.attack(rogue)
		_:
			if really:
				moves += 1 # because we've already paid for the move, pay back the no-op
	set_sprite()
	return target_type


func shoot(direction):
	facing = direction
	firing = "Fire"
	weapons.location = location + direction
	set_state(WAIT)
	moves -= 1
	equip(true)


const item_name_map = {
	drive = ["none", "basic", "improved", "advanced"],
	armour = ["none", "standard", "ablative", "active"],
}
func item_to_string(item):
	match item:
		"extras":
			if stats.equipment.extras:
				return PoolStringArray(stats.equipment.extras).join(", ")
			return "none"
		"weapons":
			return weapons.get_weapon_name()
	return item_name_map[item][stats.equipment[item]]


func show_stats(visible=false):
	if not level:
		return
	for stat in stats.stats:
		level.world.set_value(stat, stats.stats[stat], is_player)
	for item in stats.equipment:
		level.world.set_value(item, item_to_string(item), is_player)
	if is_player:
		level.world.set_value("Moves", moves, true)
	else:
		level.world.set_value("Type", "%s (%d)" % [stats.type_name, stats.level], false)
	if visible:
		level.world.show_stats(is_player)


func hit(count):
	if get_state() == DEAD:
		return
	var zapped = get_sprite("Robot/Hit")
	if not zapped:
		return
	zapped.set_visible(true)
	zapped.play()
	while count > 0:
		yield(zapped, "animation_finished")
		count -= 1
	zapped.stop()
	zapped.set_visible(false)


func check_stats():
	if stats.disabled():
		# nice death animation here please
		set_state(DEAD)
		combat = MELEE
		set_sprite()
		return true
	end_move()
	return false
