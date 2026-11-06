extends "res://main.gd"

# Production tests use a fully equipped kitchen and never touch the player save.
func _save_progress() -> void:
	pass

func _load_progress() -> void:
	coins = 0
	fresh_game = false
	purchased.assign(["oven","display","mixer","register","forming","decorator"])

func _backup_progress() -> void:
	pass
