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
func cursor_at(cursor, location):
	var location_type = level.location_type(location)
	if self.location.distance_squared_to(location) <= stats["move"]:
		var lift = level.lift_at(location)
		if not lift or lift.open:
			location_type = Level.Type.PLAYER
	if location_type == Level.Type.ROGUE:
		if self.location.x == location.x or self.location.y == location.y:
			if self.location.x == location.x:
				for y in range(self.location.y, location.y):
					if y != self.location.y and y != location.y and level.location_type(Vector2(location.x, y)) != Level.Type.FLOOR:
						location_type = Level.Type.ACCESS
						break
			if self.location.y == location.y:
				for x in range(self.location.x, location.x):
					if x != self.location.x and x != location.x and level.location_type(Vector2(x, location.y)) != Level.Type.FLOOR:
						location_type = Level.Type.ACCESS
						break
		else:
			location_type = Level.Type.ACCESS
	cursor.set_mode(cursor_types[location_type])
