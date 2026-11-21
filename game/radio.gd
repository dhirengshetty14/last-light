extends Node
var speaker: AudioStreamPlayer
var foley: AudioStreamPlayer
var music: AudioStreamPlayer
var cache: Dictionary = {}
var clips: Dictionary = {}
var sources := [-1, -1, -1, -1, -1]
var muted := false
var pending_lines: Array = []


func tone(notes: Array, seconds: float, gain: float, kind: String) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(seconds * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for n in frames:
		var t := float(n) / rate
		var pos := t / seconds
		var env := minf(t * 20.0, 1.0) * minf((seconds - t) * 10., 1.)
		var sample := 0.0
		for k in notes.size():
			var hz: float = notes[k]
			if kind == "whale":
				hz *= 1. + .040 * sin(t * 1.7 + k * .5)
			sample += sin(TAU * hz * t + .23 * sin(t * 2 + k)) / float(notes.size())
		if kind == "latch":
			env *= exp(-pos * 7.)
		if kind == "score":
			env *= .65 + .20 * sin(TAU * pos)
		data.encode_s16(n * 2, roundi(clampf(sample * env * gain, -1, 1) * 32760.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	if kind == "score":
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = frames
	return w


func _ready() -> void:
	for f in [
		"pip_cover",
		"pip_deal",
		"pip_reel",
		"pip_story",
		"morrow_echo",
		"morrow_deal",
		"morrow_reel",
		"morrow_cover",
		"morrow_story",
		"zip_rush",
		"zip_deal",
		"zip_reel",
		"zip_cover",
		"zip_story"
	]:
		var path: String = "res://assets/audio/" + str(f) + ".wav"
		if ResourceLoader.exists(path):
			cache[f] = load(path)
	speaker = AudioStreamPlayer.new()
	foley = AudioStreamPlayer.new()
	music = AudioStreamPlayer.new()
	for p in [speaker, foley, music]:
		add_child(p)
	speaker.volume_db = -2
	foley.volume_db = -7
	music.volume_db = -16
	clips.latch = tone([660., 990.], .15, .64, "latch")
	clips.gravity = tone([196., 246.94, 293.66], .8, .57, "whale")
	clips.contact = tone([420., 710.], .22, .63, "latch")
	clips.end = tone([196., 246.94, 329.63], 1.6, .6, "whale")
	clips.herd = tone([146.83, 196., 246.94, 329.63, 392.], 2.4, .66, "whale")
	clips.call = tone([196., 246.94], 1.37, .61, "whale")
	music.stream = tone([55., 82.5, 110.], 3.4, .30, "score")
	if not muted:
		music.play()


func reset_shift() -> void:
	sources.fill(-1)
	pending_lines.clear()
	speaker.stop()


func update(s) -> void:
	if muted:
		return
	for i in range(2, 5):
		var seat: Dictionary = s.seats[i]
		if seat.voice_tick != sources[i]:
			sources[i] = seat.voice_tick
			var key: String = s.NAMES[i].to_lower() + "_" + str(seat.voice)
			if cache.has(key):
				for n in range(pending_lines.size() - 1, -1, -1):
					if pending_lines[n].who == i:
						pending_lines.remove_at(n)
				pending_lines.append({"who": i, "clip": key, "expires": s.tick + 135})
	while not pending_lines.is_empty() and not speaker.playing:
		var next: Dictionary = pending_lines.pop_front()
		if next.expires >= s.tick:
			speaker.stream = cache[next.clip]
			speaker.play()
	music.volume_db = -23 if speaker.playing else -16


func fx(kind: String) -> void:
	if muted or not clips.has(kind):
		return
	foley.stream = clips[kind]
	foley.play()


func story_voice(cue: String) -> void:
	if muted or not cache.has(cue):
		return
	speaker.stop()
	speaker.stream = cache[cue]
	speaker.play()


func toggle() -> void:
	muted = not muted
	if muted:
		speaker.stop()
		foley.stop()
		music.stop()
		pending_lines.clear()
	else:
		music.play()


func _exit_tree() -> void:
	for p in [speaker, foley, music]:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
