extends Node
## Autoload "Sfx": one-shot sounds and the ambient loop.

const NAMES := ["click", "hover", "step", "battle", "correct", "wrong", "hurt", "cast",
	"poof", "door", "clear", "boss", "victory", "defeat", "coin"]

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _ambient: AudioStreamPlayer
var muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var path := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_ambient = AudioStreamPlayer.new()
	_ambient.volume_db = -10.0
	add_child(_ambient)
	var amb_path := "res://assets/sfx/ambient.wav"
	if ResourceLoader.exists(amb_path):
		var amb: AudioStreamWAV = load(amb_path)
		amb.loop_mode = AudioStreamWAV.LOOP_FORWARD
		amb.loop_begin = 0
		amb.loop_end = int(amb.get_length() * amb.mix_rate)
		_ambient.stream = amb


func play(sound: String, volume_db: float = 0.0, pitch_jitter: float = 0.0) -> void:
	if muted or not _streams.has(sound):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _streams[sound]
			p.volume_db = volume_db
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return


func ambient(on: bool) -> void:
	if _ambient.stream == null:
		return
	if on and not muted and not _ambient.playing:
		_ambient.play()
	elif not on:
		_ambient.stop()


func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
