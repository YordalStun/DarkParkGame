extends Node
## Selectable dialog: an NPC says a line, then the player picks one of 2-4 numbered replies.
##
## BUILT FOR CO-OP FROM THE START (see docs/design/coop-notes.md):
##  * A conversation is plain DATA (dictionaries, strings, numbers): nothing in it is a Callable
##    or an object, so it can be sent over the network, saved, and checked.
##  * Only the HOST runs this node. Everyone else just sees what it emits.
##  * The ONLY way an answer gets in is submit_choice(index, from_player). A client's click becomes
##    an RPC to the host, which calls this. Anything from someone who isn't `owner` is ignored.
##  * Every option list has exactly one "safe" option. When the 20 second timer runs out, that
##    option is picked and the UI says so clearly (it is never silent).
##  * Everyone sees the same options: they depend on shared flags, not on which player is asking.
##  * Effects (coins, flags, risk, notes) are data too and are applied once, on the host, by effect_fn.
##
## A conversation (a "tree"):
##   {"id": "kevin_window", "player": "YOU",
##    "start": "a",
##    "nodes": {
##      "a": {"speaker": "Kevin", "text": "Evening.",
##            "timeout": 20.0,                       # optional, default DEFAULT_TIMEOUT, 0 = no timer
##            "options": [
##               {"text": "Evening. Card, please.", "next": "b", "safe": true},
##               {"text": "What's your dog called?", "next": "c",
##                "requires": "knows_dog",          # optional: only offered if this flag is set
##                "effects": [{"flag": "asked_dog"}, {"coins": 1}, {"risk": 5}]}]},
##      "b": {"speaker": "Kevin", "text": "Here you go.", "next": ""}}}      # "" or no options = end
##
## Effects: {"flag": name, "value": any (default true)}, {"coins": n}, {"risk": n}, {"note": text}.

signal options_ready(node_id: String, entries: Array, owner: int, seconds: float)  ## show the choice UI
signal tick(left: float, total: float)                                              ## the timer, every frame
signal chosen(node_id: String, index: int, owner: int, auto: bool)                  ## a choice was made
signal finished(result: Dictionary)

const DEFAULT_TIMEOUT := 20.0
const MIN_OPTIONS := 2
const MAX_OPTIONS := 4

## Set by the story: how lines are shown (a coroutine), how effects are applied, how flags are read.
var say_fn: Callable      ## (speaker: String, text: String, auto: bool, is_player: bool) -> awaitable
var effect_fn: Callable   ## (effect: Dictionary) -> void
var flag_fn: Callable     ## (flag: String) -> bool

var active := false
var talker := 0           ## the player id allowed to answer right now
var node_id := ""
var time_left := 0.0
var _total := 0.0
var _entries: Array = []  ## the visible options for the current node: [{text, index (in the node), safe}]
var _awaiting := false
var _picked := -1
var _picked_auto := false
signal _decided


# ------------------------------------------------------------------ checking a tree
## Returns a list of problems (empty if the tree is fine). Run it on every conversation in tests.
static func validate(tree: Dictionary) -> Array:
	var errs: Array = []
	var id: String = str(tree.get("id", "?"))
	if not tree.has("nodes") or not tree.has("start"):
		return ["%s: needs 'start' and 'nodes'" % id]
	var nodes: Dictionary = tree.nodes
	if not nodes.has(tree.start):
		errs.append("%s: start node '%s' doesn't exist" % [id, tree.start])
	for nid in nodes:
		var n: Dictionary = nodes[nid]
		if n.has("next") and str(n.next) != "" and not nodes.has(n.next):
			errs.append("%s/%s: next '%s' doesn't exist" % [id, nid, n.next])
		for e in n.get("effects", []):
			if not (e.has("flag") or e.has("coins") or e.has("risk") or e.has("note")):
				errs.append("%s/%s: unknown effect %s" % [id, nid, str(e)])
		if not n.has("options"):
			continue
		var opts: Array = n.options
		if opts.size() < MIN_OPTIONS or opts.size() > MAX_OPTIONS:
			errs.append("%s/%s: needs %d-%d options, has %d" % [id, nid, MIN_OPTIONS, MAX_OPTIONS, opts.size()])
		var safe := 0
		for o in opts:
			if not o.has("text"):
				errs.append("%s/%s: an option has no text" % [id, nid])
			if o.get("safe", false):
				safe += 1
				if o.has("requires"):
					errs.append("%s/%s: the safe option can't have a 'requires' (it must always be available)" % [id, nid])
			if o.has("next") and str(o.next) != "" and not nodes.has(o.next):
				errs.append("%s/%s: option goes to '%s', which doesn't exist" % [id, nid, o.next])
			for e in o.get("effects", []):
				if not (e.has("flag") or e.has("coins") or e.has("risk") or e.has("note")):
					errs.append("%s/%s: unknown effect %s" % [id, nid, str(e)])
		if safe != 1:
			errs.append("%s/%s: needs exactly one option marked \"safe\": true (used when the timer runs out), has %d" % [id, nid, safe])
	return errs


# ------------------------------------------------------------------ running a conversation
## Plays a conversation to the end. `p_owner` is the player who may answer (whoever opened the window,
## took the ID, answered the phone or walked up to the NPC). Returns the result:
##   {"id", "path": [{node, index, text, player, auto}], "effects": [...], "timeouts": n}
func run(tree: Dictionary, p_owner: int) -> Dictionary:
	var errs := validate(tree)
	if not errs.is_empty():
		push_error("Dialog problems: " + "; ".join(errs))
		return {"id": tree.get("id", "?"), "path": [], "effects": [], "timeouts": 0, "invalid": true}
	active = true
	talker = p_owner
	var result := {"id": tree.id, "path": [], "effects": [], "timeouts": 0}
	var player_name: String = tree.get("player", "YOU")
	var nodes: Dictionary = tree.nodes
	var current: String = tree.start
	while current != "" and nodes.has(current):
		node_id = current
		var n: Dictionary = nodes[current]
		if str(n.get("text", "")) != "":
			await say_fn.call(n.get("speaker", ""), n.text, false, false)
		# Effects on a line itself apply once it has been said (what the player learns by hearing it).
		for e in n.get("effects", []):
			result.effects.append(e)
			effect_fn.call(e)
		if not n.has("options"):
			current = str(n.get("next", ""))
			continue
		_entries = []
		var opts: Array = n.options
		for i in opts.size():
			var o: Dictionary = opts[i]
			if o.has("requires") and not flag_fn.call(o.requires):
				continue
			_entries.append({"text": o.text, "index": i, "safe": o.get("safe", false)})
		_total = float(n.get("timeout", DEFAULT_TIMEOUT))
		var idx := await _ask(current)
		var opt: Dictionary = opts[_entries[idx].index]
		result.path.append({"node": current, "index": _entries[idx].index, "text": opt.text, "player": talker, "auto": _picked_auto})
		if _picked_auto:
			result.timeouts += 1
		await say_fn.call(player_name, opt.text, _picked_auto, true)
		for e in opt.get("effects", []):
			result.effects.append(e)
			effect_fn.call(e)
		current = str(opt.get("next", ""))
	active = false
	node_id = ""
	finished.emit(result)
	return result


## Shows the options and waits for submit_choice() or the timer. Returns the index into _entries.
func _ask(nid: String) -> int:
	_picked = -1
	_picked_auto = false
	time_left = _total
	_awaiting = true
	options_ready.emit(nid, _entries.duplicate(true), talker, _total)
	await _decided
	_awaiting = false
	chosen.emit(nid, _picked, talker, _picked_auto)
	return _picked


## THE entry point for an answer. Local clicks and keys call it with the local player's id; in
## co-op a client's pick arrives as an RPC and the host calls this with that client's id.
## Returns true if the choice was accepted.
func submit_choice(entry_index: int, from_player: int) -> bool:
	if not _awaiting or from_player != talker:
		return false
	if entry_index < 0 or entry_index >= _entries.size():
		return false
	_picked = entry_index
	_picked_auto = false
	_decided.emit()
	return true


func _process(delta: float) -> void:
	if not _awaiting or _total <= 0.0 or get_tree().paused:
		return
	time_left = maxf(0.0, time_left - delta)
	tick.emit(time_left, _total)
	if time_left <= 0.0:
		# Out of time: the safe option is picked for them (and the UI says so).
		for i in _entries.size():
			if _entries[i].safe:
				_picked = i
		_picked_auto = true
		_decided.emit()
