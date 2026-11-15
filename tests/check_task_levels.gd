extends SceneTree
var failed:=false
func _initialize() -> void: call_deferred("check")
func require(ok: bool, message: String) -> void:
	if not ok: failed=true; push_error(message)
func check() -> void:
	var game=load("res://tests/shop_fixture.gd").new()
	root.add_child(game)
	game.equipment_shop.hide()
	game.purchased.assign(["register","display","mixer","oven"])
	game.coins=10000
	game.room.apply_purchases(game.purchased)
	game._refresh()
	for i in range(game.tasks.GOALS.size()):
		require(game.tasks.active,"Every task is reachable using only earlier task XP")
		var xp: int=game.experience
		var goal: Dictionary=game.tasks.GOALS[i]
		for id in goal.get("equipment",[]):
			require(not game.tasks.complete(),"New equipment is required before claiming")
			game._open_tasks()
			var action: Button
			for button in game.tasks_panel.find_children("*","Button",true,false):
				if button.text=="Выполнить · купить оборудование": action=button
			require(action!=null and not action.disabled,"Equipment task has an enabled primary action")
			if action!=null: action.pressed.emit()
			require(game.staff_panel.visible if id.begins_with("staff_") else game.equipment_shop.visible,"Task purchase button opens the appropriate shop")
			var shop: Control=game.staff_panel if id.begins_with("staff_") else game.equipment_shop
			require(shop.focused_id==id and shop.focused_item!=null,"Shop highlights the exact task item")
			game._queue_changed()
			require(shop.focused_id==id,"Shop refresh preserves the highlighted task item")
			await process_frame
			await process_frame
			var target: Control=shop.focused_item
			require(target.get_global_rect().intersects(shop.scroll.get_global_rect()),"Target is scrolled into view")
			var buy: Button=shop.find_child(("Upgrade_" if id.begins_with("staff_") else "Buy_")+id,true,false)
			require(buy!=null and buy.get_global_rect().intersects(shop.scroll.get_global_rect()),"Target purchase button is visible too")
			game._purchase_equipment(id)
			game.equipment_shop.hide()
			game.staff_panel.hide()
			require(id in game.purchased and game.tasks.counts[id]==1,"Purchase updates task progress")
			require(game.experience==xp,"Buying equipment does not directly grant XP")
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
	var model=load("res://sales_tasks.gd").new()
	model.index=1
	var owned: Array[String]=["register","display","mixer","oven","forming"]
	model.sync(60,owned)
	require(model.active and model.counts.forming==1,"Previously purchased equipment counts automatically")
	model.counts.croissant=12
	require(model.complete(),"Equipment ownership and sales together complete the task")
	var equipment_save:=ConfigFile.new()
	model.write_save(equipment_save)
	var restored=load("res://sales_tasks.gd").new()
	restored.restore(equipment_save)
	require(restored.complete(),"Equipment objective survives save and restore")
	owned.erase("forming")
	model.sync(60,owned)
	require(not model.complete() and model.claim().is_empty(),"Sales alone cannot claim an equipment task")
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
