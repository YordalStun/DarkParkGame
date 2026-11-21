extends Node
## In-game time for the night shift. Missions can hook into minute_changed.

signal minute_changed(hour: int, minute: int)

const DATE_TEXT := "FRI 13-OCT-1989"

## Game minutes that pass per real second. 0.5 = an 8 hour shift takes 16 minutes.
@export var time_scale := 0.5
var running := true

var _minutes := 23.0 * 60.0 + 4.0  # 23:04
var _last_whole := -1


func _process(delta: float) -> void:
	if not running:
		return
	_minutes = fmod(_minutes + delta * time_scale, 24.0 * 60.0)
	var whole := int(_minutes)
	if whole != _last_whole:
		_last_whole = whole
		minute_changed.emit(hour(), minute())


func set_time(h: int, m: int) -> void:
	_minutes = h * 60.0 + m


func hour() -> int:
	return int(_minutes / 60.0) % 24


func minute() -> int:
	return int(_minutes) % 60


## Fractional hours (0..24), handy for clock hands.
func hours_f() -> float:
	return _minutes / 60.0


func time_text() -> String:
	return "%02d:%02d" % [hour(), minute()]
