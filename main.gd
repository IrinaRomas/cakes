extends Control

const Catalog = preload("res://recipes.gd")
const Equipment = preload("res://equipment_catalog.gd")
var coins := Equipment.STARTING_COINS
var purchased: Array[String] = ["register"]
var fresh_game := true
var shop_button: Button
var equipment_shop: Control
var new_game_dialog: Control
var baked := 0
var experience := 0
var remaining := 0.0
var busy := false
var taking_order := false
var production_phase := ""
var order_retry := 0.0
signal order_service_finished
var stage_text := ""
var inventory = preload("res://display_inventory.gd").new()
var pending_resume := ""
var stock_label: Label
var recipe_selector: OptionButton
var batch_button: Button
var selectable_ids: Array[String] = []
var coin_label: Label
var status_label: Label
var progress: ProgressBar
var room: Control
var layout_button: Button
var level_label: Label
var xp_progress: ProgressBar
var recipe_button: Button
var recipe_book: Control
var unlock_notice: Label
var notice_remaining := 0.0
var active_recipe: Dictionary = {}
var last_reward := ""
var top_panel: PanelContainer
var bottom_panel: PanelContainer
var controls_box: VBoxContainer
var production_row: HBoxContainer
var center_camera: Button
var layout_queued := false
var wide_layout := false

func _ready() -> void:
	get_window().gui_embed_subwindows = true
	RenderingServer.set_default_clear_color(Color("f5f1e9"))
	room = preload("res://room.gd").new()
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(room)
	room.oven_pressed.connect(_bake_selected)
	room.display_pressed.connect(_open_recipe_book)
	room.layout_changed.connect(_save_progress)
	room.customer_changed.connect(_customer_updated)
	room.hint_changed.connect(func(message: String): status_label.text = message)
	top_panel = PanelContainer.new()
	top_panel.z_index = 200
	top_panel.add_theme_stylebox_override("panel", _hud_style("f5f1e9"))
	add_child(top_panel)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	top_panel.add_child(header)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	var title := Label.new()
	title.text = "CAKES · Кондитерская"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("344b3f"))
	identity.add_child(title)
	level_label = Label.new()
	level_label.add_theme_color_override("font_color", Color("344b3f"))
	level_label.add_theme_font_size_override("font_size", 16)
	identity.add_child(level_label)
	xp_progress = ProgressBar.new()
	xp_progress.show_percentage = false
	xp_progress.custom_minimum_size.y = 8
	identity.add_child(xp_progress)
	unlock_notice = Label.new()
	unlock_notice.visible = false
	unlock_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unlock_notice.add_theme_color_override("font_color", Color("976b35"))
	identity.add_child(unlock_notice)
	var tools := VBoxContainer.new()
	header.add_child(tools)
	coin_label = Label.new()
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coin_label.add_theme_color_override("font_color", Color("344b3f"))
	tools.add_child(coin_label)
	var menu := HBoxContainer.new()
	tools.add_child(menu)
	recipe_button = Button.new()
	recipe_button.custom_minimum_size = Vector2(120, 44)
	recipe_button.pressed.connect(_open_recipe_book)
	menu.add_child(recipe_button)
	recipe_book = preload("res://recipe_book.gd").new()
	add_child(recipe_book)
	recipe_book.visibility_changed.connect(_sync_room_input)
	recipe_book.production_requested.connect(_start_batch)
	recipe_book.discard_requested.connect(_discard_stock)
	recipe_book.shop_requested.connect(func(): recipe_book.hide(); _open_shop())
	layout_button = Button.new()
	layout_button.text = "Мебель"
	layout_button.custom_minimum_size = Vector2(104, 44)
	layout_button.pressed.connect(_toggle_layout)
	menu.add_child(layout_button)
	shop_button = Button.new()
	shop_button.text = "Магазин"
	shop_button.custom_minimum_size = Vector2(104,44)
	shop_button.pressed.connect(_open_shop)
	menu.add_child(shop_button)
	equipment_shop = preload("res://equipment_shop.gd").new()
	add_child(equipment_shop)
	equipment_shop.visibility_changed.connect(_sync_room_input)
	equipment_shop.purchase_requested.connect(_purchase_equipment)
	equipment_shop.new_game_requested.connect(_confirm_new_game)
	new_game_dialog = preload("res://reset_dialog.gd").new()
	new_game_dialog.title = "Начать новую игру?"
	new_game_dialog.dialog_text = "Начнёшь с 500 монет и пустой кондитерской.\nТекущие уровни, покупки и запасы будут сброшены."
	new_game_dialog.ok_button_text = "Начать заново"
	new_game_dialog.cancel_button_text = "Отмена"
	new_game_dialog.confirmed.connect(_start_new_game)
	add_child(new_game_dialog)
	new_game_dialog.visibility_changed.connect(_sync_room_input)

	bottom_panel = PanelContainer.new()
	bottom_panel.z_index = 200
	bottom_panel.add_theme_stylebox_override("panel", _hud_style("e6eadd"))
	add_child(bottom_panel)
	controls_box = VBoxContainer.new()
	controls_box.add_theme_constant_override("separation", 8)
	bottom_panel.add_child(controls_box)
	stock_label = Label.new()
	stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stock_label.add_theme_color_override("font_color", Color("344b3f"))
	controls_box.add_child(stock_label)
	production_row = HBoxContainer.new()
	production_row.add_theme_constant_override("separation", 10)
	controls_box.add_child(production_row)
	recipe_selector = OptionButton.new()
	recipe_selector.custom_minimum_size.y = 52
	recipe_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_selector.item_selected.connect(func(_index: int): _refresh_batch_button())
	production_row.add_child(recipe_selector)
	batch_button = Button.new()
	batch_button.custom_minimum_size = Vector2(210, 52)
	batch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	batch_button.pressed.connect(_bake_selected)
	production_row.add_child(batch_button)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("344b3f"))
	controls_box.add_child(status_label)
	progress = ProgressBar.new()
	progress.max_value = 5.0
	progress.show_percentage = false
	progress.custom_minimum_size.y = 8
	controls_box.add_child(progress)
	center_camera = Button.new()
	center_camera.z_index = 201
	center_camera.text = "Весь зал"
	center_camera.custom_minimum_size = Vector2(100, 44)
	center_camera.pressed.connect(func():
		room.toggle_overview()
		center_camera.text = "Крупнее" if room.overview else "Весь зал"
	)
	add_child(center_camera)
	get_viewport().size_changed.connect(_queue_layout)
	top_panel.minimum_size_changed.connect(_queue_layout)
	bottom_panel.minimum_size_changed.connect(_queue_layout)
	_load_progress()
	room.apply_purchases(purchased)
	_refresh()
	if fresh_game:
		_save_progress()
		call_deferred("_open_shop")
	_queue_layout()
	if not pending_resume.is_empty():
		call_deferred("_start_batch", pending_resume)

func _hud_style(color: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color)
	style.bg_color.a = 0.96
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _queue_layout() -> void:
	if layout_queued:
		return
	layout_queued = true
	call_deferred("_arrange_screen")

func _arrange_screen() -> void:
	layout_queued = false
	var window := get_window()
	var wide := window.size.x > window.size.y * 1.2
	var base := Vector2i(1280, 720) if wide else Vector2i(750, 1000)
	if window.content_scale_size != base:
		window.content_scale_size = base
		_queue_layout()
		return
	wide_layout = wide
	_update_level_display()
	center_camera.visible = wide
	var viewport := get_viewport_rect().size
	var padding := Vector4(18, 12, 18, 12)
	if OS.has_feature("ios") or OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		if screen.x > 0 and screen.y > 0:
			padding.x = maxf(padding.x, float(safe.position.x) / screen.x * viewport.x + 8)
			padding.y = maxf(padding.y, float(safe.position.y) / screen.y * viewport.y + 8)
			padding.z = maxf(padding.z, float(screen.x - safe.end.x) / screen.x * viewport.x + 8)
			padding.w = maxf(padding.w, float(screen.y - safe.end.y) / screen.y * viewport.y + 8)
	var width := viewport.x - padding.x - padding.z
	top_panel.position = Vector2(padding.x, padding.y)
	top_panel.size = Vector2(width, top_panel.get_combined_minimum_size().y)
	bottom_panel.size = Vector2(width, bottom_panel.get_combined_minimum_size().y)
	bottom_panel.position = Vector2(padding.x, viewport.y - padding.w - bottom_panel.size.y)
	center_camera.position = Vector2(viewport.x - padding.z - center_camera.size.x, bottom_panel.position.y - 54)
	room.set_viewport_layout(Rect2(Vector2(padding.x, top_panel.position.y + top_panel.size.y + 8), Vector2(width, maxf(140, bottom_panel.position.y - top_panel.position.y - top_panel.size.y - 16))), wide)
	_refresh_stock()

func _process(delta: float) -> void:
	order_retry = maxf(0.0, order_retry-delta)
	_try_take_order()
	if notice_remaining > 0.0:
		notice_remaining = maxf(0.0, notice_remaining - delta)
		unlock_notice.visible = notice_remaining > 0.0
	if remaining > 0.0:
		remaining = maxf(0.0, remaining - delta)
		progress.value = float(active_recipe.bake) - remaining
		status_label.text = "%s × %d · выпечка · %d сек." % [active_recipe.title, active_recipe.batch, ceili(remaining)]

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
	if busy or taking_order or room.editing or id not in Catalog.unlocked_ids(experience):
		return
	if not pending_resume.is_empty() and id != pending_resume:
		status_label.text = "Сначала заверши сохранённую партию."
		return
	var recipe: Dictionary = Catalog.get_recipe(id)
	var missing := Equipment.missing_titles(recipe, purchased)
	if not missing.is_empty():
		_open_shop("Для рецепта нужно: " + missing)
		return
	if not inventory.can_fit(recipe.batch):
		status_label.text = "Для партии нужно %d мест. Свободно: %d." % [recipe.batch, inventory.free_space()]
		return
	if not room.can_complete_order(recipe.stations):
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
	production_phase = "preparing"
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
	if active_recipe.id == "cookie":
		await _visit(4, "Формуем печенье на формовочном столе")
		room.chef.working = true
		await get_tree().create_timer(1.0).timeout
		room.chef.working = false
	await _visit(0, "Переносим партию заготовок в печь")
	room.chef.carrying = false
	room.chef.carrying_dough = false
	production_phase = "baking"
	remaining = active_recipe.bake
	await get_tree().create_timer(float(active_recipe.bake)).timeout
	remaining = 0.0
	production_phase = "finishing"
	if taking_order:
		await order_service_finished
	await _visit(0, "Забираем готовую партию из печи")
	room.chef.carrying = true
	if active_recipe.id == "cupcake":
		await _visit(5, "Украшаем капкейки на столе декора")
		room.chef.working = true
		await get_tree().create_timer(2.0).timeout
		room.chef.working = false
	await _visit(1, "%s × %d · пополняем витрину" % [active_recipe.title, active_recipe.batch])
	room.chef.carrying = false
	inventory.finish_batch()
	busy = false
	production_phase = ""
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
	if room.customer_state != "waiting" or room.editing or "display" not in purchased:
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
	room.set_recipe_pool(_orderable_recipe_ids())
	baked += 1
	_save_progress()
	room.finish_customer()

func _refresh() -> void:
	coin_label.text = "%d монет" % coins
	_update_level_display()
	var recipe: Dictionary = Catalog.get_recipe(room.current_recipe_id)
	_refresh_stock()
	if room.recipe_pool.is_empty():
		status_label.text = "Для старта купи: " + Equipment.missing_titles(Catalog.RECIPES[0], purchased)
	elif room.customer_state == "ordering":
		status_label.text = "Кондитер принимает заказ: %s × 1" % recipe.title if taking_order else "Покупатель ждёт кондитера у кассы"
	elif room.customer_state == "waiting":
		status_label.text = "%s × 1 · ждёт пополнения витрины" % recipe.title
	elif room.customer_state == "to_display":
		status_label.text = "Заказ принят · покупатель идёт к витрине"
	elif room.customer_state == "entering":
		status_label.text = "Покупатель идёт к кассе…"
	elif room.customer_state == "leaving":
		status_label.text = "Продано 1 шт. · %s" % last_reward
	else:
		status_label.text = "Ждём покупателя · продано изделий: %d" % baked
	if not busy:
		progress.value = 0

func _refresh_stock() -> void:
	var details := PackedStringArray()
	for recipe in Catalog.RECIPES:
		if recipe.level <= Catalog.level_for_xp(experience):
			details.append("%s: %d" % [recipe.title, inventory.count_of(recipe.id)])
	stock_label.text = ("Витрина: %d/%d · в работе: %d" % [inventory.total(), inventory.CAPACITY, inventory.reserved_count]) + (" · " if wide_layout else "\n") + " · ".join(details)
	if "display" not in purchased:
		stock_label.text = "Витрина ещё не куплена · 18 мест после покупки"
	room.update_display_stock(inventory.total(), inventory.CAPACITY)
	_refresh_batch_button()
	if recipe_book.visible:
		_open_recipe_book()

func _refresh_batch_button() -> void:
	var recipe: Dictionary = Catalog.get_recipe(_selected_id())
	batch_button.text = "Выпечь %d шт." % recipe.batch
	var missing := Equipment.missing(recipe, purchased)
	batch_button.disabled = busy or taking_order or room.editing or not inventory.can_fit(recipe.batch) or not missing.is_empty()
	if busy or taking_order:
		batch_button.text = "Кондитер на кассе…" if taking_order else "Партия готовится…"
	elif not missing.is_empty():
		batch_button.text = "Нужно оборудование"
	elif not inventory.can_fit(recipe.batch):
		batch_button.text = "Мало места · нужно %d" % recipe.batch

func _open_recipe_book() -> void:
	recipe_book.show_recipes(experience, inventory, busy or taking_order, room.editing, purchased)

func _discard_stock(id: String) -> void:
	if room.editing or not inventory.take_one(id):
		return
	_save_progress()
	_refresh()

func _update_level_display() -> void:
	var level := Catalog.level_for_xp(experience)
	var unlocked: Array[String] = Catalog.unlocked_ids(experience)
	room.set_recipe_pool(_orderable_recipe_ids())
	recipe_button.text = "Рецепты · %d/%d" % [unlocked.size(), Catalog.RECIPES.size()]
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
		level_label.text = ("Уровень %d · %d/%d опыта" + (" · " if wide_layout else "\n") + "Ещё %d опыта — %s") % [level, experience - start, target - start, target - experience, next_title]
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
	data.set_value("business", "version", 1)
	data.set_value("business", "purchased", PackedStringArray(purchased))
	inventory.write_save(data)
	if not pending_resume.is_empty():
		data.set_value("production", "recipe", pending_resume)
	return data

func _save_progress() -> void:
	_progress_data().save("user://cakes_progress.cfg")

func _restore_progress(data: ConfigFile) -> void:
	fresh_game = false
	purchased.clear()
	var saved_purchases = data.get_value("business", "purchased", Equipment.LEGACY)
	for id in saved_purchases:
		if id in Equipment.IDS and id not in purchased:
			purchased.append(id)
	if "register" not in purchased:
		purchased.append("register")
	room.apply_purchases(purchased)
	coins = maxi(0, int(data.get_value("progress", "coins", 0)))
	baked = maxi(0, int(data.get_value("progress", "baked", 0)))
	experience = maxi(0, int(data.get_value("progress", "experience", 0)))
	pending_resume = inventory.restore_save(data)
	if pending_resume not in Catalog.unlocked_ids(experience):
		pending_resume = ""
	# A legacy batch already in progress keeps the equipment needed to finish it.
	if not data.has_section_key("business", "purchased") and not pending_resume.is_empty():
		for id in Catalog.get_recipe(pending_resume).required:
			if id not in purchased:
				purchased.append(id)
		room.apply_purchases(purchased)
	room.restore_layout(data)
	room.set_recipe_pool(_orderable_recipe_ids())

func _load_progress() -> void:
	var data := ConfigFile.new()
	if data.load("user://cakes_progress.cfg") == OK:
		_restore_progress(data)

func _toggle_layout() -> void:
	if busy or taking_order:
		return
	room.set_editing(not room.editing)
	_refresh_stock()
	layout_button.text = "Готово" if room.editing else "Мебель"
	if room.editing:
		status_label.text = "Выбери предмет, затем свободную клетку пола."
	else:
		_refresh()
		if not pending_resume.is_empty():
			call_deferred("_start_batch", pending_resume)

func _orderable_recipe_ids() -> Array[String]:
	var ready: Array[String] = []
	if "register" not in purchased or "display" not in purchased:
		return ready
	for id in Catalog.unlocked_ids(experience):
		if Equipment.missing(Catalog.get_recipe(id), purchased).is_empty() or inventory.count_of(id) > 0:
			ready.append(id)
	return ready

func _open_shop(note: String = "") -> void:
	var message := note
	if message.is_empty() and Equipment.missing(Catalog.RECIPES[0], purchased).is_empty():
		message = "Новые аппараты открываются вместе с уровнями и рецептами."
	equipment_shop.show_shop(coins, Catalog.level_for_xp(experience), purchased, busy or taking_order, room.editing, message)

func _purchase_equipment(id: String) -> void:
	var entry: Dictionary = Equipment.item(id)
	if entry.is_empty() or id in purchased:
		return
	if busy or taking_order or room.editing:
		_open_shop("Заверши партию или расстановку перед покупкой.")
		return
	if entry.level > Catalog.level_for_xp(experience):
		_open_shop("Для покупки нужен уровень %d." % entry.level)
		return
	if coins < entry.price:
		_open_shop("Не хватает %d монет." % (entry.price - coins))
		return
	if not room.prepare_purchase(entry.index):
		_open_shop("Нет свободного места. Освободи клетку в зале.")
		return
	coins -= int(entry.price)
	purchased.append(id)
	room.apply_purchases(purchased)
	_save_progress()
	_refresh()
	_queue_layout()
	_open_shop("%s куплен и установлен в зале." % entry.title)

func _confirm_new_game() -> void:
	if busy or taking_order:
		_open_shop("Сначала дождись завершения партии.")
		return
	new_game_dialog.popup_centered(Vector2i(520,180))

func _backup_progress() -> void:
	_progress_data().save("user://cakes_progress_backup.cfg")

func _start_new_game() -> void:
	if busy or taking_order:
		return
	_backup_progress()
	coins = Equipment.STARTING_COINS
	experience = 0
	baked = 0
	inventory = preload("res://display_inventory.gd").new()
	purchased = ["register"]
	pending_resume = ""
	active_recipe = {}
	remaining = 0.0
	last_reward = ""
	unlock_notice.visible = false
	notice_remaining = 0.0
	room.pause_customers()
	room.set_editing(false)
	layout_button.text = "Мебель"
	room.cells.assign([Vector2i(1,1),Vector2i(3,3),Vector2i(4,1),Vector2i(4,3),Vector2i(1,3),Vector2i(2,1)])
	room.chef_position = Vector2(2,4)
	room.current_recipe_id = "croissant"
	room.pending_new_recipe = ""
	room.recipe_rotation = 0
	room.apply_purchases(purchased)
	_save_progress()
	_refresh()
	_queue_layout()
	_open_shop()

func _sync_room_input() -> void:
	room.interaction_blocked = (equipment_shop != null and equipment_shop.visible) or (recipe_book != null and recipe_book.visible) or (new_game_dialog != null and new_game_dialog.visible)

func _try_take_order() -> void:
	if taking_order or room.editing or room.customer_state != "ordering" or order_retry > 0.0:
		return
	if busy and (production_phase != "baking" or remaining <= 0.0):
		return
	if room.station_path(3, Vector2i(room.chef_position.round())).is_empty():
		order_retry = 1.0
		status_label.text = "Нет прохода к кассе. Измени расстановку."
		return
	_take_order()

func _take_order() -> void:
	taking_order = true
	room.busy = true
	layout_button.disabled = true
	_refresh()
	status_label.text = "Кондитер идёт к кассе…"
	if room.walk_to_station(3):
		await room.arrived
		room.chef.working = true
		status_label.text = "Кондитер принимает заказ…"
		await get_tree().create_timer(0.8).timeout
		room.chef.working = false
		_accept_order()
	taking_order = false
	room.busy = busy
	layout_button.disabled = busy
	order_retry = 1.0
	_refresh()
	if equipment_shop.visible:
		_open_shop()
	order_service_finished.emit()
