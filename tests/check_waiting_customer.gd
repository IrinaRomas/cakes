extends SceneTree
var game: Control
func _initialize() -> void: call_deferred("check")
func require(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
func wait_state(state: String) -> void:
	var deadline:=Time.get_ticks_msec()+10000
	while game.room.customer_state!=state and Time.get_ticks_msec()<deadline: await process_frame
	require(game.room.customer_state==state,"Customer reaches "+state)
func check() -> void:
	Engine.time_scale=12
	game=load("res://tests/game_fixture.gd").new()
	root.add_child(game)
	game.experience=113
	game.inventory.stock.croissant=17
	game.room.customer_delay=1000
	game._refresh()
	for i in range(5): game._start_batch("cupcake")
	require(not game.busy and game.job_queue.waiting.size()==5,"Full display pauses all five queued batches")
	game.room.current_recipe_id="cupcake"
	game.room.customer_state="waiting"
	game.room.customer_position=Vector2(2,3)
	game.room.customer_entry=Vector2i(5,5)
	game.room.customer.visible=true
	game.room.customer.waiting=true
	game.room.customer.set_order(game.Catalog.get_recipe("cupcake"))
	game.customer_wait_remaining=0.2
	await wait_state("leaving")
	require(not game.room.customer.paid and game.coins==0 and game.experience==113,"Unfulfilled customer leaves without rewards")
	require(game.inventory.total()==17,"No stock is discarded automatically")
	await wait_state("absent")
	game.room.pending_new_recipe=""
	game.room.recipe_rotation=0
	game.room.customer_delay=0
	await wait_state("leaving")
	require(game.coins==15 and game.inventory.count_of("croissant")==16,"Next customer buys existing stock automatically")
	game.room.pause_customers()
	game.room.customer_delay=1000
	for i in range(4): game._discard_stock("croissant")
	var deadline:=Time.get_ticks_msec()+10000
	while game.inventory.count_of("cupcake")<6 and Time.get_ticks_msec()<deadline: await process_frame
	require(game.inventory.count_of("cupcake")==6,"Queued production resumes once six places are available")
	require(game.inventory.total()==18 and game.job_queue.waiting.size()==4,"Capacity and remaining queue preserved")
	game._start_batch("cupcake")
	game._start_batch("cupcake")
	await process_frame
	require(game.status_label.text.contains("мест") and game.status_label.text.contains("Рецепты"),"Full queue does not hide storage explanation")
	print("PASS: 17 croissants, five cupcake batches, unpaid timeout, next buyer, no lost stock, capacity recovery and visible explanation")
	quit()
