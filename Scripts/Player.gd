extends CharacterBody2D

class_name Player

# Movement constants
const SPEED = 150.0
const JUMP_VELOCITY = -400.0
const WALL_JUMP_VELOCITY = -350.0
const WALL_SLIDE_SPEED = 100.0
const DASH_SPEED = 300.0
const DASH_DURATION = 0.15

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
var max_charge_time = 2.0

# Animation and visuals
@onready var animated_sprite = $AnimatedSprite2D
@onready var dash_particles = $DashParticles
@onready var wall_slide_particles = $WallSlideParticles
@onready var shot_spawn_point = $ShotSpawnPoint

# Audio
@onready var jump_sound = $AudioPlayers/JumpSound
@onready var dash_sound = $AudioPlayers/DashSound
@onready var land_sound = $AudioPlayers/LandSound
@onready var wall_slide_sound = $AudioPlayers/WallSlideSound
@onready var shot_sound = $AudioPlayers/ShotSound
@onready var charge_sound = $AudioPlayers/ChargeSound

# Preloaded scenes
@export var PlayerShotScene: PackedScene

# State tracking
var was_on_floor = false

func _ready():
	# Initialize sprite facing direction
	animated_sprite.flip_h = false

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
			charge_sound.play()
		charge_timer += get_physics_process_delta_time()
	elif Input.is_action_just_released("shoot"):
		shoot()
		is_charging = false
		charge_sound.stop()

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
		if (wall_normal.x > 0 and direction < 0) or (wall_normal.x < 0 and direction > 0):
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
	# Regular jump or coyote jump
	if jump_buffer_timer > 0 and (is_on_floor() or coyote_timer > 0) and not is_wall_sliding:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0
		coyote_timer = 0
		jump_sound.play()

func handle_dashing(delta):
	# Dash input
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
		start_dash()
	
	# Dash mechanics
	if is_dashing:
		dash_timer -= delta
		velocity.x = facing_direction * DASH_SPEED
		velocity.y = 0  # Maintain height during dash
		
		if dash_timer <= 0:
			end_dash()
	
	# Reset dash when on floor or wall sliding
	if (is_on_floor() or is_wall_sliding) and not is_dashing:
		can_dash = true

func start_dash():
	is_dashing = true
	dash_timer = DASH_DURATION
	can_dash = false
	dash_particles.emitting = true
	dash_sound.play()

func end_dash():
	is_dashing = false
	dash_particles.emitting = false

func handle_shooting(delta):
	pass  # Shooting will be handled when shoot() is called

func shoot():
	if not can_shoot:
		return
	
	if not PlayerShotScene:
		PlayerShotScene = load("res://Scenes/PlayerShot.tscn")
	
	var shot_scene = PlayerShotScene.instantiate()
	get_tree().current_scene.add_child(shot_scene)
	
	# Position the shot at the spawn point
	shot_scene.global_position = shot_spawn_point.global_position
	
	# Set shot direction and properties based on charge
	var is_charged = charge_timer >= max_charge_time
	shot_scene.setup_shot(facing_direction, is_charged)
	
	# Play sound and reset shooting
	shot_sound.play()
	can_shoot = false
	shot_timer = shot_cooldown
	
	# Reset charge
	charge_timer = 0.0

func update_animations():
	if is_dashing:
		animated_sprite.play("dash")
	elif is_wall_sliding:
		animated_sprite.play("wall_slide")
	elif not is_on_floor():
		if velocity.y < 0:
			animated_sprite.play("jump")
		else:
			animated_sprite.play("fall")
	elif abs(velocity.x) > 10:
		animated_sprite.play("run")
	else:
		animated_sprite.play("idle")

func handle_landing_effects():
	# Play landing sound when hitting the ground
	if is_on_floor() and not was_on_floor and velocity.y > 100:
		land_sound.play()

func take_damage(amount: int):
	# Placeholder for damage system
	print("Player took ", amount, " damage!")

func heal(amount: int):
	# Placeholder for healing system
	print("Player healed ", amount, " HP!")
