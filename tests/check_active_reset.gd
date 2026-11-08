extends SceneTree
var failed:=false
func _initialize() -> void: call_deferred("check")
func require(ok: bool, message: String) -> void:
	if not ok:
		failed=true
		push_error(message)
func check() -> void:
	Engine.time_scale=12
	for phase in ["preparing","baking"]:
		var game=load("res://tests/service_fixture.gd").new()
		root.add_child(game)
		game.room.service.arrival_remaining=10000
		game._start_batch("croissant")
		var deadline:=Time.get_ticks_msec()+10000
		while (game.production_phase!=phase or not game.stage_has_started) and Time.get_ticks_msec()<deadline: await process_frame
		require(game.busy and game.production_phase==phase,"Active "+phase)
		game.room.service.spawn_customer("cookie")
		game._open_shop()
		# Exercise the actual shop button signal, rather than invoking reset directly.
		var buttons=game.equipment_shop.find_children("*","Button",true,false)
		for button in buttons:
			if button.text=="Новая игра": button.pressed.emit()
		require(game.new_game_dialog.visible,"Confirmation opens during "+phase)
		game.new_game_dialog.hide()
		game.new_game_dialog.confirmed.emit()
		require(game.coins==500 and game.experience==0 and game.purchased==["register"],"Starter state restored")
		await create_timer(50).timeout
		require(not game.busy and not game.taking_order and game.inventory.total()==0 and game.inventory.reserved_count==0,"Old batch cannot complete after reset")
		require(game.job_queue.waiting.is_empty() and game.room.service.customers.is_empty(),"Old work and customers cleared")
		require(game.coins==500 and game.experience==0,"No late rewards")
		game._purchase_equipment("display")
		require("display" in game.purchased,"New game accepts purchases")
		game.queue_free()
		await process_frame
	print("PASS: new game button during preparation/baking, confirmation, cancellation of old work, no late stock/rewards and fresh purchases")
	quit(1 if failed else 0)
