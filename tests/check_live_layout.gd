extends SceneTree
func _initialize() -> void: call_deferred("check")
func require(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
func new_game() -> Control:
	var game=load("res://tests/service_fixture.gd").new()
	root.add_child(game)
	game.room.service.arrival_remaining=10000
	return game
func wait_phase(game: Control, phase: String) -> void:
	var deadline:=Time.get_ticks_msec()+10000
	while (game.production_phase!=phase or not game.stage_has_started) and Time.get_ticks_msec()<deadline: await process_frame
	require(game.production_phase==phase and game.stage_has_started,"Reached "+phase)
func wait_idle(game: Control) -> void:
	var deadline:=Time.get_ticks_msec()+15000
	while (game.busy or not game.job_queue.waiting.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	require(not game.busy and game.job_queue.waiting.is_empty(),"Work resumes after layout")
func move_item(game: Control, index: int, cell: Vector2i) -> void:
	game.room._select(index)
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=false
	click.position=game.room.project(Vector2(cell)+Vector2(0.5,0.5))
	game.room._gui_input(click)
	require(game.room.cells[index]==cell,"Actual furniture input moves item")
func check() -> void:
	Engine.time_scale=12
	var game=new_game()
	game.room.service.spawn_customer("cookie")
	game._start_batch("croissant")
	await wait_phase(game,"preparing")
	require(not game.layout_button.disabled,"Furniture button remains available during cooking")
	game._toggle_layout()
	require(game.room.editing,"Editing opens during active batch")
	var left: float=game.remaining
	var chef: Vector2=game.room.chef_position
	var person: Dictionary=game.room.service.customers[0]
	var patience: float=person.wait_left
	var person_position: Vector2=person.pos
	await create_timer(8).timeout
	require(is_equal_approx(game.remaining,left) and game.room.chef_position==chef,"Cooking and chef movement freeze")
	require(person.wait_left==patience and person.pos==person_position,"Customers and their patience freeze")
	require(game.busy and game.inventory.reserved_count==6 and game.inventory.total()==0,"No hidden timer completes the batch during editing")
	move_item(game,2,Vector2i(0,0))
	game._toggle_layout()
	await wait_idle(game)
	require(game.inventory.count_of("croissant")==6 and game.coins==0,"Moved active mixer completes exactly one batch")
	game.room.service.clear_customers()
	game.room.service.arrival_remaining=10000
	game._start_batch("cookie")
	await wait_phase(game,"baking")
	game._toggle_layout()
	left=game.remaining
	move_item(game,0,Vector2i(5,0))
	move_item(game,1,Vector2i(0,4))
	await create_timer(10).timeout
	require(is_equal_approx(game.remaining,left) and game.inventory.count_of("cookie")==0,"Oven timer stays frozen after moving equipment")
	game._toggle_layout()
	await wait_idle(game)
	require(game.inventory.count_of("cookie")==8 and game.inventory.total()==14,"Baking resumes and chef visits moved oven/display")
	var cashier_game=new_game()
	cashier_game.inventory.stock.croissant=6
	cashier_game._refresh()
	cashier_game.room.service.spawn_customer("croissant")
	var deadline:=Time.get_ticks_msec()+10000
	while cashier_game.room.service.cashier_phase!="delivery" and Time.get_ticks_msec()<deadline: await process_frame
	require(cashier_game.room.service.cashier_phase=="delivery","Reached physical handover")
	cashier_game._toggle_layout()
	var buyer: Dictionary=cashier_game.room.service.customers[0]
	var buyer_id: int=buyer.id
	left=cashier_game.room.service.task_remaining
	move_item(cashier_game,3,Vector2i(4,0))
	move_item(cashier_game,1,Vector2i(0,4))
	await create_timer(8).timeout
	require(cashier_game.coins==0 and cashier_game.room.service.task_remaining==left,"Cashier cannot sell during layout")
	require(cashier_game.room.service.customers.size()==1 and buyer.id==buyer_id,"Pending buyer is retained")
	cashier_game._toggle_layout()
	deadline=Time.get_ticks_msec()+10000
	while cashier_game.room.service.served<1 and Time.get_ticks_msec()<deadline: await process_frame
	await create_timer(3).timeout
	require(cashier_game.room.service.served==1 and cashier_game.coins==15 and cashier_game.inventory.count_of("croissant")==5,"Moved register/display resumes order without duplicate sale")
	var helper_game=new_game()
	helper_game.experience=1700
	helper_game.purchased.append("assistant_station")
	helper_game.hired_staff.append("assistant")
	helper_game.room.apply_purchases(helper_game.purchased)
	helper_game._configure_staff()
	helper_game._start_batch("croissant")
	helper_game._start_batch("cookie")
	deadline=Time.get_ticks_msec()+10000
	while helper_game.preparing_job_id<0 and Time.get_ticks_msec()<deadline: await process_frame
	require(helper_game.preparing_job_id>=0,"Assistant begins preparation")
	helper_game._toggle_layout()
	left=helper_game.preparing_remaining
	move_item(helper_game,8,Vector2i(0,4))
	await create_timer(8).timeout
	require(helper_game.preparing_job_id>=0 and is_equal_approx(helper_game.preparing_remaining,left),"Assistant preparation freezes too")
	helper_game._toggle_layout()
	await wait_idle(helper_game)
	require(helper_game.inventory.total()==14,"Parallel preparation resumes at moved table")
	print("PASS: live furniture entry, frozen cooking/customers/patience/helper, real placement input, active mixer and oven movement, preserved buyer, moved cashier/display and no duplicate output/payment")
	quit()
