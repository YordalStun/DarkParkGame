extends SceneTree
## Checks the selectable-dialog rules without a window.
##   godot --headless --path . -s tools/dialog_test.gd
const Dialog := preload("res://scripts/story/dialog.gd")
const Samples := preload("res://scripts/story/dialogs/samples.gd")

var _ok := true
var _flags := {}
var _coins := 0
var _said: Array = []
var _d: Node


func _initialize() -> void:
	_run()


func _check(label: String, cond: bool, info = "") -> void:
	print(("PASS " if cond else "FAIL ") + label + ("" if cond else "  " + str(info)))
	_ok = _ok and cond


func _new_runner() -> Node:
	if _d:
		_d.queue_free()
	_flags = {}
	_coins = 0
	_said = []
	_d = Dialog.new()
	_d.say_fn = func(speaker: String, text: String, auto: bool, is_player: bool): _said.append([speaker, text, auto, is_player])
	_d.effect_fn = func(e: Dictionary):
		if e.has("flag"):
			_flags[e.flag] = e.get("value", true)
		if e.has("coins"):
			_coins += int(e.coins)
	_d.flag_fn = func(f: String) -> bool: return bool(_flags.get(f, false))
	root.add_child(_d)
	return _d


func _run() -> void:
	# 1. Every sample conversation is valid.
	var samples := {"window": Samples.window(), "phone": Samples.phone(), "patrol": Samples.patrol(),
		"doris": load("res://scripts/story/dialogs/doris.gd").window()}
	for name in samples:
		var errs: Array = Dialog.validate(samples[name])
		_check("sample '%s' is valid" % name, errs.is_empty(), errs)
	# 2. Bad trees are caught.
	var bad := {"id": "bad", "start": "a", "nodes": {"a": {"text": "x", "options": [{"text": "only one", "safe": true}]}}}
	_check("one option is rejected", not Dialog.validate(bad).is_empty())
	var nosafe := {"id": "nosafe", "start": "a", "nodes": {"a": {"text": "x", "options": [{"text": "a"}, {"text": "b"}]}}}
	_check("no safe option is rejected", not Dialog.validate(nosafe).is_empty())
	var five := {"id": "five", "start": "a", "nodes": {"a": {"options": [{"text": "1", "safe": true}, {"text": "2"}, {"text": "3"}, {"text": "4"}, {"text": "5"}]}}}
	_check("five options are rejected", not Dialog.validate(five).is_empty())

	# 3. The owner picks; effects are applied; the conditional option is hidden without its flag.
	var d := _new_runner()
	var shown: Array = []
	d.options_ready.connect(func(_nid, entries, _o, _s): shown.append(entries.size()))
	var t := Samples.patrol()
	_start(d, t, 1)
	await process_frame
	_check("a stranger can't answer", not d.submit_choice(0, 2))
	_check("a bad index is refused", not d.submit_choice(9, 1))
	_check("the owner can answer", d.submit_choice(1, 1))   # "Mind your own business" -> risk effect (ignored by this stub)
	var res := await _result()
	_check("conditional option hidden without the flag (2 shown)", shown[0] == 2, shown)
	_check("the path is recorded", res.path.size() == 1 and res.path[0].index == 1 and not res.path[0].auto, res)

	# 4. With the flag the third option appears and its effects apply.
	d = _new_runner()
	_flags["clue_pet_biscuit"] = true
	shown = []
	d.options_ready.connect(func(_nid, entries, _o, _s): shown.append(entries.size()))
	_start(d, Samples.patrol(), 1)
	await process_frame
	d.submit_choice(2, 1)
	res = await _result()
	_check("conditional option appears with the flag (3 shown)", shown[0] == 3, shown)
	_check("effects applied once (coins +2, flag set)", _coins == 2 and _flags.get("stranger_knows_dog", false), [_coins, _flags])

	# 5. Out of time: the safe option is picked and flagged as automatic, and the line says so.
	d = _new_runner()
	var quick := {"id": "quick", "start": "a", "nodes": {"a": {"speaker": "NPC", "text": "Well?", "timeout": 0.3, "options": [
		{"text": "Risky", "next": "", "effects": [{"coins": -5}]}, {"text": "Safe", "next": "", "safe": true}]}}}
	_start(d, quick, 1)
	res = await _result()
	_check("timeout picks the safe option", res.path[0].text == "Safe" and res.path[0].auto and res.timeouts == 1, res)
	_check("the auto answer is announced as automatic", _said.back()[2] == true and _said.back()[3] == true, _said)
	_check("the risky effect did not run", _coins == 0, _coins)

	# 6. Answers can't be submitted when nothing is being asked.
	_check("no answer accepted when idle", not d.submit_choice(0, 1))

	print("RESULT ", "PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)


## Starts a conversation without waiting for it (the result comes from the `finished` signal).
func _start(d: Node, tree: Dictionary, owner_id: int) -> void:
	_res = {}
	d.finished.connect(func(r): _res = r)
	d.call("run", tree, owner_id)


var _res := {}


## Waits (up to 3 seconds) for the conversation started with _start() to finish.
func _result() -> Dictionary:
	var n := 0
	while _res.is_empty() and n < 600:
		await process_frame
		n += 1
	return _res
