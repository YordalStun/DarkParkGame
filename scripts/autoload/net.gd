extends Node
## Co-op networking (night three on). Godot's built-in ENet multiplayer: one player HOSTS, up to three
## friends JOIN by typing the host's IP address and port. Nobody else's server is involved, so the host
## needs a LAN, port forwarding, or a virtual LAN such as Hamachi or ZeroTier.
##
## Rules (docs/design/coop-notes.md):
##  * The host runs the story. Everyone else sends what they DO (`request`) and shows what the host
##    says happened (`event`).
##  * Joining is lobby only: once the night starts, new connections are refused.
##  * The host's save is the only one that changes. Friends play as guests and keep nothing.
##
## Everything goes through this autoload, so the RPC paths (/root/Net) are the same on every machine.
##
##   Net.host(24680)                     # start a lobby
##   Net.join("192.168.1.20", 24680)     # join one
##   Net.send("notify", ["Hello", 4.0])  # host -> everyone else (Net.event on their side)
##   Net.request("phone", [])            # client -> host (Net.request_in on the host)

signal lobby_changed                       ## someone joined or left the lobby
signal joined                              ## (client) the host accepted us
signal join_failed(why: String)            ## (client) couldn't connect, or the host turned us away
signal disconnected(why: String)           ## (client) the host left / (host) the lobby was closed
signal player_left(id: int)                ## someone left (in the lobby or mid-night)
signal begin(night: int, coins: int)       ## the host pressed START: load the night
signal event(name: String, args: Array)    ## (client) something happened in the host's game
signal request_in(from_id: int, name: String, args: Array)   ## (host) a client did something
signal pose_in(from_id: int, xf: Transform3D, state: int)    ## where another guard is

const DEFAULT_PORT := 24680
const MAX_PLAYERS := 4
const PROTOCOL := 1     ## bump when the messages change, so old builds can't join new ones

var players := {}       ## id -> {"guard": 0..3}; the host is always id 1, guard 0
var in_game := false    ## the night has started (no more joining)
var port := DEFAULT_PORT
var last_error := ""    ## shown on the title screen after being dropped
var ready_ids := {}     ## (host) who has finished loading tonight's night
var _hosting := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _fail("Couldn't reach the host. Check the IP address and port, and that the host's firewall lets the game through."))
	multiplayer.server_disconnected.connect(func():
		var was_game := in_game
		_reset()
		last_error = "The host left the game." if was_game else "The host closed the lobby."
		disconnected.emit(last_error))


# ------------------------------------------------------------------ state
func active() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) \
		and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_host() -> bool:
	return _hosting


## A client in a co-op game (not the host, not solo).
func is_guest() -> bool:
	return active() and not _hosting


func my_id() -> int:
	return multiplayer.get_unique_id() if active() else 1


func guard_of(id: int) -> int:
	return int(players.get(id, {}).get("guard", 0))


## "P1".."P4": the number on the guard's back and in their colour.
func label(id: int) -> String:
	return "P%d" % (guard_of(id) + 1)


func ids() -> Array:
	var a := players.keys()
	a.sort()
	return a


func count() -> int:
	return maxi(1, players.size())


# ------------------------------------------------------------------ host / join / leave
func host(p_port := DEFAULT_PORT) -> String:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(p_port, MAX_PLAYERS - 1)
	if err != OK:
		return "Couldn't open port %d (is another copy of the game hosting already?)." % p_port
	multiplayer.multiplayer_peer = peer
	port = p_port
	_hosting = true
	in_game = false
	players = {1: {"guard": 0}}
	lobby_changed.emit()
	return ""


func join(ip: String, p_port := DEFAULT_PORT) -> String:
	leave()
	ip = ip.strip_edges()
	if ip == "":
		return "Type the host's IP address."
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, p_port)
	if err != OK:
		return "That address doesn't look right."
	multiplayer.multiplayer_peer = peer
	port = p_port
	_hosting = false
	return ""


func leave() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	_reset()


func _reset() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {}
	ready_ids = {}
	in_game = false
	_hosting = false


func _fail(why: String) -> void:
	_reset()
	last_error = why
	join_failed.emit(why)


## Host: START. Locks the lobby and tells everyone (including us) to load the night.
func start_game(night: int, coins: int) -> void:
	if not _hosting:
		return
	in_game = true
	ready_ids = {1: true}
	(multiplayer.multiplayer_peer as ENetMultiplayerPeer).refuse_new_connections = true
	_begin.rpc(night, coins)


## The host's addresses to tell friends (LAN first). Loopback is left out.
func local_ips() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		if a.contains(":") or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		out.append(a)
	out.sort_custom(func(x, y): return _lan_rank(x) < _lan_rank(y))
	return out


func _lan_rank(a: String) -> int:
	if a.begins_with("192.168."):
		return 0
	if a.begins_with("10."):
		return 1
	if a.begins_with("172."):
		return 2
	return 3


# ------------------------------------------------------------------ connection handshake
func _on_connected() -> void:
	_hello.rpc_id(1, PROTOCOL)


func _on_peer_connected(_id: int) -> void:
	pass   # the client says hello first; nothing happens until then


func _on_peer_disconnected(id: int) -> void:
	if not players.has(id):
		return
	players.erase(id)
	ready_ids.erase(id)
	if _hosting:
		_lobby.rpc(players)
	lobby_changed.emit()
	player_left.emit(id)


@rpc("any_peer", "reliable")
func _hello(protocol: int) -> void:
	if not _hosting:
		return
	var id := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL:
		_refused.rpc_id(id, "The host is running a different version of the game.")
		_kick_later(id)
		return
	if in_game:
		_refused.rpc_id(id, "That game has already started. Friends can only join from the lobby.")
		_kick_later(id)
		return
	if players.size() >= MAX_PLAYERS:
		_refused.rpc_id(id, "That game is full (4 guards).")
		_kick_later(id)
		return
	var used := {}
	for p in players.values():
		used[int(p.guard)] = true
	var g := 0
	while used.has(g):
		g += 1
	players[id] = {"guard": g}
	_lobby.rpc(players)
	lobby_changed.emit()


func _kick_later(id: int) -> void:
	await get_tree().create_timer(0.5).timeout
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)


@rpc("authority", "reliable")
func _refused(why: String) -> void:
	_fail(why)


@rpc("authority", "reliable")
func _lobby(p_players: Dictionary) -> void:
	var first := players.is_empty()
	players = p_players
	if first and players.has(my_id()):
		joined.emit()
	lobby_changed.emit()


@rpc("authority", "call_local", "reliable")
func _begin(night: int, coins: int) -> void:
	in_game = true
	begin.emit(night, coins)


# ------------------------------------------------------------------ in-game messages
## Host -> every client: something happened (a car arrived, a line of dialog, the gate opened...).
func send(name: String, args: Array = []) -> void:
	if _hosting and active() and players.size() > 1:
		_event.rpc(name, args)


## Host -> one client.
func send_to(id: int, name: String, args: Array = []) -> void:
	if _hosting and active() and id != 1 and players.has(id):
		_event.rpc_id(id, name, args)


## Client -> host: the player did something. The host checks it and acts.
func request(name: String, args: Array = []) -> void:
	if active() and not _hosting:
		_request.rpc_id(1, name, args)


@rpc("authority", "reliable")
func _event(name: String, args: Array) -> void:
	event.emit(name, args)


@rpc("any_peer", "reliable")
func _request(name: String, args: Array) -> void:
	if not _hosting:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	if name == "ready":
		ready_ids[id] = true
	request_in.emit(id, name, args)


## Where this player's head is (sent ~15 times a second, newest wins).
func send_pose(xf: Transform3D, state: int) -> void:
	if active() and players.size() > 1:
		_pose.rpc(xf, state)


## (SceneMultiplayer relays a client's broadcast through the host to the other clients.)
@rpc("any_peer", "unreliable_ordered")
func _pose(xf: Transform3D, state: int) -> void:
	pose_in.emit(multiplayer.get_remote_sender_id(), xf, state)
