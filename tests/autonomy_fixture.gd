extends "res://main.gd"
func _save_progress() -> void: pass
func _backup_progress() -> void: pass
func _load_progress() -> void:
	coins=0
	experience=180
	fresh_game=false
	purchased.assign(["oven","display","mixer","register","forming","decorator"])

# Legacy routing suites run the single-customer harness; check_service covers the new staff flow.
func _setup_customer_service() -> void:
	service_label.hide()
