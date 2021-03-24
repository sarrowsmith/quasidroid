class_name Stats
extends Reference


const critical_stats = ["chassis", "power", "logic"]
const types = [
	{ name = "Basic unit", weapon = "Blade" },
	{ name = "Scout", drive = 3, logic = 6 },
	{ name = "Probe", drive = 2, weapon = "Probe", strength = 2, logic = 9 },
	{ name = "Security model A", weapon = "Dual", strength = 3, armour = 1, protection = 2},

	{ name = "Sniper", drive = 2, weapon = "Plasma", strength = 3 },
	{ name = "Security model B", weapon = "Ion", strength = 3, armour = 1, protection = 2},
	{ name = "Grunt", weapon = "Blade", strength = 3, armour = 2, protection = 2},
	{ name = "Model A fighter", weapon = "Dual", strength = 2, armour = 2, protection = 2},
	{ name = "Tank", weapon = "Projectile", strength = 2, armour = 3, protection = 2},

	{ name = "Security model C", weapon = "Laser", strength = 3, armour = 1, protection = 2},
	{ name = "Model B fighter", weapon = "Ion", strength = 2, armour = 2, protection = 2},

	{ name = "Model C fighter", weapon = "Laser", strength = 2, armour = 2, protection = 2},
	{ name = "Killer", weapon = "EMP", strength = 2, armour = 1, protection = 2},
]
const level_limits = [4, 9, 11, 13]

var equipment = {
	drive = 1,
	weapons = ["Ram"],
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
	if level.level < len(level_limits):
		template = types[level.rng.randi_range(0, level_limits[level.level-1])]
	else:
		template = choose(types, level.rng)
		self.level = 1 + level.level - len(level_limits)
	for item in template:
		match item:
			"weapon":
				equipment.weapons.append(template[item])
			"name":
				type_name = template[item]
			_:
				if equipment.has(item):
					equipment[item] = template[item]
				else:
					stats[item] = template[item] * self.level


func disabled() -> bool:
	var lowest = stats[critical_stats[0]]
	for stat in critical_stats:
		lowest = min(lowest, stats[stat])
	return lowest == 0


func weight() -> float:
	return equipment.drive + equipment.armour + log(stats.chassis)


func health() -> float:
	var health = 0
	for critical in critical_stats:
		health += stats[critical]
	return health


func normalise(reference: Dictionary):
	for stat in stats:
		var normalised = int(round(stats[stat]))
		if normalised < 0:
			normalised = 0
		elif normalised > reference[stat]:
			normalised = reference[stat]
		stats[stat] = normalised


func scavenge(other: Robot) -> PoolStringArray:
	var theirs = other.stats.equipment.duplicate()
	var scavenged = PoolStringArray()
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
	if theirs.armour > equipment.armour:
		equipment.armour = theirs.armour
		scavenged.append("armour upgrade")
		theirs.armour = 0
	if baseline:
		for stat in stats:
			if other.stats.stats[stat] > baseline[stat]:
				scavenged.append("%d of %s" % [other.stats.stats[stat] - baseline[stat], stat])
				stats[stat] = other.stats.stats[stat]
				other.stats.stats[stat] = baseline[stat]
				baseline[stat] = stats[stat]
	return scavenged
