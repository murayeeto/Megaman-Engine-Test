extends CharacterBody2D

class_name Player

# Movement constants
const SPEED = 150.0
const JUMP_VELOCITY = -400.0
const WALL_JUMP_VELOCITY = -350.0
const WALL_SLIDE_SPEED = 100.0
const DASH_SPEED = 300.0
const DASH_DURATION = 0.30

# Physics
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var facing_direction = 1
var can_dash = true
var is_dashing = false
var dash_timer = 0.0
var is_wall_sliding = false
var wall_jump_timer = 0.0
var coyote_timer = 0.0
var jump_buffer_timer = 0.0

# Shooting
var can_shoot = true
var shot_cooldown = 0.1
var shot_timer = 0.0
var is_charging = false
var charge_timer = 0.0
var max_charge_time = 0.8
var charge_sound_started = false
var charge_loop_started = false
var is_shooting = false
var shoot_animation_timer = 0.0
var shoot_animation_duration = 0.3

# Animation and visuals
@onready var animated_sprite = $AnimatedSprite2D
@onready var charge_effect_sprite = $ChargeEffectSprite
@onready var dash_particles = $DashParticles
@onready var wall_slide_particles = $WallSlideParticles
# Shot spawn points for different states
@onready var shot_spawn_idle = $ShotSpawnPoints/ShotSpawnIdle
@onready var shot_spawn_jump = $ShotSpawnPoints/ShotSpawnJump
@onready var shot_spawn_dash = $ShotSpawnPoints/ShotSpawnDash
@onready var shot_spawn_walk = $ShotSpawnPoints/ShotSpawnWalk

# Store original positions to avoid accumulating offsets
var original_spawn_positions = {}

# Audio
@onready var jump_sound = $AudioPlayers/JumpSound
@onready var dash_sound = $AudioPlayers/DashSound
@onready var land_sound = $AudioPlayers/LandSound
@onready var wall_slide_sound = $AudioPlayers/WallSlideSound
@onready var shot_sound = $AudioPlayers/ShotSound
@onready var charge_sound = $AudioPlayers/ChargeSound
@onready var charge_loop_sound = $AudioPlayers/ChargeLoopSound

# Preloaded scenes
@export var PlayerShotScene: PackedScene

# State tracking
var was_on_floor = false

func _ready():
	# Initialize sprite facing direction
	animated_sprite.flip_h = false
	
	# Store original spawn point positions
	original_spawn_positions[shot_spawn_idle] = shot_spawn_idle.position
	original_spawn_positions[shot_spawn_walk] = shot_spawn_walk.position
	original_spawn_positions[shot_spawn_jump] = shot_spawn_jump.position
	original_spawn_positions[shot_spawn_dash] = shot_spawn_dash.position

func _physics_process(delta):
	handle_timers(delta)
	handle_input()
	handle_gravity(delta)
	handle_movement()
	handle_wall_mechanics()
	handle_jumping()
	handle_dashing(delta)
	handle_shooting(delta)
	
	# Apply movement
	move_and_slide()
	
	# Update animations and audio
	update_animations()
	handle_landing_effects()
	
	# Update state tracking
	was_on_floor = is_on_floor()

func handle_timers(delta):
	# Coyote time - allows jumping shortly after leaving ground
	if is_on_floor():
		coyote_timer = 0.1
	else:
		coyote_timer -= delta
	
	# Jump buffer - allows jump input to register slightly before landing
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	
	# Wall jump timer
	if wall_jump_timer > 0:
		wall_jump_timer -= delta
	
	# Shot cooldown
	if shot_timer > 0:
		shot_timer -= delta
		if shot_timer <= 0:
			can_shoot = true
	
	# Shooting animation timer
	if shoot_animation_timer > 0:
		shoot_animation_timer -= delta
		if shoot_animation_timer <= 0:
			is_shooting = false

func handle_input():
	# Movement input
	var direction = Input.get_axis("move_left", "move_right")
	if direction != 0:
		facing_direction = sign(direction)
		animated_sprite.flip_h = facing_direction < 0
	
	# Jump input buffering
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = 0.1
	
	# Charge shot input
	if Input.is_action_pressed("shoot"):
		if not is_charging:
			is_charging = true
			charge_timer = 0.0
			charge_sound_started = false
			charge_loop_started = false
			charge_sound.play()
		
		charge_timer += get_physics_process_delta_time()
		
		# Handle charge sound progression
		handle_charge_sound()
		
	elif Input.is_action_just_released("shoot"):
		shoot()
		is_charging = false
		charge_sound_started = false
		charge_loop_started = false
		charge_sound.stop()
		charge_loop_sound.stop()

func handle_gravity(delta):
	if not is_on_floor():
		if is_wall_sliding:
			# Slower fall when wall sliding
			velocity.y += gravity * delta * 0.3
			velocity.y = min(velocity.y, WALL_SLIDE_SPEED)
		else:
			velocity.y += gravity * delta

func handle_movement():
	var direction = Input.get_axis("move_left", "move_right")
	
	if not is_dashing:
		if direction != 0:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED * 3 * get_physics_process_delta_time())

func handle_wall_mechanics():
	var was_wall_sliding = is_wall_sliding
	is_wall_sliding = false
	
	if not is_on_floor() and is_on_wall_only():
		var wall_normal = get_wall_normal()
		var direction = Input.get_axis("move_left", "move_right")
		
		# Check if player is pressing into the wall
		if (wall_normal.x > 0 and direction < 0) or (wall_normal.x < 0 and direction > 0) and velocity.y > 0:
			is_wall_sliding = true
			
			# Wall jump
			if Input.is_action_just_pressed("jump") and wall_jump_timer <= 0:
				velocity.x = wall_normal.x * SPEED * 1.2
				velocity.y = WALL_JUMP_VELOCITY
				wall_jump_timer = 0.2
				facing_direction = sign(wall_normal.x)
				animated_sprite.flip_h = facing_direction < 0
				jump_sound.play()
	
	# Wall slide effects
	if is_wall_sliding and not was_wall_sliding:
		wall_slide_particles.emitting = true
		wall_slide_sound.play()
	elif not is_wall_sliding and was_wall_sliding:
		wall_slide_particles.emitting = false
		wall_slide_sound.stop()

func handle_jumping():
	# Regular jump or coyote jump (now allows jumping while dashing on ground)
	if jump_buffer_timer > 0 and (is_on_floor() or coyote_timer > 0) and not is_wall_sliding:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0
		coyote_timer = 0
		
		# Cancel dash if jumping while dashing (enhanced dash momentum)
		if is_dashing and is_on_floor():
			# Preserve current dash momentum + boost
			var current_dash_velocity = abs(velocity.x)
			var enhanced_velocity = max(current_dash_velocity * 1.3, DASH_SPEED * 1.25)
			velocity.x = facing_direction * enhanced_velocity
			end_dash()
		
		jump_sound.play()

func handle_dashing(delta):
	# Dash input
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
		start_dash()
	
	# Dash mechanics
	if is_dashing:
		dash_timer -= delta
		
		# Accelerate to dash speed rather than instant velocity
		var target_dash_velocity = facing_direction * DASH_SPEED
		var current_velocity_abs = abs(velocity.x)
		
		# If we're not at dash speed yet, accelerate quickly
		if current_velocity_abs < DASH_SPEED:
			velocity.x = move_toward(velocity.x, target_dash_velocity, DASH_SPEED * 8 * delta)
		else:
			# Maintain dash speed (but allow for higher speeds from momentum)
			if sign(velocity.x) == facing_direction:
				velocity.x = max(abs(velocity.x), DASH_SPEED) * facing_direction
			else:
				velocity.x = target_dash_velocity
		
		# Only maintain height if on ground (allows jumping while dashing)
		if is_on_floor():
			velocity.y = 0  # Maintain height during ground dash
		
		if dash_timer <= 0:
			end_dash()
	
	# Reset dash when on floor or wall sliding
	if (is_on_floor() or is_wall_sliding) and not is_dashing:
		can_dash = true

func start_dash():
	is_dashing = true
	dash_timer = DASH_DURATION
	can_dash = false
#	dash_particles.emitting = true
	dash_sound.play()

func end_dash():
	is_dashing = false
#	dash_particles.emitting = false

func handle_shooting(delta):
	pass  # Shooting will be handled when shoot() is called

func shoot():
	if not can_shoot:
		return
	
	if not PlayerShotScene:
		PlayerShotScene = load("res://Scenes/PlayerShot.tscn")
	
	var shot_scene = PlayerShotScene.instantiate()
	get_tree().current_scene.add_child(shot_scene)
	
	# Position the shot at the appropriate spawn point based on player state
	var spawn_point = get_current_shot_spawn_point()
	shot_scene.global_position = spawn_point.global_position
	
	# Set shot direction and properties based on charge
	var is_charged = charge_timer >= max_charge_time
	shot_scene.setup_shot(facing_direction, is_charged)
	
	# Trigger shooting animation
	is_shooting = true
	shoot_animation_timer = shoot_animation_duration
	
	# Play sound and reset shooting
	
	shot_sound.play()
	can_shoot = false
	shot_timer = shot_cooldown
	
	# Reset charge
	charge_timer = 0.0

func update_animations():
	var animation_to_play = ""
	
	# Determine base animation based on movement state
	if is_dashing:
		if is_shooting:
			animation_to_play = "Dash_Shoot"
		else:
			animation_to_play = "Dash"
	elif is_wall_sliding:
		# Wall slide doesn't have a shooting variant in your sprites
		animation_to_play = "Wall_Slide"
	elif not is_on_floor():
		if velocity.y < 0:
			if is_shooting:
				animation_to_play = "Jump_Shoot"
			else:
				animation_to_play = "Jump"
		else:
			# Fall animation - you might want to add Fall_Shoot if you have it
			animation_to_play = "Fall"
	elif abs(velocity.x) > 10:
		if is_shooting:
			animation_to_play = "Walk_Shoot"
		else:
			animation_to_play = "Walk"
	else:
		if is_shooting:
			animation_to_play = "Shoot"
		else:
			animation_to_play = "Idle"
	
	# Play animation (only restart if different or not currently playing)
	if animated_sprite.animation != animation_to_play or not animated_sprite.is_playing():
		animated_sprite.play(animation_to_play)
		adjust_sprite_offset(animation_to_play)
	
	# Update visual effects for charged shot
	update_charge_visual_effect()

func get_current_shot_spawn_point() -> Node2D:
	# Return appropriate shot spawn point based on player state
	var spawn_point: Node2D
	
	if is_dashing:
		spawn_point = shot_spawn_dash
	elif not is_on_floor():
		# In air (jumping or falling)
		spawn_point = shot_spawn_jump
	elif abs(velocity.x) > 10:
		# Walking/running
		spawn_point = shot_spawn_walk
	else:
		# Idle/standing
		spawn_point = shot_spawn_idle
	
	# Advanced directional positioning with custom offsets for left vs right
	adjust_spawn_point_for_direction(spawn_point)
	
	return spawn_point

func adjust_spawn_point_for_direction(spawn_point: Node2D):
	# Get the original position (stored at _ready) - NOT the current position
	var original_pos = original_spawn_positions[spawn_point]
	
	if facing_direction < 0:  # Facing left
		# Custom left-facing positions with additional offset adjustments
		if spawn_point == shot_spawn_idle:
			spawn_point.position = Vector2(-abs(original_pos.x) - 17, original_pos.y)  # Extra 2 pixels left
		elif spawn_point == shot_spawn_walk:
			spawn_point.position = Vector2(-abs(original_pos.x) - 35, original_pos.y)  # Extra 3 pixels left, 1 up
		elif spawn_point == shot_spawn_jump:
			spawn_point.position = Vector2(-abs(original_pos.x) - 30, original_pos.y)  # Extra 1 pixel left, 1 down
		elif spawn_point == shot_spawn_dash:
			spawn_point.position = Vector2(-abs(original_pos.x) - 35, original_pos.y)  # Extra 4 pixels left, 2 up
	else:  # Facing right
		# Restore original right-facing position
		spawn_point.position = original_pos

func adjust_sprite_offset(animation_name: String):
	# Adjust sprite position based on animation to keep feet aligned
	# You'll need to tweak these values based on your specific sprites
	match animation_name:
		"Idle":
			animated_sprite.position.y = -19  # Base position
		"Walk":
			animated_sprite.position.y = -19  # Same as idle
		"Walk_Shoot":
			animated_sprite.position.y = -19  # Same as idle
		"Jump":
			animated_sprite.position.y = -19  # Adjust if jump sprite is different height
		"Jump_Shoot":
			animated_sprite.position.y = -19  # Match jump
		"Fall":
			animated_sprite.position.y = -19  # Adjust if fall sprite is different
		"Dash":
			animated_sprite.position.y = -19  # Adjust if dash sprite is different height
		"Dash_Shoot":
			animated_sprite.position.y = -19  # Match dash
		"Shoot":
			animated_sprite.position.y = -23  # Adjust if shooting changes height
		"Wall_Slide":
			animated_sprite.position.y = -19  # Adjust for wall slide
		_:
			animated_sprite.position.y = -19  # Default position

func handle_landing_effects():
	# Play landing sound when hitting the ground
	if is_on_floor() and not was_on_floor and velocity.y > 100:
		land_sound.play()

func update_charge_visual_effect():
	# Check if player has a charged shot ready
	var is_charged_ready = charge_timer >= max_charge_time
	
	if is_charged_ready:
		# Show and play charge effect animation on top of player
		charge_effect_sprite.visible = true
		if charge_effect_sprite.animation != "default" or not charge_effect_sprite.is_playing():
			charge_effect_sprite.play("default")
	else:
		# Hide charge effect when not charged
		charge_effect_sprite.visible = false
		charge_effect_sprite.stop()

func handle_charge_sound():
	# Start initial charge sound when charging begins
	if not charge_sound_started:
		charge_sound_started = true
		charge_sound.play()
	
	# Check if we should start the loop sound (after 1.4 seconds of charging)
	if charge_timer >= 1.4 and not charge_loop_started:
		charge_loop_started = true
		# Stop initial charge sound and start looping sound
		charge_sound.stop()
		charge_loop_sound.play()
	
	# Keep the loop sound playing while charged (in case it stops)
	elif charge_loop_started and not charge_loop_sound.is_playing():
		# Restart loop if it stopped
		charge_loop_sound.play()

func take_damage(amount: int):
	# Placeholder for damage system
	print("Player took ", amount, " damage!")

func heal(amount: int):
	# Placeholder for healing system
	print("Player healed ", amount, " HP!")
