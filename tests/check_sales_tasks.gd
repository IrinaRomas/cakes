extends SceneTree
var failed:=false
func _initialize() -> void: call_deferred("check")
func require(ok: bool, message: String) -> void:
	if not ok: failed=true; push_error(message)
func check() -> void:
	var game=load("res://tests/shop_fixture.gd").new()
	root.add_child(game)
	game.equipment_shop.hide()
	game.tasks_button.pressed.emit()
	require(game.tasks_panel.visible and game.room.interaction_blocked,"Icon opens modal and blocks room clicks")
	require(not game.tasks.active,"Unavailable recipe does not activate")
	for id in ["display","mixer","oven"]: game._purchase_equipment(id)
	require(game.tasks.active,"Buying required equipment activates goal")
	game.inventory.stock.croissant=6
	game._refresh()
	require(not game.tasks.complete(),"Production/stock does not count as sales")
	for i in range(6): require(game._sell_recipe("croissant"),"Visitor sale")
	require(game.tasks.complete() and game.tasks_button.text=="!","Six issued products complete goal and badge")
	require(not game._sell_recipe("croissant") and game.tasks.counts.croissant==6,"Failed sale cannot count")
	var saved: ConfigFile=game._progress_data()
	var restored=load("res://sales_tasks.gd").new()
	restored.restore(saved)
	require(restored.complete(),"Completed unclaimed goal survives save")
	var coins: int=game.coins
	var xp: int=game.experience
	game._claim_task_reward()
	require(game.Catalog.level_for_xp(game.experience)==2 and game.level_up_panel.visible,"First task immediately unlocks level two and its celebration")
	require(game.coins==coins+110 and game.experience==xp+60 and game.tasks.index==1,"Claim pays reward and advances")
	game._claim_task_reward()
	require(game.coins==coins+110 and game.tasks.counts.is_empty(),"No duplicate rewards or retroactive sales")
	require(game.tasks.active,"Next available goal starts immediately")
	game._start_new_game()
	require(game.tasks.index==0 and game.tasks.counts.is_empty() and not game.tasks.active,"New game resets tasks")
	var legacy=load("res://sales_tasks.gd").new()
	legacy.restore(ConfigFile.new())
	require(legacy.index==0 and legacy.counts.is_empty(),"Old saves start at first goal")
	print("PASS: tasks icon/modal, equipment gates, actual sales, reward badge, persistence, single claim, no retroactive progress, new game and legacy saves")
	quit(1 if failed else 0)
