extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var run_speed: float = 8.0

@export var max_player_range: float = 30.0 : 
	set(value):
		max_player_range = value
		if raycast != null: 
			raycast.target_position = Vector3(0, 0, -value)

@onready var height_checker: ShapeCast3D = $HeightCast
@onready var kill_area: Area3D = $KillArea
@onready var raycast: RayCast3D = $Eyes/SightCast
@onready var navigator: NavigationAgent3D = $NavigationAgent

## Current pathfinding goal in global coordinates
var goal_position: Vector3 = Vector3.ZERO :
	get(): 
		return navigator.target_position
	set(value):
		navigator.target_position = value
		if value == Vector3.ZERO:
			push_warning("Navigating to 0,0,0. This is likely unintentional")

func _ready() -> void:
	raycast.target_position = Vector3(0, 0, -max_player_range)
	
	navigator.velocity_computed.connect(Callable(_move))
	
	# Not sure why we need to wait for it to be fired twice before the map is loaded
	await NavigationServer3D.map_changed
	await NavigationServer3D.map_changed
	goal_position = NavigationServer3D.map_get_random_point(navigator.get_navigation_map(), 1, true)

func _get_nearest(nodes: Array[Node3D]) -> Node3D:
	var best = nodes[0]
	var best_dist = INF
	for node in nodes:
		var dist = global_position.distance_squared_to(node.global_position)
		if dist < best_dist:
			best_dist = dist
			best = node
	return best
	
## Outright evil function where i sacrifice performance for type safety
func _get_players() -> Array[Node3D]:
	var players: Array[Node] = (
		get_tree()
		.get_nodes_in_group("players")
		.filter(func(node: Node): return node.is_class("Node3D"))
	)
	var result: Array[Node3D] = []
	result.assign(players) # Performance waster
	return result

func tick_ai():
	var players = _get_players()
	players.sort_custom(func(p1: Node3D, p2: Node3D): return (
		p1.global_position.distance_squared_to(global_position) 
		< p2.global_position.distance_squared_to(global_position)
	))
	if not players:
		return
	
	var seen: Array[Node3D] = []
	for player in players:
		var player_pos = player.global_position + Vector3.UP * 1.0;
		raycast.look_at_from_position(raycast.global_position, player_pos)
		raycast.force_raycast_update()
		var collider = raycast.get_collider()
		raycast.debug_shape_custom_color = Color.RED
		if collider == null:
			continue
		if collider.get_instance_id() != player.get_instance_id():
			continue
		raycast.debug_shape_custom_color = Color.GREEN
		seen.append(player)
		
	if seen:
		goal_position = seen[0].global_position

func _move(safe_velocity: Vector3): 
	velocity = Vector3(safe_velocity.x, 0, safe_velocity.z)
	move_and_slide()

func _physics_process(_delta: float) -> void:
	#DebugDraw3D.draw_sphere(global_position, max_player_range, Color.from_rgba8(30,30,60))
	
	if navigator.is_navigation_finished():
		return
	var next_pos = navigator.get_next_path_position()
	var new_velocity = global_position.direction_to(next_pos) * 2
	if navigator.avoidance_enabled:
		navigator.set_velocity(new_velocity)
	else:
		_move(new_velocity)
