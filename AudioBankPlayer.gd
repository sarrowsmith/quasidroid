class_name AudioBankPlayer
extends AudioStreamPlayer


export(Array, AudioStream) var streams

var last_played = -1


func play_from_bank(idx: int):
	if not (playing and idx == last_played):
		stream = streams[idx]
		play()
		last_played = idx
