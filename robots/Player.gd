extends Robot


const move_map = {
	"move_up": Vector2(0, -1),
	"move_down": Vector2(0, 1),
	"move_left": Vector2(-1, 0),
	"move_right": Vector2(1, 0)
}
func _unhandled_input(event):
	for e in move_map:
		if InputMap.event_is_action(event, e):
			this.move(move_map[e])
