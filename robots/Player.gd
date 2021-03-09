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
