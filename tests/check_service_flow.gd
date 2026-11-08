extends SceneTree
func _initialize() -> void: call_deferred("check")
func require(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
func check() -> void:
	Engine.time_scale=12
	var game=load("res://tests/service_fixture.gd").new()
	root.add_child(game)
	game.experience=2500
	game.hired_staff.append("assistant")
	for id in ["fridge","display_extra","display_shelves","oven_upgrade","assistant_station","staff_walk","staff_work","staff_tasks"]: game.purchased.append(id)
	game.room.apply_purchases(game.purchased)
	game._configure_staff()
	game._refresh()
	game.auto_restock=true
	game.room.service.arrival_interval=2.5
	var completed: Array[String]=[]
	game.batch_completed.connect(func(id: String): completed.append(id))
	var concurrent:=false
	var saw_full:=false
	var deadline:=Time.get_ticks_msec()+25000
	while Time.get_ticks_msec()<deadline:
		if game.busy and game.room.service.cashier_phase in ["order","delivery"]: concurrent=true
		if game.room.service.active_count()==3: saw_full=true
		require(game.inventory.total()+game.inventory.reserved_count<=48,"Autonomous production never exceeds storage")
		require(game.room.service.active_count()<=3,"Customer limit respected under continuous arrivals")
		await process_frame
	print("Flow: batches=",completed.size()," sold=",game.baked," people=",game.room.service.customers.size()," left=",game.room.service.left_unserved," phase=",game.production_phase," cashier=",game.room.service.cashier_phase)
	for item in game.room.service.customers: print(item.id," ",item.state," ",item.pos," -> ",item.goal)
	require(concurrent and saw_full,"Full queue and concurrent staff work observed")
	require(completed.size()>=5 and game.baked>=10,"Continuous service makes progress without clicks or traffic deadlock")
	require(game.room.service.customers.size()<=10,"Departing customers do not accumulate indefinitely")
	require(game.coins>0 and game.economy.sales_income==game.coins,"Every physical handover pays exactly once")
	print("PASS: sustained autonomous production, three-customer traffic, parallel employees, capacity and exact income")
	quit()
