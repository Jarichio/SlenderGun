extends Control

@export var scene_to_load: PackedScene
@export var default_ip: String = "127.0.0.1"
@export var default_port: int = 7000

@onready var username_input: LineEdit = $VerticalBox/Body/Inputs/NameInput

@onready var join_address_input: LineEdit = $VerticalBox/Body/Inputs/JoinVBox/JoinHBox/IpInput
@onready var join_button: Button = $VerticalBox/Body/Inputs/JoinVBox/JoinHBox/JoinButton
@onready var join_progress: ProgressBar = $VerticalBox/Body/Inputs/JoinVBox/ProgressBar

@onready var host_port_input: LineEdit = $VerticalBox/Body/Inputs/HostHBox/PortInput
@onready var host_button: Button = $VerticalBox/Body/Inputs/HostHBox/HostButton

@onready var disconnect_button: Button = $VerticalBox/Body/Inputs/DisconnectButton
@onready var start_button: Button = $VerticalBox/Body/Inputs/StartButton

@onready var player_list: ItemList = $VerticalBox/Body/LobbyList/Aligner/PlayerList
@onready var lobby_timer: LabelTimer = $VerticalBox/Body/LobbyList/Aligner/TitleBar/Timer
@onready var player_counter: Label = $VerticalBox/Body/LobbyList/Aligner/TitleBar/PlayerCounter

var ip_regex = RegEx.create_from_string("^\\s*(?<ip>.+?)(?::(?<port>[0-9]+))?\\s*$")
var port_regex = RegEx.create_from_string("^\\s*([0-9]+)\\s*$")

func _ready() -> void:
	join_address_input.text = "%s:%d" % [default_ip, default_port]
	host_port_input.text = "%d" % default_port
	
	MultiplayerManager.player_connected.connect(func(peer_id,_b): 
		print("player_connected: ", peer_id)
		update_lobby_list())
	MultiplayerManager.player_disconnected.connect(func(peer_id): 
		print("player_disconnected: ", peer_id)
		update_lobby_list())
		
	MultiplayerManager.server_connected.connect(_server_connected)
	MultiplayerManager.server_disconnected.connect(_server_disconnected)
	MultiplayerManager.join_failed.connect(func(): join_progress.visible = false)

func update_lobby_list():
	player_counter.text = "%d" % MultiplayerManager.connected_players.size()
	player_list.clear()
	
	var peer_ids = MultiplayerManager.connected_players.keys();
	peer_ids.sort()
	for peer_id in peer_ids:
		player_list.add_item(MultiplayerManager.connected_players[peer_id].name)

func _server_connected():
	print("server_connected")
	start_button.disabled = not MultiplayerManager.is_host()
	disconnect_button.disabled = false
	username_input.editable = false
	join_address_input.editable = false
	host_port_input.editable = false
	join_button.disabled = true
	host_button.disabled = true
	join_progress.visible = false
	
func _server_disconnected():
	print("server_disconnected")
	start_button.disabled = true
	disconnect_button.disabled = true
	username_input.editable = true
	join_address_input.editable = true
	host_port_input.editable = true
	join_button.disabled = username_input.text.is_empty()
	host_button.disabled = username_input.text.is_empty()
	join_progress.visible = false

func username_enter(text: String):
	MultiplayerManager.local_player.name = text
	join_button.disabled = text.is_empty()
	host_button.disabled = text.is_empty()

func join_press() -> void:
	var ip_address: String = default_ip
	var port: int = default_port
	var matches = ip_regex.search(join_address_input.text.strip_edges())
	if matches != null:
		ip_address = matches.get_string("ip")
		if matches.get_string(2):
			port = int(matches.get_string("port"))

	var error = MultiplayerManager.join(ip_address, port)
	if error:
		print("Errored (join)!")
	else:
		join_progress.visible = true

func host_press() -> void:
	var port = default_port
	var matches = port_regex.search(host_port_input.text.strip_edges())
	if matches != null:
		port = int(matches.get_string(1))
	
	var error = MultiplayerManager.host(port)
	if error:
		print("Errored (host)!")
	else:
		lobby_timer.time_s = 0
		lobby_timer.active = true
		
func disconnect_press() -> void:
	MultiplayerManager.leave()
	
func start_press() -> void:
	MultiplayerManager.load_into.rpc(scene_to_load.resource_path)
	
