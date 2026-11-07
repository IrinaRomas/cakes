extends "res://modal_panel.gd"

signal production_requested(id: String)
signal discard_requested(id: String)
signal shop_requested
const Equipment = preload("res://equipment_catalog.gd")
const Catalog = preload("res://recipes.gd")
var list: VBoxContainer

func _ready() -> void:
	super._ready()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f5f1e9")
	style.border_color = Color("a5b59a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var outer:=VBoxContainer.new()
	margin.add_child(outer)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(450,260)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	var close:=Button.new()
	close.text="Вернуться в кондитерскую"
	close.custom_minimum_size.y=48
	close.pressed.connect(hide)
	outer.add_child(close)

func show_recipes(total_xp: int, inventory, busy: bool, editing: bool = false, purchased: Array[String] = [], queue_full: bool = false) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	_add_text("Витрина: %d / %d · в работе: %d" % [inventory.total(), inventory.CAPACITY, inventory.reserved_count], false, 22)
	var level := Catalog.level_for_xp(total_xp)
	for recipe in Catalog.RECIPES:
		if recipe.level > level:
			_add_text("%s · уровень %d · нужно %d опыта" % [recipe.title, recipe.level, Catalog.LEVEL_XP[recipe.level - 1]], true)
			continue
		var missing := Equipment.missing(recipe, purchased)
		_add_text("%s · в витрине %d шт.\nПартия %d шт. · продажа за %d\n%s" % [recipe.title, inventory.count_of(recipe.id), recipe.batch, recipe.price,Catalog.route_title(recipe.id)])
		if not missing.is_empty():
			_add_text("Нужно купить: " + Equipment.missing_titles(recipe, purchased), true)
		var row := HBoxContainer.new()
		list.add_child(row)
		var bake := Button.new()
		bake.text = "В очередь · %d шт." % recipe.batch
		bake.custom_minimum_size.y = 44
		bake.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bake.disabled = editing or queue_full or not missing.is_empty()
		bake.pressed.connect(func(): hide(); production_requested.emit(recipe.id))
		row.add_child(bake)
		if not missing.is_empty():
			var shop := Button.new()
			shop.text = "Оборудование"
			shop.pressed.connect(func(): shop_requested.emit())
			row.add_child(shop)
		var discard := Button.new()
		discard.text = "Списать 1 шт."
		discard.disabled = editing or inventory.count_of(recipe.id) == 0
		discard.pressed.connect(func(): discard_requested.emit(recipe.id))
		row.add_child(discard)
	_add_text("Место резервируется при начале партии.\nПорядок партий меняется в окне «Очередь».")
	popup_centered(Vector2i(540, 480))

func _add_text(value: String, muted: bool = false, font_size: int = 17) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 450
	label.size.x = 450
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("888b80") if muted else Color("344b3f"))
	list.add_child(label)
