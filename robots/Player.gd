extends Robot


signal move(position)


func _ready():
	base = "0"
	moveable = true
	set_sprite()


func _process(delta):
	if state == "Move":
		emit_signal("move", position)
	._process(delta)


func change_level(level):
	self.level = level
	set_location(level.lifts[0].location + Vector2.DOWN)
	level.set_cursor(level.lifts[0].location)


const move_map = {
	"move_up": Vector2.UP,
	"move_down": Vector2.DOWN,
	"move_left": Vector2.LEFT,
	"move_right": Vector2.RIGHT
}
func _unhandled_input(event):
	if not moveable:
		return
	for e in move_map:
		if InputMap.event_is_action(event, e):
			move(move_map[e])


const cursor_types = {
	Level.Type.FLOOR: "Default",
	Level.Type.WALL: null,
	Level.Type.LIFT: "Info",
	Level.Type.ACCESS: "Info",
	Level.Type.PLAYER: "Move",
	Level.Type.ROGUE: "Target"
}
func set_cursor():
	var location_type = level.location_type(level.cursor.location)
	match location_type:
		Level.Type.LIFT:
			var lift = level.lift_at(level.cursor.location)
			if lift and lift.open:
				location_type = Level.Type.PLAYER
		Level.Type.FLOOR, Level.Type.ACCESS:
			if location.distance_squared_to(level.cursor.location) <= stats["move"]:
				location_type = Level.Type.PLAYER
		Level.Type.ROGUE:
			if location.x == level.cursor.location.x or location.y == level.cursor.location.y:
				if location.x == level.cursor.location.x:
					for y in range(min(location.y, level.cursor.location.y), max(location.y, level.cursor.location.y)):
						if y != location.y and y != level.cursor.location.y and level.location_type(Vector2(location.x, y)) != Level.Type.FLOOR:
							location_type = Level.Type.ACCESS
							break
				if location.y == level.cursor.location.y:
					for x in range(min(location.x, level.cursor.location.x), max(location.x, level.cursor.location.x)):
						if x != location.x and x != level.cursor.location.x and level.location_type(Vector2(x, location.y)) != Level.Type.FLOOR:
							location_type = Level.Type.ACCESS
							break
			else:
				location_type = Level.Type.ACCESS
	level.cursor.set_mode(cursor_types[location_type])
