extends Area2D

class_name PlayerShot

const NORMAL_SPEED = 400.0
const CHARGED_SPEED = 500.0
const NORMAL_DAMAGE = 1
const CHARGED_DAMAGE = 3

var direction = 1
var speed = NORMAL_SPEED
var damage = NORMAL_DAMAGE
var is_charged = false

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var hit_particles = $HitParticles
@onready var hit_sound = $HitSound

func _ready():
	# Connect area entered signal for collision detection
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	# Set up lifetime timer
	var timer = Timer.new()
	timer.wait_time = 2.0  # Shot disappears after 2 seconds
	timer.one_shot = true
	timer.timeout.connect(destroy_shot)
	add_child(timer)
	timer.start()

func _physics_process(delta):
	# Move the shot
	position.x += direction * speed * delta

func setup_shot(shot_direction: int, charged: bool = false):
	direction = shot_direction
	is_charged = charged
	
	if is_charged:
		speed = CHARGED_SPEED
		damage = CHARGED_DAMAGE
		# Scale up charged shot
		scale = Vector2(1.5, 1.5)
		# Change color/sprite for charged shot
		modulate = Color.CYAN
	else:
		speed = NORMAL_SPEED
		damage = NORMAL_DAMAGE
		scale = Vector2.ONE
		modulate = Color.WHITE
	
	# Flip sprite if shooting left
	if direction < 0:
		sprite.flip_h = true

func _on_area_entered(area):
	# Hit an enemy or destructible object
	if area.has_method("take_damage"):
		area.take_damage(damage)
		create_hit_effect()
		destroy_shot()

func _on_body_entered(body):
	# Hit a wall or solid object
	if body.is_in_group("walls") or body.is_in_group("terrain"):
		create_hit_effect()
		destroy_shot()

func create_hit_effect():
	# Play hit sound
	hit_sound.play()
	
	# Create hit particles
	hit_particles.emitting = true
	
	# Hide the shot sprite
	sprite.visible = false
	collision.set_deferred("disabled", true)
	
	# Wait for particles to finish before destroying
	await get_tree().create_timer(0.5).timeout

func destroy_shot():
	queue_free()