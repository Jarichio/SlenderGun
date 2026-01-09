class_name Player
extends CharacterBody3D

@export_group("Movement")
@export var walk_speed: float = 5.0
@export var crouch_speed: float = 3.0
@export var ground_acceleration: float = 20.0
@export var air_acceleration: float = 3.0

@export var toggle_crouch: bool = false
@export var crouch_transition_time: float = 0.1
@export var lean_transition_time: float = 0.1

@export_group("Damage", "dmg_")
@export var dmg_max_injuries: float = 10
@export var dmg_effect_material: ShaderMaterial

@export_subgroup("Fall Damage", "dmg_fall_")
@export var dmg_fall_start: float = 4.0
@export var dmg_fall_scale: float = 0.4
@export var dmg_fall_height_min: float = 2.0
@export var dmg_fall_height_max: float = 15.0

var injuries: float = 0.0 :
	set(new_injuries):
		injuries_changed.emit(injuries, new_injuries)
		dmg_effect_material.set_shader_parameter("injury_factor", new_injuries / dmg_max_injuries)
		injuries = new_injuries
		# TODO: Death
		if injuries > dmg_max_injuries:
			print("Player is kill")
		
var is_crouched: bool = false
var _want_crouch: bool = false
var _start_fall_height: float = -INF
var lean_factor_right = 0

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var stand_space_checker: ShapeCast3D = $StandingSpaceCast
@onready var nametag: Label3D = $Head/Nameplate
@onready var lean_right_checker: Area3D = $Head/LeanRightCheck
@onready var lean_left_checker: Area3D = $Head/LeanLeftCheck

signal injuries_changed(old_value: float, new_value: float)

# TODO: View bobbing
# TODO: Injury visual, viewbob and/or blood vignette?

func _enter_tree() -> void:
	set_multiplayer_authority(int(name), true) # We have each player be named with their peer ID 

func _ready() -> void:
	if is_multiplayer_authority():
		_local_ready()
	else:
		_remote_ready()

func _local_ready():
	nametag.text = MultiplayerManager.local_player.name
	
func _remote_ready():
	set_process(false)
	set_physics_process(false) # TODO: keep on but only interpolate on other machines?
	set_process_input(false)
	var owner_peer_id = get_multiplayer_authority()
	var owner_peer = MultiplayerManager.connected_players.get(owner_peer_id)
	if owner_peer == null:
		return
	nametag.text = owner_peer["name"]

func _process(_delta: float) -> void:
	pass
		
func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Fall damage
	if is_on_floor():
		var fall_dist = min(
			_start_fall_height - global_position.y, 
			dmg_fall_height_max
		) - dmg_fall_height_min
		if fall_dist > 0:
			injuries += dmg_fall_start + fall_dist * dmg_fall_scale
		_start_fall_height = -INF
	else:
		_start_fall_height = max(global_position.y, _start_fall_height)
		
	# Crouching
	if toggle_crouch and Input.is_action_just_pressed("crouch"):
		_want_crouch = !_want_crouch
	elif !toggle_crouch:
		_want_crouch = Input.is_action_pressed("crouch")
	#print(_want_crouch)
		
	if _want_crouch != is_crouched:
		if _want_crouch:
			is_crouched = true
		elif not stand_space_checker.is_colliding():
			is_crouched = false
	
	# Horizontal movement
	var acceleration = ground_acceleration if is_on_floor() else air_acceleration
	var speed = crouch_speed if is_crouched else walk_speed
	
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var newVelocity = velocity.move_toward(direction * speed, acceleration * delta)
	velocity.x = newVelocity.x
	velocity.z = newVelocity.z

	move_and_slide()
	
	# Leaning
	var lean_left = Input.is_action_pressed("lean_left")
	var lean_right = Input.is_action_pressed("lean_right")
	lean_factor_right = int(lean_right) - int(lean_left)
	"""var desired_lean_factor = 0
	if lean_left and not lean_right:
		desired_lean_factor = -1
	elif lean_right and not lean_left:
		desired_lean_factor = 1
	if desired_lean_factor == 1 and lean_right_checker.has_overlapping_bodies():
		desired_lean_factor = 0
	if desired_lean_factor == -1 and lean_left_checker.has_overlapping_bodies():
		desired_lean_factor = 0
	if desired_lean_factor != lean_factor_right:
		if lean_factor_right == 1:
			animation_player.play("Lean Right", -1, -1/lean_transition_time, true)
		elif lean_factor_right == -1:
			animation_player.play("Lean Left", -1, -1/lean_transition_time, true)
		if desired_lean_factor == 1:
			animation_player.play("Lean Right", -1, 1/lean_transition_time)
		elif desired_lean_factor == -1:
			animation_player.play("Lean Left", -1, 1/lean_transition_time)
		lean_factor_right = desired_lean_factor"""
		
