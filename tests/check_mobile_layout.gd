extends SceneTree
func _initialize() -> void:
	call_deferred("check")
func check() -> void:
	root.size = Vector2i(1560,720)
	var game = load("res://tests/game_fixture.gd").new()
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(game)
	for i in range(12):
		await process_frame
	assert(game.top_panel.z_index > 100 and game.bottom_panel.z_index > 100)
	assert(game.wide_layout)
	assert(game.room.wide_camera)
	assert(game.room.unit * 12.0 / game.room.size.x > 0.95)
	assert(game.top_panel.position.y + game.top_panel.size.y < game.bottom_panel.position.y)
	assert(game.bottom_panel.position.y + game.bottom_panel.size.y <= game.get_viewport_rect().size.y)
	assert(game.recipe_selector.get_global_rect().end.x <= game.get_viewport_rect().size.x)
	game.room.show_work_status(0,"Выпечка · 5 сек.",0.5)
	var marker: Control=game.room.work_markers[0]
	assert(marker.position.y>=game.room.play_area.position.y)
	assert(marker.get_rect().end.x<=game.room.play_area.end.x)
	game.room.clear_work_status(0)
	var before: Vector2 = game.room.origin
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = game.room.play_area.get_center()
	game.room._input(press)
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(30,20)
	game.room._input(move)
	assert(game.room.origin.is_equal_approx(before + Vector2(30,20)))
	game.room._select(0)
	assert(not game.busy, "Dragging must not activate oven")
	game.room.toggle_overview()
	assert(game.room.overview and game.room.pan_offset == Vector2.ZERO)
	assert(game.room.unit * 8 < game.room.play_area.size.y)
	root.size = Vector2i(600,900)
	for i in range(12):
		await process_frame
	assert(not game.wide_layout)
	assert(game.bottom_panel.position.y > game.top_panel.position.y + game.top_panel.size.y)
	print("PASS: wide room fills screen width, compact HUD, camera drag, click suppression, whole-room overview and portrait reflow")
	quit()
