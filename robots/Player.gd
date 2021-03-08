extends Robot


func _ready():
	base = "0"
	set_sprite()


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
	for e in move_map:
		if InputMap.event_is_action(event, e):
			move(move_map[e])
