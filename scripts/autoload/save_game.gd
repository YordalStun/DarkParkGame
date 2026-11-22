extends Node
## Save slots. The game saves between nights: when you press NEXT NIGHT on the end-of-shift
## screen, the slot gets the next night's number, the coins you have left, the bills you
## skipped and a line of history. Quitting part-way through a night restarts that night.
##
## Files: user://save_1.cfg .. save_3.cfg. (An old user://progress.cfg becomes slot 1.)

const SLOTS := 3
const START_COINS := 8

var slot := 0               ## the slot being played (1..3), 0 = none chosen yet
var data := {}              ## the current slot's contents (see _blank)
var skip_title := false     ## going straight into the next night (no title screen)


func _ready() -> void:
	_migrate_old_progress()


func _path(n: int) -> String:
	return "user://save_%d.cfg" % n


func _blank() -> Dictionary:
	return {"night": 1, "coins": START_COINS, "skipped": {}, "history": [],
		"started": Time.get_datetime_string_from_system(false, true),
		"saved": Time.get_datetime_string_from_system(false, true), "playtime": 0.0}


## What's in a slot (or {} if it's empty), for the title screen.
func peek(n: int) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(_path(n)) != OK:
		return {}
	var d := _blank()
	for k in d:
		d[k] = cfg.get_value("save", k, d[k])
	return d


func exists(n: int) -> bool:
	return FileAccess.file_exists(_path(n))


## The most recently saved slot (for CONTINUE), or 0.
func latest() -> int:
	var best := 0
	var best_t := ""
	for n in range(1, SLOTS + 1):
		var d := peek(n)
		if not d.is_empty() and str(d.saved) > best_t:
			best_t = str(d.saved)
			best = n
	return best


func new_game(n: int) -> void:
	slot = n
	data = _blank()
	_write()


func load_slot(n: int) -> bool:
	var d := peek(n)
	if d.is_empty():
		return false
	slot = n
	data = d
	return true


func delete_slot(n: int) -> void:
	if exists(n):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(n)))


## No slot picked (testing runs, screenshots): play in slot 1 without touching other slots.
func ensure_slot() -> void:
	if slot == 0:
		if not load_slot(1):
			new_game(1)


func night() -> int:
	return int(data.get("night", 1))


func coins() -> int:
	return int(data.get("coins", START_COINS))


## End of a night: record it and move on to the next one.
func finish_night(coins_left: int, wages: int, skipped_bills: Array) -> void:
	ensure_slot()
	var h: Array = data.history
	h.append({"night": night(), "wages": wages, "coins": coins_left, "skipped": skipped_bills})
	var sk: Dictionary = data.skipped
	for b in skipped_bills:
		sk[b] = int(sk.get(b, 0)) + 1
	data.coins = coins_left
	data.night = night() + 1
	_write()


## Testing menu / broke: set the coins or night directly.
func set_progress(coins_: int, night_: int) -> void:
	ensure_slot()
	data.coins = coins_
	data.night = night_
	_write()


func _process(delta: float) -> void:
	if slot != 0 and not get_tree().paused:
		data["playtime"] = float(data.get("playtime", 0.0)) + delta


func _write() -> void:
	data.saved = Time.get_datetime_string_from_system(false, true)
	var cfg := ConfigFile.new()
	for k in data:
		cfg.set_value("save", k, data[k])
	cfg.save(_path(slot))


func _migrate_old_progress() -> void:
	var old := "user://progress.cfg"
	if not FileAccess.file_exists(old) or exists(1):
		return
	var cfg := ConfigFile.new()
	if cfg.load(old) == OK:
		slot = 1
		data = _blank()
		data.coins = int(cfg.get_value("career", "coins", START_COINS))
		data.night = int(cfg.get_value("career", "night", 1))
		_write()
		slot = 0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(old))
