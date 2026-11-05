extends Control

const BAKE_TIME := 5.0
var coins := 0
var baked := 0
var experience := 0
var remaining := 0.0
var busy := false
var stage_text := ""
var pastry_ready := false
var coin_label: Label
var status_label: Label
var action: Button
var progress: ProgressBar
var room: Control
var layout_button: Button

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
	layout_button = Button.new()
	layout_button.text = "Расстановка мебели"
	layout_button.custom_minimum_size.y = 48
	layout_button.pressed.connect(_toggle_layout)
	root.add_child(layout_button)
	room = preload("res://room.gd").new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room.custom_minimum_size.y = 320
	root.add_child(room)
	room.oven_pressed.connect(_on_action)
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
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color("344b3f"))
	controls.add_child(status_label)
	progress = ProgressBar.new()
	progress.max_value = BAKE_TIME
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

func _process(delta: float) -> void:
	if remaining > 0.0:
		remaining = maxf(0.0, remaining - delta)
		progress.value = BAKE_TIME - remaining
		status_label.text = "Выпекаем круассан · %d сек." % ceili(remaining)

func _on_action() -> void:
	if busy or room.editing:
		return
	if room.customer_state == "ordering":
		_accept_order()
		return
	if room.customer_state != "waiting":
		return
	if not room.can_complete_order():
		status_label.text = "Нет прохода к оборудованию. Измени расстановку."
		return
	busy = true
	room.busy = true
	layout_button.disabled = true
	action.disabled = true
	action.text = "Кондитер выполняет заказ…"
	await _visit(2, "Кондитер идёт к миксеру")
	stage_text = "Готовим тесто…"
	status_label.text = stage_text
	room.chef.working = true
	await get_tree().create_timer(2.0).timeout
	room.chef.working = false
	room.chef.carrying = true
	await _visit(0, "Переносим заготовку в печь")
	room.chef.carrying = false
	remaining = BAKE_TIME
	await get_tree().create_timer(BAKE_TIME).timeout
	remaining = 0.0
	room.chef.carrying = true
	await _visit(1, "Круассан готов · несём в витрину")
	room.chef.carrying = false
	pastry_ready = true
	busy = false
	room.busy = false
	layout_button.disabled = false
	_serve_customer()
	_refresh()

func _visit(station: int, message: String) -> void:
	stage_text = message
	status_label.text = message
	if room.walk_to_station(station):
		await room.arrived

func _accept_order() -> void:
	if not busy and not room.editing:
		room.accept_customer_order()

func _customer_updated() -> void:
	_serve_customer()
	if not busy and not room.editing:
		_refresh()

func _serve_customer() -> void:
	if not pastry_ready or room.customer_state != "waiting":
		return
	pastry_ready = false
	coins += 15
	experience += 5
	baked += 1
	_save_progress()
	room.finish_customer()

func _refresh() -> void:
	coin_label.text = "%d монет · %d опыта" % [coins, experience]
	action.disabled = busy or room.editing or room.customer_state not in ["ordering", "waiting"]
	if busy:
		status_label.text = stage_text
		action.text = "Кондитер выполняет заказ…"
	elif room.customer_state == "ordering":
		status_label.text = "У кассы: покупатель хочет 1 круассан"
		action.text = "Принять заказ"
	elif room.customer_state == "to_display":
		status_label.text = "Заказ принят · покупатель идёт к витрине"
		action.text = "Ждём покупателя у витрины"
	elif room.customer_state == "waiting":
		status_label.text = "Заказ: 1 круассан · награда 15 монет и 5 опыта"
		action.text = "Приготовить заказ"
		progress.value = 0
	elif room.customer_state == "entering":
		status_label.text = "Покупатель идёт к кассе…"
		action.text = "Ждём заказ"
	elif room.customer_state == "leaving":
		status_label.text = "Заказ выполнен! +15 монет · +5 опыта"
		action.text = "Покупатель забрал круассан"
	else:
		status_label.text = "Ждём покупателя · выполнено заказов: %d" % baked
		action.text = "Скоро придёт покупатель"
		progress.value = 0

func _save_progress() -> void:
	var data := ConfigFile.new()
	data.set_value("progress", "coins", coins)
	data.set_value("progress", "baked", baked)
	data.set_value("progress", "experience", experience)
	for i in range(room.cells.size()):
		data.set_value("layout", str(i), room.cells[i])
	data.save("user://cakes_progress.cfg")

func _load_progress() -> void:
	var data := ConfigFile.new()
	if data.load("user://cakes_progress.cfg") == OK:
		coins = maxi(0, int(data.get_value("progress", "coins", 0)))
		baked = maxi(0, int(data.get_value("progress", "baked", 0)))
		experience = maxi(0, int(data.get_value("progress", "experience", 0)))

		room.restore_layout(data)

func _toggle_layout() -> void:
	if busy:
		return
	room.set_editing(not room.editing)
	action.disabled = room.editing or room.customer_state not in ["ordering", "waiting"]
	layout_button.text = "Готово · вернуться к готовке" if room.editing else "Расстановка мебели"
	if room.editing:
		status_label.text = "Выбери предмет, затем свободную клетку пола."
	else:
		_refresh()
