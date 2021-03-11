class_name Stats
extends Reference


const critical_stats = ["chassis", "power", "logic"]
const types = [
	{ name = "Basic" },
	{ name = "Probe", drive = 2, weapon = "Probe", strength = 2, logic = 9 },
	{ name = "Scout", drive = 3, logic = 6 },
	{ name = "Sniper", drive = 2, weapon = "Plasma", strength = 3 },
	{ name = "Security model A", weapon = "Dual", strength = 3, armour = 1, protection = 2},
	{ name = "Security model B", weapon = "Ion", strength = 3, armour = 1, protection = 2},
	{ name = "Security model C", weapon = "Laser", strength = 3, armour = 1, protection = 2},
	{ name = "Grunt", weapon = "Blade", strength = 3, armour = 2, protection = 2},
	{ name = "Model A fighter", weapon = "Dual", strength = 2, armour = 2, protection = 2},
	{ name = "Model B fighter", weapon = "Ion", strength = 2, armour = 2, protection = 2},
	{ name = "Model C fighter", weapon = "Laser", strength = 2, armour = 2, protection = 2},
	{ name = "Tank", weapon = "Projectile", strength = 2, armour = 3, protection = 2},
	{ name = "Killer", weapon = "EMP", strength = 2, armour = 1, protection = 2},
]

var equipment = {
	drive = 1,
	weapons = ["Grapple", "Ram"],
	armour = 0,
	extras = [],
}
var stats = {
	name = "",
	chassis = 3,
	power = 3,
	logic = 3,
	strength = 1,
	protection = 1,
	speed = 1,
}
var weapon = 6


func create(level):
	var template = Util.choose(types)
	for item in template:
		if item == "weapon":
			equipment.weapons.append(template[item])
		elif equipment.has(item):
			equipment[item] = template[item]
		else:
			stats[item] = template[item]
