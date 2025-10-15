extends Area2D

class_name BossHurtbox

func take_damage(amount: int):
	print("BossHurtbox take_damage called with: ", amount)
	var boss = get_parent()
	if boss and boss.has_method("take_damage"):
		boss.take_damage(amount)
	else:
		print("Boss parent not found or no take_damage method")