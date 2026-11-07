extends SceneTree
const Queue=preload("res://production_queue.gd")
var game: Control
var completed: Array[String]=[]
var phases: Array[Dictionary]=[]
func _initialize() -> void: call_deferred("check")
func require(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
func wait_count(count: int) -> void:
	var deadline:=Time.get_ticks_msec()+15000
	while completed.size()<count and Time.get_ticks_msec()<deadline: await process_frame
	require(completed.size()>=count,"Production did not complete requested batches")
func station_trace(id: String) -> Array[int]:
	var result: Array[int]=[]
	for phase in phases:
		if phase.recipe==id: result.append(phase.station)
	return result
func check() -> void:
	Engine.time_scale=12
	var model=Queue.new()
	for i in range(5): require(model.enqueue("croissant")>0,"Queue admits five waiting batches")
	require(model.enqueue("cookie")==-1,"Queue limit enforced")
	game=load("res://tests/game_fixture.gd").new()
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(game)
	game.experience=150
	game.purchased.append("fridge")
	game.room.apply_purchases(game.purchased)
	game.room.customer_delay=1000
	game._refresh()
	game.batch_completed.connect(func(id: String): completed.append(id))
	game.stage_started.connect(func(id: String,key: String,station: int):
		phases.append({"recipe":id,"key":key,"station":station})
		require(game.room.work_markers[station].visible,"Machine displays active stage")
	)
	game._start_batch("croissant")
	require(game.busy and game.inventory.reserved_count==6,"First batch starts and reserves capacity")
	game._start_batch("cookie")
	game._start_batch("cupcake")
	game._start_batch("mousse")
	require(game.job_queue.waiting.size()==3,"Player can plan while chef works")
	var cake_id: int=game.job_queue.waiting[1].id
	game._move_job(cake_id,-1)
	require(game.job_queue.waiting[0].recipe=="cupcake","Priority changes next batch")
	var mousse_id: int=game.job_queue.waiting[2].id
	game._cancel_job(mousse_id)
	require(game.job_queue.waiting.size()==2 and game.inventory.reserved_count==6,"Cancel does not affect active reservation")
	require(not game.job_queue.cancel(game.job_queue.active.id),"Active batch cannot be cancelled")
	var saved:=ConfigFile.new()
	saved.parse(game._progress_data().encode_to_text())
	var clone=load("res://tests/game_fixture.gd").new()
	root.add_child(clone)
	clone.room.editing=true
	clone._restore_progress(saved)
	require(clone.job_queue.waiting.size()==3,"Reload retains active plus waiting batches once")
	require(clone.job_queue.waiting[0].recipe=="croissant" and clone.job_queue.waiting[1].recipe=="cupcake","Reload preserves priority")
	require(clone.inventory.total()==0 and clone.inventory.reserved_count==0,"Interrupted batch is not duplicated in stock")
	clone.queue_free()
	await wait_count(2)
	for i in range(3): await process_frame
	require(completed==["croissant","cupcake"],"Queue executes changed priority")
	require(not game.busy and game.job_queue.waiting[0].recipe=="cookie" and not game.queue_reason.is_empty(),"Full display pauses head batch")
	require(game.inventory.total()==12 and game.room.stock_visual.contents.size()==12,"Display renders actual inventory only")
	game._start_batch("croissant")
	game._move_job(game.job_queue.waiting[1].id,-1)
	await wait_count(3)
	require(game.inventory.total()==18 and completed[2]=="croissant","Reordering starts smaller batch that fits")
	for i in range(8): game._discard_stock("croissant")
	await wait_count(4)
	require(completed[3]=="cookie" and game.inventory.total()==18,"Queue resumes when stock frees space")
	require(station_trace("cookie")==[2,4,0,1],"Cookie passes preparation, forming, oven and display")
	require(station_trace("cupcake")==[2,0,5,1],"Cupcake passes decorating stage")
	for i in range(6): game._discard_stock("cookie")
	game._start_batch("mousse")
	await wait_count(5)
	require(station_trace("mousse")==[2,6,5,1],"Cold dessert uses fridge and never oven")
	require(game.inventory.count_of("mousse")==6 and game.room.stock_visual.contents.count("mousse")==6,"Visual mousse quantity matches stock")
	require(game.inventory.total()==18 and game.coins==0,"Capacity and sale-only rewards retained")
	game._open_queue()
	require(game.queue_panel.visible and game.room.interaction_blocked,"Queue panel opens and blocks camera input")
	game._start_batch("cookie")
	game._start_batch("mousse")
	game._open_queue()
	var first_id: int=game.job_queue.waiting[0].id
	var row: HBoxContainer=game.queue_panel.list.get_child(2)
	row.get_child(2).pressed.emit()
	require(game.job_queue.waiting[0].recipe=="mousse","Priority button operates on its own row")
	game._cancel_job(first_id)
	game._cancel_job(game.job_queue.waiting[0].id)
	require(game.queue_reason.is_empty(),"Empty queue clears stale blocked reason")
	print("PASS: queue limits, priorities, cancel, reservations, save/load, full-display waiting, smaller-priority batch, automatic resume, all production routes, cooling and exact visual stock")
	quit()
