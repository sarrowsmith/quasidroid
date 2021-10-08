class_name AudioBankPlayer
extends AudioStreamPlayer


export(Array, AudioStream) var streams

var last_played = -1


func play_from_bank(idx: int, from=0.0):
	if not (playing and idx == last_played):
		stream = streams[idx]
		play(from)
		last_played = idx


func fade_in(idx: int, duration: float):
	$Fader.interpolate_property(self, "volume_db", -80, 0, duration)
	$Fader.start()
	play_from_bank(last_played if idx < 0 else idx)


func fade_out(duration: float):
	$Fader.interpolate_property(self, "volume_db", 0, -80, duration)
	$Fader.start()
	yield($Fader, "tween_all_completed")
	if playing:
		stop()


func cross_fade(idx: int, duration: float):
	fade_out(duration)
	fade_in(idx, duration)
