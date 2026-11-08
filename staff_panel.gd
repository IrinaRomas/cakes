extends "res://modal_panel.gd"
signal hire_requested(id: String)
signal upgrade_requested(id: String)
signal shop_requested
const Staff=preload("res://staff_catalog.gd")
const Equipment=preload("res://equipment_catalog.gd")
var list: VBoxContainer
var heading: Label
func _ready() -> void:
	super._ready()
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("f5f1e9")
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	panel.add_child(box)
	heading=Label.new()
	heading.size.x=540
	heading.custom_minimum_size.x=540
	heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_color_override("font_color",Color("344b3f"))
	box.add_child(heading)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(540,260)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	list=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",12)
	scroll.add_child(list)
	var close:=Button.new()
	close.text="Вернуться в кондитерскую"
	close.custom_minimum_size.y=48
	close.pressed.connect(hide)
	box.add_child(close)
func text_row(value: String) -> void:
	var label:=Label.new()
	label.size.x=520
	label.custom_minimum_size.x=520
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color",Color("344b3f"))
	label.text=value
	list.add_child(label)
func show_staff(level: int, coins: int, hired: Array[String], purchased: Array[String], busy: bool, note: String="") -> void:
	heading.text="Персонал · %d/3 сотрудника · %d монет\n%s" % [hired.size(),coins,note if not note.is_empty() else "Новые сотрудники не выходят автоматически — найми их здесь."]
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for entry in Staff.ROLES:
		text_row(entry.title+"\n"+entry.description)
		var button:=Button.new()
		button.custom_minimum_size.y=44
		button.disabled=true
		button.name="Hire_"+entry.id
		var missing:=false
		for id in entry.requires:
			if id not in purchased: missing=true
		if entry.id in hired: button.text="В команде"
		elif level<entry.level: button.text="Найм откроется на уровне %d" % entry.level
		elif missing:
			button.text="Купить рабочее место" if entry.id=="assistant" else "Нужна касса"
			button.disabled=false
			button.pressed.connect(func(): shop_requested.emit())
		else:
			button.text="Нанять бесплатно"
			button.disabled=false
			button.pressed.connect(func(): hire_requested.emit(entry.id))
		list.add_child(button)
	text_row("Улучшения персонала")
	for entry in Equipment.ITEMS:
		if not entry.id.begins_with("staff_"): continue
		text_row("%s · %d монет\n%s" % [entry.title,entry.price,entry.description])
		var button:=Button.new()
		button.custom_minimum_size.y=44
		button.name="Upgrade_"+entry.id
		button.disabled=true
		if entry.id in purchased: button.text="Улучшение куплено"
		elif level<entry.level: button.text="Откроется на уровне %d" % entry.level
		elif busy: button.text="После завершения текущей работы"
		elif coins<entry.price: button.text="Не хватает %d монет" % (entry.price-coins)
		else:
			button.text="Улучшить за %d" % entry.price
			button.disabled=false
		button.pressed.connect(func(): upgrade_requested.emit(entry.id))
		list.add_child(button)
	popup_centered(Vector2i(600,540))
