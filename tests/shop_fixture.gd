extends "res://main.gd"

func _save_progress() -> void:
	pass

func _load_progress() -> void:
	pass

func _backup_progress() -> void:
	pass

# Explicit-queue suites isolate planning; autonomous behavior has its own suite.
func _plan_autonomous_batch() -> void: pass
