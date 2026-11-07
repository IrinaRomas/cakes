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

# Explicit-queue suites isolate planning; autonomous behavior has its own suite.
func _plan_autonomous_batch() -> void: pass
