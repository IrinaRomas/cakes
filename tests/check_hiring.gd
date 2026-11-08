extends SceneTree
func _initialize() -> void: call_deferred("check")
func require(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
func check() -> void:
	Engine.time_scale=12
	var game=load("res://tests/hiring_fixture.gd").new()
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(game)
	game.room.service.arrival_remaining=10000
	require(game.hired_staff==["chef"] and not game.room.service.cashier_enabled,"No automatic second employee at level four")
	game.experience=0
	game._configure_staff()
	game._hire_staff("cashier")
	require(game.hired_staff.size()==1,"Level gate enforced in controller")
	game.experience=380
	game._configure_staff()
	game._open_staff()
	require(game.staff_panel.visible and game.room.interaction_blocked,"Dedicated panel opens and blocks world input")
	var button: Button=game.staff_panel.list.get_node("Hire_cashier")
	require(not button.disabled,"Unlocked cashier can be hired")
	button.pressed.emit()
	require(game.hired_staff==["chef","cashier"] and game.room.service.cashier_enabled and game.coins==500,"Panel explicitly hires cashier without a charge")
	game._hire_staff("cashier")
	require(game.hired_staff.size()==2 and game.coins==500,"Hiring cannot duplicate employees")
	game.experience=1700
	game._configure_staff()
	game._hire_staff("assistant")
	require("assistant" not in game.hired_staff,"Assistant requires workplace")
	game._purchase_equipment("assistant_station")
	require(game.coins==180 and not game.room.assistant.visible,"Buying a workstation does not hire its employee")
	game._open_staff()
	game.staff_panel.list.get_node("Hire_assistant").pressed.emit()
	require(game.hired_staff.size()==3 and game.room.assistant.visible and game.coins==180,"Assistant hired separately after table purchase")
	game.staff_panel.list.get_node("Upgrade_staff_walk").pressed.emit()
	require(game.coins==20 and "staff_walk" in game.purchased and game.staff_panel.visible and not game.equipment_shop.visible,"Staff improvement purchased within personnel panel")
	var saved:=ConfigFile.new()
	saved.parse(game._progress_data().encode_to_text())
	var copy=load("res://tests/hiring_fixture.gd").new()
	root.add_child(copy)
	copy.room.editing=true
	copy._restore_progress(saved)
	require(copy.hired_staff.size()==3 and copy.room.service.cashier_enabled and copy.room.helper_enabled,"Explicit hires persist")
	saved.erase_section("staff")
	copy._restore_progress(saved)
	require(copy.hired_staff==["chef"] and not copy.room.service.cashier_enabled and not copy.room.helper_enabled,"Older automatic-employee saves require manual hiring")
	game._start_new_game()
	require(game.hired_staff==["chef"] and not game.room.service.cashier_enabled,"New game starts with one employee")
	await hire_during_service()
	print("PASS: personnel panel, hire gates, no automatic cashier, separate assistant/table, no duplicates, staff upgrade UI, hire persistence and old-save migration")
	quit()

func hire_during_service() -> void:
	var game=load("res://tests/hiring_fixture.gd").new()
	root.add_child(game)
	game.room.service.arrival_remaining=10000
	game.inventory.stock.croissant=6
	game._refresh()
	game.room.service.spawn_customer("croissant")
	var deadline:=Time.get_ticks_msec()+10000
	while not game.room.service.using_chef and Time.get_ticks_msec()<deadline: await process_frame
	require(game.room.service.using_chef,"Chef is receiving an order before hiring")
	game._hire_staff("cashier")
	require("cashier" in game.hired_staff and not game.room.service.cashier_enabled,"Cashier waits for safe handoff instead of interrupting current order")
	deadline=Time.get_ticks_msec()+10000
	while game.room.service.served<1 and Time.get_ticks_msec()<deadline: await process_frame
	require(game.room.service.cashier_enabled and not game.taking_order,"New cashier takes over after current chef service")
	require(game.coins==515 and game.inventory.count_of("croissant")==5 and game.room.service.served==1,"Handoff never duplicates stock or payment")
