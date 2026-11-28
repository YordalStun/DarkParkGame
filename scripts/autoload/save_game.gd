extends Node
## Save slots. The game saves between nights: when you press NEXT NIGHT on the end-of-shift
## screen, the slot gets the next night's number, the coins you have left, the bills you
## skipped and a line of history. Quitting part-way through a night restarts that night.
##
## Files: user://save_1.cfg .. save_3.cfg. (An old user://progress.cfg becomes slot 1.)

const SLOTS := 3
const START_COINS := 8
## Survival (single player): each bill is a meter of METER_MAX nights. Paying it fills it;
## skipping it costs one. A meter at 0 is game over (evicted / starving / ill from the cold).
const METER_MAX := 3
const BILL_COST := {"rent": 2, "food": 1, "heat": 1}   ## 4 a day: the 8-coin bank covers two days
## Reports to Dale: 5 = suspicious, 7 = last warning, 10 = fired. One is forgiven every 2 nights.
const REPORTS_SUSPICIOUS := 5
const REPORTS_WARNING := 7
const REPORTS_FIRED := 10
## Risk (hacking and stealing), 0-100: 100 = caught. Drops 20 a day.
const RISK_DECAY := 20

var slot := 0               ## the slot being played (1..3), 0 = none chosen yet
var data := {}              ## the current slot's contents (see _blank)
var skip_title := false     ## going straight into the next night (no title screen)
var guest := false          ## a friend in someone else's co-op game: nothing is saved (the host's save counts)

const COOP_NIGHT := 3       ## co-op starts on night three (it unlocks when night two is finished)


func _ready() -> void:
	_migrate_old_progress()


func _path(n: int) -> String:
	return "user://save_%d.cfg" % n


func _blank() -> Dictionary:
	return {"night": 1, "coins": START_COINS, "skipped": {}, "history": [], "upgrades": {},
		"meters": {"rent": METER_MAX, "food": METER_MAX, "heat": METER_MAX}, "reports": 0, "risk": 0,
		"started": Time.get_datetime_string_from_system(false, true),
		"saved": Time.get_datetime_string_from_system(false, true), "playtime": 0.0, "coop_unlocked": false}


## What's in a slot (or {} if it's empty), for the title screen.
func peek(n: int) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(_path(n)) != OK:
		return {}
	var d := _blank()
	for k in d:
		d[k] = cfg.get_value("save", k, d[k])
	# Everything else in the file too (the crate, story progress, tips seen...), not just the basics.
	if cfg.has_section("save"):
		for k in cfg.get_section_keys("save"):
			if not d.has(k):
				d[k] = cfg.get_value("save", k)
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
	guest = false
	slot = n
	data = _blank()
	_write()


## MULTIPLAYER on the title screen for someone who hasn't unlocked co-op yet: a fresh game that starts
## straight on night three, with co-op unlocked (their other slots are left alone).
func new_coop_game(n: int) -> void:
	new_game(n)
	data.night = COOP_NIGHT
	data.coop_unlocked = true
	_write()


## Co-op is open in this save (night two is done).
func coop_ready(d: Dictionary) -> bool:
	return not d.is_empty() and (bool(d.get("coop_unlocked", false)) or int(d.get("night", 1)) >= COOP_NIGHT)


## Any save slot with co-op unlocked.
func any_coop_unlocked() -> bool:
	for n in range(1, SLOTS + 1):
		if coop_ready(peek(n)):
			return true
	return false


## A friend joining someone else's game: play that night in memory only. Nothing is written.
func start_guest(night_: int, coins_: int) -> void:
	guest = true
	slot = 0
	data = _blank()
	data.night = night_
	data.coins = coins_
	data.coop_unlocked = true


func load_slot(n: int) -> bool:
	var d := peek(n)
	if d.is_empty():
		return false
	guest = false
	slot = n
	data = d
	return true


func delete_slot(n: int) -> void:
	if exists(n):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(n)))


## No slot picked (testing runs, screenshots): play in slot 1 without touching other slots.
func ensure_slot() -> void:
	if slot == 0 and not guest:
		if not load_slot(1):
			new_game(1)


func night() -> int:
	return int(data.get("night", 1))


func coins() -> int:
	return int(data.get("coins", START_COINS))


## Guide tips already shown in this save (so each appears once).
func tip_seen(id: String) -> bool:
	return bool((data.get("tips", {}) as Dictionary).get(id, false))


func mark_tip(id: String) -> void:
	var t: Dictionary = data.get("tips", {})
	t[id] = true
	data["tips"] = t
	if slot != 0:
		_write()


## Upgrades bought on the end-of-shift screen (e.g. "vehicle_log").
func has_upgrade(id: String) -> bool:
	return bool((data.get("upgrades", {}) as Dictionary).get(id, false))


func add_upgrade(id: String) -> void:
	ensure_slot()
	var u: Dictionary = data.get("upgrades", {})
	u[id] = true
	data["upgrades"] = u


func remove_upgrade(id: String) -> void:
	var u: Dictionary = data.get("upgrades", {})
	u.erase(id)
	data["upgrades"] = u
	if slot != 0:
		_write()


## Story progress kept between nights (the dealer note, Baxter's deal, the second hut...).
func story(key: String, default = false):
	return (data.get("story", {}) as Dictionary).get(key, default)


func set_story(key: String, value = true) -> void:
	var st: Dictionary = data.get("story", {})
	st[key] = value
	data["story"] = st
	if slot != 0:
		_write()


func meters() -> Dictionary:
	var m: Dictionary = data.get("meters", {})
	for k in BILL_COST:
		if not m.has(k):
			m[k] = METER_MAX
	data["meters"] = m
	return m


func reports() -> int:
	return int(data.get("reports", 0))


func risk() -> int:
	return int(data.get("risk", 0))


## The storage crate in the hut (night three on): up to CRATE_SIZE item ids, kept between nights.
const CRATE_SIZE := 10


func stash() -> Array:
	return data.get("stash", [])


func set_stash(ids: Array) -> void:
	data["stash"] = ids.slice(0, CRATE_SIZE)   # (spaces are checked by the crate; this is a backstop)
	if slot != 0:
		_write()


func crate_hidden() -> bool:
	return bool(data.get("crate_hidden", false))


func set_crate_hidden(h: bool) -> void:
	data["crate_hidden"] = h
	if slot != 0:
		_write()


## A customer complained to Dale (saved straight away).
func add_report() -> int:
	data["reports"] = reports() + 1
	if slot != 0:
		_write()
	return reports()


## The meters after tonight's bills: paid ones refill, skipped ones drop by one.
static func meters_after(now: Dictionary, paid: Dictionary) -> Dictionary:
	var out := {}
	for k in BILL_COST:
		out[k] = METER_MAX if paid.get(k, true) else maxi(0, int(now.get(k, METER_MAX)) - 1)
	return out


## End of a night: record it and move on to the next one.
func finish_night(coins_left: int, wages: int, skipped_bills: Array, risk_now := -1) -> void:
	ensure_slot()
	var paid := {}
	for k in BILL_COST:
		paid[k] = not skipped_bills.has(k.capitalize())
	data["meters"] = meters_after(meters(), paid)
	if risk_now >= 0:
		data["risk"] = maxi(0, risk_now - RISK_DECAY)
	if night() % 2 == 0 and reports() > 0:
		data["reports"] = reports() - 1   # forgiveness: one report every two nights
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
	if guest or slot == 0:
		return
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
