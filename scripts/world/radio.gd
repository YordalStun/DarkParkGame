extends Node3D
## The transistor radio on the desk. On by default; click it to switch on/off.
## The music is a positional sound placed on the radio's speaker grille, so it
## pans and fades with the player's head like a real object in the room.
##
## The "station" keeps broadcasting while the radio is off (it is only muted),
## so switching back on drops you into the middle of whatever is playing.

signal switched(on: bool)

const TRACKS := ["radio_1", "radio_2", "radio_3", "radio_4", "radio_5"]
const MUSIC_DB := -2.0
const HISS_DB := -14.0

var is_on := true
var dial_mat: StandardMaterial3D
var interact: Interactable

var _music: AudioStreamPlayer3D
var _hiss: AudioStreamPlayer3D
var _glow: OmniLight3D
var _order: Array = []
var _index := 0
var _t := 0.0
var _fade_db := 0.0        ## the station drifting in and out in heavy rain
var _hiss_boost_db := 0.0  ## more crackle in heavy rain
var _crackle_timer := 6.0


func _ready() -> void:
	var speaker := Vector3(-0.055, 0.065, 0.05)  # the grille, local to the radio

	_music = _player(speaker, 1.0)
	_music.finished.connect(_next_track)
	_hiss = _player(speaker, 1.0)
	var h := load("res://assets/audio/radio_hiss.ogg") as AudioStreamOggVorbis
	h.loop = true
	_hiss.stream = h
	_hiss.volume_db = HISS_DB
	_hiss.play()

	# Dial lamp.
	_glow = OmniLight3D.new()
	_glow.position = Vector3(0.06, 0.09, 0.08)
	_glow.light_color = Color(1.0, 0.7, 0.35)
	_glow.light_energy = 0.06
	_glow.omni_range = 0.45
	_glow.light_volumetric_fog_energy = 0.0
	_glow.light_specular = 0.2
	add_child(_glow)

	_order = TRACKS.duplicate()
	_order.shuffle()
	_index = 0
	_play_current(true)

	if interact:
		interact.activated.connect(toggle)
	Settings.mix_changed.connect(_apply)
	_apply()


func _player(pos: Vector3, unit: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.position = pos
	p.bus = "Interior"
	p.unit_size = unit
	p.max_db = 0.0
	p.max_distance = 25.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.panning_strength = 1.0
	add_child(p)
	return p


func _play_current(random_start := false) -> void:
	var s := load("res://assets/audio/%s.ogg" % _order[_index]) as AudioStream
	_music.stream = s
	var start := randf() * s.get_length() * 0.6 if random_start else 0.0
	_music.play(start)


func _next_track() -> void:
	# A short gap of just hiss between songs, like a quiet late-night DJ.
	await get_tree().create_timer(randf_range(1.5, 3.0)).timeout
	_index = (_index + 1) % _order.size()
	if _index == 0:
		_order.shuffle()
	_play_current()


func toggle() -> void:
	set_on(not is_on)


func set_on(on: bool) -> void:
	if on == is_on:
		return
	is_on = on
	_one_shot("radio_click", -6.0)
	if on:
		_one_shot("radio_static", -8.0)
	_apply()
	switched.emit(on)


## Heavy rain interferes: the hiss comes up, the station fades in and out, and now and then it pops.
func _process(delta: float) -> void:
	if not is_on:
		return
	_t += delta
	var heavy := smoothstep(0.45, 0.95, Weather.rain)
	var wob := 0.5 + 0.5 * sin(_t * 0.37) * sin(_t * 0.113 + 1.7)
	var fade := 1.0 - heavy * 0.75 * wob
	_fade_db = linear_to_db(maxf(fade, 0.06))
	_hiss_boost_db = heavy * (7.0 + 6.0 * (1.0 - fade))
	_apply()
	_crackle_timer -= delta
	if heavy > 0.15 and _crackle_timer <= 0.0:
		_one_shot("radio_static", -24.0 + heavy * 8.0 + Settings.mix_db("music"))
		_crackle_timer = randf_range(4.0, 14.0) / (0.4 + heavy)


func _apply() -> void:
	var mix := Settings.mix_db("music")
	_music.volume_db = MUSIC_DB + mix + _fade_db if is_on else -80.0
	_hiss.volume_db = HISS_DB + mix + _hiss_boost_db if is_on else -80.0
	_glow.visible = is_on
	if dial_mat:
		dial_mat.emission_enabled = is_on
		dial_mat.emission = Color(1.0, 0.65, 0.3)
		dial_mat.emission_energy_multiplier = 1.4


func _one_shot(n: String, db: float) -> void:
	var p := _player(Vector3(0.06, 0.045, 0.05), 1.0)
	p.stream = load("res://assets/audio/%s.ogg" % n)
	p.volume_db = db
	p.play()
	p.finished.connect(p.queue_free)
