extends Node
## The hospital side hustle (night three on): connect to Ashford General's remote gateway from the PC,
## log in with a password guessed from what the visitors told you, and download files.
##
## CO-OP RULES (docs/design/coop-notes.md): this runs on the HOST only. Every action takes the id of the
## player who did it and goes through one function (connect_to / login / start_download); the PC's
## owner (whoever started using it first) is the only one allowed to act, everyone else just watches the
## screen. All state is plain data in `state`, so clients can be sent it.
##
## Risk: every action raises story.risk (0-100). What happens at 100 is still to be decided (see
## docs/design/hacking-system.md); for now the session is cut and the gateway is locked for the night.

signal changed                      ## anything in `state` changed (the app redraws)
signal download_finished(file_id: String)
signal message(msg: String)         ## co-op guest: the host's answer to what we asked

const GATEWAY_IP := "10.113.7.20"
const USER_ID := "K.PLATT"          ## the porter whose account is easy to guess
const PASSWORD := "BISCUIT"         ## his dog's name (the clue is learned from him at the window)
const MAX_WRONG := 3
const LOCK_SECONDS := 60.0

## What each clue flag says (shown in the login window's "what you know" box).
const CLUES := {
	"clue_pet_biscuit": "Kevin Platt (porter): his dog is called Biscuit.",
}

## Files on the gateway: id -> {name, what, seconds to download, risk it adds, the text it contains}.
const FILES := {
	"rota": {"name": "ROTA.TXT", "what": "Staff rota, this month", "seconds": 25.0, "risk": 4},
	"visitors": {"name": "VISITORS.DAT", "what": "Visitor and vehicle log, tonight", "seconds": 45.0, "risk": 8},
	"patients": {"name": "PATIENTS.DB", "what": "Patient records (ward 7)", "seconds": 110.0, "risk": 15},
}

var story
var state := {
	"connected": false, "logged_in": false, "wrong": 0, "lock_left": 0.0, "dead": false,
	"downloading": "", "progress": 0.0, "downloaded": [], "log": [],
}
var pc_owner := 0                   ## the player using the PC (0 = nobody); set by the story
## Co-op guest: the host runs the real gateway. Actions are sent to it, and `state` is what it sends back.
var remote := false


func _ask_host(args: Array, waiting: String) -> Dictionary:
	Net.request("hack", args)
	return {"ok": false, "msg": waiting, "pending": true}


func setup(p_story) -> void:
	story = p_story


func _log(text: String) -> void:
	state.log.append("%s  %s" % [NightClock.time_text(), text])
	if state.log.size() > 12:
		state.log.pop_front()
	changed.emit()


## Checks that this player may use the PC right now.
func _allowed(player_id: int) -> String:
	if state.dead:
		return "The gateway is not answering. Try again tomorrow."
	if pc_owner != 0 and player_id != pc_owner:
		return "The PC is being used by P%d." % pc_owner
	return ""


func connect_to(ip: String, player_id: int) -> Dictionary:
	if remote:
		return _ask_host(["connect", ip], "Dialling %s..." % ip.strip_edges())
	var why := _allowed(player_id)
	if why != "":
		return {"ok": false, "msg": why}
	story.add_risk(2)
	if ip.strip_edges() != GATEWAY_IP:
		_log("DIAL %s - NO ANSWER" % ip.strip_edges())
		return {"ok": false, "msg": "No answer from %s." % ip.strip_edges()}
	state.connected = true
	_log("CONNECTED %s" % GATEWAY_IP)
	return {"ok": true, "msg": "CONNECT 2400. Ashford General Hospital remote gateway."}


func login(user: String, password: String, player_id: int) -> Dictionary:
	if remote:
		return _ask_host(["login", user, password], "Checking...")
	var why := _allowed(player_id)
	if why != "":
		return {"ok": false, "msg": why}
	if not state.connected:
		return {"ok": false, "msg": "Not connected."}
	if state.lock_left > 0.0:
		return {"ok": false, "msg": "Too many tries. Locked for %d seconds." % int(ceil(state.lock_left))}
	if user.strip_edges().to_upper() == USER_ID and password.strip_edges().to_upper() == PASSWORD:
		state.logged_in = true
		state.wrong = 0
		story.add_risk(3)
		_log("LOGIN %s" % USER_ID)
		return {"ok": true, "msg": "Welcome, %s." % USER_ID}
	state.wrong += 1
	story.add_risk(6)
	_log("LOGIN FAILED (%s)" % user.strip_edges().to_upper())
	if state.wrong >= MAX_WRONG:
		state.lock_left = LOCK_SECONDS
		state.wrong = 0
		return {"ok": false, "msg": "ACCESS DENIED. Account locked for %d seconds." % int(LOCK_SECONDS)}
	return {"ok": false, "msg": "ACCESS DENIED. %d tries left." % (MAX_WRONG - state.wrong)}


func start_download(file_id: String, player_id: int) -> Dictionary:
	if remote:
		return _ask_host(["download", file_id], "Requesting the file...")
	var why := _allowed(player_id)
	if why != "":
		return {"ok": false, "msg": why}
	if not state.logged_in or not FILES.has(file_id):
		return {"ok": false, "msg": "Not logged in."}
	if state.downloading != "":
		return {"ok": false, "msg": "A transfer is already running."}
	if file_id in state.downloaded:
		return {"ok": false, "msg": "You already have that file."}
	state.downloading = file_id
	state.progress = 0.0
	story.add_risk(int(FILES[file_id].risk))
	_log("DOWNLOAD %s" % FILES[file_id].name)
	return {"ok": true, "msg": "Transfer started."}


## Drops the session (the player closes the window, or the risk meter fills up).
func hang_up(reason := "") -> void:
	if remote:
		Net.request("hack", ["hang_up", reason])
		return
	state.connected = false
	state.logged_in = false
	state.downloading = ""
	state.progress = 0.0
	if reason != "":
		_log(reason)
	changed.emit()


## Called by the story when the risk reaches 100: the session is cut and the gateway is shut for the night.
func caught() -> void:
	state.dead = true
	hang_up("SECURITY ALERT - SESSION TERMINATED")


func _process(delta: float) -> void:
	if remote or (is_inside_tree() and get_tree().paused):
		return
	if state.lock_left > 0.0:
		state.lock_left = maxf(0.0, state.lock_left - delta)
	if state.downloading != "":
		var f: Dictionary = FILES[state.downloading]
		state.progress = minf(1.0, state.progress + delta / float(f.seconds))
		if state.progress >= 1.0:
			var id: String = state.downloading
			state.downloaded.append(id)
			state.downloading = ""
			state.progress = 0.0
			_log("DOWNLOAD COMPLETE %s" % FILES[id].name)
			download_finished.emit(id)
	changed.emit()


## The text of a downloaded file (built from tonight's real arrivals, so it matches the story).
func file_text(file_id: String) -> String:
	match file_id:
		"rota":
			return "ASHFORD GENERAL - PORTERS AND NIGHT STAFF - ROTA\n------------------------------------------------\nPIKE, S      Ward 7      Fri-Sun   NIGHTS\nADEYEMI, M   Portering   Fri-Sat   NIGHTS\nPLATT, K     Portering   (agency)  COVER\nDOYLE, M     Portering   OFF SICK until further notice\nMARSH, Dr H  A&E         Fri       ON CALL\nLOWE, J      Pharmacy    OFF - pharmacy closed Fri\n"
		"visitors":
			var t := "VISITOR AND VEHICLE LOG - LOT C BARRIER\n--------------------------------------\nname              staff no  vehicle     usual arrival\n"
			for p in story.arrivals:
				if p.get("ghost", false):
					continue
				t += "%-17s %-9s %-11s %s\n" % [p.name, p.get("staff_no", "?"), p.get("reg", "?"), "%02d:%02d" % [(23 + int(absi(hash(p.name)) % 2)) % 24, 10 + int(absi(hash(p.name)) % 45)]]
			t += "\nNOTE: DOYLE, M - car D501 NKA not seen since Tuesday.\n"
			return t
		"patients":
			return "WARD 7 - CONFIDENTIAL\n----------------------\n(Download incomplete: 31 records recovered.)\n\nBed 4: name withheld. Admitted 11 Oct. Visitors: none permitted.\nBed 9: name withheld. Admitted 12 Oct. Visitor log: R. KESSLER (x3).\n"
	return ""
