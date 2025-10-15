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

@onready var sprite = $AnimatedSprite2D
@onready var collision = $CollisionShape2D
@onready var charge_collision = $ChargeShotCollisionShape2D
@onready var hit_particles = $HitParticles
@onready var hit_sound = $HitSound
@onready var Chargeshot_Sound = $ChargedShot
@onready var screen_notifier = $VisibleOnScreenNotifier2D

func _ready():
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	screen_notifier.screen_exited.connect(_on_screen_exited)
	
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	timer.timeout.connect(destroy_shot)
	add_child(timer)
	timer.start()

func _physics_process(delta):
	position.x += direction * speed * delta

func setup_shot(shot_direction: int, charged: bool = false):
	direction = shot_direction
	is_charged = charged
	
	if is_charged:
		speed = CHARGED_SPEED
		damage = CHARGED_DAMAGE
		scale = Vector2(1.5, 1.5)
		$AnimatedSprite2D.play("ChargedShot")
		Chargeshot_Sound.play()
		
		collision.disabled = true
		charge_collision.disabled = false
	else:
		$AnimatedSprite2D.play("default")
		speed = NORMAL_SPEED
		damage = NORMAL_DAMAGE
		scale = Vector2.ONE
		modulate = Color.WHITE
		
		collision.disabled = false
		charge_collision.disabled = true
	
	if direction < 0:
		sprite.flip_h = true

func _on_area_entered(area):
	if area.has_method("take_damage"):
		area.take_damage(damage)
		create_hit_effect()
		destroy_shot()

func _on_body_entered(body):
	if body.is_in_group("walls") or body.is_in_group("terrain"):
		create_hit_effect()
		destroy_shot()

func _on_screen_exited():
	destroy_shot()

func create_hit_effect():
	hit_sound.play()
	hit_particles.emitting = true
	sprite.visible = false
	collision.set_deferred("disabled", true)
	await get_tree().create_timer(0.5).timeout

func destroy_shot():
	queue_free()
