extends SceneTree
## Checks the hospital hack rules without a window.
##   godot --headless --path . -s tools/hack_test.gd
var Hack

var _ok := true


class FakeStory extends Node:
	var risk := 0
	var flags := {}
	var arrivals: Array = [{"name": "Kevin Platt", "staff_no": "40612", "reg": "B908 RWD"}]
	var hack: Node
	func add_risk(n: int) -> void:
		risk = clampi(risk + n, 0, 100)
		if risk >= 100 and not hack.state.dead:
			hack.caught()


func _check(label: String, cond: bool, info = "") -> void:
	print(("PASS " if cond else "FAIL ") + label + ("" if cond else "  " + str(info)))
	_ok = _ok and cond


func _initialize() -> void:
	Hack = load("res://scripts/story/hack.gd")   # loaded at run time so the autoloads exist
	var st := FakeStory.new()
	root.add_child(st)
	var h: Node = Hack.new()
	root.add_child(h)
	h.setup(st)
	st.hack = h

	_check("wrong IP gets no answer", not h.connect_to("1.2.3.4", 1).ok and not h.state.connected)
	_check("right IP connects", h.connect_to(Hack.GATEWAY_IP, 1).ok and h.state.connected)
	_check("can't download before logging in", not h.start_download("rota", 1).ok)
	var r: Dictionary = h.login("K.PLATT", "rex", 1)
	_check("wrong password refused, 2 tries left", not r.ok and "2 tries" in r.msg, r)
	h.login("K.PLATT", "fido", 1)
	r = h.login("K.PLATT", "spot", 1)
	_check("third wrong try locks the account", "locked" in r.msg.to_lower() and h.state.lock_left > 0.0, r)
	_check("locked: even the right password fails", not h.login("K.PLATT", "biscuit", 1).ok)
	h.state.lock_left = 0.0
	_check("user id and password are not case sensitive", h.login("k.platt", "Biscuit", 1).ok and h.state.logged_in)
	_check("wrong tries added risk", st.risk > 15, st.risk)

	# PC ownership: only the player using the PC may act.
	h.pc_owner = 2
	_check("another player can't act while P2 owns the PC", not h.start_download("rota", 1).ok)
	_check("the owner can", h.start_download("rota", 2).ok)
	_check("only one transfer at a time", not h.start_download("visitors", 2).ok)

	# Run the download to the end.
	var n := 0
	while h.state.downloading != "" and n < 2000:
		h._process(1.0)
		n += 1
	_check("download finishes and is recorded", "rota" in h.state.downloaded and h.state.downloading == "")
	_check("downloaded file has content", h.file_text("rota").contains("PLATT") and h.file_text("visitors").contains("B908 RWD"))
	_check("can't download the same file twice", not h.start_download("rota", 2).ok)

	# Risk reaching 100 cuts the session for the night.
	st.add_risk(100)
	_check("risk 100 ends the session", h.state.dead and not h.state.connected)
	_check("nothing works afterwards", not h.connect_to(Hack.GATEWAY_IP, 2).ok)

	print("RESULT ", "PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
