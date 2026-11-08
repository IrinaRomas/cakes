extends "res://main.gd"
func _save_progress() -> void: pass
func _backup_progress() -> void: pass
func _load_progress() -> void:
	hired_staff=["chef","cashier"]
	coins=0
	experience=1100
	fresh_game=false
	auto_restock=false
	purchased.assign(["oven","display","mixer","register","forming","decorator"])
