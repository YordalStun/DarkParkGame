extends SceneTree
## Checks the end-of-night scoring and the babble generator without a window.
##   godot --headless --path . -s tools/scoring_test.gd

func _initialize() -> void:
	var Shift = load("res://scripts/story/shift.gd")
	var ok := true
	# Everyone right, every plate logged (one typed with no space, one lowercase).
	var s = Shift.new()
	s.results = _results(["admitted", "admitted", "refused", "admitted", "refused", "admitted", "refused"])
	for r in s.results:
		r.checked = true
	for reg in ["E412KTV", "c771 pfm", "F23 HLM", "D310YXE"]:
		s.log_entry(reg, "x")
	var ev: Dictionary = s.evaluate()
	ok = _check("perfect night: 8+4+3", ev.total == 15 and ev.bonus == 3 and ev.success, ev) and ok
	# One impostor let in (-2), one plate missing: no bonus.
	s = Shift.new()
	s.results = _results(["admitted", "admitted", "admitted", "admitted", "refused", "admitted", "refused"])
	for reg in ["E412 KTV", "C771 PFM", "B908 RWD"]:
		s.log_entry(reg, "x")
	ev = s.evaluate()
	ok = _check("impostor in, plate missing: 8+4-2 and no bonus", ev.total == 10 and ev.bonus == 0 and not ev.success and ev.wrong_in == 1, ev) and ok
	# Nobody let in: no bonus, not a success.
	s = Shift.new()
	s.results = _results(["refused", "refused", "refused", "refused", "refused", "refused", "refused"])
	ev = s.evaluate()
	ok = _check("all refused: 8, no bonus, fail", ev.total == 8 and ev.bonus == 0 and not ev.success and ev.wrong.size() == 4, ev) and ok

	var Babble = load("res://scripts/ui/babble.gd")
	var t0 := Time.get_ticks_msec()
	var w: AudioStreamWAV = Babble.make("Evening, Dave. Still flooded over our side, then?", "Sandra Pike")
	var ms := Time.get_ticks_msec() - t0
	var secs: float = w.data.size() / 2.0 / w.mix_rate
	print("BABBLE %.2fs of audio made in %d ms" % [secs, ms])
	ok = _check("babble length sensible", secs > 1.5 and secs < 8.0 and ms < 400, secs) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)


func _results(decisions: Array) -> Array:
	var regs := ["E412 KTV", "C771 PFM", "B908 RWD", "F23 HLM", "A456 GNB", "D310 YXE", "TKM 117"]
	var admit := [true, true, false, true, false, true, false]
	var out := []
	for i in 7:
		out.append({"name": "P%d" % i, "reg": regs[i], "admit": admit[i], "decided": decisions[i], "checked": true, "why": "because"})
	return out


func _check(label: String, cond: bool, info) -> bool:
	print(("PASS " if cond else "FAIL ") + label + ("" if cond else "  " + str(info)))
	return cond
