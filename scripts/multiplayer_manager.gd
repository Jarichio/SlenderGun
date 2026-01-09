extends Node

## Recieved from every player when we join.
## Acts like a richer peer_connected.
signal player_connected(peer_id, player_data)
## Light wrapper around peer_disconnected.
signal player_disconnected(peer_id)

signal server_connected
signal server_disconnected
signal join_failed

var _connected_to_server: bool = false
var connected_players: Dictionary[int, Dictionary] = {}
var local_player = {"name": "Local Unset Name"}

func _ready() -> void:	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_join_ok)
	multiplayer.connection_failed.connect(_on_join_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# When a peer connects we send them our own player data.
func _on_peer_connected(peer_id):
	_register_player.rpc_id(peer_id, local_player)
# And they store it
@rpc("any_peer", "call_local", "reliable")
func _register_player(player_data):
	var player_peer_id = multiplayer.get_remote_sender_id()
	connected_players[player_peer_id] = player_data
	print(multiplayer.get_unique_id(), " got peer connection ", player_peer_id)
	player_connected.emit(player_peer_id, player_data)

func _on_peer_disconnected(peer_id):
	print("Player %s disconnected" % [peer_id])
	connected_players.erase(peer_id)
	player_disconnected.emit(peer_id)
	
func _on_join_ok():
	print("Joined server")
	_connected_to_server = true
	server_connected.emit()
	_register_player.rpc_id(multiplayer.get_unique_id(), local_player) # Register ourselves (the client player)
func _on_join_fail():
	print("Failed to join server")
	join_failed.emit()
	leave()
func _on_server_disconnected():
	print("Disconnected from server")
	leave()

func join(address: String, port: int) -> Error:
	print("Attempting to connect to: ", address, ":", port)
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	return OK

func host(port: int, max_clients: int = 32) -> Error:
	print("Attempting to host on port: ", port)
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, max_clients)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	server_connected.emit()
	_register_player.rpc_id(1, local_player) # Register ourselves (the host player)
	return OK
	
func leave() -> void:
	for peer_id in MultiplayerManager.connected_players.keys():
		_on_peer_disconnected(peer_id)
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_connected_to_server = false
	server_disconnected.emit()
	
func is_host() -> bool:
	return multiplayer.is_server()
	
func is_in_server() -> bool:
	return _connected_to_server

@rpc("authority", "call_local", "reliable")
func load_into(scene_path: String):
	get_tree().change_scene_to_file(scene_path)
