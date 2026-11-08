extends SceneTree
const Inventory = preload("res://display_inventory.gd")
var scene: Control
func _initialize() -> void:
	call_deferred("check")
func require(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
func wait_state(state: String) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while scene.room.customer_state != state and Time.get_ticks_msec() < deadline:
		await process_frame
	require(scene.room.customer_state == state, "Customer did not reach " + state)
func wait_batch(target: Control) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while target.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	require(not target.busy, "Batch did not complete")
func check() -> void:
	Engine.time_scale = 12.0
	var inv = Inventory.new()
	for i in range(3):
		require(inv.reserve("croissant", 6), "Reserve space for complete batch")
		inv.finish_batch()
	require(inv.total() == 18 and not inv.reserve("cookie", 8), "Capacity cannot overflow")
	require(inv.take_one("croissant") and not inv.can_fit(6), "Single sale does not create room for entire batch")
	require(not inv.take_one("cookie"), "Stock cannot become negative")
	scene = load("res://tests/game_fixture.gd").new()
	root.add_child(scene)
	await process_frame
	scene.room.customer_delay = 1000
	scene._start_batch("cookie")
	require(not scene.busy, "Locked recipe cannot be baked")
	scene._start_batch("croissant")
	require(scene.busy and scene.inventory.reserved_count == 6 and scene.inventory.total() == 0, "Batch starts without customer and reserves six places")
	scene._start_batch("croissant")
	require(scene.inventory.reserved_count == 6 and scene.job_queue.waiting.size() == 1, "Next batch queues without duplicate reservation")
	scene._cancel_job(scene.job_queue.waiting[0].id)
	await wait_batch(scene)
	require(scene.inventory.count_of("croissant") == 6, "Six croissants arrive together")
	require(scene.coins == 0 and scene.experience == 0, "Baking alone earns no reward")
	for count in range(1,3):
		scene.room.customer_delay = 0
		await wait_state("ordering")
		scene._accept_order()
		await wait_state("leaving")
		require(not scene.busy and scene.inventory.count_of("croissant") == 6-count, "Customers buy individually from same batch")
		require(scene.coins == 15*count and scene.experience == 5*count, "Per-item sale reward")
		scene._serve_customer()
		require(scene.coins == 15*count, "No double sale")
	# Accept and sell an existing item while the chef is making another recipe.
	scene.room.pause_customers()
	scene.experience = 180
	scene._refresh()
	scene.room.pending_new_recipe = ""
	scene.room.recipe_rotation = 0
	scene.room.customer_delay = 0
	await wait_state("ordering")
	require(scene.room.current_recipe_id == "croissant", "Buyer asks for stocked croissant")
	scene._start_batch("cookie")
	require(scene.busy and scene.inventory.reserved_count == 8, "Independent cookie batch starts")
	scene._accept_order()
	await wait_state("leaving")
	require(scene.busy, "Existing stock sells while new batch cooks")
	require(scene.inventory.count_of("croissant") == 3 and scene.coins == 45, "Sale reduces only requested recipe")
	var saved := ConfigFile.new()
	require(saved.parse(scene._progress_data().encode_to_text()) == OK, "Save round trip")
	var copy = load("res://tests/game_fixture.gd").new()
	root.add_child(copy)
	copy._restore_progress(saved)
	copy.room.customer_delay = 1000
	copy._refresh()
	require(copy.inventory.count_of("croissant") == 3 and copy.job_queue.waiting[0].recipe == "cookie", "Stock and unfinished batch survive reload")
	copy._dispatch_queue()
	await wait_batch(copy)
	require(copy.inventory.count_of("cookie") == 8 and copy.inventory.total() == 11, "Resumed batch committed exactly once")
	copy._start_batch("cupcake")
	await wait_batch(copy)
	require(copy.inventory.total() == 17, "Mixed recipes share same capacity")
	copy._start_batch("croissant")
	require(not copy.busy and copy.inventory.total() == 17, "Insufficient room blocks production")
	var old_coins: int = copy.coins
	copy._discard_stock("cookie")
	require(copy.inventory.count_of("cookie") == 7 and copy.coins == old_coins, "Discard frees space without payment")
	copy._open_recipe_book()
	require(copy.recipe_book.visible, "Inventory management opens")
	copy.recipe_book.hide()
	# Check that an order with zero stock waits rather than producing or paying.
	var empty = load("res://tests/game_fixture.gd").new()
	root.add_child(empty)
	scene = empty
	await wait_state("ordering")
	scene._accept_order()
	await wait_state("waiting")
	require(scene.coins == 0 and not scene.busy, "Empty display never fulfils order or starts automatic single baking")
	require(scene.batch_button.disabled == false, "Player can start a batch for waiting buyer")
	print("PASS: independent batches, reservations, 18-item limit, per-recipe stock, per-item sales, concurrent baking and sales, no duplicate rewards, save/resume, mixed capacity, discard and out-of-stock waiting")
	quit()
