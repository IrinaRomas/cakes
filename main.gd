extends Control

var work_generation:=0
var relocating_work:=false
var layout_generation:=0
var hired_staff: Array[String]=["chef"]
var staff_panel: Control
var header_menu: GridContainer
var progression_panel: Control
const Progression=preload("res://progression.gd")
const Catalog = preload("res://recipes.gd")
const Equipment = preload("res://equipment_catalog.gd")
var auto_status:=""
var auto_restock:=true
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
const CUSTOMER_WAIT_SECONDS := 30.0
var customer_wait_remaining := CUSTOMER_WAIT_SECONDS
var order_retry := 0.0
var economy=preload("res://economy.gd").new()
var preparing_job_id: int=-1
var preparing_remaining:=0.0
var preparing_duration:=0.0
var job_queue=preload("res://production_queue.gd").new()
var queue_button: Button
var queue_panel: Control
var queue_reason := ""
var active_step: Dictionary={}
var stage_index := 0
var stage_has_started := false
var stage_history: Array[int]=[]
signal order_service_finished
signal batch_completed(recipe_id: String)
signal stage_started(recipe_id: String, phase: String, station: int)
var stage_text := ""
var inventory = preload("res://display_inventory.gd").new()
var pending_resume := ""
var service_label: Label
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
	var menu := GridContainer.new()
	menu.columns=2
	header_menu=menu
	menu.add_theme_constant_override("h_separation",8)
	menu.add_theme_constant_override("v_separation",6)
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
	recipe_book.auto_restock_changed.connect(_set_auto_restock)
	recipe_book.progression_requested.connect(func(): recipe_book.hide(); _open_progression())
	progression_panel=preload("res://progression_panel.gd").new()
	add_child(progression_panel)
	progression_panel.visibility_changed.connect(_sync_room_input)
	level_label.mouse_filter=Control.MOUSE_FILTER_STOP
	level_label.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	level_label.tooltip_text="Карта уровней"
	level_label.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT: _open_progression()
	)
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
	var staff_button:=Button.new()
	staff_button.text="Персонал"
	staff_button.custom_minimum_size=Vector2(110,44)
	staff_button.pressed.connect(_open_staff)
	menu.add_child(staff_button)
	staff_panel=preload("res://staff_panel.gd").new()
	add_child(staff_panel)
	staff_panel.hire_requested.connect(_hire_staff)
	staff_panel.upgrade_requested.connect(_purchase_equipment)
	staff_panel.shop_requested.connect(func(): staff_panel.hide(); _open_shop("Сначала купи рабочее место, затем найми помощника в «Персонале»."))
	staff_panel.visibility_changed.connect(_sync_room_input)
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
	service_label=Label.new()
	service_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	service_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	service_label.add_theme_font_size_override("font_size",14)
	service_label.add_theme_color_override("font_color",Color("344b3f"))
	controls_box.add_child(service_label)
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
	queue_button=Button.new()
	queue_button.text="Очередь · 0"
	queue_button.z_index=201
	queue_button.custom_minimum_size=Vector2(150,44)
	queue_button.pressed.connect(_open_queue)
	add_child(queue_button)
	queue_panel=preload("res://production_panel.gd").new()
	add_child(queue_panel)
	queue_panel.visibility_changed.connect(_sync_room_input)
	queue_panel.move_requested.connect(_move_job)
	queue_panel.cancel_requested.connect(_cancel_job)
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
	_configure_staff()
	_setup_customer_service()
	_refresh()
	if fresh_game:
		_save_progress()
		call_deferred("_open_shop")
	_queue_layout()

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
	header_menu.columns=4 if wide else 2
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
	queue_button.position=Vector2(padding.x,bottom_panel.position.y-54)
	center_camera.position = Vector2(viewport.x - padding.z - center_camera.size.x, bottom_panel.position.y - 54)
	room.set_viewport_layout(Rect2(Vector2(padding.x, top_panel.position.y + top_panel.size.y + 8), Vector2(width, maxf(140, bottom_panel.position.y - top_panel.position.y - top_panel.size.y - 16))), wide)
	_refresh_stock()

func _process(delta: float) -> void:
	if room.editing or relocating_work: return
	if room.service!=null:
		service_label.text=room.service.summary()
		service_label.add_theme_color_override("font_color",Color("a33f37") if not room.service.missing_orders().is_empty() else Color("344b3f"))
	order_retry=maxf(0.0,order_retry-delta)
	_try_take_order()
	_plan_autonomous_batch()
	_dispatch_queue()
	_try_prepare_next()
	if preparing_job_id>=0:
		preparing_remaining=maxf(0,preparing_remaining-delta)
		room.show_work_status(8,"Подготовка · %d сек." % ceili(preparing_remaining),1-preparing_remaining/preparing_duration)
	_update_customer_wait(delta)
	if not busy and not taking_order and job_queue.waiting.is_empty() and auto_restock and not auto_status.is_empty(): status_label.text=auto_status
	if not busy and not taking_order and not queue_reason.is_empty():
		status_label.text=queue_reason + (" · освободи место через «Рецепты» или дождись продаж" if queue_reason.contains("мест") else " · проверь очередь и рецепты")
	if notice_remaining>0:
		notice_remaining=maxf(0.0,notice_remaining-delta)
		unlock_notice.visible=notice_remaining>0
	if remaining>0 and not active_step.is_empty():
		remaining=maxf(0.0,remaining-delta)
		progress.value=float(active_step.duration)-remaining
		room.show_work_status(active_step.station, "%s · %d сек." % [active_step.title,ceili(remaining)], _stage_fraction())
		if not taking_order:
			status_label.text="%s × %d · %s · %d сек." % [active_recipe.title,active_recipe.batch,active_step.title,ceili(remaining)]
	if queue_panel.visible:
		queue_panel.update_current(_production_summary(),_stage_fraction())

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
	if room.editing or id not in Catalog.unlocked_ids(experience): return
	var recipe: Dictionary=Catalog.get_recipe(id)
	var missing:=Equipment.missing_titles(recipe,purchased)
	if not missing.is_empty():
		_open_shop("Для рецепта нужно: "+missing)
		return
	var job_id: int=job_queue.enqueue(id)
	if job_id<0:
		status_label.text="В очереди уже %d партий. Заверши или отмени одну." % job_queue.limit
		return
	var index: int=job_queue.waiting.size()-1
	while index>0 and job_queue.waiting[index-1].get("automatic",false):
		job_queue.move_job(job_id,-1)
		index-=1
	_save_progress()
	_queue_changed()
	_dispatch_queue()

func _dispatch_queue() -> void:
	if busy or taking_order or room.editing or job_queue.waiting.is_empty(): return
	var recipe: Dictionary=_recipe_for_job(job_queue.waiting[0])
	var reason:=""
	if recipe.id not in Catalog.unlocked_ids(experience):
		reason="Первый рецепт пока не открыт"
	elif not Equipment.missing(recipe,purchased).is_empty():
		reason="Нужно купить: "+Equipment.missing_titles(recipe,purchased)
	elif job_queue.waiting[0].get("preparing",false):
		reason="Помощник заканчивает подготовку первой партии"
	elif not inventory.can_fit(recipe.batch):
		reason="Первая партия ждёт %d мест в витрине · свободно %d" % [recipe.batch,inventory.free_space()]
	elif not room.can_complete_order(_job_stations(job_queue.waiting[0],recipe)):
		reason="Нет прохода к оборудованию первой партии"
	if queue_reason!=reason:
		queue_reason=reason
		_queue_changed()
	if not reason.is_empty(): return
	_snapshot_job(job_queue.waiting[0],recipe)
	if not inventory.reserve(recipe.id,recipe.batch): return
	job_queue.begin_next()
	_run_batch(recipe)

func _run_batch(recipe: Dictionary) -> void:
	var epoch:=work_generation
	active_recipe=recipe.duplicate()
	room.chef.carried_recipe=recipe.id
	room.chef.carried_count=recipe.batch
	room.chef.carrying=false
	busy=true
	room.busy=true
	layout_button.disabled=false
	_save_progress()
	_queue_changed()
	var steps: Array[Dictionary]=Catalog.steps(recipe.id)
	if job_queue.active.get("prepared",false):
		steps.pop_front()
		await _visit(8,"Забираем подготовленный поднос у помощника")
		if epoch!=work_generation: return
		room.chef.carrying=true
		room.chef.carrying_dough=true
		room.set_assistant_work(false)
		room.clear_work_status(8)
	for step in steps:
		if step.key=="baking": step.duration=recipe.bake
		elif step.key=="preparing": step.duration=recipe.prep
		elif not step.passive: step.duration*=float(recipe.get("work_factor",1.0))
	var destination:=_display_destination(recipe)
	for step in steps:
		if step.station==1: step.station=destination
	stage_history.clear()
	for index in range(steps.size()):
		stage_index=index
		active_step=steps[index]
		stage_has_started=false
		production_phase=active_step.key
		remaining=0
		progress.max_value=active_step.duration
		progress.value=0
		await _visit(active_step.station,"%s × %d · %s" % [recipe.title,recipe.batch,active_step.title])
		if epoch!=work_generation: return
		stage_history.append(active_step.station)
		if active_step.passive:
			room.chef.carrying=false
			room.chef.carrying_dough=false
		room.chef.working=not active_step.passive
		remaining=active_step.duration
		stage_has_started=true
		room.show_work_status(active_step.station,active_step.title,0)
		stage_started.emit(recipe.id,active_step.key,active_step.station)
		await _wait_work(float(active_step.duration))
		if epoch!=work_generation: return
		remaining=0
		room.chef.working=false
		if active_step.passive:
			production_phase="collecting"
			room.show_work_status(active_step.station,"Готово · ждёт кондитера",1)
			if taking_order: await order_service_finished
			if epoch!=work_generation: return
			await _visit(active_step.station,"Забираем партию · "+active_step.title)
			if epoch!=work_generation: return
		room.clear_work_status(active_step.station)
		room.chef.carrying=true
		room.chef.carrying_dough=active_step.key in ["preparing","forming"]
	room.chef.carrying=false
	room.chef.carrying_dough=false
	inventory.finish_batch()
	job_queue.finish()
	busy=false
	production_phase=""
	active_step={}
	room.busy=false
	layout_button.disabled=false
	_save_progress()
	_serve_customer()
	_queue_changed()
	if room.service!=null: room.park_chef()
	batch_completed.emit(recipe.id)

func _stage_fraction() -> float:
	if active_step.is_empty() or not stage_has_started: return 0
	return clampf(1.0-remaining/float(active_step.duration),0,1)

func _production_summary() -> String:
	if not busy:
		if job_queue.waiting.is_empty(): return "Кондитер свободен · добавь партии в очередь"
		var next: Dictionary=Catalog.get_recipe(job_queue.waiting[0].recipe)
		return "Следующая партия: %s × %d\n%s" % [next.title,next.batch,Catalog.route_title(next.id)]
	return "%s × %d · этап %d/%d: %s\n%s" % [active_recipe.title,active_recipe.batch,stage_index+1,Catalog.steps(active_recipe.id).size()-int(job_queue.active.get("prepared",false)),active_step.get("title","В пути"),Catalog.route_title(active_recipe.id)]

func _queue_changed() -> void:
	if job_queue.waiting.is_empty(): queue_reason=""
	queue_button.text="Очередь · %d%s" % [job_queue.waiting.size()," + 1 в работе" if busy else ""]
	_refresh()
	if queue_panel.visible: _open_queue()
	if equipment_shop.visible: _open_shop()
	if staff_panel.visible: _open_staff()

func _open_queue() -> void:
	queue_panel.show_queue(job_queue,_production_summary(),_stage_fraction(),queue_reason,_recipe_quotes())

func _move_job(id: int, direction: int) -> void:
	for job in job_queue.waiting:
		if int(job.id)==id: job.automatic=false
	if job_queue.move_job(id,direction):
		_save_progress()
		_queue_changed()

func _cancel_job(id: int) -> void:
	for job in job_queue.waiting:
		if int(job.id)==id and job.get("prepared",false):
			room.set_assistant_work(false)
			room.clear_work_status(8)
	if id==preparing_job_id:
		preparing_job_id=-1
		room.clear_work_status(8)
		room.set_assistant_work(false)
	if job_queue.cancel(id):
		_save_progress()
		_queue_changed()

func _visit(station: int, message: String) -> void:
	var epoch:=work_generation
	stage_text=message
	while is_inside_tree():
		if room.editing:
			await get_tree().process_frame
			if epoch!=work_generation: return
			continue
		status_label.text=message
		if room.walk_to_station(station):
			while room.walking and epoch==work_generation:
				await get_tree().process_frame
			if epoch!=work_generation: return
			if not room.editing and absi(roundi(room.chef_position.x)-room.cells[station].x)+absi(roundi(room.chef_position.y)-room.cells[station].y)==1: return
		else:
			status_label.text="Нет прохода к %s. Открой «Мебель» и освободи проход." % room.TITLES[station]
			await get_tree().process_frame
			if epoch!=work_generation: return

func _accept_order() -> void:
	if not room.editing:
		if room.accept_customer_order() and inventory.count_of(room.current_recipe_id) == 0:
			_select_recipe(room.current_recipe_id)

func _customer_updated() -> void:
	_serve_customer()
	if not room.editing:
		_refresh()

func _serve_customer() -> void:
	if room.service!=null: return
	if room.customer_state!="waiting" or room.editing or "display" not in purchased: return
	if _sell_recipe(room.current_recipe_id): room.finish_customer()

func _sell_recipe(id: String) -> bool:
	if room.editing or "display" not in purchased: return false
	var sold_recipe: Dictionary=Catalog.get_recipe(id)
	if not inventory.take_one(sold_recipe.id): return false
	var previous_level := Catalog.level_for_xp(experience)
	coins += int(sold_recipe.price)
	economy.sales_income+=int(sold_recipe.price)
	experience += int(sold_recipe.xp)
	last_reward = "+%d монет · +%d опыта" % [sold_recipe.price, sold_recipe.xp]
	var new_level := Catalog.level_for_xp(experience)
	if new_level > previous_level:
		var opened := PackedStringArray()
		for recipe in Catalog.RECIPES:
			if recipe.level > previous_level and recipe.level <= new_level:
				opened.append(recipe.title)
		unlock_notice.text = "Уровень %d! %s" % [new_level,Progression.MILESTONES[new_level-1]]
		_configure_staff()
		unlock_notice.visible = true
		notice_remaining = 8.0
	room.set_recipe_pool(_orderable_recipe_ids())
	baked += 1
	_save_progress()
	_refresh()
	return true

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
		status_label.text = "Продано 1 шт. · %s" % last_reward if room.customer.paid else "Покупатель ушёл без покупки · ждём следующего"
	else:
		status_label.text = "Ждём покупателя · продано изделий: %d" % baked
	if room.service!=null and not busy:
		status_label.text="Кондитер свободен · ждёт продаж и места в витринах" if auto_restock else "Кондитер свободен · автопополнение на паузе"
	if busy and not taking_order:
		status_label.text=stage_text if remaining<=0 else "%s × %d · %s · %d сек." % [active_recipe.title,active_recipe.batch,active_step.title,ceili(remaining)]
	elif not busy:
		progress.value = 0
		if not queue_reason.is_empty(): status_label.text=queue_reason

func _refresh_stock() -> void:
	inventory.capacity=_storage_capacity()
	var details := PackedStringArray()
	for recipe in Catalog.RECIPES:
		if recipe.level <= Catalog.level_for_xp(experience):
			details.append("%s: %d" % [recipe.title, inventory.count_of(recipe.id)])
	stock_label.text = (("Витрины" if "display_extra" in purchased else "Витрина") + ": %d/%d · в работе: %d" % [inventory.total(), inventory.capacity, inventory.reserved_count]) + (" · " if wide_layout else "\n") + " · ".join(details)
	if "display" not in purchased:
		stock_label.text = "Витрина ещё не куплена · 18 мест после покупки"
	room.update_display_inventory(inventory.stock,inventory.capacity)
	_refresh_batch_button()
	if recipe_book.visible:
		_open_recipe_book()

func _refresh_batch_button() -> void:
	var recipe: Dictionary=_effective_recipe(_selected_id())
	var missing:=Equipment.missing(recipe,purchased)
	batch_button.text="В очередь · %d шт." % recipe.batch
	batch_button.disabled=room.editing or job_queue.waiting.size()>=job_queue.limit or not missing.is_empty()
	if not missing.is_empty(): batch_button.text="Нужно оборудование"
	elif job_queue.waiting.size()>=job_queue.limit: batch_button.text="Очередь заполнена"

func _open_recipe_book() -> void:
	recipe_book.show_recipes(experience, inventory, busy or taking_order, room.editing, purchased, job_queue.waiting.size()>=job_queue.limit,_recipe_quotes(),economy.sales_income,auto_restock)

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
	for index in range(selectable_ids.size()):
		var recipe:=_effective_recipe(selectable_ids[index])
		recipe_selector.set_item_text(index,"%s · партия %d" % [recipe.title,recipe.batch])
	if level < Catalog.LEVEL_XP.size():
		var start: int = Catalog.LEVEL_XP[level - 1]
		var target: int = Catalog.LEVEL_XP[level]
		var next_title: String = Progression.NEXT_TITLES[level]
		level_label.text = ("Уровень %d · %d/%d опыта" + (" · " if wide_layout else "\n") + "Ещё %d опыта — %s") % [level, experience - start, target - start, target - experience, next_title]
		xp_progress.max_value = target - start
		xp_progress.value = experience - start
	else:
		level_label.text = ("Уровень %d · %d опыта"+(" · " if wide_layout else "\n")+"все этапы развития открыты") % [level, experience]
		xp_progress.max_value = 1
		xp_progress.value = 1

func _progress_data() -> ConfigFile:
	var data := ConfigFile.new()
	data.set_value("staff","hired",PackedStringArray(hired_staff))
	data.set_value("progression","version",Progression.VERSION)
	data.set_value("progress", "coins", coins)
	data.set_value("progress", "baked", baked)
	data.set_value("progress", "experience", experience)
	for i in range(room.cells.size()):
		data.set_value("layout", str(i), room.cells[i])
	data.set_value("business", "version", 1)
	data.set_value("business", "purchased", PackedStringArray(purchased))
	inventory.write_save(data)
	job_queue.write_save(data)
	economy.write_save(data)
	data.set_value("automation","enabled",auto_restock)
	if not pending_resume.is_empty():
		data.set_value("production", "recipe", pending_resume)
	return data

func _save_progress() -> void:
	_progress_data().save("user://cakes_progress.cfg")

func _restore_progress(data: ConfigFile) -> void:
	fresh_game = false
	economy.restore(data)
	hired_staff=["chef"]
	for role in data.get_value("staff","hired",[]):
		if role in ["cashier","assistant"] and role not in hired_staff: hired_staff.append(role)
	auto_restock=bool(data.get_value("automation","enabled",true))
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
	experience = Progression.migrate_xp(data,maxi(0, int(data.get_value("progress", "experience", 0))))
	_configure_staff()
	inventory.capacity=_storage_capacity()
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
	job_queue.restore(data,pending_resume)
	for job in job_queue.waiting:
		if job.get("prepared",false):
			var recipe:=_recipe_for_job(job)
			room.set_assistant_work(false,recipe.id,recipe.batch)
			room.show_work_status(8,"Поднос готов · %d шт." % recipe.batch,1)
	pending_resume=""

func _load_progress() -> void:
	var data := ConfigFile.new()
	if data.load("user://cakes_progress.cfg") == OK:
		_restore_progress(data)

func _toggle_layout() -> void:
	layout_generation+=1
	room.set_editing(not room.editing)
	_refresh_stock()
	layout_button.text="Готово" if room.editing else "Мебель"
	layout_button.disabled=false
	if room.editing:
		status_label.text="Работа на паузе. Выбери предмет, затем свободную клетку."
	else:
		_resume_layout_work(layout_generation)
		_save_progress()
		_refresh()

func _orderable_recipe_ids() -> Array[String]:
	var ready: Array[String] = []
	if "register" not in purchased or "display" not in purchased:
		return ready
	for id in Catalog.unlocked_ids(experience):
		if Equipment.missing(Catalog.get_recipe(id), purchased).is_empty() or inventory.count_of(id) > 0:
			ready.append(id)
	return ready

func _open_shop(note: String = "") -> void:
	if staff_panel!=null: staff_panel.hide()
	var message := note
	if message.is_empty() and Equipment.missing(Catalog.RECIPES[0], purchased).is_empty():
		message = "Новые аппараты открываются вместе с уровнями и рецептами."
	equipment_shop.show_shop(coins, Catalog.level_for_xp(experience), purchased, busy or taking_order or preparing_job_id>=0, room.editing, message)

func _purchase_equipment(id: String) -> void:
	if id=="display" and "display" in purchased: id="display_extra"
	var entry: Dictionary = Equipment.item(id)
	if id=="display_extra" and "display" not in purchased:
		_purchase_feedback(id,"Сначала купи первую витрину.")
		return
	if entry.is_empty() or id in purchased:
		return
	if busy or taking_order or preparing_job_id>=0 or room.editing:
		_purchase_feedback(id,"Заверши партию или расстановку перед покупкой.")
		return
	if entry.level > Catalog.level_for_xp(experience):
		_purchase_feedback(id,"Для покупки нужен уровень %d." % entry.level)
		return
	if not Equipment.prerequisites(entry,purchased).is_empty():
		_purchase_feedback(id,"Сначала купи: "+Equipment.prerequisites(entry,purchased))
		return
	if coins < entry.price:
		_purchase_feedback(id,"Не хватает %d монет." % (entry.price - coins))
		return
	if entry.index>=0 and not room.prepare_purchase(entry.index):
		_purchase_feedback(id,"Нет свободного места. Освободи клетку в зале.")
		return
	coins -= int(entry.price)
	purchased.append(id)
	room.apply_purchases(purchased)
	_configure_staff()
	_save_progress()
	_refresh()
	_queue_layout()
	_purchase_feedback(id,"%s куплен и установлен в зале." % entry.title)

func _confirm_new_game() -> void:
	new_game_dialog.popup_centered(Vector2i(520,180))

func _backup_progress() -> void:
	_progress_data().save("user://cakes_progress_backup.cfg")

func _start_new_game() -> void:
	_backup_progress()
	work_generation+=1
	layout_generation+=1
	busy=false
	taking_order=false
	relocating_work=false
	room.busy=false
	room.walking=false
	room.route.clear()
	room.route_station=-1
	room.chef.working=false
	room.chef.walking=false
	room.chef.carrying=false
	stage_has_started=false
	production_phase=""
	stage_history.clear()
	preparing_remaining=0
	order_retry=0
	for index in range(room.cells.size()): room.clear_work_status(index)
	for modal in [new_game_dialog,recipe_book,queue_panel,progression_panel,staff_panel]: modal.hide()
	coins = Equipment.STARTING_COINS
	hired_staff=["chef"]
	auto_restock=true
	experience = 0
	baked = 0
	inventory = preload("res://display_inventory.gd").new()
	economy=preload("res://economy.gd").new()
	preparing_job_id=-1
	room.clear_work_status(8)
	room.set_assistant_work(false)
	job_queue=preload("res://production_queue.gd").new()
	queue_reason=""
	active_step={}
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
	room.cells.assign([Vector2i(1,1),Vector2i(3,3),Vector2i(4,1),Vector2i(4,3),Vector2i(1,3),Vector2i(2,1),Vector2i(5,1),Vector2i(1,4),Vector2i(0,2)])
	room.chef_position = Vector2(2,4)
	room.current_recipe_id = "croissant"
	room.pending_new_recipe = ""
	room.recipe_rotation = 0
	room.apply_purchases(purchased)
	_configure_staff()
	_save_progress()
	_queue_changed()
	_queue_layout()
	_open_shop()

func _sync_room_input() -> void:
	room.interaction_blocked = (equipment_shop != null and equipment_shop.visible) or (recipe_book != null and recipe_book.visible) or (new_game_dialog != null and new_game_dialog.visible) or (queue_panel != null and queue_panel.visible) or (progression_panel!=null and progression_panel.visible) or (staff_panel!=null and staff_panel.visible)

func _try_take_order() -> void:
	if room.service!=null: return
	if taking_order or room.editing or room.customer_state != "ordering" or order_retry > 0.0:
		return
	if busy and (production_phase not in ["baking","cooling"] or remaining <= 0.0):
		return
	if room.station_path(3, Vector2i(room.chef_position.round())).is_empty():
		order_retry = 1.0
		status_label.text = "Нет прохода к кассе. Измени расстановку."
		return
	_take_order()

func _take_order() -> void:
	var epoch:=work_generation
	taking_order = true
	room.busy = true
	layout_button.disabled = false
	_refresh()
	status_label.text = "Кондитер идёт к кассе…"
	if room.walk_to_station(3):
		while room.walking and epoch==work_generation:
			await get_tree().process_frame
		if epoch!=work_generation: return
		room.chef.working = true
		room.show_work_status(3,"Приём заказа",0)
		status_label.text = "Кондитер принимает заказ…"
		await _wait_work(0.8)
		if epoch!=work_generation: return
		room.chef.working = false
		room.clear_work_status(3)
		_accept_order()
	taking_order = false
	room.busy = busy
	layout_button.disabled = false
	order_retry = 1.0
	_refresh()
	if equipment_shop.visible:
		_open_shop()
	order_service_finished.emit()

func _update_customer_wait(delta: float) -> void:
	if room.service!=null: return
	if room.customer_state != "waiting":
		customer_wait_remaining=CUSTOMER_WAIT_SECONDS
		room.customer.wait_seconds=-1
		return
	if room.editing: return
	customer_wait_remaining=maxf(0.0,customer_wait_remaining-delta)
	room.customer.wait_seconds=ceili(customer_wait_remaining)
	if customer_wait_remaining<=0:
		room.finish_customer(false)

func _display_destination(recipe: Dictionary) -> int:
	return 7 if "display_extra" in purchased and inventory.total()+int(recipe.batch)>_display_size() else 1

func _production_stations(recipe: Dictionary) -> Array[int]:
	var stations: Array[int]=[]
	for station in recipe.stations:
		stations.append(_display_destination(recipe) if station==1 else station)
	return stations

func _display_size() -> int:
	return 24 if "display_shelves" in purchased else 18

func _storage_capacity() -> int:
	return maxi(1,Equipment.display_count(purchased))*_display_size()

func _effective_recipe(id: String) -> Dictionary:
	return economy.quote(id,purchased,Catalog.level_for_xp(experience))

func _recipe_quotes() -> Dictionary:
	var quotes: Dictionary={}
	for recipe in Catalog.RECIPES: quotes[recipe.id]=_effective_recipe(recipe.id)
	return quotes

func _recipe_for_job(job: Dictionary) -> Dictionary:
	return job.snapshot if job.has("snapshot") else _effective_recipe(job.recipe)

func _snapshot_job(job: Dictionary, recipe: Dictionary) -> void:
	if not job.has("snapshot"): job.snapshot=recipe.duplicate(true)

func _try_prepare_next() -> void:
	if "assistant" not in hired_staff or Catalog.level_for_xp(experience)<7 or "assistant_station" not in purchased or preparing_job_id>=0 or not busy or room.editing: return
	# Only one prepared tray can wait on the assistant's table.
	for job in job_queue.waiting:
		if job.get("prepared",false): return
	if job_queue.waiting.is_empty(): return
	var job: Dictionary=job_queue.waiting[0]
	if job.get("preparing",false): return
	var recipe:=_recipe_for_job(job)
	if not Equipment.missing(recipe,purchased).is_empty() or not inventory.can_fit(recipe.batch): return
	_snapshot_job(job,recipe)
	_prepare_next(job,recipe)

func _prepare_next(job: Dictionary, recipe: Dictionary) -> void:
	var epoch:=work_generation
	preparing_job_id=job.id
	job.preparing=true
	preparing_duration=recipe.prep
	preparing_remaining=preparing_duration
	room.set_assistant_work(true,recipe.id,recipe.batch)
	_save_progress()
	_queue_changed()
	await _wait_work(preparing_duration)
	if epoch!=work_generation: return
	if preparing_job_id!=int(job.id): return
	job.preparing=false
	job.prepared=true
	preparing_job_id=-1
	room.show_work_status(8,"Поднос готов · %d шт." % recipe.batch,1)
	room.set_assistant_work(false,recipe.id,recipe.batch)
	_save_progress()
	_queue_changed()

func _job_stations(job: Dictionary, recipe: Dictionary) -> Array[int]:
	var stations:=_production_stations(recipe)
	if job.get("prepared",false): stations.push_front(8)
	return stations

func _set_auto_restock(enabled: bool) -> void:
	auto_restock=enabled
	if not enabled:
		for index in range(job_queue.waiting.size()-1,-1,-1):
			var job: Dictionary=job_queue.waiting[index]
			if job.get("automatic",false) and not job.get("prepared",false) and not job.get("preparing",false): job_queue.waiting.remove_at(index)
	_save_progress()
	_queue_changed()

func _plan_autonomous_batch() -> void:
	auto_status=""
	if not auto_restock or room.editing or job_queue.waiting.size()>=job_queue.limit: return
	var projected: Dictionary=inventory.stock.duplicate()
	var available:=inventory.free_space()
	if inventory.reserved_count>0: projected[inventory.reserved_id]=int(projected.get(inventory.reserved_id,0))+inventory.reserved_count
	for job in job_queue.waiting:
		var recipe:=_recipe_for_job(job)
		projected[recipe.id]=int(projected.get(recipe.id,0))+int(recipe.batch)
		available-=int(recipe.batch)
	var candidates: Array[String]=Catalog.unlocked_ids(experience)
	var requested: String=room.service.needed_recipe() if room.service!=null else room.current_recipe_id
	if (room.service!=null or room.customer_state in ["ordering","to_display","waiting"]) and requested in candidates:
		candidates.erase(requested)
		candidates.push_front(requested)
	for id in candidates:
		if int(projected.get(id,0))>0: continue
		var recipe:=_effective_recipe(id)
		var missing:=Equipment.missing_titles(recipe,purchased)
		if not missing.is_empty():
			if auto_status.is_empty(): auto_status="Авто: для %s нужно купить: %s" % [recipe.title,missing]
			continue
		if int(recipe.batch)>available:
			if auto_status.is_empty(): auto_status="Авто: %s ждёт %d мест · свободно %d" % [recipe.title,recipe.batch,maxi(0,available)]
			continue
		if not room.can_complete_order(_production_stations(recipe)):
			if auto_status.is_empty(): auto_status="Авто: освободи проход к оборудованию для %s" % recipe.title
			continue
		if job_queue.enqueue(id)<0: return
		auto_status=""
		job_queue.waiting.back().automatic=true
		_save_progress()
		_queue_changed()
		return

func _setup_customer_service() -> void:
	room.customer.visible=false
	room.customer_state="absent"
	var service=preload("res://customer_service.gd").new()
	room.add_child(service)
	room.service=service
	service.setup(self,room)
	service.configure(purchased,Catalog.level_for_xp(experience),"cashier" in hired_staff)
	service_label.visible=true

func _configure_staff() -> void:
	job_queue.limit=8 if "staff_tasks" in purchased else 5
	room.chef_move_speed=3.08 if "staff_walk" in purchased else 2.2
	room.helper_enabled=Catalog.level_for_xp(experience)>=7 and "assistant" in hired_staff
	room._position_assistant()
	if room.service!=null: room.service.configure(purchased,Catalog.level_for_xp(experience),"cashier" in hired_staff)

func _open_progression() -> void:
	progression_panel.show_map(experience)

func _open_staff(note: String="") -> void:
	equipment_shop.hide()
	staff_panel.show_staff(Catalog.level_for_xp(experience),coins,hired_staff,purchased,busy or taking_order or preparing_job_id>=0 or room.editing,note)

func _hire_staff(id: String) -> void:
	var entry:=preload("res://staff_catalog.gd").role(id)
	if entry.is_empty() or id in hired_staff: return
	if Catalog.level_for_xp(experience)<int(entry.level):
		_open_staff("Найм доступен с уровня %d." % entry.level)
		return
	for required in entry.requires:
		if required not in purchased:
			_open_staff("Сначала нужно рабочее место для сотрудника.")
			return
	if room.editing:
		_open_staff("Заверши расстановку перед наймом.")
		return
	hired_staff.append(id)
	_configure_staff()
	_save_progress()
	_refresh()
	_open_staff("Кассир выйдет после завершения текущего заказа кондитером." if id=="cashier" and room.service!=null and room.service.using_chef else entry.title+" теперь в команде.")

func _purchase_feedback(id: String, message: String="") -> void:
	if id.begins_with("staff_"): _open_staff(message)
	else: _open_shop(message)

func _wait_work(duration: float) -> void:
	var epoch:=work_generation
	var left:=duration
	while left>0:
		await get_tree().process_frame
		if epoch!=work_generation: return
		if not room.editing and not relocating_work: left-=get_process_delta_time()

func _resume_layout_work(generation: int) -> void:
	var epoch:=work_generation
	if busy and stage_has_started and remaining>0 and not active_step.is_empty() and not active_step.passive and not taking_order:
		relocating_work=true
		room.chef.working=false
		await _visit(active_step.station,"Возвращаемся к оборудованию после перестановки")
		if epoch!=work_generation: return
		if generation!=layout_generation or room.editing: return
		room.chef.working=true
	relocating_work=false
