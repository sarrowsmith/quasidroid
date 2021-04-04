class_name Weapons
extends Node2D


enum {GRAPPLE, RAM, BLADE, PROBE, PROJECTILE, EMP}
enum Field {NAME, DAMAGE, RANGE, AC}

const stats_map = {
	Grapple = ["grapple", GRAPPLE, 1, 0],
	Ram = ["ram", RAM, 1, 1],
	Blade = ["thermal lance", BLADE, 1, 1],
	Probe = ["logic probe", PROBE, 1, 0],
	Plasma = ["plasma beam", BLADE, 7, 2],
	Laser = ["laser", BLADE, 5, 2],
	Dual = ["plasma barrage", BLADE, 5, 2],
	Ion = ["ion cannon", RAM, 5, 3],
	Projectile = ["rail gun", PROJECTILE, 7, 1],
	EMP = ["EMP", EMP, 7, 3],
}

var location = Vector2.ZERO


func get_weapon_name(weapon: String="") -> String:
	if not weapon:
		weapon = owner.get_weapon()
	return stats_map[weapon][Field.NAME]


func get_damage_type():
	return stats_map[owner.get_weapon()][Field.DAMAGE]


func get_range() -> int:
	return stats_map[owner.get_weapon()][Field.RANGE]


func get_armour_required() -> int:
	return stats_map[owner.get_weapon()][Field.AC]


func shoot() -> bool:
	match owner.level.location_type(location):
		Level.FLOOR:
			var weapon_range = get_range()
			if location.distance_squared_to(owner.location) < weapon_range * weapon_range:
				return false
			continue
		Level.PLAYER:
			if owner.is_player:
				return false
			attack(owner.level.world.player)
		Level.ROGUE:
			var rogue = owner.level.rogue_at(location)
			if rogue and rogue != owner:
				if rogue.get_state() != Robot.DEAD:
					return splash(rogue)
			else:
				return false
		_:
			owner.end_move()
	return true


func splash(rogue: Rogue) -> bool:
	match owner.get_weapon():
		"Dual", "Ion":
			for r in owner.level.rogues:
				if location.distance_squared_to(r.location) < 4:
					attack(r)
		"Laser":
			attack(rogue)
			return false
		_:
			attack(rogue)
	return true


func attack(other: Robot):
	if other.get_state() == Robot.DEAD:
		return
	owner.set_state(Robot.WAIT)
	var hit = 1
	var theirs = other.stats.stats.duplicate()
	match get_damage_type():
		GRAPPLE:
			if owner.is_player:
				grapple(other, theirs)
				return
			continue
		BLADE:
			hit = 2
			attack_b(other)
		PROBE:
			probe(other)
		PROJECTILE:
			hit = 2
			projectile(other)
		EMP:
			hit = 3
			emp(other)
		RAM, _:
			attack_a(other)
	other.hit(hit)
	var damages = other.stats.normalise(theirs)
	for i in len(damages):
		if not damages[i].ends_with("!"):
			damages[i] = get_weapon_name(damages[i]) + " destroyed!"
	owner.level.world.report_attack(owner, other, {}, theirs, damages)
	owner.end_move()


func grapple(other: Robot, theirs: Dictionary):
	var ours = owner.stats.stats.duplicate()
	owner.hit(1)
	other.hit(1)
	var attack = grapple_effect(owner.stats, 0 if (other.target() == owner.location) else 1)
	var defence = grapple_effect(other.stats, 0)
	var delta = attack - defence
	var damage = 1.0 / delta
	match sign(delta):
		-1.0:
			for k in owner.stats.stats:
				# delta and damage are negative
				owner.stats.stats[k] += delta * (1.5 if k in Stats.critical_stats else 0.5)
				# defender also take damage for an unconvincing win
				if other.stats.stats[k] > (1 - damage):
					other.stats.stats[k] += damage
		0.0:
			for k in Stats.critical_stats:
				other.stats.stats[k] -= 1
				owner.stats.stats[k] -= 1
		+1.0:
			# victory is an automatic kill
			other.set_state(Robot.DEAD)
			for k in other.stats.stats:
				# a convincing win inflicts less damage for better scavenging
				other.stats.stats[k] -= damage * (3.0 if k in Stats.critical_stats else 1.0)
			# we also take non-fatal critical damage for an unconvincing win
			for k in Stats.critical_stats:
				if owner.stats.stats[k] > (1 + damage):
					owner.stats.stats[k] -= damage
	other.stats.normalise(theirs, true)
	owner.stats.normalise(ours, true)
	owner.level.world.report_attack(owner, other, ours, theirs, [])
	owner.end_move()


# There's all sorts of possibilities for adjusting the deviation on
# these random distributions that I've not got time to get my head
# round right now. Just throwing some wild guesses in.
# (The idea behind using health is the "desperate fight".)

func grapple_effect(stats: Stats, initiative: int) -> float:
	# weight penalty is effectively a trade off against armour and speed
	return owner.level.rng.randfn(stats.stats.logic * (initiative +  stats.stats.power) / stats.weight(), 1.0 / stats.health())


func modify_attack(theirs: Stats) -> float:
	var ours = owner.stats
	var ac = get_armour_required()
	var attack = 1 + ours.stats.strength - theirs.equipment.armour
	if theirs.equipment.armour >= ac:
		attack -= theirs.stats.protection - 2
	if get_range() == 1:
		attack += 1
	return attack


func attack_a(other: Robot):
	var attack = modify_attack(other.stats)
	for k in other.stats.stats:
		if other.stats.stats[k] <= 0:
			continue
		var defence = other.stats.stats[k] / 3.0 if k in Stats.critical_stats else other.stats.stats[k]
		if defence > 0 and owner.level.rng.randfn(attack / defence) > 0.5:
			other.stats.stats[k] -= 1


func attack_b(other: Robot):
	var attack = modify_attack(other.stats)
	var vulnerabilities = []
	for stat in other.stats.stats:
		vulnerabilities.append([other.stats.stats[stat], stat])
	vulnerabilities.sort()
	while attack > 0 and not other.stats.disabled():
		for v in vulnerabilities:
			if attack == 0 or other.stats.disabled():
				break
			var k = v[1]
			if other.stats.stats[k] <= 0:
				continue
			other.stats.stats[k] -= (owner.level.rng.randfn(attack,  1.0 / other.stats.health()) if v[1] in Stats.critical_stats else 1)
			attack -= 1


func probe(other: Robot):
	other.stats.stats.logic -= owner.level.rng.randfn(owner.stats.stats.strength,  1.0 / other.stats.health())


func projectile(other: Robot):
	var attack = modify_attack(other.stats)
	if attack > 0:
		other.stats.stats.protection -= owner.level.rng.randfn(attack, 0.1 + other.stats.equipment.armour)
		other.stats.stats.chassis -= owner.level.rng.randfn(attack, log(1.1 + other.stats.stats.protection))
		if other.stats.equipment.armour > 0 and owner.level.rng.randfn(attack) > attack:
			other.stats.equipment.armour -= 1


func emp(other: Robot):
	var attack = modify_attack(other.stats)
	if attack > 0:
		other.stats.stats.logic -= owner.level.rng.randfn(attack, log(other.stats.stats.logic))
		other.stats.stats.power -= owner.level.rng.randfn(attack, log(other.stats.stats.chassis))

