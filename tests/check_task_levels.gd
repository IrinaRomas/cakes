extends SceneTree
var failed:=false
func _initialize() -> void: call_deferred("check")
func require(ok: bool, message: String) -> void:
	if not ok: failed=true; push_error(message)
func check() -> void:
	var game=load("res://tests/shop_fixture.gd").new()
	root.add_child(game)
	game.equipment_shop.hide()
	game.purchased.assign(["register","display","mixer","oven","forming","decorator","fridge"])
	game._refresh()
	for i in range(game.tasks.GOALS.size()):
		require(game.tasks.active,"Every task is reachable using only earlier task XP")
		var xp: int=game.experience
		var goal: Dictionary=game.tasks.GOALS[i]
		for id in goal.needs:
			game.inventory.stock[id]=int(goal.needs[id])
			for n in range(int(goal.needs[id])): game._sell_recipe(id)
		require(game.experience==xp,"Sales never grant experience")
		var old_level: int=game.Catalog.level_for_xp(xp)
		var coins: int=game.coins
		game._claim_task_reward()
		var level: int=game.Catalog.level_for_xp(game.experience)
		require(game.experience==xp+int(goal.xp),"Only claimed completed tasks grant XP")
		if level>old_level:
			require(game.level_up_panel.visible and game.room.interaction_blocked,"Level celebration blocks room")
			require(game.coins==coins+int(goal.coins)+game.Progression.level_reward(level),"Level bonus is paid once")
			game._claim_task_reward()
			require(game.coins==coins+int(goal.coins)+game.Progression.level_reward(level),"Repeated claim pays nothing")
			game.level_up_panel.hide()
		require(not game.level_up_panel.visible,"Celebration can close")
	require(game.Catalog.level_for_xp(game.experience)==8,"Tasks reach final level")
	var saved: ConfigFile=game._progress_data()
	saved.set_value("tasks","index",2)
	saved.set_value("progress","experience",15)
	game._restore_progress(saved)
	require(game.experience==115,"Old claimed tasks receive rebalanced XP to avoid a locked recipe")
	game.level_up_panel.show_level(2,80)
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	game.level_up_panel._gui_input(event)
	require(not game.level_up_panel.visible and not game.room.interaction_blocked,"Continue closes popup and restores room input")
	print("PASS: task-only XP, reachable progression, level popup, bonus paid once")
	quit(1 if failed else 0)
