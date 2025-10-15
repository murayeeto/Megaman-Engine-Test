extends CharacterBody2D

# Node references
@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var default_hurtbox = $Hurtbox
@onready var attack1_hurtbox = $Attack1HurtBox
@onready var attack2_hurtbox = $Attack2HurtBox
@onready var attack1_area = $Attack1Area
@onready var attack2_area = $Attack2Area
@onready var player_detector = $PlayerDetector

# Constants
const GRAVITY = 980.0
const MAX_HEALTH = 50
const BOSS_SPEED = 80.0
const BOSS_DASH_SPEED = 200.0
const BOSS_DASH_DURATION = 0.5

# Health and combat
var current_health = MAX_HEALTH
var is_dead = false

# State machine
enum BossState {
	IDLE,
	WALKING,
	DASHING,
	ATTACKING
}

var current_state = BossState.IDLE
var state_timer = 0.0

# Movement
var facing_direction = 1
var target_velocity_x = 0.0

# Attack system
var attack_cooldown = 0.0
var current_active_hurtbox = null

# Player tracking
var player_reference = null
var is_player_on_screen = true

# Attack types
enum AttackType {
	ATTACK1,
	ATTACK2
}

func _ready():
	print("Boss initialized")
	
	# Set up collision layers
	collision_layer = 4  # Enemy layer
	collision_mask = 2   # Terrain layer
	
	# Set up hurtboxes
	setup_all_hurtboxes()
	activate_hurtbox(default_hurtbox)
	
	# Set up player detection
	if player_detector:
		player_detector.body_entered.connect(_on_player_entered)
		player_detector.body_exited.connect(_on_player_exited)
		player_detector.collision_layer = 0
		player_detector.collision_mask = 1  # Player layer
	
	# Start in idle state
	change_state(BossState.IDLE)
	
	# Start attack cycle after a delay
	get_tree().create_timer(2.0).timeout.connect(_start_attack_cycle)

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0
	
	# Update state timer
	state_timer += delta
	
	# Update attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	# Handle current state
	match current_state:
		BossState.IDLE:
			_handle_idle_state(delta)
		BossState.WALKING:
			_handle_walking_state(delta)
		BossState.DASHING:
			_handle_dashing_state(delta)
		BossState.ATTACKING:
			_handle_attacking_state(delta)
	
	# Smoothly interpolate to target velocity
	velocity.x = move_toward(velocity.x, target_velocity_x, BOSS_SPEED * 4 * delta)
	
	# Handle wall collisions
	if is_on_wall() and abs(velocity.x) > 10:
		facing_direction *= -1
		target_velocity_x = 0
		if current_state == BossState.WALKING:
			change_state(BossState.IDLE)
	
	# Update sprite direction
	if animated_sprite:
		animated_sprite.flip_h = facing_direction < 0
	
	# Move the boss
	move_and_slide()
	
	# Update animation
	_update_animation()

func _handle_idle_state(delta):
	target_velocity_x = 0
	
	# Randomly start walking or attacking
	if state_timer > 1.0:
		if randf() < 0.3:
			_start_wandering()
		elif attack_cooldown <= 0 and is_player_on_screen:
			_try_start_attack()

func _handle_walking_state(delta):
	target_velocity_x = BOSS_SPEED * facing_direction
	
	# Walk for a random duration, then go idle
	if state_timer > randf_range(2.0, 4.0):
		change_state(BossState.IDLE)
	
	# Occasionally dash towards player
	if player_reference and randf() < 0.01:
		_start_dash_to_player()

func _handle_dashing_state(delta):
	target_velocity_x = BOSS_DASH_SPEED * facing_direction
	
	# End dash after duration
	if state_timer > BOSS_DASH_DURATION:
		change_state(BossState.IDLE)

func _handle_attacking_state(delta):
	target_velocity_x = 0
	# Attack state is handled by animation completion

func change_state(new_state: BossState):
	if is_dead:
		return
		
	current_state = new_state
	state_timer = 0.0
	
	print("Boss state changed to: ", BossState.keys()[new_state])

func _start_wandering():
	# Pick random direction
	if randf() < 0.5:
		facing_direction *= -1
	change_state(BossState.WALKING)

func _start_dash_to_player():
	if player_reference:
		var direction_to_player = sign(player_reference.global_position.x - global_position.x)
		facing_direction = direction_to_player
		change_state(BossState.DASHING)

func _try_start_attack():
	if attack_cooldown > 0:
		return
		
	var attack_type = [AttackType.ATTACK1, AttackType.ATTACK2][randi() % 2]
	_execute_attack(attack_type)

func _execute_attack(attack_type: AttackType):
	change_state(BossState.ATTACKING)
	attack_cooldown = randf_range(3.0, 5.0)
	
	# Switch hurtbox
	match attack_type:
		AttackType.ATTACK1:
			activate_hurtbox(attack1_hurtbox)
		AttackType.ATTACK2:
			activate_hurtbox(attack2_hurtbox)
	
	# Play attack animation
	var animation_name = "attack1" if attack_type == AttackType.ATTACK1 else "attack2"
	if animated_sprite and animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
		# Wait for animation to finish
		if not animated_sprite.animation_finished.is_connected(_on_attack_animation_finished):
			animated_sprite.animation_finished.connect(_on_attack_animation_finished, CONNECT_ONE_SHOT)
	else:
		# Fallback if no animation
		get_tree().create_timer(1.0).timeout.connect(_on_attack_animation_finished)
	
	# Activate attack area
	match attack_type:
		AttackType.ATTACK1:
			if attack1_area and attack1_area.has_method("activate_attack"):
				attack1_area.activate_attack()
		AttackType.ATTACK2:
			if attack2_area and attack2_area.has_method("activate_attack"):
				attack2_area.activate_attack()

func _on_attack_animation_finished():
	# Clean up attack
	_deactivate_all_attack_areas()
	activate_hurtbox(default_hurtbox)
	change_state(BossState.IDLE)

func _start_attack_cycle():
	if not is_dead and is_player_on_screen:
		_try_start_attack()
		# Schedule next attack
		get_tree().create_timer(randf_range(4.0, 7.0)).timeout.connect(_start_attack_cycle)

func _update_animation():
	if not animated_sprite or is_dead:
		return
	
	var target_animation = "Idle"
	
	match current_state:
		BossState.IDLE:
			target_animation = "Idle"
		BossState.WALKING:
			target_animation = "Walk"
		BossState.DASHING:
			target_animation = "Walk"  # Use walk animation for dash
		BossState.ATTACKING:
			return  # Don't change animation during attacks
	
	if animated_sprite.animation != target_animation:
		animated_sprite.play(target_animation)

func take_damage(amount: int):
	if is_dead:
		return
		
	current_health -= amount
	print("Boss took ", amount, " damage! Health: ", current_health, "/", MAX_HEALTH)
	
	if current_health <= 0:
		_die()
	else:
		# Flash red
		if animated_sprite:
			animated_sprite.modulate = Color.RED
			var tween = create_tween()
			tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)

func _die():
	is_dead = true
	current_state = BossState.IDLE
	target_velocity_x = 0
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	if animated_sprite:
		if animated_sprite.sprite_frames.has_animation("death"):
			animated_sprite.play("death")
			animated_sprite.animation_finished.connect(queue_free, CONNECT_ONE_SHOT)
		else:
			queue_free()

func setup_all_hurtboxes():
	setup_hurtbox(default_hurtbox, "Default")
	setup_hurtbox(attack1_hurtbox, "Attack1")
	setup_hurtbox(attack2_hurtbox, "Attack2")

func setup_hurtbox(hurtbox: Area2D, name: String):
	if hurtbox:
		hurtbox.collision_layer = 8  # Hurtbox layer
		hurtbox.collision_mask = 0
		hurtbox.monitoring = false
		print("Hurtbox setup: ", name)

func activate_hurtbox(hurtbox: Area2D):
	# Deactivate all hurtboxes first
	if default_hurtbox:
		default_hurtbox.monitoring = false
	if attack1_hurtbox:
		attack1_hurtbox.monitoring = false
	if attack2_hurtbox:
		attack2_hurtbox.monitoring = false
	
	# Activate the specified hurtbox
	if hurtbox:
		hurtbox.monitoring = true
		current_active_hurtbox = hurtbox

func _deactivate_all_attack_areas():
	if attack1_area and attack1_area.has_method("deactivate_attack"):
		attack1_area.deactivate_attack()
	if attack2_area and attack2_area.has_method("deactivate_attack"):
		attack2_area.deactivate_attack()

func _on_player_entered(body):
	if body.name == "Player":
		is_player_on_screen = true
		player_reference = body
		print("Player entered boss area")

func _on_player_exited(body):
	if body.name == "Player":
		is_player_on_screen = false
		player_reference = null
		print("Player left boss area")
