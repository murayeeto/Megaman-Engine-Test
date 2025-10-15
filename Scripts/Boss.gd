extends CharacterBody2D

class_name Boss

const GRAVITY = 980.0
const HEALTH = 100

var current_health = HEALTH
var is_attacking = false
var attack_cooldown = 0.0
var player_reference = null
var is_player_on_screen = false

@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var player_detector = $PlayerDetector
@onready var attack_timer = $AttackTimer

enum AttackType {
	ATTACK1,
	ATTACK2, 
	ATTACK3
}

var available_attacks = [AttackType.ATTACK1, AttackType.ATTACK2, AttackType.ATTACK3]

func _ready():
	player_detector.body_entered.connect(_on_player_entered_screen)
	player_detector.body_exited.connect(_on_player_exited_screen)
	attack_timer.timeout.connect(_start_random_attack)
	attack_timer.wait_time = randf_range(2.0, 4.0)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	move_and_slide()
	
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	if is_player_on_screen and not is_attacking and attack_cooldown <= 0:
		if not attack_timer.is_stopped():
			return
		attack_timer.start()

func _on_player_entered_screen(body):
	if body is Player:
		is_player_on_screen = true
		player_reference = body

func _on_player_exited_screen(body):
	if body is Player:
		is_player_on_screen = false
		player_reference = null

func _start_random_attack():
	if is_attacking or attack_cooldown > 0:
		return
	
	var attack = available_attacks[randi() % available_attacks.size()]
	execute_attack(attack)

func execute_attack(attack_type: AttackType):
	is_attacking = true
	
	match attack_type:
		AttackType.ATTACK1:
			animated_sprite.play("attack1")
		AttackType.ATTACK2:
			animated_sprite.play("attack2")
		AttackType.ATTACK3:
			animated_sprite.play("attack3")
	
	animated_sprite.animation_finished.connect(_on_attack_finished, CONNECT_ONE_SHOT)

func _on_attack_finished():
	is_attacking = false
	attack_cooldown = randf_range(1.5, 3.0)
	animated_sprite.play("idle")
	attack_timer.wait_time = randf_range(2.0, 4.0)

func take_damage(amount: int):
	current_health -= amount
	
	if current_health <= 0:
		die()
	else:
		animated_sprite.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)

func die():
	is_attacking = false
	attack_timer.stop()
	animated_sprite.play("death")
	collision_shape.set_deferred("disabled", true)
	
	animated_sprite.animation_finished.connect(_on_death_finished, CONNECT_ONE_SHOT)

func _on_death_finished():
	queue_free()
