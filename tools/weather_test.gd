extends SceneTree
## Checks that the weather values stay in range over a long simulated night.
##   godot --headless --path . -s tools/weather_test.gd

func _initialize() -> void:
	var w = load("res://scripts/autoload/weather.gd").new()
	root.add_child(w)
	w.set_profile("rain_mist", 0.0)
	var worst := 0.0
	var bad_at := -1.0
	for i in 60 * 60 * 10:              # 10 minutes at 60 fps
		w._process(1.0 / 60.0)
		var m: float = maxf(absf(w.rain), maxf(absf(w.wind), absf(w.fog)))
		worst = maxf(worst, m)
		if bad_at < 0.0 and (m > 1.5 or is_nan(m)):
			bad_at = i / 60.0
	print("WEATHER worst=%s first_bad_at=%s s" % [worst, bad_at])
	quit()
