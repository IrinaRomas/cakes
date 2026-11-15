extends SceneTree
var failed:=false
func _initialize() -> void: call_deferred("check")
func require(ok: bool, message: String) -> void:
	if not ok: failed=true; push_error(message)
func check() -> void:
	Engine.time_scale=12
	var game=load("res://tests/onboarding_fixture.gd").new()
	root.add_child(game)
	var guide=game.onboarding
	require(guide.intro_remaining>0 and not guide.target.visible and not guide.hint.visible,"Cafe is shown before tutorial focus")
	require(guide.step==0 and game.purchased.size()==4 and game.coins==500,"Starter equipment installed without spending capital")
	await process_frame
	await process_frame
	var icon_position: Vector2=game.tasks_button.position
	await create_timer(10).timeout
	require(game.scale==Vector2.ONE and game.tasks_button.position==icon_position and guide.target.icon==null and absf((guide.portrait.position.x+guide.hint.get_rect().end.x)*0.5-guide.size.x*0.5)<2 and guide.portrait.visible,"No zoom or relocated icon; centered speech bubble and chef portrait")
	require(not game.busy and game.room.service.customers.size()==1,"No autonomous production or extra arrivals before instructions")
	guide.target.pressed.emit()
	require(game.tasks_panel.visible and game.tasks_panel.current_only and guide.step==0,"Task icon opens actual task before buyer focus")
	for button in game.tasks_panel.find_children("*","Button",true,false):
		if button.text=="Выполнить": button.pressed.emit()
	require(guide.step==1 and not game.tasks_panel.visible,"Perform task focuses buyer")
	guide.target.pressed.emit()
	require(guide.dialog.visible and guide.action.text=="Принять","Buyer opens order with accept")
	guide.action.pressed.emit()
	require(guide.step==2 and not game.busy,"Accept focuses equipment without cooking yet")
	var save: ConfigFile=game._progress_data()
	require(save.get_value("onboarding","step")==2,"Tutorial checkpoint saved")
	guide.target.pressed.emit()
	var cooking_save: ConfigFile=game._progress_data()
	var deadline:=Time.get_ticks_msec()+10000
	while guide.step!=4 and Time.get_ticks_msec()<deadline: await process_frame
	require(guide.step==4 and game.inventory.count_of("croissant")==6,"Equipment tap produces batch and waits for manual handover")
	require(game.coins==500 and game.baked==0,"No automatic handover during tutorial")
	guide.target.pressed.emit()
	require(guide.dialog.visible and guide.action.text=="Отдать","Display opens handover")
	guide.action.pressed.emit()
	require(not guide.active() and game.coins==515 and game.inventory.count_of("croissant")==5,"Manual handover sells once and completes tutorial")
	guide.action.pressed.emit()
	require(game.coins==515,"No duplicate handover")
	var resumed=load("res://tests/service_fixture.gd").new()
	root.add_child(resumed)
	resumed._restore_progress(cooking_save)
	resumed.onboarding.begin(resumed.onboarding_saved_step)
	deadline=Time.get_ticks_msec()+10000
	while resumed.onboarding.step!=4 and Time.get_ticks_msec()<deadline: await process_frame
	require(resumed.onboarding.step==4 and resumed.inventory.count_of("croissant")==6,"Resume mid-production without losing tutorial or batch")
	game._start_new_game()
	require(guide.step==0 and game.room.service.customers.size()==1,"New game restarts guide cleanly")
	print("PASS: starter layout, gated arrivals/production, hint, buyer order, accept, manual equipment start, batch, manual handover, save checkpoint and reset")
	quit(1 if failed else 0)
