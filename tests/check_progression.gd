extends SceneTree
const Progression=preload("res://progression.gd")
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
func check() -> void:
	Engine.time_scale=12
	for level in range(1,9):
		require(Progression.level_for_xp(Progression.LEVEL_XP[level-1])==level,"Milestone threshold")
		require(Progression.buyers(level)==(1 if level<3 else (2 if level<6 else 3)),"Visitor flow grows gradually")
	var legacy:=ConfigFile.new()
	legacy.set_value("progress","experience",318)
	legacy.set_value("progress","coins",854)
	legacy.set_value("business","purchased",PackedStringArray(["oven","mixer","display","register","assistant_station"]))
	var game=new_game()
	game.room.editing=true
	game._restore_progress(legacy)
	require(game.experience==548 and game.Catalog.level_for_xp(game.experience)==4 and game.coins==854,"Migration retains earned level and wallet")
	require("assistant_station" in game.purchased and not game.room.assistant.visible,"Purchased workstation retained; assistant arrives at later tier")
	var saved:=ConfigFile.new()
	saved.parse(game._progress_data().encode_to_text())
	game._restore_progress(saved)
	require(game.experience==548,"Progress migration runs only once")
	game._open_progression()
	require(game.progression_panel.visible and game.room.interaction_blocked,"Level map opens and blocks world interactions")
	game.progression_panel.hide()
	game.queue_free()
	var early=new_game()
	early.experience=0
	early.hired_staff.assign(["chef"])
	early._configure_staff()
	early._refresh()
	early.auto_restock=true
	early.room.service.arrival_remaining=0
	early.room.service.arrival_interval=0.8
	var served_by_chef:=false
	var deadline:=Time.get_ticks_msec()+12000
	while early.baked<2 and Time.get_ticks_msec()<deadline:
		if early.room.service.using_chef:
			served_by_chef=true
			require(not early.busy or early.production_phase in ["baking","cooling","collecting"],"Chef serves only outside active manual cooking")
		require(early.room.service.customers.size()<=1,"First level never crowds")
		require(not early.room.service.cashier.visible,"Cashier not visible before unlock")
		await process_frame
	print("Early: sold=",early.baked," phase=",early.production_phase," cashier=",early.room.service.cashier_phase," taking=",early.taking_order)
	require(early.baked>=2 and served_by_chef,"One chef autonomously produces, accepts and hands over without cashier")
	early.room.service.clear_customers()
	early.room.service.arrival_remaining=10000
	while early.busy: await process_frame
	early.auto_restock=false
	early.experience=180
	early._configure_staff()
	require(early.room.service.capacity==2 and not early.room.service.cashier_enabled,"Level three adds visitor, not employee")
	var slots: Array=early.room.service._queue_cells()
	require(slots.size()==2 and absi(slots[0].x-slots[1].x)+absi(slots[0].y-slots[1].y)>=2,"Waiting positions leave walking space between guests")
	early.experience=380
	early._configure_staff()
	require(early.room.service.capacity==2 and not early.room.service.cashier_enabled,"Level four permits hiring without automatically adding cashier")
	early._hire_staff("cashier")
	require(early.room.service.cashier_enabled,"Explicit hire activates unlocked cashier")
	early.purchased.append("assistant_station")
	early.room.apply_purchases(early.purchased)
	early.experience=1100
	early._configure_staff()
	require(early.room.service.capacity==3 and not early.room.assistant.visible,"Third visitor precedes assistant")
	early.experience=1700
	early._configure_staff()
	require(not early.room.assistant.visible,"Assistant is not automatic at seventh level")
	early._hire_staff("assistant")
	require(early.room.assistant.visible,"Assistant appears after explicit hiring")
	early.purchased.append("staff_tasks")
	early.experience=2500
	early._configure_staff()
	require(early.room.service.capacity==3 and early.job_queue.limit==8,"Organisation never raises crowd beyond three")
	await check_middle_level()
	print("PASS: eight-stage map, gentle visitor caps, delayed cashier and assistant, solo-chef service, one-time migration and no crowd upgrade")
	quit()

func check_middle_level() -> void:
	var game=new_game()
	game.experience=180
	game._configure_staff()
	game._refresh()
	game.auto_restock=true
	game.room.service.arrival_remaining=0
	var deadline:=Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<deadline:
		require(game.room.service.customers.size()<=2,"Middle tier keeps two-person physical limit")
		require(not game.room.service.cashier.visible,"Middle tier remains solo")
		await process_frame
	require(game.baked>=4,"Solo chef sustains two spaced buyers without a cashier")
