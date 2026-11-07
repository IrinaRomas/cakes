extends SceneTree
var game: Control
var delivered_to: Array[int]=[]
func _initialize() -> void: call_deferred("check")
func require(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
func check() -> void:
	Engine.time_scale=12
	game=load("res://tests/shop_fixture.gd").new()
	root.add_child(game)
	game._purchase_equipment("display_extra")
	require(game.coins==500 and not game.room.is_owned(7),"Second cabinet requires first")
	for id in ["display","mixer","oven"]: game._purchase_equipment(id)
	game.coins=200
	game._open_shop()
	var purchase_button: Button=game.equipment_shop.list.get_child(2)
	require(purchase_button.disabled and purchase_button.text.contains("уровне 2"),"First level shows second-display lock even with enough money")
	game._purchase_equipment("display")
	game._purchase_equipment("display_extra")
	require(game.coins==200 and game.Equipment.display_count(game.purchased)==1,"Both purchase routes enforce level gate without charging")
	game.experience=25
	game._open_shop()
	require(not game.equipment_shop.list.get_child(2).disabled,"Second level unlocks second-display purchase")
	game.room.pause_customers()
	game.room.customer_delay=1000
	game.experience=75
	game.purchased.append("decorator")
	game.room.apply_purchases(game.purchased)
	game.inventory.stock.croissant=17
	game._refresh()
	game._start_batch("cupcake")
	require(not game.busy,"Batch initially blocked by storage")
	game.coins=151
	game._open_shop()
	require(game.equipment_shop.list.get_child(0).text.contains("в зале: 1"),"Existing display card shows quantity")
	game.equipment_shop.list.get_child(2).pressed.emit()
	require(game.coins==1 and game.inventory.capacity==36 and game.room.objects[7].visible,"Purchase adds cabinet and eighteen places")
	game._purchase_equipment("display")
	require(game.equipment_shop.list.get_child(0).text.contains("в зале: 2") and game.equipment_shop.list.get_child(2).disabled,"Quantity updates and two-display limit disables purchase")
	for entry in game.Equipment.ITEMS: require(entry.id!="display_extra","No separate equipment card for second instance")
	require(game.coins==1,"Duplicate does not charge")
	game.stage_started.connect(func(_id: String, phase: String, station: int):
		if phase=="displaying": delivered_to.append(station)
	)
	var deadline:=Time.get_ticks_msec()+10000
	while game.inventory.count_of("cupcake")<6 and Time.get_ticks_msec()<deadline: await process_frame
	require(game.inventory.total()==23 and delivered_to==[7],"Waiting batch resumes and chef delivers to second cabinet")
	require(game.room.stock_visual.contents.size()==18 and game.room.extra_stock_visual.contents.size()==5,"Exact stock distributed across both cabinets")
	game.room.set_editing(true)
	game.room._select(7)
	require(game.room.selected==7,"Second cabinet can be selected for placement")
	game.room.cells[7]=Vector2i(0,4)
	game.room.set_editing(false)
	var saved:=ConfigFile.new()
	saved.parse(game._progress_data().encode_to_text())
	var copy=load("res://tests/shop_fixture.gd").new()
	root.add_child(copy)
	copy.room.editing=true
	copy._restore_progress(saved)
	copy._refresh()
	require(copy.inventory.total()==23 and copy.inventory.capacity==36,"Reload retains inventory above old capacity")
	require(copy.room.is_owned(7) and copy.room.cells[7]==Vector2i(0,4),"Reload retains second cabinet and placement")
	copy._start_new_game()
	require(copy.inventory.capacity==18 and not copy.room.is_owned(7),"New game resets extra capacity")
	print("PASS: second display purchase, prerequisites, duplicate prevention, queue resumption, physical delivery, split visual stock, placement, save/load above eighteen and reset")
	quit()
