extends "res://modal_panel.gd"
signal task_selected
signal reward_requested
var current_only:=false
const Recipes=preload("res://recipes.gd")
var list: VBoxContainer
func _ready() -> void:
	super._ready()
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("f5f1e9")
	style.set_corner_radius_all(14)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",14)
	panel.add_child(box)
	var title:=Label.new()
	title.text="Задания кондитерской"
	title.add_theme_font_size_override("font_size",24)
	title.add_theme_color_override("font_color",Color("344b3f"))
	box.add_child(title)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(500,230)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	list=VBoxContainer.new()
	list.add_theme_constant_override("separation",14)
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var close:=Button.new()
	close.text="Вернуться в кондитерскую"
	close.custom_minimum_size.y=48
	close.pressed.connect(hide)
	box.add_child(close)
func label(text: String, muted: bool=false) -> void:
	var node:=Label.new()
	node.text=text
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size.x=480
	node.add_theme_color_override("font_color",Color("74806f") if muted else Color("344b3f"))
	list.add_child(node)
func refresh(tasks: RefCounted) -> void:
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	label("Продавай десерты посетителям. Засчитываются только выданные товары.")
	for i in range(tasks.GOALS.size()):
		if current_only and i!=tasks.index: continue
		var goal: Dictionary=tasks.GOALS[i]
		var done: bool=i<tasks.index
		var current: bool=i==tasks.index
		label(("✓ " if done else "")+goal.title+(" · выполнено" if done else ""),not current)
		for id in goal.needs:
			var count: int=int(goal.needs[id]) if done else (int(tasks.counts.get(id,0)) if current else 0)
			label("Продать: %s · %d/%d" % [Recipes.get_recipe(id).title,count,goal.needs[id]],not current)
			var bar:=ProgressBar.new()
			bar.max_value=goal.needs[id]
			bar.value=count
			bar.show_percentage=false
			bar.custom_minimum_size.y=10
			list.add_child(bar)
		if not done:
			label("Награда: %d монет · %d опыта" % [goal.coins,goal.xp],not current)
			if current and tasks.active:
				var claim:=Button.new()
				claim.text="Получить награду" if tasks.complete() else ("Выполнить" if current_only else "Выполняется")
				claim.custom_minimum_size.y=44
				claim.disabled=not tasks.complete() and not current_only
				claim.pressed.connect(func():
					if current_only and not tasks.complete(): task_selected.emit()
					else: reward_requested.emit()
				)
				list.add_child(claim)
			else: label("Сначала заверши предыдущее задание" if not current else "Открой рецепты и купи нужное оборудование",true)
		list.add_child(HSeparator.new())
func show_tasks(tasks: RefCounted) -> void:
	current_only=false
	refresh(tasks)
	popup_centered(Vector2i(560,510))

func show_current_task(tasks: RefCounted) -> void:
	current_only=true
	refresh(tasks)
	popup_centered(Vector2i(560,460))
