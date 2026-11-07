extends "res://modal_panel.gd"

signal move_requested(id: int, direction: int)
signal cancel_requested(id: int)
var current: Label
var meter: ProgressBar
var list: VBoxContainer
const Catalog=preload("res://recipes.gd")

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
	current=Label.new()
	current.size.x=560
	current.custom_minimum_size.x=560
	current.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	current.add_theme_color_override("font_color",Color("344b3f"))
	box.add_child(current)
	meter=ProgressBar.new()
	meter.show_percentage=false
	meter.max_value=1
	box.add_child(meter)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(560,220)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	list=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",12)
	scroll.add_child(list)
	var close:=Button.new()
	close.text="Вернуться в зал"
	close.custom_minimum_size.y=48
	close.pressed.connect(hide)
	box.add_child(close)

func show_queue(queue, stage_text: String, fraction: float, reason: String, quotes: Dictionary={}) -> void:
	update_current(stage_text,fraction)
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var help:=Label.new()
	help.text="Ожидают: %d/%d · выше в списке — раньше в работу" % [queue.waiting.size(),queue.LIMIT]
	help.add_theme_color_override("font_color",Color("344b3f"))
	list.add_child(help)
	if not reason.is_empty():
		var note:=Label.new()
		note.text=reason
		note.size.x=550
		note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_color_override("font_color",Color("986334"))
		list.add_child(note)
	for i in range(queue.waiting.size()):
		var job: Dictionary=queue.waiting[i]
		var recipe: Dictionary=job.get("snapshot",quotes.get(job.recipe,Catalog.get_recipe(job.recipe)))
		var row:=HBoxContainer.new()
		list.add_child(row)
		var label:=Label.new()
		label.text="%d. %s × %d" % [i+1,recipe.title,recipe.batch]
		label.add_theme_font_size_override("font_size",14)
		label.text+="\n"+("Подготовлено" if job.get("prepared",false) else ("Помощник готовит" if job.get("preparing",false) else "Ожидает"))
		label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color",Color("344b3f"))
		row.add_child(label)
		for direction in [-1,1,0]:
			var button:=Button.new()
			button.text="Выше" if direction==-1 else ("Ниже" if direction==1 else "Отмена")
			button.custom_minimum_size.y=44
			button.disabled=(direction==-1 and i==0) or (direction==1 and i==queue.waiting.size()-1)
			button.pressed.connect(func():
				if direction==0: cancel_requested.emit(job.id)
				else: move_requested.emit(job.id,direction)
			)
			row.add_child(button)
	popup_centered(Vector2i(620,480))

func update_current(text: String, fraction: float) -> void:
	current.text=text
	meter.value=fraction
