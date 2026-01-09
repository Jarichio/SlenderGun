extends Node3D

@export var current_scene: PackedScene
@export var player_scene: PackedScene
@export var player_container: Node
@export var spawn_area: Vector3 = Vector3.ONE

var _rng = RandomNumberGenerator.new()

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Spawn all the players
	print(MultiplayerManager.connected_players)
	for player_id in MultiplayerManager.connected_players.keys():
		add_player(player_id)
	# Handle subsequent player join/leave
	MultiplayerManager.player_connected.connect(func (peer_id):
		MultiplayerManager.load_into.rpc_id(peer_id, current_scene.resource_path) # We also gotta send them here
		add_player(peer_id))
	MultiplayerManager.player_disconnected.connect(remove_player)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = (
			Input.MOUSE_MODE_CAPTURED 
			if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE 
			else Input.MOUSE_MODE_VISIBLE
		)

func _get_random_spawn():
	var x = _rng.randf_range(-spawn_area.x, spawn_area.x)
	var y = _rng.randf_range(-spawn_area.y, spawn_area.y)
	var z = _rng.randf_range(-spawn_area.z, spawn_area.z)
	return Vector3(x, y, z)

func add_player(peer_id):
	if Engine.is_editor_hint():
		return
	var new_player: Node3D = player_scene.instantiate()
	new_player.name = str(peer_id)
	player_container.add_child(new_player, true)
	print("Added player node")
	new_player.global_position += _get_random_spawn()

func remove_player(peer_id):
	if Engine.is_editor_hint():
		return
	var player_node = player_container.get_node(peer_id)
	if player_node:
		player_container.remove_child(player_node)
		print("Removed player node")
