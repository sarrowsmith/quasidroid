class_name AudioBankPlayer
extends AudioStreamPlayer


export(Array, AudioStream) var streams

var last_played = -1
onready var volume = volume_db


func play_from_bank(idx: int, from=0.0):
	if not (playing and idx == last_played):
		stream = streams[idx]
		play(from)
		last_played = idx


func play_random(from=0.0):
	if last_played < 0:
		return
	if last_played == 0:
		volume_db = volume
		play_from_bank(1 + randi() % (len(streams) - 1), from)
	else:
		play_from_bank(randi() % len(streams), from)


func fade(idx: int, duration: float):
	$Fader.interpolate_property(self, "volume_db", volume_db, -80, duration)
	$Fader.start()
	yield($Fader, "tween_all_completed")
	if playing:
		last_played = -1
		stop()
	$Fader.interpolate_property(self, "volume_db", -80, 0 if idx == 0 else volume, duration)
	$Fader.start()
	if (idx >= 0):
		play_from_bank(idx)
