extends Node2D


var melee = false
var location = Vector2.ZERO


func shoot():
	match owner.level.location_type(location):
		Level.FLOOR:
			if location.distance_squared_to(owner.location) < owner.stats._weapon * owner.stats._weapon:
				return false
		Level.PLAYER:
			if owner.is_player:
				return false
			owner.shot()
		Level.ROGUE:
			for r in owner.level.rogues:
				if r.location == location:
					r.shot()
					return splash()
	return true


func splash():
	match owner.equipment.weapon:
		"Dual":
			for r in owner.level.rogues:
				if location.distance_squared_to(r.location) == 1:
					r.shot()
		"Laser":
			return false
	return true
