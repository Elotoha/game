extends Node

enum { FIRE, HIT, PICKUP, BOOST, CRASH }

const SOUNDTRACK := [
	preload("res://assets/audio/redshift_relay.ogg"),
	preload("res://assets/audio/ion_rush.ogg"),
	preload("res://assets/audio/pulsar_drift.ogg"),
]
const EFFECTS := [
	preload("res://assets/audio/fire.wav"),
	preload("res://assets/audio/hit.wav"),
	preload("res://assets/audio/pickup.wav"),
	preload("res://assets/audio/boost.wav"),
	preload("res://assets/audio/crash.wav"),
]
const EFFECT_VOLUME_DB := [-9.0, -5.0, -11.0, -8.0, -4.0]
const EFFECT_POLYPHONY := [3, 2, 3, 1, 1]
const MENU_VOLUME_DB := -11.0
const RACE_VOLUME_DB := -4.5
const MUTED_VOLUME_DB := -80.0

var _music := AudioStreamPlayer.new()
var _effects: Array[AudioStreamPlayer] = []
var _muted := false
var _external_music := false
var _racing := false
var _paused := false
var _playback_enabled: bool
var _track_index := 0


func _init(playback_enabled: bool = AudioServer.get_driver_name() != "Dummy") -> void:
	_playback_enabled = playback_enabled


func _ready() -> void:
	_music.volume_db = _music_target()
	add_child(_music)
	_music.finished.connect(_next_track)
	_play_track()
	for index in EFFECTS.size():
		var player := AudioStreamPlayer.new()
		player.stream = EFFECTS[index]
		player.volume_db = EFFECT_VOLUME_DB[index]
		player.max_polyphony = EFFECT_POLYPHONY[index]
		add_child(player)
		_effects.append(player)


func _process(delta: float) -> void:
	_music.volume_db = move_toward(_music.volume_db, _music_target(), 40.0 * delta)


func set_racing(enabled: bool) -> void:
	_racing = enabled


func start_run() -> void:
	_racing = true
	_next_track()


func _next_track() -> void:
	_track_index = (_track_index + 1) % SOUNDTRACK.size()
	_play_track()


func _play_track() -> void:
	if _playback_enabled and not _muted and not _external_music and _music.is_inside_tree():
		_music.stream = SOUNDTRACK[_track_index]
		_music.play()
		_music.stream_paused = _paused


func set_external_music(enabled: bool) -> void:
	if enabled == _external_music:
		return
	_external_music = enabled
	if enabled:
		_music.stop()
	else:
		_play_track()


func is_muted() -> bool:
	return _muted


func set_muted(enabled: bool) -> void:
	if enabled == _muted:
		return
	_muted = enabled
	if enabled:
		_music.stop()
		for player in _effects:
			player.stop()
	else:
		_play_track()


func set_paused(enabled: bool) -> void:
	_paused = enabled
	_music.stream_paused = enabled
	for player in _effects:
		player.stream_paused = enabled


func cue(kind: int) -> void:
	if _playback_enabled and not _muted and not _paused and kind >= 0 and kind < _effects.size():
		_effects[kind].play()


func _music_target() -> float:
	if _muted:
		return MUTED_VOLUME_DB
	return RACE_VOLUME_DB if _racing else MENU_VOLUME_DB
