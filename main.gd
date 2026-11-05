extends Control

const Catalog = preload("res://recipes.gd")
var coins := 0
var baked := 0
var experience := 0
var remaining := 0.0
var busy := false
var stage_text := ""
var inventory = preload("res://display_inventory.gd").new()
var pending_resume := ""
var stock_label: Label
var recipe_selector: OptionButton
var batch_button: Button
var selectable_ids: Array[String] = []
var coin_label: Label
var status_label: Label
var action: Button
var progress: ProgressBar
var room: Control
var layout_button: Button
var level_label: Label
var xp_progress: ProgressBar
var recipe_button: Button
var recipe_book: PopupPanel
var unlock_notice: Label
var notice_remaining := 0.0
var active_recipe: Dictionary = {}
var last_reward := ""

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("f5f1e9"))
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	add_child(root)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	root.add_child(margin)
	var header := HBoxContainer.new()
	margin.add_child(header)
	var title := Label.new()
	title.text = "CAKES · Кондитерская"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("344b3f"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	coin_label = Label.new()
	coin_label.add_theme_color_override("font_color", Color("344b3f"))
	header.add_child(coin_label)
	var level_margin := MarginContainer.new()
	level_margin.add_theme_constant_override("margin_left", 24)
	level_margin.add_theme_constant_override("margin_right", 24)
	root.add_child(level_margin)
	var level_box := VBoxContainer.new()
	level_margin.add_child(level_box)
	level_label = Label.new()
	level_label.add_theme_color_override("font_color", Color("344b3f"))
	level_label.add_theme_font_size_override("font_size", 18)
	level_box.add_child(level_label)
	xp_progress = ProgressBar.new()
	xp_progress.show_percentage = false
	xp_progress.custom_minimum_size.y = 12
	level_box.add_child(xp_progress)
	unlock_notice = Label.new()
	unlock_notice.visible = false
	unlock_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unlock_notice.add_theme_color_override("font_color", Color("976b35"))
	level_box.add_child(unlock_notice)
	var menu := HBoxContainer.new()
	root.add_child(menu)
	recipe_button = Button.new()
	recipe_button.custom_minimum_size.y = 48
	recipe_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_button.pressed.connect(_open_recipe_book)
	menu.add_child(recipe_button)
	recipe_book = preload("res://recipe_book.gd").new()
	add_child(recipe_book)
	recipe_book.production_requested.connect(_start_batch)
	recipe_book.discard_requested.connect(_discard_stock)
	layout_button = Button.new()
	layout_button.text = "Расстановка мебели"
	layout_button.custom_minimum_size.y = 48
	layout_button.pressed.connect(_toggle_layout)
	layout_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.add_child(layout_button)
	room = preload("res://room.gd").new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room.custom_minimum_size.y = 320
	root.add_child(room)
	room.oven_pressed.connect(_bake_selected)
	room.display_pressed.connect(_open_recipe_book)
	room.register_pressed.connect(_accept_order)
	room.layout_changed.connect(_save_progress)
	room.customer_changed.connect(_customer_updated)
	room.hint_changed.connect(func(message: String): status_label.text = message)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e6eadd")
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	panel.add_child(controls)
	stock_label = Label.new()
	stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stock_label.add_theme_color_override("font_color", Color("344b3f"))
	controls.add_child(stock_label)
	var production_row := HBoxContainer.new()
	controls.add_child(production_row)
	recipe_selector = OptionButton.new()
	recipe_selector.custom_minimum_size.y = 48
	recipe_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_selector.item_selected.connect(func(_index: int): _refresh_batch_button())
	production_row.add_child(recipe_selector)
	batch_button = Button.new()
	batch_button.custom_minimum_size.y = 48
	batch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	batch_button.pressed.connect(_bake_selected)
	production_row.add_child(batch_button)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color("344b3f"))
	controls.add_child(status_label)
	progress = ProgressBar.new()
	progress.max_value = 5.0
	progress.show_percentage = false
	progress.custom_minimum_size.y = 12
	controls.add_child(progress)
	action = Button.new()
	action.custom_minimum_size.y = 58
	action.add_theme_font_size_override("font_size", 21)
	action.pressed.connect(_on_action)
	controls.add_child(action)
	_load_progress()
	_refresh()
	if not pending_resume.is_empty():
		call_deferred("_start_batch", pending_resume)

func _process(delta: float) -> void:
	if notice_remaining > 0.0:
		notice_remaining = maxf(0.0, notice_remaining - delta)
		unlock_notice.visible = notice_remaining > 0.0
	if remaining > 0.0:
		remaining = maxf(0.0, remaining - delta)
		progress.value = float(active_recipe.bake) - remaining
		status_label.text = "%s × %d · выпечка · %d сек." % [active_recipe.title, active_recipe.batch, ceili(remaining)]

func _on_action() -> void:
	_accept_order()

func _selected_id() -> String:
	return selectable_ids[recipe_selector.selected] if recipe_selector.selected >= 0 and recipe_selector.selected < selectable_ids.size() else "croissant"

func _select_recipe(id: String) -> void:
	var index := selectable_ids.find(id)
	if index >= 0:
		recipe_selector.select(index)
	_refresh_batch_button()

func _bake_selected() -> void:
	_start_batch(_selected_id())

func _start_batch(id: String) -> void:
	if busy or room.editing or id not in Catalog.unlocked_ids(experience):
		return
	if not pending_resume.is_empty() and id != pending_resume:
		status_label.text = "Сначала заверши сохранённую партию."
		return
	var recipe: Dictionary = Catalog.get_recipe(id)
	if not inventory.can_fit(recipe.batch):
		status_label.text = "Для партии нужно %d мест. Свободно: %d." % [recipe.batch, inventory.free_space()]
		return
	if not room.can_complete_order():
		status_label.text = "Нет прохода к оборудованию. Измени расстановку."
		return
	if not inventory.reserve(id, recipe.batch):
		return
	pending_resume = ""
	active_recipe = recipe.duplicate()
	progress.max_value = active_recipe.bake
	progress.value = 0
	room.chef.carried_recipe = active_recipe.id
	room.chef.carried_count = active_recipe.batch
	busy = true
	room.busy = true
	layout_button.disabled = true
	_save_progress()
	_refresh()
	await _visit(2, "Партия %d шт. · кондитер идёт к миксеру" % active_recipe.batch)
	stage_text = "%s × %d · готовим тесто…" % [active_recipe.title, active_recipe.batch]
	status_label.text = stage_text
	room.chef.working = true
	await get_tree().create_timer(float(active_recipe.prep)).timeout
	room.chef.working = false
	room.chef.carrying = true
	room.chef.carrying_dough = true
	await _visit(0, "Переносим партию заготовок в печь")
	room.chef.carrying = false
	room.chef.carrying_dough = false
	remaining = active_recipe.bake
	await get_tree().create_timer(float(active_recipe.bake)).timeout
	remaining = 0.0
	room.chef.carrying = true
	await _visit(1, "%s × %d · пополняем витрину" % [active_recipe.title, active_recipe.batch])
	room.chef.carrying = false
	inventory.finish_batch()
	busy = false
	room.busy = false
	layout_button.disabled = false
	_save_progress()
	_serve_customer()
	_refresh()

func _visit(station: int, message: String) -> void:
	stage_text = message
	status_label.text = message
	if room.walk_to_station(station):
		await room.arrived

func _accept_order() -> void:
	if not room.editing:
		if room.accept_customer_order() and inventory.count_of(room.current_recipe_id) == 0:
			_select_recipe(room.current_recipe_id)

func _customer_updated() -> void:
	_serve_customer()
	if not room.editing:
		_refresh()

func _serve_customer() -> void:
	if room.customer_state != "waiting" or room.editing:
		return
	var sold_recipe: Dictionary = Catalog.get_recipe(room.current_recipe_id)
	if not inventory.take_one(sold_recipe.id):
		return
	var previous_level := Catalog.level_for_xp(experience)
	coins += int(sold_recipe.price)
	experience += int(sold_recipe.xp)
	last_reward = "+%d монет · +%d опыта" % [sold_recipe.price, sold_recipe.xp]
	var new_level := Catalog.level_for_xp(experience)
	if new_level > previous_level:
		var opened := PackedStringArray()
		for recipe in Catalog.RECIPES:
			if recipe.level > previous_level and recipe.level <= new_level:
				opened.append(recipe.title)
		unlock_notice.text = "Уровень %d! Открыто: %s" % [new_level, ", ".join(opened)]
		unlock_notice.visible = true
		notice_remaining = 8.0
	room.set_recipe_pool(Catalog.unlocked_ids(experience))
	baked += 1
	_save_progress()
	room.finish_customer()

func _refresh() -> void:
	coin_label.text = "%d монет" % coins
	_update_level_display()
	var recipe: Dictionary = Catalog.get_recipe(room.current_recipe_id)
	_refresh_stock()
	action.disabled = room.editing or room.customer_state != "ordering"
	if room.customer_state == "ordering":
		status_label.text = "У кассы: %s × 1 · в витрине %d" % [recipe.title, inventory.count_of(recipe.id)]
		action.text = "Принять заказ"
	elif room.customer_state == "waiting":
		status_label.text = "%s × 1 · ждёт пополнения витрины" % recipe.title
		action.text = "Нет в наличии — выпеки партию"
	elif room.customer_state == "to_display":
		status_label.text = "Заказ принят · покупатель идёт к витрине"
		action.text = "Продажа из запаса витрины"
	elif room.customer_state == "entering":
		status_label.text = "Покупатель идёт к кассе…"
		action.text = "Ждём заказ"
	elif room.customer_state == "leaving":
		status_label.text = "Продано 1 шт. · %s" % last_reward
		action.text = "Покупатель забрал заказ"
	else:
		status_label.text = "Ждём покупателя · продано изделий: %d" % baked
		action.text = "Можно заранее пополнить витрину"
	if not busy:
		progress.value = 0

func _refresh_stock() -> void:
	var details := PackedStringArray()
	for recipe in Catalog.RECIPES:
		if recipe.level <= Catalog.level_for_xp(experience):
			details.append("%s: %d" % [recipe.title, inventory.count_of(recipe.id)])
	stock_label.text = "Витрина: %d/%d · в работе: %d\n%s" % [inventory.total(), inventory.CAPACITY, inventory.reserved_count, " · ".join(details)]
	room.update_display_stock(inventory.total(), inventory.CAPACITY)
	_refresh_batch_button()
	if recipe_book.visible:
		_open_recipe_book()

func _refresh_batch_button() -> void:
	var recipe: Dictionary = Catalog.get_recipe(_selected_id())
	batch_button.text = "Выпечь %d шт." % recipe.batch
	batch_button.disabled = busy or room.editing or not inventory.can_fit(recipe.batch)
	if busy:
		batch_button.text = "Партия готовится…"
	elif not inventory.can_fit(recipe.batch):
		batch_button.text = "Мало места · нужно %d" % recipe.batch

func _open_recipe_book() -> void:
	recipe_book.show_recipes(experience, inventory, busy, room.editing)

func _discard_stock(id: String) -> void:
	if room.editing or not inventory.take_one(id):
		return
	_save_progress()
	_refresh()

func _update_level_display() -> void:
	var level := Catalog.level_for_xp(experience)
	var unlocked: Array[String] = Catalog.unlocked_ids(experience)
	room.set_recipe_pool(unlocked)
	recipe_button.text = "Рецепты и витрина · %d/%d" % [unlocked.size(), Catalog.RECIPES.size()]
	if selectable_ids != unlocked:
		var selected := _selected_id()
		selectable_ids = unlocked.duplicate()
		recipe_selector.clear()
		for id in selectable_ids:
			var recipe: Dictionary = Catalog.get_recipe(id)
			recipe_selector.add_item("%s · партия %d" % [recipe.title, recipe.batch])
		var index := selectable_ids.find(selected)
		recipe_selector.select(maxi(index, 0))
	if level < Catalog.LEVEL_XP.size():
		var start: int = Catalog.LEVEL_XP[level - 1]
		var target: int = Catalog.LEVEL_XP[level]
		var next_title: String = Catalog.RECIPES[level].title
		level_label.text = "Уровень %d · %d/%d опыта
Ещё %d опыта — %s" % [level, experience - start, target - start, target - experience, next_title]
		xp_progress.max_value = target - start
		xp_progress.value = experience - start
	else:
		level_label.text = "Уровень %d · %d опыта · все 3 рецепта открыты" % [level, experience]
		xp_progress.max_value = 1
		xp_progress.value = 1

func _progress_data() -> ConfigFile:
	var data := ConfigFile.new()
	data.set_value("progress", "coins", coins)
	data.set_value("progress", "baked", baked)
	data.set_value("progress", "experience", experience)
	for i in range(room.cells.size()):
		data.set_value("layout", str(i), room.cells[i])
	inventory.write_save(data)
	if not pending_resume.is_empty():
		data.set_value("production", "recipe", pending_resume)
	return data

func _save_progress() -> void:
	_progress_data().save("user://cakes_progress.cfg")

func _restore_progress(data: ConfigFile) -> void:
	coins = maxi(0, int(data.get_value("progress", "coins", 0)))
	baked = maxi(0, int(data.get_value("progress", "baked", 0)))
	experience = maxi(0, int(data.get_value("progress", "experience", 0)))
	pending_resume = inventory.restore_save(data)
	if pending_resume not in Catalog.unlocked_ids(experience):
		pending_resume = ""
	room.restore_layout(data)
	room.set_recipe_pool(Catalog.unlocked_ids(experience))

func _load_progress() -> void:
	var data := ConfigFile.new()
	if data.load("user://cakes_progress.cfg") == OK:
		_restore_progress(data)

func _toggle_layout() -> void:
	if busy:
		return
	room.set_editing(not room.editing)
	action.disabled = room.editing or room.customer_state != "ordering"
	_refresh_stock()
	layout_button.text = "Готово · вернуться к готовке" if room.editing else "Расстановка мебели"
	if room.editing:
		status_label.text = "Выбери предмет, затем свободную клетку пола."
	else:
		_refresh()
		if not pending_resume.is_empty():
			call_deferred("_start_batch", pending_resume)
