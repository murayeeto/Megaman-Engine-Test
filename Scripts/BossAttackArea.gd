extends Area2D

class_name BossAttackArea

var damage = 5
var is_active = false

func _ready():
	# Set collision layers - Boss attack areas detect player (use different layer than hurtbox)
	collision_layer = 16  # Layer 5 (bit 4, value 16) - Boss attack areas
	collision_mask = 1    # Layer 1 (bit 0, value 1) - Detect player
	
	body_entered.connect(_on_body_entered)
	set_monitoring(false)  # Start disabled

func activate_attack():
	print("BossAttackArea activated: ", name)
	is_active = true
	set_monitoring(true)
	
func deactivate_attack():
	is_active = false
	set_monitoring(false)

func _on_body_entered(body):
	print("Boss attack area hit body: ", body.name)
	if not is_active:
		print("Attack area not active, ignoring hit")
		return
		
	if body is Player:
		print("Boss attack hitting player for ", damage, " damage")
		body.take_damage(damage)
		deactivate_attack()
	else:
		print("Hit non-player body: ", body.get_class())
