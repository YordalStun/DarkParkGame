extends Node
## Player settings, saved to user://settings.cfg: master volume, mute, and a level for
## each part of the mix (rain & weather, radio music, room ambience).
## Owns the Master bus volume: the player's volume times the start-up fade-in,
## on top of the game's fixed MASTER_DB headroom.

signal volume_changed(volume: float, muted: bool)
signal mix_changed  ## one of the channel levels below changed
signal graphics_changed(key: String)

## Graphics options (pause screen > GRAPHICS). "pixels" picks the internal render height:
## 0 = 360 (PS1 look), 1 = 480, 2 = 720, 3 = full resolution.
const PIXEL_HEIGHTS := [360, 480, 720, 0]
const FPS_CAPS := [0, 30, 60, 120, 144]
var graphics := {
	"pixels": 0, "fullscreen": false, "vsync": true, "fps_cap": 0,
	"mist": true, "reflections": true, "ao": true, "glow": true,
	"retro_colour": true, "grain": true, "shadows": true, "show_fps": false,
	"motion": 0,   ## camera motion: 0 full, 1 reduced, 2 minimal
}

const PATH := "user://settings.cfg"
const MASTER_DB := -3.0     ## fixed headroom (the limiter keeps peaks under -1.5 dBFS)
## Mix channels the pause screen shows a slider for: key -> label.
const CHANNELS := {"weather": "RAIN & WEATHER", "music": "RADIO", "ambience": "ROOM & LOT", "cars": "CARS", "voices": "VOICES"}

var volume := 0.8           ## 0..1
var muted := false
var fade := 0.0             ## 0..1, driven by the start-up fade-in
var mix := {"weather": 0.7, "music": 1.0, "ambience": 1.0, "cars": 0.8, "voices": 0.8}   ## 0..1 each


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		volume = clampf(float(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)
		muted = bool(cfg.get_value("audio", "muted", muted))
		for k in mix:
			mix[k] = clampf(float(cfg.get_value("audio", k, mix[k])), 0.0, 1.0)
		for k in graphics:
			var v = cfg.get_value("graphics", k, graphics[k])
			graphics[k] = v if typeof(v) == typeof(graphics[k]) else graphics[k]
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


func set_mix(channel: String, v: float) -> void:
	mix[channel] = clampf(v, 0.0, 1.0)
	save()
	mix_changed.emit()


## Gain in dB for a mix channel (same square-law feel as the master slider).
func mix_db(channel: String) -> float:
	var lin: float = mix.get(channel, 1.0)
	lin = lin * lin
	return -80.0 if lin < 0.0001 else linear_to_db(lin)


func set_graphics(key: String, v) -> void:
	graphics[key] = v
	save()
	graphics_changed.emit(key)


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
	for k in mix:
		cfg.set_value("audio", k, mix[k])
	for k in graphics:
		cfg.set_value("graphics", k, graphics[k])
	cfg.save(PATH)
