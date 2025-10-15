extends CharacterBody2D

class_name Player

const SPEED = 150.0
const JUMP_VELOCITY = -400.0
const WALL_JUMP_VELOCITY = -350.0
const WALL_SLIDE_SPEED = 100.0
const DASH_SPEED = 300.0
const DASH_DURATION = 0.30
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var facing_direction = 1
var can_dash = true
var is_dashing = false
var dash_timer = 0.0
var is_wall_sliding = false
var wall_jump_timer = 0.0
var coyote_timer = 0.0
var jump_buffer_timer = 0.0

const MAX_HEALTH = 25
var current_health = MAX_HEALTH
var is_invulnerable = false
var invulnerability_duration = 1.0
var invulnerability_timer = 0.0

var can_shoot = true
var shot_cooldown = 0.1
var shot_timer = 0.0
var is_charging = false
var charge_timer = 0.0
var active_shots = []
var max_uncharged_shots = 3
var max_charge_time = 0.8
var charge_sound_started = false
var charge_loop_started = false
var is_shooting = false
var shoot_animation_timer = 0.0
var shoot_animation_duration = 0.3

@onready var animated_sprite = $AnimatedSprite2D
@onready var charge_effect_sprite = $ChargeEffectSprite
@onready var dash_particles = $DashParticles
@onready var wall_slide_particles = $WallSlideParticles
@onready var shot_spawn_idle = $ShotSpawnPoints/ShotSpawnIdle
@onready var shot_spawn_jump = $ShotSpawnPoints/ShotSpawnJump
@onready var shot_spawn_dash = $ShotSpawnPoints/ShotSpawnDash
@onready var shot_spawn_walk = $ShotSpawnPoints/ShotSpawnWalk

var original_spawn_positions = {}

@onready var jump_sound = $AudioPlayers/JumpSound
@onready var dash_sound = $AudioPlayers/DashSound
@onready var land_sound = $AudioPlayers/LandSound
@onready var wall_slide_sound = $AudioPlayers/WallSlideSound
@onready var shot_sound = $AudioPlayers/ShotSound
@onready var charge_sound = $AudioPlayers/ChargeSound
@onready var charge_loop_sound = $AudioPlayers/ChargeLoopSound

@export var PlayerShotScene: PackedScene

var was_on_floor = false

func _ready():
	collision_layer = 1
	collision_mask = 2
	
	animated_sprite.flip_h = false
	
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
	
	move_and_slide()
	
	update_animations()
	handle_landing_effects()
	
	was_on_floor = is_on_floor()

func handle_timers(delta):
	if is_on_floor():
		coyote_timer = 0.1
	else:
		coyote_timer -= delta
	
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	
	if wall_jump_timer > 0:
		wall_jump_timer -= delta
	
	if invulnerability_timer > 0:
		invulnerability_timer -= delta
		if invulnerability_timer <= 0:
			is_invulnerable = false
			animated_sprite.modulate = Color.WHITE
	
	if shot_timer > 0:
		shot_timer -= delta
		if shot_timer <= 0:
			can_shoot = true
	
	if shoot_animation_timer > 0:
		shoot_animation_timer -= delta
		if shoot_animation_timer <= 0:
			is_shooting = false

func handle_input():
	var direction = Input.get_axis("move_left", "move_right")
	if direction != 0:
		facing_direction = sign(direction)
		animated_sprite.flip_h = facing_direction < 0
	
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = 0.1
	
	if Input.is_action_pressed("shoot"):
		if not is_charging:
			is_charging = true
			charge_timer = 0.0
			charge_sound_started = false
			charge_loop_started = false
			charge_sound.play()
		
		charge_timer += get_physics_process_delta_time()
		
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
		
		if (wall_normal.x > 0 and direction < 0) or (wall_normal.x < 0 and direction > 0) and velocity.y > 0:
			is_wall_sliding = true
			
			if Input.is_action_just_pressed("jump") and wall_jump_timer <= 0:
				velocity.x = wall_normal.x * SPEED * 1.2
				velocity.y = WALL_JUMP_VELOCITY
				wall_jump_timer = 0.2
				facing_direction = sign(wall_normal.x)
				animated_sprite.flip_h = facing_direction < 0
				jump_sound.play()
	
	if is_wall_sliding and not was_wall_sliding:
		wall_slide_sound.play()
	elif not is_wall_sliding and was_wall_sliding:
		wall_slide_sound.stop()

func handle_jumping():
	if jump_buffer_timer > 0 and (is_on_floor() or coyote_timer > 0) and not is_wall_sliding:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0
		coyote_timer = 0
		
		if is_dashing and is_on_floor():
			var current_dash_velocity = abs(velocity.x)
			var enhanced_velocity = max(current_dash_velocity * 1.3, DASH_SPEED * 1.25)
			velocity.x = facing_direction * enhanced_velocity
			end_dash()
		
		jump_sound.play()

func handle_dashing(delta):
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
		start_dash()
	
	if is_dashing:
		dash_timer -= delta
		
		var target_dash_velocity = facing_direction * DASH_SPEED
		var current_velocity_abs = abs(velocity.x)
		
		if current_velocity_abs < DASH_SPEED:
			velocity.x = move_toward(velocity.x, target_dash_velocity, DASH_SPEED * 8 * delta)
		else:
			if sign(velocity.x) == facing_direction:
				velocity.x = max(abs(velocity.x), DASH_SPEED) * facing_direction
			else:
				velocity.x = target_dash_velocity
		
		if is_on_floor():
			velocity.y = 0
		
		if dash_timer <= 0:
			end_dash()
	
	if (is_on_floor() or is_wall_sliding) and not is_dashing:
		can_dash = true

func start_dash():
	is_dashing = true
	dash_timer = DASH_DURATION
	can_dash = false
	dash_sound.play()

func end_dash():
	is_dashing = false

func handle_shooting(delta):
	pass

func shoot():
	if not can_shoot:
		return
	
	var is_charged = charge_timer >= max_charge_time
	if not is_charged:
		clean_up_shot_references()
		
		if active_shots.size() >= max_uncharged_shots:
			return
	
	if not PlayerShotScene:
		PlayerShotScene = load("res://Scenes/PlayerShot.tscn")
	
	var shot_scene = PlayerShotScene.instantiate()
	get_tree().current_scene.add_child(shot_scene)
	
	var spawn_point = get_current_shot_spawn_point()
	shot_scene.global_position = spawn_point.global_position
	
	shot_scene.setup_shot(facing_direction, is_charged)
	
	if not is_charged:
		active_shots.append(shot_scene)
		if shot_scene.has_signal("shot_destroyed"):
			shot_scene.shot_destroyed.connect(_on_shot_destroyed)
		else:
			shot_scene.tree_exited.connect(_on_shot_destroyed.bind(shot_scene))
	
	is_shooting = true
	shoot_animation_timer = shoot_animation_duration
	
	shot_sound.play()
	can_shoot = false
	shot_timer = shot_cooldown
	
	charge_timer = 0.0

func update_animations():
	var animation_to_play = ""
	
	if is_dashing:
		if is_shooting:
			animation_to_play = "Dash_Shoot"
		else:
			animation_to_play = "Dash"
	elif is_wall_sliding:
		animation_to_play = "Wall_Slide"
	elif not is_on_floor():
		if velocity.y < 0:
			if is_shooting:
				animation_to_play = "Jump_Shoot"
			else:
				animation_to_play = "Jump"
		else:
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
	
	if animated_sprite.animation != animation_to_play or not animated_sprite.is_playing():
		animated_sprite.play(animation_to_play)
		adjust_sprite_offset(animation_to_play)
	
	update_charge_visual_effect()

func get_current_shot_spawn_point() -> Node2D:
	var spawn_point: Node2D
	
	if is_dashing:
		spawn_point = shot_spawn_dash
	elif not is_on_floor():
		spawn_point = shot_spawn_jump
	elif abs(velocity.x) > 10:
		spawn_point = shot_spawn_walk
	else:
		spawn_point = shot_spawn_idle
	
	adjust_spawn_point_for_direction(spawn_point)
	
	return spawn_point

func adjust_spawn_point_for_direction(spawn_point: Node2D):
	var original_pos = original_spawn_positions[spawn_point]
	
	if facing_direction < 0:
		if spawn_point == shot_spawn_idle:
			spawn_point.position = Vector2(-abs(original_pos.x) - 17, original_pos.y)
		elif spawn_point == shot_spawn_walk:
			spawn_point.position = Vector2(-abs(original_pos.x) - 35, original_pos.y)
		elif spawn_point == shot_spawn_jump:
			spawn_point.position = Vector2(-abs(original_pos.x) - 30, original_pos.y)
		elif spawn_point == shot_spawn_dash:
			spawn_point.position = Vector2(-abs(original_pos.x) - 35, original_pos.y)
	else:
		spawn_point.position = original_pos

func adjust_sprite_offset(animation_name: String):
	match animation_name:
		"Idle":
			animated_sprite.position.y = -19
		"Walk":
			animated_sprite.position.y = -19
		"Walk_Shoot":
			animated_sprite.position.y = -19
		"Jump":
			animated_sprite.position.y = -19
		"Jump_Shoot":
			animated_sprite.position.y = -19
		"Fall":
			animated_sprite.position.y = -19
		"Dash":
			animated_sprite.position.y = -19
		"Dash_Shoot":
			animated_sprite.position.y = -19
		"Shoot":
			animated_sprite.position.y = -23
		"Wall_Slide":
			animated_sprite.position.y = -19
		_:
			animated_sprite.position.y = -19

func handle_landing_effects():
	if is_on_floor() and not was_on_floor and velocity.y > 100:
		land_sound.play()

func update_charge_visual_effect():
	var is_charged_ready = charge_timer >= max_charge_time
	
	if is_charged_ready:
		charge_effect_sprite.visible = true
		if charge_effect_sprite.animation != "default" or not charge_effect_sprite.is_playing():
			charge_effect_sprite.play("default")
	else:
		charge_effect_sprite.visible = false
		charge_effect_sprite.stop()

func handle_charge_sound():
	if not charge_sound_started:
		charge_sound_started = true
		charge_sound.play()
	
	if charge_timer >= 1.4 and not charge_loop_started:
		charge_loop_started = true
		charge_sound.stop()
		charge_loop_sound.play()
	
	elif charge_loop_started and not charge_loop_sound.is_playing():
		charge_loop_sound.play()

func clean_up_shot_references():
	active_shots = active_shots.filter(func(shot): return is_instance_valid(shot))

func _on_shot_destroyed(shot_to_remove = null):
	if shot_to_remove:
		var index = active_shots.find(shot_to_remove)
		if index != -1:
			active_shots.remove_at(index)
	else:
		clean_up_shot_references()

func take_damage(amount: int):
	if is_invulnerable:
		return
	
	current_health -= amount
	print("Player took ", amount, " damage! Health: ", current_health, "/", MAX_HEALTH)
	
	# Start invulnerability period
	is_invulnerable = true
	invulnerability_timer = invulnerability_duration
	
	# Visual feedback - flash red
	animated_sprite.modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 0.5), 0.1)
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.1)
	tween.set_loops(int(invulnerability_duration * 5))
	
	if current_health <= 0:
		die()

func heal(amount: int):
	current_health = min(current_health + amount, MAX_HEALTH)
	print("Player healed ", amount, " HP! Health: ", current_health, "/", MAX_HEALTH)

func die():
	print("Player died!")
	set_physics_process(false)
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
	else:
		animated_sprite.modulate = Color.RED
