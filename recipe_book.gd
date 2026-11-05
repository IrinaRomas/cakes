extends PopupPanel

signal production_requested(id: String)
signal discard_requested(id: String)
const Catalog = preload("res://recipes.gd")
var list: VBoxContainer

func _ready() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("f5f1e9")
	panel.border_color = Color("a5b59a")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(12)
	add_theme_stylebox_override("panel", panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	margin.add_child(list)

func show_recipes(total_xp: int, inventory, busy: bool, editing: bool = false) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	_add_text("Витрина: %d / %d · в работе: %d" % [inventory.total(), inventory.CAPACITY, inventory.reserved_count], false, 22)
	var level := Catalog.level_for_xp(total_xp)
	for recipe in Catalog.RECIPES:
		if recipe.level > level:
			_add_text("%s · уровень %d · нужно %d опыта" % [recipe.title, recipe.level, Catalog.LEVEL_XP[recipe.level - 1]], true)
			continue
		_add_text("%s · в витрине %d шт.\nПартия %d шт. · %d сек. выпечки · продажа за %d" % [recipe.title, inventory.count_of(recipe.id), recipe.batch, recipe.bake, recipe.price])
		var row := HBoxContainer.new()
		list.add_child(row)
		var bake := Button.new()
		bake.text = "Выпечь %d шт." % recipe.batch
		bake.custom_minimum_size.y = 44
		bake.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bake.disabled = busy or editing or not inventory.can_fit(recipe.batch)
		bake.pressed.connect(func(): hide(); production_requested.emit(recipe.id))
		row.add_child(bake)
		var discard := Button.new()
		discard.text = "Списать 1 шт."
		discard.disabled = editing or inventory.count_of(recipe.id) == 0
		discard.pressed.connect(func(): discard_requested.emit(recipe.id))
		row.add_child(discard)
	_add_text("Место под партию резервируется заранее.\nМонеты и опыт начисляются за проданные изделия.")
	var close := Button.new()
	close.text = "Вернуться в кондитерскую"
	close.custom_minimum_size.y = 44
	close.pressed.connect(hide)
	list.add_child(close)
	popup_centered(Vector2i(540, 480))

func _add_text(value: String, muted: bool = false, font_size: int = 17) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 450
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("888b80") if muted else Color("344b3f"))
	list.add_child(label)
