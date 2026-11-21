extends Node
## Player settings, saved to user://settings.cfg. For now: master volume and mute.
## Owns the Master bus volume: the player's volume times the start-up fade-in,
## on top of the game's fixed MASTER_DB headroom.

signal volume_changed(volume: float, muted: bool)

const PATH := "user://settings.cfg"
const MASTER_DB := -3.0     ## fixed headroom (the limiter keeps peaks under -1.5 dBFS)

var volume := 0.8           ## 0..1
var muted := false
var fade := 0.0             ## 0..1, driven by the start-up fade-in


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		volume = clampf(float(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)
		muted = bool(cfg.get_value("audio", "muted", muted))
	apply()


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	apply()
	save()
	volume_changed.emit(volume, muted)


func set_muted(m: bool) -> void:
	muted = m
	apply()
	save()
	volume_changed.emit(volume, muted)


func set_fade(f: float) -> void:
	fade = clampf(f, 0.0, 1.0)
	apply()


func apply() -> void:
	var lin := 0.0 if muted else volume * fade
	# Square law so the slider feels even (half way is clearly quieter, not almost full).
	lin = lin * lin
	AudioServer.set_bus_volume_db(0, -80.0 if lin < 0.0001 else linear_to_db(lin) + MASTER_DB)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "muted", muted)
	cfg.save(PATH)
