extends SceneTree
func _initialize() -> void: call_deferred("check")
func require(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
func new_game() -> Control:
	var game=load("res://tests/autonomy_fixture.gd").new()
	root.add_child(game)
	game.room.customer_delay=10000
	return game
func wait_idle(game: Control) -> void:
	var deadline:=Time.get_ticks_msec()+15000
	while (game.busy or not game.job_queue.waiting.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	require(not game.busy and game.job_queue.waiting.is_empty(),"Autonomous work settles")
func check() -> void:
	Engine.time_scale=12
	var game=new_game()
	game.inventory.stock.cookie=3
	game._refresh()
	var deadline:=Time.get_ticks_msec()+10000
	while game.inventory.count_of("croissant")==0 and Time.get_ticks_msec()<deadline: await process_frame
	game._set_auto_restock(false)
	require(game.inventory.count_of("croissant")==6 and game.coins==0,"Screenshot case: zero croissants and three cookies trigger free baking without clicks")
	await wait_idle(game)
	game.inventory.stock={"croissant":0,"cookie":0,"cupcake":0,"mousse":0}
	game._refresh()
	game._set_auto_restock(true)
	deadline=Time.get_ticks_msec()+15000
	while (game.inventory.total()<14 or game.busy or not game.job_queue.waiting.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	require(game.inventory.total()==14 and not game.busy,"Autonomous planner stocks two different recipes in eighteen places")
	for i in range(20): await process_frame
	require(game.inventory.total()==14 and game.job_queue.waiting.is_empty(),"Existing and reserved stock prevent duplicates and overflow")
	game._set_auto_restock(false)
	game.inventory.stock={"croissant":0,"cookie":0,"cupcake":0,"mousse":0}
	game._refresh()
	game.auto_restock=true
	game._plan_autonomous_batch()
	game._plan_autonomous_batch()
	require(game.job_queue.waiting.size()==2 and game.job_queue.waiting[0].automatic,"Auto jobs are labelled")
	game._start_batch("cupcake")
	require(game.job_queue.active.recipe=="cupcake","Manual batch takes priority over unstarted automatic jobs")
	game._set_auto_restock(false)
	require(game.job_queue.waiting.is_empty(),"Pausing removes unstarted auto work")
	await wait_idle(game)
	game._open_recipe_book()
	game.recipe_book.auto_toggle.button_pressed=true
	require(game.auto_restock,"Recipe-book switch enables autonomy")
	game.recipe_book.auto_toggle.button_pressed=false
	require(not game.auto_restock,"Recipe-book switch pauses autonomy")
	game.recipe_book.hide()
	var saved:=ConfigFile.new()
	saved.parse(game._progress_data().encode_to_text())
	var copy=new_game()
	copy.room.editing=true
	copy._restore_progress(saved)
	require(not copy.auto_restock,"Manual pause survives restart")
	saved.erase_section("automation")
	copy._restore_progress(saved)
	require(copy.auto_restock,"Old saves automatically enable autonomy")
	copy.queue_free()
	var helper=new_game()
	helper.experience=1700
	helper.hired_staff.append("assistant")
	helper.purchased.append("assistant_station")
	helper.room.apply_purchases(helper.purchased)
	helper._configure_staff()
	helper._refresh()
	deadline=Time.get_ticks_msec()+10000
	while helper.preparing_job_id<0 and Time.get_ticks_msec()<deadline: await process_frame
	require(helper.busy and helper.preparing_job_id>=0,"Assistant autonomously prepares next tray in parallel")
	helper._set_auto_restock(false)
	await wait_idle(helper)
	require(helper.inventory.total()==14,"Pause finishes preparations already underway")
	var upgraded=new_game()
	upgraded.room.editing=true
	for id in ["display_extra","display_shelves","oven_upgrade"]: upgraded.purchased.append(id)
	upgraded.room.apply_purchases(upgraded.purchased)
	upgraded._refresh()
	upgraded.room.editing=false
	for i in range(5): upgraded._plan_autonomous_batch()
	require(upgraded.job_queue.waiting.size()==3 and upgraded.inventory.capacity==48,"Planner uses upgraded storage and all available recipes")
	var planned:=0
	for job in upgraded.job_queue.waiting: planned+=int(upgraded._recipe_for_job(job).batch)
	require(planned==26,"Planner accounts for upgraded batch sizes")
	upgraded._set_auto_restock(false)
	upgraded.purchased.erase("oven")
	upgraded.room.apply_purchases(upgraded.purchased)
	upgraded.auto_restock=true
	upgraded._plan_autonomous_batch()
	require(upgraded.job_queue.waiting.is_empty() and not upgraded.auto_status.is_empty(),"Missing equipment prevents planning and explains why")
	upgraded.room.editing=true
	print("PASS: autonomous empty-stock recovery, no clicks or money, variety, capacity forecasts, duplicate prevention, manual priority, pause/save migration, assistant and upgraded batches")
	quit()
