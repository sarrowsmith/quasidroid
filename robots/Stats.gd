class_name Stats
extends Reference


const critical_stats = ["chassis", "power", "logic"]
const types = [
	{ name = "Basic Unit", weapon = "Blade" },
	{ name = "Scout", drive = 3, logic = 6 },
	{ name = "Probe", drive = 2, weapon = "Probe", strength = 2, logic = 9 },
	{ name = "Security Model A", weapon = "Dual", strength = 3, armour = 1, protection = 2},

	{ name = "Sniper", drive = 2, weapon = "Plasma", strength = 3 },
	{ name = "Security Model B", weapon = "Ion", strength = 3, armour = 1, protection = 2},
	{ name = "Grunt", weapon = "Blade", strength = 3, armour = 2, protection = 2},
	{ name = "Model A Fighter", weapon = "Dual", strength = 2, armour = 2, protection = 2},
	{ name = "Tank", weapon = "Projectile", strength = 2, armour = 3, protection = 2},

	{ name = "Security Model C", weapon = "Laser", strength = 3, armour = 1, protection = 2},
	{ name = "Model B Fighter", weapon = "Ion", strength = 2, armour = 2, protection = 2},

	{ name = "Model C Fighter", weapon = "Laser", strength = 2, armour = 2, protection = 2},
	{ name = "Killer", weapon = "EMP", strength = 2, armour = 1, protection = 2},
]
const level_limits = [4, 9, 11, 13]

var equipment = {
	drive = 1,
	weapons = ["Grapple", "Ram"],
	armour = 0,
	extras = [],
}
var stats = {
	chassis = 3,
	power = 3,
	logic = 3,
	strength = 1,
	protection = 1,
	speed = 1,
}
var type_name = ""
var level = 1
var baseline = null


static func choose(choices: Array, rng: RandomNumberGenerator):
	return choices[rng.randi_range(0, len(choices) - 1)]


# warning-ignore:shadowed_variable
func create(level: Level):
	var template = types[0]
	var hybrid = null
	if level.level < len(level_limits):
		template = types[level.rng.randi_range(0, level_limits[level.level-1])]
	else:
		template = choose(types, level.rng)
		if level.level == level.world.world_depth:
			self.level = level.rng.randi_range(1, 3)
			template = template.duplicate()
			hybrid = choose(types, level.rng)
		else:
			self.level = 1 + level.level - len(level_limits)
	for model in [template, hybrid]:
		if not model:
			continue
		for item in model:
			match item:
				"weapon":
					equipment.weapons.append(model[item])
				"name":
					type_name = model[item]
				_:
					if equipment.has(item):
						equipment[item] = max(equipment[item], model[item])
					else:
						stats[item] = max(stats[item], model[item])
	stats.speed = equipment.drive
	for item in stats:
		stats[item] *= self.level
	if hybrid:
		self.level = 0


func disabled() -> bool:
	var lowest = stats[critical_stats[0]]
	for stat in critical_stats:
		lowest = min(lowest, stats[stat])
	return lowest == 0


func weight() -> float:
	return equipment.drive - 1 + equipment.armour + log(stats.chassis + 1)


func health() -> float:
	var health = 0
	for critical in critical_stats:
		health += stats[critical]
	return health


func implicit_damage() -> bool:
	var damage_taken = false
	if weight() > 2 * stats.power:
		stats.chassis -= 1
		damage_taken = true
	if stats.speed > equipment.drive * level:
		stats.speed -= 1
		damage_taken = true
	return damage_taken


const damage = [["protection", "armour"], ["chassis", "drive"], ["strength", ""], ["power", ""], ["logic", ""]]
func normalise(reference: Dictionary, no_damage: bool=false) -> Array:
	for stat in stats:
		var normalised = int(round(stats[stat]))
		if normalised < 0:
			normalised = 0
		elif normalised > reference[stat]:
			normalised = reference[stat]
		stats[stat] = normalised
	if no_damage:
		return []
	var damages = []
	for i in len(damage):
		var s = damage[i][0]
		if stats[s] == 0 or reference[s] - stats[s] > 1:
			match s:
				"proection", "armour":
					var e = damage[i][1]
					if equipment[e] > i:
						equipment[e] -= 1
						damages.append(e + (" damaged!" if equipment[e] > 0 else " destroyed!"))
				"strength":
					var n_weapons = len(equipment.weapons)
					if n_weapons > 2:
						damages.append(equipment.weapons.pop_back())
				_:
					if equipment.extras and equipment.extras[-1] != "none":
						damages.append(equipment.extras.pop_back() + " destroyed!")
					break
	return damages


func scavenge(other: Robot) -> PoolStringArray:
	var theirs = other.stats.equipment.duplicate()
	var scavenged = PoolStringArray()
	if stats.strength < 1 and len(theirs.weapons) > Robot.WEAPON:
		stats.strength = 1
	for i in len(theirs.weapons):
		if not theirs.weapons[i] in equipment.weapons:
			scavenged.append(other.weapons.get_weapon_name(theirs.weapons[i]))
			equipment.weapons.append(theirs.weapons[i])
			other.stats.equipment.weapons.remove(i)
	for i in len(theirs.extras):
		var extra = theirs.extras[i]
		if extra  =="none":
			continue
		if not theirs.extras[i] in equipment.extras:
			scavenged.append(extra)
			equipment.extras.append(extra)
			other.stats.extras.extras.remove(i)
	if theirs.drive > equipment.drive:
		equipment.drive = theirs.drive
		scavenged.append("drive upgrade")
		theirs.drive = 1
		stats.speed = max(stats.speed, 1)
	if theirs.armour > equipment.armour:
		equipment.armour = theirs.armour
		scavenged.append("armour upgrade")
		theirs.armour = 0
		stats.protection = max(stats.protection, 1)
	if baseline:
		for stat in stats:
			if other.stats.stats[stat] > baseline[stat]:
				scavenged.append("%d of %s" % [other.stats.stats[stat] - baseline[stat], stat])
				stats[stat] = other.stats.stats[stat]
				other.stats.stats[stat] = baseline[stat]
				baseline[stat] = stats[stat]
	return scavenged


func load(file: File):
	equipment = file.get_var()
	stats = file.get_var()
	type_name = file.get_pascal_string()
	level = file.get_32()
	baseline = file.get_var()


func save(file: File):
	file.store_var(equipment)
	file.store_var(stats)
	file.store_pascal_string(type_name)
	file.store_32(level)
	file.store_var(baseline)
