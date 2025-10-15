extends Area2D

class_name PlayerShot

const NORMAL_SPEED = 400.0
const CHARGED_SPEED = 500.0
const NORMAL_DAMAGE = 1
const CHARGED_DAMAGE = 5

var direction = 1
var speed = NORMAL_SPEED
var damage = NORMAL_DAMAGE
var is_charged = false

@onready var sprite = $AnimatedSprite2D
@onready var collision = $CollisionShape2D
@onready var charge_collision = $ChargeShotCollisionShape2D
@onready var hit_particles = $HitParticles
@onready var hit_sound = $HitSound
@onready var Chargeshot_Sound = $ChargedShot
@onready var screen_notifier = $VisibleOnScreenNotifier2D

func _ready():
	# Set collision layers - PlayerShot should be on layer 3 and detect layer 4 (enemies)
	collision_layer = 4  # Layer 3 (bit 2, value 4) - Player shots layer
	collision_mask = 8   # Layer 4 (bit 3, value 8) - Detect enemies layer
	print("PlayerShot collision setup - Layer: ", collision_layer, " Mask: ", collision_mask)
	
	# Connect area entered signal for collision detection
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	# Connect screen exit signal to destroy shot when it leaves camera view
	screen_notifier.screen_exited.connect(_on_screen_exited)
	
	# Set up lifetime timer as fallback (in case shot gets stuck)
	var timer = Timer.new()
	timer.wait_time = 5.0  # Increased to 5 seconds as fallback only
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
		$AnimatedSprite2D.play("ChargedShot")
		Chargeshot_Sound.play()
		
		# Use charge shot collision shape
		collision.disabled = true
		charge_collision.disabled = false
	else:
		$AnimatedSprite2D.play("default")
		speed = NORMAL_SPEED
		damage = NORMAL_DAMAGE
		scale = Vector2.ONE
		modulate = Color.WHITE
		
		# Use normal shot collision shape
		collision.disabled = false
		charge_collision.disabled = true
	
	# Flip sprite if shooting left
	if direction < 0:
		sprite.flip_h = true

func _on_area_entered(area):
	print("PlayerShot hit area: ", area.name, " of type: ", area.get_class(), " Layer: ", area.collision_layer)
	
	# Ignore attack areas (layer 5/16) - only hit hurtboxes (layer 4/8)
	if area.collision_layer == 16:  # Boss attack areas
		print("Ignoring boss attack area")
		return
	
	# Check if it's on the enemy layer (8)
	if area.collision_layer == 8:
		print("Hit enemy layer area: ", area.name)
		var parent = area.get_parent()
		print("Parent: ", parent.name, " has take_damage: ", parent.has_method("take_damage"))
		if parent.has_method("take_damage"):
			print("PlayerShot hitting enemy for ", damage, " damage")
			parent.take_damage(damage)
			create_hit_effect()
			destroy_shot()
			return
	
	# Check if it's a boss hurtbox (try different ways)
	if area.name.to_lower().contains("hurtbox") or area.name.to_lower().contains("hurt"):
		var parent = area.get_parent()
		print("Found hurtbox, parent: ", parent.name, " has take_damage: ", parent.has_method("take_damage"))
		if parent.has_method("take_damage"):
			print("PlayerShot hitting boss for ", damage, " damage")
			parent.take_damage(damage)
			create_hit_effect()
			destroy_shot()
			return
	
	# Check if the area itself has take_damage method
	if area.has_method("take_damage"):
		print("Area has take_damage method, calling it")
		area.take_damage(damage)
		create_hit_effect()
		destroy_shot()
		return
		
	print("PlayerShot hit area but no damage method found")

func _on_body_entered(body):
	# Hit a wall or solid object
	if body.is_in_group("walls") or body.is_in_group("terrain"):
		create_hit_effect()
		destroy_shot()

func _on_screen_exited():
	# Destroy shot when it leaves the camera view
	destroy_shot()

func create_hit_effect():
	# Play hit sound
	#hit_sound.play()
	
	# Create hit particles
	#hit_particles.emitting = true
	
	# Hide the shot sprite
	sprite.visible = false
	collision.set_deferred("disabled", true)
	
	# Wait for particles to finish before destroying
	await get_tree().create_timer(0.5).timeout

func destroy_shot():
	queue_free()
