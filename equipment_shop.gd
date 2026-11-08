extends "res://modal_panel.gd"

signal purchase_requested(id: String)
signal new_game_requested
const Equipment = preload("res://equipment_catalog.gd")
var list: VBoxContainer
var message: Label

func _ready() -> void:
	super._ready()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f5f1e9")
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)
	message = Label.new()
	message.size.x = 540
	message.custom_minimum_size.x = 540
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color", Color("344b3f"))
	message.add_theme_font_size_override("font_size", 20)
	outer.add_child(message)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 240)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)
	var footer := HBoxContainer.new()
	outer.add_child(footer)
	var restart := Button.new()
	restart.text = "Новая игра"
	restart.custom_minimum_size.y = 48
	restart.pressed.connect(func(): new_game_requested.emit())
	footer.add_child(restart)
	var close := Button.new()
	close.text = "Вернуться в зал"
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(hide)
	footer.add_child(close)

func show_shop(coins: int, level: int, purchased: Array[String], busy: bool, editing: bool, note: String = "") -> void:
	message.text = "Магазин оборудования · %d монет\n%s" % [coins, note if not note.is_empty() else "Для начала купи витрину, миксер и печь — всего 450 монет."]
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for entry in Equipment.ITEMS:
		if entry.id.begins_with("staff_"): continue
		var quantity:=Equipment.display_count(purchased) if entry.id=="display" else int(entry.id in purchased)
		var required_level: int=Equipment.item("display_extra").level if entry.id=="display" and quantity>0 else entry.level
		var title := Label.new()
		title.text = "%s · %d монет" % [entry.title, entry.price]
		if entry.id=="display": title.text += " · в зале: %d" % quantity
		title.add_theme_color_override("font_color", Color("344b3f"))
		title.add_theme_font_size_override("font_size", 20)
		list.add_child(title)
		var detail := Label.new()
		detail.size.x = 520
		detail.custom_minimum_size.x = 520
		detail.text = entry.description
		if entry.id=="display": detail.text="Обычная витрина: 18 мест; с улучшением: 24. В зале: %d из 2 · всего %d мест." % [quantity,quantity*(24 if "display_shelves" in purchased else 18)]
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_color_override("font_color", Color("61705b"))
		list.add_child(detail)
		var button := Button.new()
		button.custom_minimum_size.y = 44
		button.text = "Купить за %d" % entry.price
		button.disabled = true
		if entry.id in purchased and (entry.id!="display" or quantity>=2):
			button.text = "Установлено: %d из 2" % quantity if entry.id=="display" else "Уже установлено"
			if entry.id=="assistant_station": button.text="Стол установлен · найм в «Персонале»"
		elif not Equipment.prerequisites(entry,purchased).is_empty():
			button.text="Сначала купи: "+Equipment.prerequisites(entry,purchased)
		elif required_level > level:
			button.text = "Откроется на уровне %d" % required_level
		elif busy:
			button.text = "Покупка после завершения партии"
		elif editing:
			button.text = "Сначала заверши расстановку"
		elif coins < entry.price:
			button.text = "Не хватает %d монет" % (entry.price - coins)
		else:
			button.disabled = false
			if entry.id=="display" and quantity>0: button.text="Купить ещё за %d" % entry.price
		button.pressed.connect(func(): purchase_requested.emit(entry.id))
		list.add_child(button)
	popup_centered(Vector2i(600, 540))
