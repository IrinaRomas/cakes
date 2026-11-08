extends Control

signal oven_pressed
signal register_pressed
signal display_pressed
signal layout_changed
signal hint_changed(message: String)
const Equipment = preload("res://equipment_catalog.gd")
const CELLS := 6
const FLOOR_SLOPE := 0.5
const TITLES := ["Печь", "Витрина", "Стол с миксером", "Касса", "Формовочный стол", "Стол декора", "Холодильник", "Витрина", "Место помощника"]
var cells: Array[Vector2i] = [Vector2i(1, 1), Vector2i(3, 3), Vector2i(4, 1), Vector2i(4, 3), Vector2i(1,3), Vector2i(2,1),Vector2i(5,1),Vector2i(1,4),Vector2i(0,2)]
var owned_equipment: Array[String] = ["register"]
var editing := false
var selected := -1
var objects: Array[Node2D] = []
var service: Node2D
var chef_move_speed:=2.2
var unit := 48.0
var origin := Vector2.ZERO
var display_badge: Label
var play_area := Rect2()
var wide_camera := false
var overview := false
var pan_offset := Vector2.ZERO
var camera_focus_y := 2.0
var camera_initialized := false
var pointer_down := false
var pointer_travel := Vector2.ZERO
var dragged := false
var interaction_blocked := false
var extra_stock_visual: Node2D
var extra_display_badge: Label
var assistant: Node2D
var helper_enabled:=false
var assistant_active:=false
var stock_visual: Node2D
var work_markers: Array[Control]=[]
var work_labels: Array[Label]=[]
var work_meters: Array[ProgressBar]=[]

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sheet: Texture2D = preload("res://assets/equipment_isometric.png")
	for i in range(3):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * sheet.get_width() / 3.0, 0, sheet.get_width() / 3.0, sheet.get_height())
		if i==1:
			atlas.atlas=preload("res://assets/cold_display.png")
			atlas.region=Rect2(0,0,atlas.atlas.get_width()/2.0,atlas.atlas.get_height())
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
	var workstations: Texture2D = preload("res://assets/workstations.png")
	for i in range(2):
		var atlas := AtlasTexture.new()
		atlas.atlas = workstations
		atlas.region = Rect2(i * workstations.get_width() / 2.0, 0, workstations.get_width() / 2.0, workstations.get_height())
		var station := preload("res://equipment.gd").new()
		station.name = ["FormingTable", "DecoratingTable"][i]
		station.setup(atlas, i+4, TITLES[i+4])
		station.pressed.connect(_select.bind(i+4))
		add_child(station)
		objects.append(station)
	var cold: Texture2D=preload("res://assets/cold_display.png")
	var fridge_atlas:=AtlasTexture.new()
	fridge_atlas.atlas=cold
	fridge_atlas.region=Rect2(cold.get_width()/2.0,0,cold.get_width()/2.0,cold.get_height())
	var fridge:=preload("res://equipment.gd").new()
	fridge.name="Fridge"
	fridge.setup(fridge_atlas,6,TITLES[6])
	fridge.pressed.connect(_select.bind(6))
	add_child(fridge)
	objects.append(fridge)
	stock_visual=preload("res://display_contents.gd").new()
	objects[1].add_child(stock_visual)
	var extra:=preload("res://equipment.gd").new()
	extra.name="SecondDisplay"
	extra.setup(objects[1].button.texture_normal,1,TITLES[7])
	extra.pressed.connect(_select.bind(7))
	add_child(extra)
	objects.append(extra)
	extra_stock_visual=preload("res://display_contents.gd").new()
	extra.add_child(extra_stock_visual)
	var assistant_table:=preload("res://equipment.gd").new()
	assistant_table.name="AssistantStation"
	assistant_table.setup(objects[4].button.texture_normal,4,TITLES[8])
	assistant_table.pressed.connect(_select.bind(8))
	add_child(assistant_table)
	objects.append(assistant_table)
	assistant=preload("res://chef.gd").new()
	add_child(assistant)
	assistant.visible=false
	_create_work_markers()
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
	extra_display_badge=display_badge.duplicate()
	add_child(extra_display_badge)
	resized.connect(_arrange)
	_arrange()

func project(cell: Vector2) -> Vector2:
	return origin + Vector2((cell.x - cell.y) * unit, (cell.x + cell.y) * unit * FLOOR_SLOPE)

func _arrange() -> void:
	if size.x < 1 or size.y < 1:
		return
	var area := play_area if play_area.has_area() else Rect2(Vector2.ZERO, size)
	if wide_camera and not overview:
		unit = size.x / 12.4
	else:
		unit = minf(size.x / 13.2, area.size.y / 8.8)
	pan_offset.x = clampf(pan_offset.x, -unit * 4, unit * 4)
	pan_offset.y = clampf(pan_offset.y, -unit * 5, unit * 5)
	var focus := camera_focus_y if wide_camera and not overview else 2.0
	origin = Vector2(size.x * 0.5, area.get_center().y - focus * unit) + pan_offset
	for i in range(objects.size()):
		objects[i].visible = is_owned(i)
		objects[i].fit_to_grid(project(Vector2(cells[i]) + Vector2(0.5, 0.5)), unit, FLOOR_SLOPE)
		objects[i].z_index = cells[i].x + cells[i].y + 1
		objects[i].modulate = Color("c7e6b3") if selected == i else Color.WHITE
	_update_chef()
	_position_assistant()
	if service!=null: service.refresh_positions()
	_position_badge()
	_position_work_markers()
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
	editing=value
	chef.set_process(not value)
	assistant.set_process(not value)
	customer.set_process(not value)
	if service!=null:
		service.cashier.set_process(not value)
		for item in service.customers: item.node.set_process(not value)
		if not value: service.resume_layout()
	if not value: _resume_chef_route()
	selected=-1
	_arrange()

func _resume_chef_route() -> void:
	if not walking: return
	if route_station>=0:
		route=station_path(route_station,Vector2i(chef_position.round()))
	else:
		route.clear()
		walking=false
		chef.walking=false

func _select(index: int) -> void:
	if dragged or not is_owned(index):
		return
	if editing:
		selected = index
		_arrange()
		hint_changed.emit("%s: нажми на свободную клетку" % TITLES[index])
	elif index in [1,7]:
		display_pressed.emit()
	elif index == 3:
		register_pressed.emit()
	else:
		oven_pressed.emit()

func _gui_input(event: InputEvent) -> void:
	if not editing or selected < 0 or dragged:
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var offset: Vector2 = event.position - origin
		var cell := Vector2i(floori((offset.x / unit + offset.y / (unit * FLOOR_SLOPE)) * 0.5), floori((offset.y / (unit * FLOOR_SLOPE) - offset.x / unit) * 0.5))
		if cell.x < 0 or cell.y < 0 or cell.x >= CELLS or cell.y >= CELLS:
			return
		for i in range(cells.size()):
			if i != selected and is_owned(i) and cells[i] == cell:
				hint_changed.emit("Эта клетка занята. Выбери другую.")
				return
		if service!=null and service.actor_at(cell):
			hint_changed.emit("Здесь стоит человек. Выбери свободную клетку.")
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
var route_station:=-1
var walking := false
var busy := false
signal arrived

func _process(delta: float) -> void:
	if editing: return
	if walking and route.is_empty() and route_station>=0:
		route=station_path(route_station,Vector2i(chef_position.round()))
	if service==null: _customer_step(delta)
	if walking and not route.is_empty():
		if service!=null and service.is_cell_blocked(route[0]):
			if chef_position.is_equal_approx(chef_position.round()):
				var alternative:=find_path(Vector2i(chef_position.round()),route.back())
				if not alternative.is_empty(): route=alternative
			_update_chef()
			return
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
		chef_position = chef_position.move_toward(target, delta * chef_move_speed)
		if chef_position.distance_to(target) < 0.001:
			chef_position = target
			route.pop_front()
			if route.is_empty():
				walking = false
				chef.walking = false
				route_station=-1
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
			if next.x < 0 or next.y < 0 or next.x >= CELLS or next.y >= CELLS or is_occupied(next) or next == blocked or previous.has(next) or (service!=null and service.is_cell_blocked(next)):
				continue
			previous[next] = current
			frontier.append(next)
	return []

func station_path(index: int, start: Vector2i) -> Array[Vector2i]:
	if not is_owned(index):
		return []
	var best: Array[Vector2i] = []
	for direction in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]:
		var goal: Vector2i = cells[index] + direction
		if customer_state != "absent" and goal == customer_target:
			continue
		if is_occupied(goal) or goal.x < 0 or goal.y < 0 or goal.x >= CELLS or goal.y >= CELLS:
			continue
		if goal == start:
			return [start]
		var blocked := customer_target if customer_state != "absent" else Vector2i(-99, -99)
		var path := find_path(start, goal, blocked)
		if not path.is_empty() and (best.is_empty() or path.size() < best.size()):
			best = path
	return best

func can_complete_order(stations: Array = [2,0,1]) -> bool:
	var start := Vector2i(chef_position.round())
	for station in stations:
		var path := station_path(station, start)
		if path.is_empty():
			return false
		start = path.back()
	return true

func walk_to_station(index: int) -> bool:
	route_station=index
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
	if recipe_pool.is_empty():
		pause_customers()

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
	var index:=7 if is_owned(7) and current_recipe_id not in stock_visual.contents and current_recipe_id in extra_stock_visual.contents else 1
	return _pickup_path_at(start,index)

func _pickup_path_at(start: Vector2i, index: int) -> Array[Vector2i]:
	for direction in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]:
		var goal: Vector2i = cells[index] + direction
		if not _inside(goal) or is_occupied(goal) or goal == Vector2i(chef_position.round()):
			continue
		if walking and not route.is_empty() and goal == route.back():
			continue
		var path: Array[Vector2i] = [start] if start == goal else find_path(start, goal, Vector2i(chef_position.round()))
		if path.is_empty():
			continue
		var old_target := customer_target
		customer_target = goal
		var reachable := can_complete_order([2,0,index])
		customer_target = old_target
		if reachable:
			return path
	return []

func _spawn_customer() -> void:
	if recipe_pool.is_empty() or not is_owned(1) or not is_owned(3):
		return
	if walking:
		customer_delay = 0.4
		return
	# Plan both stages before admitting a visitor: register, then display.
	for direction in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]:
		var goal: Vector2i = cells[3] + direction
		if not _inside(goal) or is_occupied(goal) or goal == Vector2i(chef_position.round()):
			continue
		for edge in range(CELLS - 1, -1, -1):
			var entry := Vector2i(edge, CELLS - 1)
			if is_occupied(entry) or entry == goal or entry == Vector2i(chef_position.round()):
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

func finish_customer(paid: bool = true) -> void:
	if customer_state != "waiting":
		return
	customer_state = "leaving"
	customer.waiting = false
	customer.paid = paid
	customer.walking = true
	customer_route = find_path(Vector2i(customer_position.round()), customer_entry, Vector2i(chef_position.round()))
	if customer_route.is_empty():
		customer_route = find_path(Vector2i(customer_position.round()), customer_entry)
	customer_changed.emit()

func pause_customers() -> void:
	if service!=null: service.clear_customers()
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
		if i >= 3 and (not data.has_section_key("layout", str(i)) or cell in loaded):
			cell = _free_register_cell(loaded)
		if not cell is Vector2i or not _inside(cell) or cell in loaded:
			return
		loaded.append(cell)
	cells = loaded
	if is_occupied(Vector2i(chef_position)):
		for x in range(CELLS):
			for y in range(CELLS):
				if not is_occupied(Vector2i(x, y)):
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
	display_badge.visible = is_owned(1)
	display_badge.text = "%d / %d шт." % [count, capacity]
	display_badge.reset_size()
	_position_badge()

func _position_badge() -> void:
	if display_badge != null:
		display_badge.position = project(Vector2(cells[1]) + Vector2(0.5, 0.5)) - Vector2(display_badge.size.x * 0.5, unit * 1.25)
	if extra_display_badge != null:
		extra_display_badge.position=project(Vector2(cells[7])+Vector2(0.5,0.5))-Vector2(extra_display_badge.size.x*0.5,unit*1.25)

func set_viewport_layout(area: Rect2, wide: bool) -> void:
	if not camera_initialized or wide_camera != wide:
		pan_offset = Vector2.ZERO
		var minimum := INF
		var maximum := -INF
		for i in range(cells.size()):
			if not is_owned(i):
				continue
			var cell := cells[i]
			var ground_y := (cell.x + cell.y + 1) * FLOOR_SLOPE
			minimum = minf(minimum, ground_y - 2.2)
			maximum = maxf(maximum, ground_y + 0.4)
		camera_focus_y = (minimum + maximum) * 0.5
		camera_initialized = true
	play_area = area
	wide_camera = wide
	_arrange()

func toggle_overview() -> void:
	overview = not overview
	pan_offset = Vector2.ZERO
	_arrange()

func _input(event: InputEvent) -> void:
	if interaction_blocked:
		pointer_down = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_down = play_area.has_point(get_global_transform().affine_inverse() * event.position)
			pointer_travel = Vector2.ZERO
			dragged = false
		else:
			pointer_down = false
	elif event is InputEventMouseMotion and pointer_down:
		pointer_travel += event.relative
		if pointer_travel.length() > 8:
			dragged = true
			pan_offset += event.relative
			_arrange()
			get_viewport().set_input_as_handled()

func is_owned(index: int) -> bool:
	return index >= 0 and index < Equipment.IDS.size() and Equipment.IDS[index] in owned_equipment

func is_equipment_at(cell: Vector2i) -> bool:
	for i in range(cells.size()):
		if is_owned(i) and cells[i] == cell:
			return true
	return false

func apply_purchases(ids: Array[String]) -> void:
	owned_equipment = ids.duplicate()
	for i in range(objects.size()):
		objects[i].visible = is_owned(i)
	display_badge.visible = is_owned(1)
	extra_display_badge.visible=is_owned(7)
	camera_initialized = false
	_arrange()

func prepare_purchase(index: int) -> bool:
	var candidates: Array[Vector2i] = [cells[index]]
	for x in range(CELLS):
		for y in range(CELLS):
			candidates.append(Vector2i(x,y))
	for cell in candidates:
		if service!=null and (service.is_cell_blocked(cell) or cell==service._register_cell()): continue
		if is_occupied(cell) or cell == Vector2i(chef_position.round()):
			continue
		if customer_state != "absent" and (cell == Vector2i(customer_position.round()) or cell == customer_target or cell in customer_route):
			continue
		cells[index] = cell
		return true
	return false

func update_display_inventory(stock: Dictionary, total_capacity: int) -> void:
	var first: Dictionary={}
	var second: Dictionary={}
	var slots:=total_capacity/maxi(1,Equipment.display_count(owned_equipment))
	var space:=slots
	var total:=0
	for id in preload("res://display_inventory.gd").IDS:
		var count:=int(stock.get(id,0))
		first[id]=mini(count,space)
		second[id]=count-int(first[id])
		space-=int(first[id])
		total+=count
	stock_visual.set_stock(first,slots)
	extra_stock_visual.set_stock(second,slots)
	update_display_stock(mini(total,slots),slots)
	extra_display_badge.visible=is_owned(7)
	extra_display_badge.text="%d / %d шт." % [maxi(0,total-slots),slots]
	extra_display_badge.reset_size()
	_position_badge()

func _create_work_markers() -> void:
	for i in range(objects.size()):
		var marker:=PanelContainer.new()
		marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
		marker.z_index=95
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("fff9ed")
		style.set_corner_radius_all(7)
		style.set_content_margin_all(5)
		marker.add_theme_stylebox_override("panel",style)
		var box:=VBoxContainer.new()
		box.mouse_filter=Control.MOUSE_FILTER_IGNORE
		marker.add_child(box)
		var label:=Label.new()
		label.add_theme_font_size_override("font_size",13)
		label.add_theme_color_override("font_color",Color("344b3f"))
		box.add_child(label)
		var meter:=ProgressBar.new()
		meter.custom_minimum_size=Vector2(110,7)
		meter.mouse_filter=Control.MOUSE_FILTER_IGNORE
		meter.max_value=1
		meter.show_percentage=false
		box.add_child(meter)
		add_child(marker)
		marker.hide()
		work_markers.append(marker)
		work_labels.append(label)
		work_meters.append(meter)

func show_work_status(index: int, text: String, fraction: float) -> void:
	if index<0 or index>=work_markers.size(): return
	work_labels[index].text=text
	work_meters[index].value=fraction
	work_markers[index].visible=is_owned(index)
	_position_work_markers()

func clear_work_status(index: int) -> void:
	if index>=0 and index<work_markers.size(): work_markers[index].hide()

func _position_work_markers() -> void:
	for i in range(work_markers.size()):
		work_markers[i].reset_size()
		var at:=project(Vector2(cells[i])+Vector2(0.5,0.5))-Vector2(work_markers[i].size.x/2,unit*1.8)
		var area:=play_area if play_area.has_area() else Rect2(Vector2.ZERO,size)
		at.x=clampf(at.x,area.position.x+4,maxf(area.position.x+4,area.end.x-work_markers[i].size.x-4))
		at.y=clampf(at.y,area.position.y+4,maxf(area.position.y+4,area.end.y-work_markers[i].size.y-4))
		work_markers[i].position=at

func set_assistant_work(active: bool, recipe: String="croissant", quantity: int=0) -> void:
	assistant_active=active
	assistant.working=active
	assistant.carrying=not active and quantity>0
	assistant.carrying_dough=true
	assistant.carried_recipe=recipe
	assistant.carried_count=quantity
	_position_assistant()

func _position_assistant() -> void:
	if assistant==null: return
	assistant.visible=is_owned(8) and helper_enabled
	assistant.unit=unit
	assistant.position=project(Vector2(cells[8])+Vector2(0.5,1.3))
	assistant.z_index=cells[8].x+cells[8].y+2

func is_occupied(cell: Vector2i) -> bool:
	return is_equipment_at(cell)

func park_chef() -> void:
	if service==null or walking or service.using_chef: return
	for goal in [Vector2i(2,2),Vector2i(1,2),Vector2i(3,1),Vector2i(1,0),Vector2i(0,1)]:
		if is_equipment_at(goal) or service.is_cell_blocked(goal) or goal==service._register_cell(): continue
		if Vector2i(chef_position.round())==goal: return
		var path:=find_path(Vector2i(chef_position.round()),goal)
		if path.is_empty(): continue
		route_station=-1
		route=path
		walking=true
		chef.walking=true
		return
