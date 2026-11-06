extends SceneTree
var game: Control
var visited: Array[int] = []
func _initialize() -> void:
	call_deferred("check")
func require(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
func await_batch() -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while game.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	require(not game.busy, "Batch route did not finish")
func check() -> void:
	Engine.time_scale = 12.0
	game = load("res://tests/shop_fixture.gd").new()
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(game)
	await process_frame
	await process_frame
	print("Shop size: ",game.equipment_shop.panel.size)
	require(game.equipment_shop.panel.size.y < game.get_viewport_rect().size.y, "Shop must fit the screen")
	require(game.coins == 500 and game.purchased == ["register"], "Fresh game starts with capital and only free register")
	require(game.room.recipe_pool.is_empty(), "No visitors before kitchen is ready")
	require(not game.room.is_occupied(game.room.cells[0]), "Unpurchased equipment does not block floor")
	require(not game.room.objects[0].visible and game.room.objects[3].visible, "Only purchased objects appear")
	game._purchase_equipment("forming")
	require(game.coins == 500 and "forming" not in game.purchased, "Level-locked purchase rejected")
	game._start_batch("croissant")
	require(not game.busy, "Cannot bake without equipment")
	for index in range(3):
		game.equipment_shop.list.get_child(index*3+2).pressed.emit()
	require(game.coins == 50 and game.room.recipe_pool == ["croissant"], "Starter kit costs 450 and enables first recipe")
	game._purchase_equipment("oven")
	require(game.coins == 50, "Duplicate purchase does not charge")
	game.experience = 25
	game._refresh()
	game._purchase_equipment("forming")
	require(game.coins == 50 and "forming" not in game.purchased, "Insufficient funds rejected")
	require("cookie" not in game.room.recipe_pool, "Unlocked recipe not ordered until its equipment is bought")
	game._start_batch("cookie")
	require(not game.busy, "Cannot bypass recipe requirements")
	game.coins = 200
	game._purchase_equipment("forming")
	require(game.coins == 110 and "cookie" in game.room.recipe_pool, "Equipment purchase enables cookie recipe")
	game.equipment_shop.hide()
	game.room.pause_customers()
	game.room.customer_delay = 1000
	game.room.objects[4].pressed.connect(func(): pass)
	game.room.arrived.connect(func(): visited.append(int(game.room.chef_position.x)*10+int(game.room.chef_position.y)))
	game._start_batch("cookie")
	require(game.busy, "Cookie batch begins after purchase")
	game._purchase_equipment("decorator")
	require("decorator" not in game.purchased, "Purchases cannot interrupt active batch")
	await await_batch()
	require(game.inventory.count_of("cookie") == 8, "Forming station participates in cookie batch")
	require(visited.size() >= 4, "Chef visits mixer, forming table, oven and display")
	game.experience = 75
	game.coins = 300
	game._purchase_equipment("decorator")
	require(game.coins == 120 and "cupcake" in game.room.recipe_pool, "Level-three station enables cupcake")
	game.equipment_shop.hide()
	game.room.pause_customers()
	game.room.customer_delay = 1000
	game._start_batch("cupcake")
	await await_batch()
	require(game.inventory.count_of("cupcake") == 6, "Cupcake batch uses decorating station")
	var saved := ConfigFile.new()
	require(saved.parse(game._progress_data().encode_to_text()) == OK, "Save format round trip")
	var restored = load("res://tests/shop_fixture.gd").new()
	root.add_child(restored)
	restored._restore_progress(saved)
	restored._refresh()
	require(restored.coins == 120 and restored.purchased.size() == 6, "Purchases restored with no repeat grant")
	require(restored.inventory.count_of("cookie") == 8 and restored.room.is_owned(5), "Stock and visible ownership restored")
	var legacy := ConfigFile.new()
	legacy.set_value("progress", "coins", 105)
	legacy.set_value("progress", "experience", 15)
	restored._restore_progress(legacy)
	require(restored.coins == 105 and restored.experience == 15 and restored.purchased.size() == 4, "Legacy save keeps progress and original equipment")
	game._confirm_new_game()
	require(game.new_game_dialog.visible, "New game requires confirmation")
	game.new_game_dialog.confirmed.emit()
	require(game.coins == 500 and game.experience == 0 and game.inventory.total() == 0 and game.purchased == ["register"], "Explicit new game resets to starter budget")
	print("PASS: startup capital, purchases, unique charges, level and money gates, floor occupancy, recipe dependencies, real production routes, ownership save/load, legacy migration and explicit new game")
	quit()
