extends SceneTree
var game: Control
func _initialize() -> void:
	call_deferred("check")
func require(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
func check() -> void:
	Engine.time_scale = 12.0
	root.size = Vector2i(1560,720)
	game = load("res://tests/game_fixture.gd").new()
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(game)
	await process_frame
	game.inventory.reserve("croissant",6)
	game.inventory.finish_batch()
	game._refresh()
	var saw_counter := false
	var deadline := Time.get_ticks_msec()+10000
	while game.coins < 15 and Time.get_ticks_msec()<deadline:
		if game.taking_order:
			require(game.layout_button.disabled and not game.batch_button.disabled,"Reception locks furniture but allows planning batches")
			if game.room.chef.working:
				var cell: Vector2i = Vector2i(game.room.chef_position.round())
				var register: Vector2i = game.room.cells[3]
				saw_counter = absi(cell.x-register.x)+absi(cell.y-register.y)==1
		await process_frame
	require(game.coins == 15 and game.inventory.count_of("croissant")==5,"Order accepted and sold without input")
	require(saw_counter,"Chef physically receives order next to register")
	game._serve_customer()
	require(game.coins==15,"Automatic checkout cannot pay twice")
	for button in game.find_children("*","Button",true,false):
		require(button.text!="Принять заказ","Manual acceptance button removed")
	# Pause further arrivals until a new batch reaches the oven.
	game.room.pause_customers()
	game.room.customer_delay=1000
	game.experience=25
	game._refresh()
	game._start_batch("cookie")
	deadline=Time.get_ticks_msec()+10000
	while game.production_phase!="baking" and Time.get_ticks_msec()<deadline:
		await process_frame
	require(game.production_phase=="baking","Batch reaches oven")
	game.room.pending_new_recipe=""
	game.room.recipe_rotation=0
	game.room.customer_delay=0
	var serviced_during_bake := false
	deadline=Time.get_ticks_msec()+10000
	while (game.busy or game.coins<30) and Time.get_ticks_msec()<deadline:
		if game.taking_order and game.busy:
			serviced_during_bake=true
		await process_frame
	require(serviced_during_bake,"Chef uses baking time for reception")
	require(not game.busy and game.inventory.count_of("cookie")==8,"Batch delivered after automatic reception")
	require(game.coins==30 and game.inventory.count_of("croissant")==4,"Existing stock sells during batch")
	require(not game.room.chef.carrying and not game.taking_order,"Chef tasks return to idle")
	var cold=load("res://tests/game_fixture.gd").new()
	root.add_child(cold)
	cold.experience=150
	cold.purchased.append("fridge")
	cold.room.apply_purchases(cold.purchased)
	cold.room.customer_delay=1000
	cold.inventory.reserve("croissant",6)
	cold.inventory.finish_batch()
	cold._refresh()
	cold._start_batch("mousse")
	deadline=Time.get_ticks_msec()+10000
	while cold.production_phase!="cooling" and Time.get_ticks_msec()<deadline: await process_frame
	require(cold.production_phase=="cooling","Mousse reaches cooling stage")
	cold.room.pending_new_recipe=""
	cold.room.recipe_rotation=0
	cold.room.customer_delay=0
	var serviced_during_cooling:=false
	deadline=Time.get_ticks_msec()+10000
	while (cold.busy or cold.coins<15) and Time.get_ticks_msec()<deadline:
		if cold.taking_order and cold.busy: serviced_during_cooling=true
		await process_frame
	require(serviced_during_cooling and not cold.busy,"Chef receives orders during cooling and resumes dessert")
	require(cold.inventory.count_of("mousse")==6 and cold.inventory.count_of("croissant")==5,"Cooling reception preserves batch and sells stocked item once")
	print("PASS: automatic reception, physical register visit, no acceptance button, conflict locks, oven-time and cooling-time reception, batch continuation and per-item payment")
	quit()
