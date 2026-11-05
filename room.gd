extends Control

signal oven_pressed
signal register_pressed
signal display_pressed
signal layout_changed
signal hint_changed(message: String)
const CELLS := 6
const FLOOR_SLOPE := 0.5
const TITLES := ["Печь", "Витрина", "Стол с миксером", "Касса"]
var cells: Array[Vector2i] = [Vector2i(1, 1), Vector2i(3, 3), Vector2i(4, 1), Vector2i(4, 3)]
var editing := false
var selected := -1
var objects: Array[Node2D] = []
var unit := 48.0
var origin := Vector2.ZERO
var display_badge: Label

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sheet: Texture2D = preload("res://assets/equipment_isometric.png")
	for i in range(3):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * sheet.get_width() / 3.0, 0, sheet.get_width() / 3.0, sheet.get_height())
		var item := preload("res://equipment.gd").new()
		item.name = ["Oven", "Display", "MixerTable"][i]
		item.setup(atlas, i, TITLES[i])
		item.pressed.connect(_select.bind(i))
		add_child(item)
		objects.append(item)
	var register := preload("res://equipment.gd").new()
	register.name = "Register"
	register.setup(preload("res://assets/register.png"), 3, TITLES[3])
	register.pressed.connect(_select.bind(3))
	add_child(register)
	objects.append(register)
	chef = preload("res://chef.gd").new()
	chef.name = "PastryChef"
	add_child(chef)
	customer = preload("res://customer.gd").new()
	customer.name = "Customer"
	add_child(customer)
	customer.visible = false
	display_badge = Label.new()
	display_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	display_badge.z_index = 100
	display_badge.add_theme_font_size_override("font_size", 14)
	display_badge.add_theme_color_override("font_color", Color("344b3f"))
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("fff9ed")
	badge_style.set_corner_radius_all(7)
	badge_style.content_margin_left = 7
	badge_style.content_margin_right = 7
	display_badge.add_theme_stylebox_override("normal", badge_style)
	add_child(display_badge)
	resized.connect(_arrange)
	_arrange()

func project(cell: Vector2) -> Vector2:
	return origin + Vector2((cell.x - cell.y) * unit, (cell.x + cell.y) * unit * FLOOR_SLOPE)

func _arrange() -> void:
	unit = minf(size.x / 13.5, size.y / 10.0)
	origin = Vector2(size.x * 0.5, (size.y - 6.0 * unit) * 0.5 + unit)
	for i in range(objects.size()):
		objects[i].fit_to_grid(project(Vector2(cells[i]) + Vector2(0.5, 0.5)), unit, FLOOR_SLOPE)
		objects[i].z_index = cells[i].x + cells[i].y + 1
		objects[i].modulate = Color("c7e6b3") if selected == i else Color.WHITE
	_update_chef()
	_position_badge()
	queue_redraw()

func _draw() -> void:
	var a := project(Vector2.ZERO)
	var b := project(Vector2(6, 0))
	var c := project(Vector2(6, 6))
	var d := project(Vector2(0, 6))
	var up := Vector2(0, -unit * 2.0)
	draw_colored_polygon(PackedVector2Array([a, b, b + up, a + up]), Color("e0d5c6"))
	draw_colored_polygon(PackedVector2Array([a, d, d + up, a + up]), Color("eee5d7"))
	draw_colored_polygon(PackedVector2Array([a, b, c, d]), Color("e7dac7"))
	for x in range(CELLS):
		for y in range(CELLS):
			var points := PackedVector2Array([project(Vector2(x,y)), project(Vector2(x+1,y)), project(Vector2(x+1,y+1)), project(Vector2(x,y+1))])
			if (x+y) % 2 == 0:
				draw_colored_polygon(points, Color("f0e6d7"))
			if editing:
				draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("b6bca9"), 1.0)

func set_editing(value: bool) -> void:
	if busy:
		return
	editing = value
	if value:
		pause_customers()
	selected = -1
	_arrange()

func _select(index: int) -> void:
	if editing:
		selected = index
		_arrange()
		hint_changed.emit("%s: нажми на свободную клетку" % TITLES[index])
	elif index == 1:
		display_pressed.emit()
	elif index == 3:
		register_pressed.emit()
	else:
		oven_pressed.emit()

func _gui_input(event: InputEvent) -> void:
	if not editing or selected < 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var offset: Vector2 = event.position - origin
		var cell := Vector2i(floori((offset.x / unit + offset.y / (unit * FLOOR_SLOPE)) * 0.5), floori((offset.y / (unit * FLOOR_SLOPE) - offset.x / unit) * 0.5))
		if cell.x < 0 or cell.y < 0 or cell.x >= CELLS or cell.y >= CELLS:
			return
		for i in range(cells.size()):
			if i != selected and cells[i] == cell:
				hint_changed.emit("Эта клетка занята. Выбери другую.")
				return
		if cell == Vector2i(chef_position.round()):
			hint_changed.emit("Здесь стоит кондитер. Выбери другую клетку.")
			return
		cells[selected] = cell
		selected = -1
		_arrange()
		layout_changed.emit()
		hint_changed.emit("Расстановка сохранена. Можно выбрать другой предмет.")

var chef: Node2D
var chef_position := Vector2(2, 4)
var route: Array[Vector2i] = []
var walking := false
var busy := false
signal arrived

func _process(delta: float) -> void:
	_customer_step(delta)
	if walking and not route.is_empty():
		if customer_state != "absent" and route[0] == Vector2i(customer_position.round()):
			if chef_position.is_equal_approx(chef_position.round()):
				var alternative := find_path(Vector2i(chef_position.round()), route.back(), Vector2i(customer_position.round()))
				if not alternative.is_empty():
					route = alternative
			_update_chef()
			return
		var target := Vector2(route[0])
		var direction := project(target) - project(chef_position)
		chef.facing_left = direction.x < 0 if absf(direction.x) > 0.01 else chef.facing_left
		chef_position = chef_position.move_toward(target, delta * 2.2)
		if chef_position.distance_to(target) < 0.001:
			chef_position = target
			route.pop_front()
			if route.is_empty():
				walking = false
				chef.walking = false
				arrived.emit()
	_update_chef()

func _update_chef() -> void:
	if chef == null:
		return
	chef.unit = unit
	chef.position = project(chef_position + Vector2(0.5, 0.5))
	chef.z_index = int(floorf(chef_position.x + chef_position.y)) + 1

func find_path(start: Vector2i, goal: Vector2i, blocked := Vector2i(-99, -99)) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [start]
	var previous := {start: start}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == goal:
			var path: Array[Vector2i] = []
			while current != start:
				path.push_front(current)
				current = previous[current]
			return path
		for direction in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]:
			var next: Vector2i = current + direction
			if next.x < 0 or next.y < 0 or next.x >= CELLS or next.y >= CELLS or next in cells or next == blocked or previous.has(next):
				continue
			previous[next] = current
			frontier.append(next)
	return []

func station_path(index: int, start: Vector2i) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	for direction in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]:
		var goal: Vector2i = cells[index] + direction
		if customer_state != "absent" and goal == customer_target:
			continue
		if goal in cells or goal.x < 0 or goal.y < 0 or goal.x >= CELLS or goal.y >= CELLS:
			continue
		if goal == start:
			return [start]
		var blocked := customer_target if customer_state != "absent" else Vector2i(-99, -99)
		var path := find_path(start, goal, blocked)
		if not path.is_empty() and (best.is_empty() or path.size() < best.size()):
			best = path
	return best

func can_complete_order() -> bool:
	var start := Vector2i(chef_position.round())
	for station in [2, 0, 1]:
		var path := station_path(station, start)
		if path.is_empty():
			return false
		start = path.back()
	return true

func walk_to_station(index: int) -> bool:
	route = station_path(index, Vector2i(chef_position.round()))
	if route.is_empty():
		return false
	walking = true
	chef.walking = true
	return true

signal customer_changed
var customer: Node2D
var customer_position := Vector2(5, 5)
var customer_target := Vector2i(5, 5)
var customer_entry := Vector2i(5, 5)
var customer_route: Array[Vector2i] = []
var customer_state := "absent"
var customer_delay := 1.5
var recipe_pool: Array[String] = ["croissant"]
var current_recipe_id := "croissant"
var pending_new_recipe := ""
var recipe_rotation := 0

func set_recipe_pool(ids: Array[String]) -> void:
	for id in ids:
		if id not in recipe_pool:
			pending_new_recipe = id
	recipe_pool = ids.duplicate()

func _choose_recipe() -> void:
	if not pending_new_recipe.is_empty() and pending_new_recipe in recipe_pool:
		current_recipe_id = pending_new_recipe
		pending_new_recipe = ""
	else:
		current_recipe_id = recipe_pool[recipe_rotation % recipe_pool.size()]
		recipe_rotation += 1
	customer.set_order(preload("res://recipes.gd").get_recipe(current_recipe_id))


func _customer_step(delta: float) -> void:
	if customer == null or editing:
		return
	if customer_state == "absent":
		customer_delay -= delta
		if customer_delay <= 0.0:
			_spawn_customer()
	elif customer_state in ["entering", "to_display", "leaving"]:
		if not customer_route.is_empty():
			var next_cell: Vector2i = customer_route[0]
			if next_cell == Vector2i(chef_position.round()) or (walking and not route.is_empty() and next_cell == route[0]):
				if customer_position.is_equal_approx(customer_position.round()):
					var destination := customer_entry if customer_state == "leaving" else customer_target
					var alternative := find_path(Vector2i(customer_position.round()), destination, Vector2i(chef_position.round()))
					if not alternative.is_empty():
						customer_route = alternative
				customer.walking = false
				return
			customer.walking = true
			var target := Vector2(customer_route[0])
			var direction := project(target) - project(customer_position)
			if absf(direction.x) > 0.01:
				customer.facing_left = direction.x > 0.0
			customer_position = customer_position.move_toward(target, delta * 1.8)
			if customer_position.distance_to(target) < 0.001:
				customer_position = target
				customer_route.pop_front()
		if customer_route.is_empty():
			customer.walking = false
			if customer_state == "entering":
				customer_state = "ordering"
				customer.waiting = true
			elif customer_state == "to_display":
				customer_state = "waiting"
				customer.waiting = true
			else:
				customer_state = "absent"
				customer.visible = false
				customer.paid = false
				customer_delay = 3.0
			customer_changed.emit()
	customer.unit = unit
	customer.position = project(customer_position + Vector2(0.5, 0.5))
	customer.z_index = int(floorf(customer_position.x + customer_position.y)) + 1

func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < CELLS and cell.y < CELLS

func pickup_path(start: Vector2i) -> Array[Vector2i]:
	for direction in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]:
		var goal: Vector2i = cells[1] + direction
		if not _inside(goal) or goal in cells or goal == Vector2i(chef_position.round()):
			continue
		if walking and not route.is_empty() and goal == route.back():
			continue
		var path: Array[Vector2i] = [start] if start == goal else find_path(start, goal, Vector2i(chef_position.round()))
		if path.is_empty():
			continue
		var old_target := customer_target
		customer_target = goal
		var reachable := can_complete_order()
		customer_target = old_target
		if reachable:
			return path
	return []

func _spawn_customer() -> void:
	if walking:
		customer_delay = 0.4
		return
	# Plan both stages before admitting a visitor: register, then display.
	for direction in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]:
		var goal: Vector2i = cells[3] + direction
		if not _inside(goal) or goal in cells or goal == Vector2i(chef_position.round()):
			continue
		for edge in range(CELLS - 1, -1, -1):
			var entry := Vector2i(edge, CELLS - 1)
			if entry in cells or entry == goal or entry == Vector2i(chef_position.round()):
				continue
			var path := find_path(entry, goal, Vector2i(chef_position.round()))
			if path.is_empty():
				continue
			customer_state = "entering"
			customer_target = goal
			if pickup_path(goal).is_empty():
				customer_state = "absent"
				continue
			customer_entry = entry
			customer_position = Vector2(entry)
			customer_route = path
			_choose_recipe()
			customer.visible = true
			customer.waiting = false
			customer.paid = false
			customer.walking = true
			customer_changed.emit()
			return
	customer_delay = 2.0
	hint_changed.emit("Освободи проход к кассе и витрине для покупателя.")

func accept_customer_order() -> bool:
	if editing or customer_state != "ordering":
		return false
	var path := pickup_path(Vector2i(customer_position.round()))
	if path.is_empty():
		hint_changed.emit("Нет прохода от кассы к витрине. Измени расстановку.")
		return false
	customer_target = path.back()
	customer_route = path
	customer_state = "to_display"
	customer.waiting = false
	customer.walking = true
	customer_changed.emit()
	return true

func finish_customer() -> void:
	if customer_state != "waiting":
		return
	customer_state = "leaving"
	customer.waiting = false
	customer.paid = true
	customer.walking = true
	customer_route = find_path(Vector2i(customer_position.round()), customer_entry, Vector2i(chef_position.round()))
	if customer_route.is_empty():
		customer_route = find_path(Vector2i(customer_position.round()), customer_entry)
	customer_changed.emit()

func pause_customers() -> void:
	customer_state = "absent"
	customer_route.clear()
	customer.visible = false
	customer.waiting = false
	customer.paid = false
	customer_delay = 1.5

func restore_layout(data: ConfigFile) -> void:
	var loaded: Array[Vector2i] = []
	for i in range(cells.size()):
		var cell = data.get_value("layout", str(i), cells[i])
		if i == 3 and (not data.has_section_key("layout", "3") or cell in loaded):
			cell = _free_register_cell(loaded)
		if not cell is Vector2i or not _inside(cell) or cell in loaded:
			return
		loaded.append(cell)
	cells = loaded
	if Vector2i(chef_position) in cells:
		for x in range(CELLS):
			for y in range(CELLS):
				if Vector2i(x, y) not in cells:
					chef_position = Vector2(x, y)
					_arrange()
					return
	_arrange()

func _free_register_cell(occupied: Array[Vector2i]) -> Vector2i:
	for cell in [Vector2i(4,3), Vector2i(4,4), Vector2i(3,4), Vector2i(2,3)]:
		if cell not in occupied and cell != Vector2i(chef_position.round()):
			return cell
	for x in range(CELLS):
		for y in range(CELLS):
			var cell := Vector2i(x,y)
			if cell not in occupied and cell != Vector2i(chef_position.round()):
				return cell
	return Vector2i.ZERO

func update_display_stock(count: int, capacity: int) -> void:
	if display_badge == null:
		return
	display_badge.text = "%d / %d шт." % [count, capacity]
	display_badge.reset_size()
	_position_badge()

func _position_badge() -> void:
	if display_badge != null:
		display_badge.position = project(Vector2(cells[1]) + Vector2(0.5, 0.5)) - Vector2(display_badge.size.x * 0.5, unit * 2.5)
