class_name Player
extends CharacterBody3D

@export var toggle_crouch: bool = false
@export var crouch_transition_time: float = 0.1
@export var lean_transition_time: float = 0.1

@export var injury_effect_material: ShaderMaterial
@export var max_injuries: float = 10

@export_group("Movement")
@export var walk_speed: float = 5.0
@export var crouch_speed: float = 3.0

@export var ground_acceleration: float = 20.0
@export var air_acceleration: float = 3.0

@export_group("Fall damage", "fall_")
@export var fall_damage_height_min: float = 2.0
@export var fall_damage_height_max: float = 15.0
@export var fall_damage_start: float = 4.0
@export var fall_damage_scale: float = 0.4

var injuries: float = 0.0 :
	set(new_injuries):
		injuries_changed.emit(injuries, new_injuries)
		injury_effect_material.set_shader_parameter("injury_factor", new_injuries / max_injuries)
		injuries = new_injuries
		# TODO: Death
		
var is_crouched: bool = false
var _want_crouch: bool = false
var _start_fall_height: float = -INF
var lean_factor_right = 0

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var stand_space_checker: ShapeCast3D = $HeightCast
@onready var lean_right_checker: Area3D = $CameraController/LeanRightCheck
@onready var lean_left_checker: Area3D = $CameraController/LeanLeftCheck

signal injuries_changed(old_value: float, new_value: float)

# TODO: View bobbing
# TODO: Injury visual, viewbob and/or blood vignette?

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = (
			Input.MOUSE_MODE_CAPTURED 
			if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE 
			else Input.MOUSE_MODE_VISIBLE
		)
		
func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Fall damage
	if is_on_floor():
		var fall_dist = min(
			_start_fall_height - global_position.y, 
			fall_damage_height_max
		) - fall_damage_height_min
		if fall_dist > 0:
			injuries += fall_damage_start + fall_dist * fall_damage_scale
		_start_fall_height = -INF
	else:
		_start_fall_height = max(global_position.y, _start_fall_height)
		
	# Crouching
	if toggle_crouch and Input.is_action_just_pressed("crouch"):
		_want_crouch = !_want_crouch
	elif !toggle_crouch:
		_want_crouch = Input.is_action_pressed("crouch")
	if _want_crouch != is_crouched:
		if is_crouched:
			if not stand_space_checker.is_colliding():
				animation_player.play("Crouch", -1, -1/crouch_transition_time, true) # Reverse
				is_crouched = false
		else:
			animation_player.play("Crouch", -1, 1/crouch_transition_time, false)
			is_crouched = true
	
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
	var desired_lean_factor = 0
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
		lean_factor_right = desired_lean_factor
		
