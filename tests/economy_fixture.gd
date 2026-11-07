extends "res://main.gd"
func _save_progress() -> void: pass
func _backup_progress() -> void: pass
func _load_progress() -> void:
	coins=5000
	experience=150
	fresh_game=false
	purchased.assign(["oven","display","mixer","register","forming","decorator","fridge"])
