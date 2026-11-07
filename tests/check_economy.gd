extends SceneTree
var game: Control
var stations: Array[int]=[]
func _initialize() -> void: call_deferred("check")
func require(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
func new_game() -> Control:
	var result=load("res://tests/economy_fixture.gd").new()
	root.add_child(result)
	result.room.customer_delay=10000
	return result
func wait_idle(target: Control) -> void:
	var deadline:=Time.get_ticks_msec()+15000
	while (target.busy or not target.job_queue.waiting.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	require(not target.busy and target.job_queue.waiting.is_empty(),"Production completes")
func check() -> void:
	Engine.time_scale=12
	game=new_game()
	game.coins=0
	game._start_batch("croissant")
	require(game.busy and game.coins==0,"Production starts with zero coins")
	game._start_batch("cookie")
	await wait_idle(game)
	require(game.inventory.total()==14 and game.coins==0,"Multiple batches complete without any production cost")
	var upgraded=new_game()
	for id in ["display_shelves","oven_upgrade","assistant_station","display"]: upgraded._purchase_equipment(id)
	require(upgraded.coins==4130 and upgraded.inventory.capacity==48,"Upgrades still charge and expand storage")
	var improved: Dictionary=upgraded._effective_recipe("croissant")
	require(improved.batch==8 and is_equal_approx(improved.bake,3.5) and improved.revenue==120,"Oven size, speed and revenue remain")
	upgraded.coins=0
	upgraded.stage_started.connect(func(id: String,_key: String,station: int):
		if id=="cookie": stations.append(station)
	)
	upgraded._start_batch("croissant")
	upgraded._start_batch("cookie")
	var deadline:=Time.get_ticks_msec()+10000
	while not upgraded.job_queue.waiting[0].get("prepared",false) and Time.get_ticks_msec()<deadline: await process_frame
	require(upgraded.busy and upgraded.job_queue.waiting[0].get("prepared",false) and upgraded.coins==0,"Assistant prepares in parallel without money")
	var data:=ConfigFile.new()
	data.parse(upgraded._progress_data().encode_to_text())
	# Load a save from the removed system without changing its current wallet or tray.
	data.set_value("economy","ingredients",321)
	data.set_value("economy","pressure",{"croissant":4})
	var restored=new_game()
	restored.room.editing=true
	restored._restore_progress(data)
	require(restored.job_queue.waiting[1].prepared and restored.coins==0,"Legacy costs do not affect saved wallet or prepared tray")
	require(not restored._effective_recipe("croissant").has("cost"),"No recipe costs or repeat markups")
	restored.room.editing=false
	restored.room.customer_delay=10000
	await wait_idle(restored)
	require(restored.inventory.total()==18 and restored.coins==0,"Saved batches finish for free")
	await wait_idle(upgraded)
	require(upgraded.coins==0 and upgraded.inventory.total()==18 and stations==[4,0,1],"Main chef still uses prepared tray")
	upgraded._start_batch("croissant")
	upgraded._start_batch("mousse")
	deadline=Time.get_ticks_msec()+10000
	while upgraded.preparing_job_id<0 and Time.get_ticks_msec()<deadline: await process_frame
	require(upgraded.preparing_job_id>=0,"Additional preparation begins")
	upgraded._cancel_job(upgraded.preparing_job_id)
	await wait_idle(upgraded)
	require(upgraded.coins==0 and upgraded.inventory.count_of("mousse")==0 and not upgraded.room.work_markers[8].visible,"Cancellation is free and does not create a delayed batch")
	upgraded.inventory.stock={"croissant":24,"cookie":10,"cupcake":6,"mousse":0}
	upgraded._refresh()
	require(upgraded.room.stock_visual.contents.size()==24 and upgraded.room.extra_stock_visual.contents.size()==16,"Expanded display stock remains accurate")
	var starter=load("res://tests/shop_fixture.gd").new()
	root.add_child(starter)
	for id in ["display","mixer","oven"]: starter._purchase_equipment(id)
	starter.coins=180
	starter.experience=25
	starter._purchase_equipment("display_shelves")
	require("display_shelves" in starter.purchased and starter.coins==0,"No obsolete ingredient budget blocks purchases")
	upgraded._open_recipe_book()
	upgraded._open_queue()
	for panel in [upgraded.recipe_book,upgraded.queue_panel]:
		for label in panel.find_children("*","Label",true,false):
			require(not label.text.to_lower().contains("ингредиент") and not label.text.contains("оплачено"),"Removed mechanic is absent from UI")
	print("PASS: free production at zero balance, no repeat markups, upgrades, parallel assistant, cancellation, old-save compatibility, prepared trays, stock accuracy and clean UI")
	quit()
