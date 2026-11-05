extends SceneTree
var game: Control
func _initialize() -> void:
	call_deferred("check")
func expect(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
func wait_state(state: String) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while game.room.customer_state != state and Time.get_ticks_msec() < deadline:
		await process_frame
	expect(game.room.customer_state == state, "Buyer did not reach " + state)
func check() -> void:
	Engine.time_scale = 12.0
	game = load("res://tests/game_fixture.gd").new()
	root.add_child(game)
	await wait_state("ordering")
	game._accept_order()
	await wait_state("waiting")
	game._bake_selected()
	await wait_state("leaving")
	expect(game.inventory.count_of("croissant") == 5, "Batch supplies waiting buyer and leaves five items")
	for number in range(2,6):
		await wait_state("ordering")
		game._accept_order()
		await wait_state("leaving")
		expect(game.inventory.count_of("croissant") == 6-number, "Each sale uses one item")
		expect(not game.busy, "No additional baking for remaining stock")
	expect(game.experience == 25 and game.coins == 75, "Five sales award level-two threshold")
	expect("cookie" in game.room.recipe_pool, "Cookie unlock remains tied to sales")
	await wait_state("ordering")
	expect(game.room.current_recipe_id == "cookie", "Next buyer tries newly unlocked recipe")
	game._accept_order()
	await wait_state("waiting")
	expect(game.inventory.count_of("croissant") == 1 and game.inventory.count_of("cookie") == 0, "No substitution with another dessert")
	game._bake_selected()
	await wait_state("leaving")
	expect(game.inventory.count_of("cookie") == 7 and game.inventory.count_of("croissant") == 1, "Eight-cookie batch leaves seven after sale")
	expect(game.coins == 97 and game.experience == 31, "Recipe-specific sale rewards retained")
	print("PASS: batch delivered to waiting customer, five sales from one batch, level-up, newly unlocked demand, separate stock and cookie batch")
	quit()
