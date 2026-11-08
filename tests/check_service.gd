extends SceneTree
var game: Control
var chef_handled_order:=false
func _initialize() -> void: call_deferred("check")
func require(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
func wait_sales(count: int) -> void:
	var deadline:=Time.get_ticks_msec()+15000
	while game.room.service.served<count and Time.get_ticks_msec()<deadline:
		if game.taking_order: chef_handled_order=true
		await process_frame
	if game.room.service.served<count:
		for item in game.room.service.customers: print(item.id," ",item.state," ",item.pos," -> ",item.goal," route ",item.route)
		print("cashier ",game.room.service.cashier_position," ",game.room.service.cashier_phase," ",game.room.service.status)
	require(game.room.service.served>=count,"Cashier must finish expected sales")
func check() -> void:
	Engine.time_scale=12
	game=load("res://tests/service_fixture.gd").new()
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(game)
	var service=game.room.service
	service.arrival_remaining=10000
	game.inventory.stock.croissant=6
	game._refresh()
	for i in range(3):
		var spawn_deadline:=Time.get_ticks_msec()+3000
		var spawned: bool=service.spawn_customer("croissant")
		while not spawned and Time.get_ticks_msec()<spawn_deadline:
			await process_frame
			spawned=service.spawn_customer("croissant")
		require(spawned,"Three customers enter actual queue as entrance clears")
	require(not service.spawn_customer("cookie"),"Queue limit enforced")
	await wait_sales(3)
	require(game.coins==45 and game.inventory.count_of("croissant")==3,"Three independent handovers each charge stock and reward once")
	require(not chef_handled_order and not game.taking_order,"Cashier handles every order; chef only moves aside to keep paths free")
	service.clear_customers()
	service.arrival_remaining=10000
	game.inventory.stock.croissant=6
	require(service.spawn_customer("cupcake"),"Missing-desert buyer enters")
	require(service.missing_orders().get("cupcake",0)==1,"Missing dessert visible immediately")
	require(service.summary().contains("Капкейк"),"HUD names missing dessert")
	var deadline:=Time.get_ticks_msec()+10000
	while service.customers[0].state!="waiting" and Time.get_ticks_msec()<deadline: await process_frame
	require(service.customers[0].state=="waiting","Buyer physically waits at display")
	require(service.spawn_customer("croissant"),"Cashier can accept another customer while first waits for stock")
	await wait_sales(4)
	require(service.missing_orders().has("cupcake"),"Unfulfilled order remains while other order sells")
	service.clear_customers()
	service.arrival_remaining=10000
	var unserved_before: int=service.left_unserved
	var coins_before: int=game.coins
	require(service.spawn_customer("cupcake"),"Timeout buyer enters")
	deadline=Time.get_ticks_msec()+10000
	while service.customers[0].state!="waiting" and Time.get_ticks_msec()<deadline: await process_frame
	service.customers[0].wait_left=0.1
	await process_frame
	await process_frame
	require(service.left_unserved==unserved_before+1 and game.coins==coins_before,"Unfulfilled buyer leaves without false payment")
	service.clear_customers()
	service.arrival_remaining=10000
	game.inventory.stock={"croissant":4,"cookie":0,"cupcake":0,"mousse":0}
	game._refresh()
	game._start_batch("cookie")
	require(game.busy and service.spawn_customer("croissant"),"Customer enters during production")
	await wait_sales(5)
	deadline=Time.get_ticks_msec()+10000
	while game.busy and Time.get_ticks_msec()<deadline: await process_frame
	require(game.inventory.count_of("cookie")==8,"Production completes while cashier serves")
	service.clear_customers()
	game.experience=2500
	game._configure_staff()
	game.coins=1000
	var old_time: float=game.Catalog.processing_seconds(game._effective_recipe("cookie"))
	for id in ["staff_walk","staff_work","staff_tasks"]: game._purchase_equipment(id)
	require(game.coins==400 and is_equal_approx(game.room.chef_move_speed,3.08),"Movement upgrade costs once and accelerates chef")
	require(is_equal_approx(service.walking_speed,3.36) and is_equal_approx(service.work_factor,0.75),"Cashier movement and work improve")
	require(game.Catalog.processing_seconds(game._effective_recipe("cookie"))<old_time,"Manual cooking stages improve")
	require(game.job_queue.limit==8 and service.capacity==3,"Organisation expands both production and customer capacity")
	for i in range(8): require(game.job_queue.enqueue("croissant")>0,"Eight employee tasks accepted after upgrade")
	require(game.job_queue.enqueue("cookie")==-1,"Ninth task rejected")
	var saved:=ConfigFile.new()
	saved.parse(game._progress_data().encode_to_text())
	var copy=load("res://tests/service_fixture.gd").new()
	root.add_child(copy)
	copy.room.editing=true
	copy._restore_progress(saved)
	require(copy.job_queue.limit==8 and copy.job_queue.waiting.size()==8 and copy.room.service.capacity==3 and is_equal_approx(copy.room.chef_move_speed,3.08),"Staff upgrades persist")
	copy.queue_free()
	game._start_new_game()
	require(game.job_queue.limit==5 and service.capacity==1 and service.active_count()==0,"New game clears buyers and resets staff upgrades")
	print("PASS: FIFO queue, cashier physical service and handover, missing-stock visibility, independent orders, no false rewards, concurrent production, staff upgrades, persistence and reset")
	quit()
