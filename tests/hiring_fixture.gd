extends "res://main.gd"
func _save_progress() -> void: pass
func _backup_progress() -> void: pass
func _load_progress() -> void:
	coins=500
	experience=380
	fresh_game=false
	auto_restock=false
	purchased.assign(["oven","display","mixer","register","forming","decorator"])
