extends Node3D

@export var horizontal_rotator: Node3D 
@export var vertical_rotator: Node3D

@export var sensitivity: float = 0.005
@export var max_angle: float = 90.

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		horizontal_rotator.rotate_y(-event.relative.x * sensitivity)
		vertical_rotator.rotate_x(-event.relative.y * sensitivity)
		vertical_rotator.rotation.x = clamp(vertical_rotator.rotation.x, -deg_to_rad(max_angle), deg_to_rad(max_angle))
