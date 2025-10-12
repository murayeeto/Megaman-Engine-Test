extends Camera2D

class_name PlayerCamera

@export var target: Node2D
@export var follow_speed: float = 5.0
@export var look_ahead_distance: float = 50.0
@export var vertical_offset: float = -20.0

var target_position: Vector2

func _ready():
	# Find player if target not set
	if not target:
		target = get_tree().get_first_node_in_group("player")
	
	# Set initial position
	if target:
		global_position = target.global_position + Vector2(0, vertical_offset)

func _process(delta):
	if not target:
		return
	
	# Calculate target position with look-ahead
	var player = target as Player
	if player:
		var look_ahead = player.facing_direction * look_ahead_distance
		target_position = target.global_position + Vector2(look_ahead, vertical_offset)
	else:
		target_position = target.global_position + Vector2(0, vertical_offset)
	
	# Smoothly move camera to target position
	global_position = global_position.lerp(target_position, follow_speed * delta)

func shake(intensity: float, duration: float):
	# Camera shake effect for impacts
	var original_position = global_position
	var timer = 0.0
	
	while timer < duration:
		timer += get_process_delta_time()
		var shake_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		global_position = original_position + shake_offset
		await get_tree().process_frame
	
	global_position = original_position
