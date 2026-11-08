extends Node2D
const Progression=preload("res://progression.gd")
const Catalog=preload("res://recipes.gd")
const DIRECTIONS=[Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]
var room: Control
var game: Control
var customers: Array[Dictionary]=[]
var cashier: Node2D
var cashier_position:=Vector2(4,2)
var cashier_route: Array[Vector2i]=[]
var cashier_goal:=Vector2i(4,2)
var cashier_phase:="idle"
var task_id:=-1
var task_remaining:=0.0
var task_duration:=1.0
var level:=1
var cashier_hired:=false
var cashier_enabled:=false
var using_chef:=false
var chef_shift_elapsed:=0.0
var queue_wait_seconds:=45.0
var capacity:=1
var arrival_remaining:=1.5
var arrival_interval:=4.0
var next_id:=1
var recipe_rotation:=0
var status:="Ждёт покупателей"
var walking_speed:=2.4
var work_factor:=1.0
var served:=0
var left_unserved:=0

func setup(owner_game: Control, owner_room: Control) -> void:
	game=owner_game
	room=owner_room
	var post:=_register_cell()
	if post.x>=0:
		cashier_position=Vector2(post)
		cashier_goal=post
	cashier=preload("res://cashier.gd").new()
	add_child(cashier)
	refresh_positions()

func configure(purchased: Array[String], current_level: int=1, hired: bool=false) -> void:
	cashier_hired=hired
	level=current_level
	capacity=Progression.buyers(level)
	arrival_interval=Progression.arrival_seconds(level)
	queue_wait_seconds=60.0 if "staff_tasks" in purchased else 45.0
	var was_enabled:=cashier_enabled
	if not using_chef: cashier_enabled=level>=4 and cashier_hired
	if cashier_enabled and not was_enabled and cashier!=null: relocate_cashier()
	if cashier!=null: cashier.visible=cashier_enabled and not room.editing
	walking_speed=3.36 if "staff_walk" in purchased else 2.4
	work_factor=0.75 if "staff_work" in purchased else 1.0

func active_count() -> int:
	var count:=0
	for item in customers:
		if item.state!="leaving": count+=1
	return count

func queue_items() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for item in customers:
		if item.state in ["queue","counter"]: result.append(item)
	return result

func _process(delta: float) -> void:
	if room==null or cashier==null: return
	cashier.visible=cashier_enabled and room.is_owned(3)
	if room.editing: return
	if not room.is_owned(1) or not room.is_owned(3) or room.recipe_pool.is_empty():
		status="Для обслуживания нужны касса, витрина и кухня"
		return
	arrival_remaining-=delta
	if arrival_remaining<=0:
		arrival_remaining=arrival_interval
		spawn_customer()
	_update_queue_goals()
	for item in customers.duplicate():
		if item.state!="leaving":
			item.wait_left=maxf(0,float(item.wait_left)-delta)
			if float(item.wait_left)<=0:
				leave(item,false)
		if item.get("needs_pickup_route",false):
			var patience: float=item.wait_left
			if _send_to_display(item): item.needs_pickup_route=false
			item.wait_left=patience
		_move_customer(item,delta)
	if cashier_enabled:
		_step_cashier(delta)
	elif _chef_can_serve():
		if not using_chef: _borrow_chef()
		chef_shift_elapsed+=delta
		_step_cashier(delta)
		room.chef_position=cashier_position
		room.chef.walking=cashier.walking
		room.chef.working=cashier.working
		room.chef.facing_left=cashier.facing_left
		room._update_chef()
		if cashier_phase=="idle" or chef_shift_elapsed>12.0: _release_chef()
	else:
		status="Готовит; обслуживание позже" if game.busy else "Ждёт гостя"
	refresh_positions()

func _register_cell() -> Vector2i:
	for direction in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
		var cell: Vector2i=room.cells[3]+direction
		if room._inside(cell) and not room.is_equipment_at(cell): return cell
	return Vector2i(-1,-1)

func _queue_cells() -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	var staff_cell:=_register_cell()
	for direction in DIRECTIONS:
		var cell: Vector2i=room.cells[3]+direction
		if room._inside(cell) and not room.is_equipment_at(cell) and cell!=staff_cell:
			result.append(cell)
			break
	if result.is_empty(): return result
	var front: Vector2i=result[0]
	var frontier: Array[Vector2i]=[front]
	var seen: Dictionary={front:true}
	while not frontier.is_empty() and result.size()<capacity:
		var current: Vector2i=frontier.pop_front()
		if current!=front:
			var spaced:=true
			for other in result:
				if absi(current.x-other.x)+absi(current.y-other.y)<2: spaced=false
			if spaced: result.append(current)
		for direction in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			var next: Vector2i=current+direction
			if seen.has(next) or not room._inside(next) or next.y<front.y or next==staff_cell or room.is_equipment_at(next): continue
			seen[next]=true
			frontier.append(next)
	return result

func spawn_customer(recipe_id: String="") -> bool:
	if customers.size()>=capacity or room.recipe_pool.is_empty(): return false
	var waiting:=queue_items()
	var cells:=_queue_cells()
	if waiting.size()>=cells.size():
		status="Освободи место для очереди у кассы"
		return false
	var goal: Vector2i=cells[waiting.size()]
	var path: Array[Vector2i]=[]
	var entry:=Vector2i(-1,-1)
	for x in range(5,-1,-1):
		var candidate:=Vector2i(x,5)
		if _blocked(candidate,-1,false): continue
		path=_path(candidate,goal,-1,false)
		if not path.is_empty():
			entry=candidate
			break
	if entry.x<0:
		status="Освободи вход и проход к кассе"
		if not game.busy: room.park_chef()
		return false
	if recipe_id.is_empty():
		recipe_id=room.recipe_pool[recipe_rotation%room.recipe_pool.size()]
		recipe_rotation+=1
	if not Catalog.has_recipe(recipe_id): return false
	var actor=preload("res://customer.gd").new()
	add_child(actor)
	actor.set_order(Catalog.get_recipe(recipe_id))
	actor.bubble.add_theme_font_size_override("font_size",13)
	actor.bubble.z_as_relative=false
	actor.bubble.z_index=120
	actor.modulate=[Color.WHITE,Color("eee5dc"),Color("dfe8ee")][(next_id-1)%capacity]
	var item: Dictionary={"id":next_id,"recipe":recipe_id,"state":"queue","pos":Vector2(entry),"goal":goal,"entry":entry,"route":path,"wait_left":queue_wait_seconds,"node":actor,"paid":false,"blocked":0.0}
	next_id+=1
	customers.append(item)
	refresh_positions()
	return true

func _update_queue_goals() -> void:
	var waiting:=queue_items()
	var cells:=_queue_cells()
	for index in range(mini(waiting.size(),cells.size())):
		var item: Dictionary=waiting[index]
		if item.state=="counter": continue
		if item.goal!=cells[index]:
			item.goal=cells[index]
			item.route=_path(Vector2i(item.pos.round()),item.goal,item.id,false)
		if index==0 and Vector2(item.pos).distance_to(Vector2(item.goal))<0.01:
			item.state="counter"
			item.route=[]

func _blocked(cell: Vector2i, except_id: int, for_cashier: bool) -> bool:
	if not room._inside(cell) or room.is_equipment_at(cell): return true
	if not (for_cashier and using_chef) and cell==Vector2i(room.chef_position.round()): return true
	if not (for_cashier and using_chef) and room.walking and not room.route.is_empty() and (cell==room.route[0] or cell==room.route.back()): return true
	if not for_cashier and (cell==Vector2i(cashier_position.round()) or (not cashier_route.is_empty() and cell==cashier_goal)): return true
	for other in customers:
		if int(other.id)==except_id: continue
		if cell==Vector2i(other.pos.round()): return true
		if other.state!="leaving" and cell==other.goal: return true
	return false

func is_cell_blocked(cell: Vector2i) -> bool:
	if room.editing: return false
	if cashier!=null and cashier.visible and (cell==Vector2i(cashier_position.round()) or (not cashier_route.is_empty() and cell==cashier_goal)): return true
	for item in customers:
		if cell==Vector2i(item.pos.round()) or (item.state!="leaving" and cell==item.goal): return true
	return false

func _path(start: Vector2i, goal: Vector2i, except_id: int, for_cashier: bool) -> Array[Vector2i]:
	var frontier: Array[Vector2i]=[start]
	var previous: Dictionary={start:start}
	while not frontier.is_empty():
		var cell: Vector2i=frontier.pop_front()
		if cell==goal:
			var result: Array[Vector2i]=[]
			while cell!=start:
				result.push_front(cell)
				cell=previous[cell]
			if result.is_empty(): result.append(start)
			return result
		for direction in DIRECTIONS:
			var next: Vector2i=cell+direction
			if previous.has(next) or _blocked(next,except_id,for_cashier): continue
			previous[next]=cell
			frontier.append(next)
	var empty: Array[Vector2i]=[]
	return empty

func _move_customer(item: Dictionary, delta: float) -> void:
	var path: Array=item.route
	var actor: Node2D=item.node
	if path.is_empty() and item.state in ["queue","to_display","leaving"] and Vector2(item.pos).distance_to(Vector2(item.goal))>0.01:
		if item.state=="leaving": _route_to_exit(item)
		else: item.route=_path(Vector2i(item.pos.round()),item.goal,item.id,false)
		path=item.route
	actor.walking=not path.is_empty()
	if not path.is_empty():
		var next: Vector2i=path[0]
		if _blocked(next,item.id,false):
			if Vector2(item.pos).is_equal_approx(Vector2(item.pos).round()):
				if item.state=="leaving": _route_to_exit(item)
				else: item.route=_path(Vector2i(item.pos.round()),item.goal,item.id,false)
			actor.walking=false
			return
		actor.facing_left=room.project(Vector2(next)).x>room.project(item.pos).x
		item.pos=Vector2(item.pos).move_toward(Vector2(next),delta*1.8)
		if Vector2(item.pos).distance_to(Vector2(next))<0.001:
			item.pos=Vector2(next)
			path.pop_front()
	if Vector2(item.pos).distance_to(Vector2(item.goal))<0.01:
		if item.state=="to_display": item.state="waiting"
		elif item.state=="leaving":
			actor.queue_free()
			customers.erase(item)

func _display_index(item: Dictionary) -> int:
	return 7 if room.is_owned(7) and item.recipe not in room.stock_visual.contents and item.recipe in room.extra_stock_visual.contents else 1

func _adjacent_path(index: int, start: Vector2i, except_id: int, for_cashier: bool) -> Dictionary:
	var best: Array[Vector2i]=[]
	var goal:=Vector2i(-1,-1)
	for direction in DIRECTIONS:
		var candidate: Vector2i=room.cells[index]+direction
		if not for_cashier and candidate==_display_staff_cell(index): continue
		if _blocked(candidate,except_id,for_cashier): continue
		var path:=_path(start,candidate,except_id,for_cashier)
		if not path.is_empty() and (best.is_empty() or path.size()<best.size()):
			best=path
			goal=candidate
	return {"path":best,"goal":goal}

func _send_to_display(item: Dictionary) -> bool:
	var result:=_adjacent_path(_display_index(item),Vector2i(item.pos.round()),item.id,false)
	if result.path.is_empty():
		status="Нет прохода к витрине"
		return false
	item.state="to_display"
	item.route=result.path
	item.goal=result.goal
	item.wait_left=30.0
	return true

func _find(id: int) -> Dictionary:
	for item in customers:
		if int(item.id)==id: return item
	return {}

func _go_cashier(goal: Vector2i, phase: String) -> bool:
	var path:=_path(Vector2i(cashier_position.round()),goal,-1,true)
	if path.is_empty(): return false
	cashier_goal=goal
	cashier_route=path
	cashier_phase=phase
	return true

func _step_cashier(delta: float) -> void:
	if task_id>=0:
		var current:=_find(task_id)
		if current.is_empty() or current.state=="leaving":
			task_id=-1
			cashier_phase="idle"
			cashier_route.clear()
			room.clear_work_status(3)
	if cashier_phase in ["to_delivery","return"] and cashier_route.is_empty() and cashier_position.distance_to(Vector2(cashier_goal))>0.01:
		cashier_route=_path(Vector2i(cashier_position.round()),cashier_goal,-1,true)
		if cashier_route.is_empty():
			status="Освободи проход для кассира"
			return
	cashier.working=false
	cashier.walking=not cashier_route.is_empty()
	if not cashier_route.is_empty():
		var next: Vector2i=cashier_route[0]
		if _blocked(next,-1,true):
			cashier_route=_path(Vector2i(cashier_position.round()),cashier_goal,-1,true)
			cashier.walking=false
			return
		cashier.facing_left=room.project(Vector2(next)).x<room.project(cashier_position).x
		cashier_position=cashier_position.move_toward(Vector2(next),delta*walking_speed)
		if cashier_position.distance_to(Vector2(next))<0.001: cashier_route.pop_front()
		if not cashier_route.is_empty(): return
	if cashier_phase=="to_delivery":
		cashier_phase="delivery"
		task_duration=1.2*work_factor
		task_remaining=task_duration
	elif cashier_phase=="return": cashier_phase="idle"
	if cashier_phase in ["order","delivery"]:
		var item:=_find(task_id)
		if item.is_empty() or item.state=="leaving":
			cashier_phase="idle"
			task_id=-1
			room.clear_work_status(3)
			return
		cashier.working=true
		task_remaining=maxf(0,task_remaining-delta)
		status="Принимает заказ" if cashier_phase=="order" else "Выдаёт "+Catalog.get_recipe(item.recipe).title
		if cashier_phase=="order": room.show_work_status(3,status,1-task_remaining/task_duration)
		else: room.clear_work_status(3)
		cashier.role_label.text="Выдача · %d сек." % ceili(task_remaining) if cashier_phase=="delivery" else "Кассир"
		if task_remaining>0: return
		if cashier_phase=="order":
			_send_to_display(item)
		else:
			if game._sell_recipe(item.recipe): leave(item,true)
			else: item.state="waiting"
		cashier_phase="idle"
		task_id=-1
		room.clear_work_status(3)
		cashier.role_label.text="Кассир"
		return
	for item in customers:
		if item.state=="waiting" and game.inventory.count_of(item.recipe)>0:
			var result:=_adjacent_path(_display_index(item),Vector2i(cashier_position.round()),-1,true)
			if not result.path.is_empty():
				task_id=item.id
				item.state="handover"
				cashier_goal=result.goal
				cashier_route=result.path
				cashier_phase="to_delivery"
				status="Идёт к витрине"
				return
	var register_cell:=_register_cell()
	if register_cell.x<0:
		status="Нет места для кассира у кассы"
		return
	if cashier_position.distance_to(Vector2(register_cell))>0.01:
		if _go_cashier(register_cell,"return"): status="Возвращается к кассе"
		else:
			status="Освободи проход к кассе"
			if not game.busy: room.park_chef()
		return
	var waiting:=queue_items()
	if not waiting.is_empty() and waiting[0].state=="counter":
		task_id=waiting[0].id
		task_duration=2.0*work_factor
		task_remaining=task_duration
		cashier_phase="order"
		status="Принимает заказ"
	else: status="Ждёт покупателя у кассы"

func leave(item: Dictionary, paid: bool) -> void:
	if item.state=="leaving": return
	item.paid=paid
	item.node.paid=paid
	item.state="leaving"
	_route_to_exit(item)
	item.node.waiting=false
	if paid: served+=1
	else: left_unserved+=1

func missing_orders() -> Dictionary:
	var demand: Dictionary={}
	for item in customers:
		if item.state!="leaving": demand[item.recipe]=int(demand.get(item.recipe,0))+1
	var missing: Dictionary={}
	for id in demand:
		var count: int=int(demand[id])-game.inventory.count_of(id)
		if count>0: missing[id]=count
	return missing

func needed_recipe() -> String:
	var missing:=missing_orders()
	for item in customers:
		if item.state!="leaving" and missing.has(item.recipe): return item.recipe
	return ""

func summary() -> String:
	var text:="Покупатели: %d/%d · %s: %s" % [customers.size(),capacity,"кассир" if cashier_enabled else "кондитер",status]
	var missing:=missing_orders()
	if not missing.is_empty():
		var parts:=PackedStringArray()
		for id in missing: parts.append("%s × %d" % [Catalog.get_recipe(id).title,missing[id]])
		text+="\nНе хватает: "+" · ".join(parts)
	return text

func refresh_positions() -> void:
	if cashier==null or room==null: return
	cashier.unit=room.unit
	cashier.position=room.project(cashier_position+Vector2(0.5,0.5))
	cashier.z_index=int(floorf(cashier_position.x+cashier_position.y))+1
	var waiting:=queue_items()
	for item in customers:
		var actor: Node2D=item.node
		actor.unit=room.unit
		actor.position=room.project(Vector2(item.pos)+Vector2(0.5,0.5))
		actor.z_index=int(floorf(item.pos.x+item.pos.y))+1
		actor.waiting=item.state!="leaving"
		actor.wait_seconds=ceili(item.wait_left)
		actor.shortfall=item.state!="leaving" and game.inventory.count_of(item.recipe)==0
		actor.queue_number=waiting.find(item)+1 if item.state in ["queue","counter"] else 0
		actor.phase_label=""
		if item.state in ["queue","counter"]: actor.phase_label="№%d · у кассы" % (waiting.find(item)+1)
		elif item.state in ["to_display","waiting","handover"]: actor.phase_label="Нет в витрине" if actor.shortfall else ("Выдача" if item.state=="handover" else "У витрины")
	_arrange_bubbles()

func clear_customers() -> void:
	if using_chef: _release_chef()
	for item in customers: item.node.queue_free()
	customers.clear()
	cashier_route.clear()
	cashier_phase="idle"
	task_id=-1
	arrival_remaining=1.5
	room.clear_work_status(3)

func _display_staff_cell(index: int) -> Vector2i:
	for direction in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
		var cell: Vector2i=room.cells[index]+direction
		if room._inside(cell) and not room.is_equipment_at(cell): return cell
	return Vector2i(-1,-1)

func relocate_cashier() -> void:
	var post:=_register_cell()
	if post.x>=0: cashier_position=Vector2(post)
	cashier_goal=post
	cashier_route.clear()
	refresh_positions()

func _route_to_exit(item: Dictionary) -> void:
	item.goal=item.entry
	var best: Array[Vector2i]=[]
	for x in range(6):
		var exit:=Vector2i(x,5)
		if _blocked(exit,item.id,false): continue
		var path:=_path(Vector2i(item.pos.round()),exit,item.id,false)
		if not path.is_empty() and (best.is_empty() or path.size()<best.size()):
			item.goal=exit
			best=path
	item.route=best

func _arrange_bubbles() -> void:
	var occupied: Array[Rect2]=[]
	for badge in [room.display_badge,room.extra_display_badge]:
		if badge!=null and badge.visible: occupied.append(badge.get_rect().grow(3))
	if cashier!=null and cashier.visible:
		occupied.append(Rect2(cashier.position+cashier.role_label.position,cashier.role_label.size).grow(3))
	var area: Rect2=room.play_area if room.play_area.has_area() else Rect2(Vector2.ZERO,room.size)
	for item in customers:
		var actor: Node2D=item.node
		var dimensions: Vector2=actor.bubble.get_minimum_size()
		var base: Vector2=actor.position+Vector2(-dimensions.x/2,-room.unit*2.35)
		actor.bubble_offset=Vector2.ZERO
		for offset in [Vector2.ZERO,Vector2(-room.unit*1.7,0),Vector2(room.unit*1.7,0),Vector2(0,-dimensions.y-5),Vector2(0,dimensions.y+5),Vector2(-room.unit*3.4,0),Vector2(room.unit*3.4,0)]:
			var at: Vector2=base+offset
			at.x=clampf(at.x,area.position.x+4,maxf(area.position.x+4,area.end.x-dimensions.x-4))
			at.y=clampf(at.y,area.position.y+4,maxf(area.position.y+4,area.end.y-dimensions.y-4))
			var rect:=Rect2(at,dimensions).grow(2)
			var overlap:=false
			for other in occupied:
				if rect.intersects(other):
					overlap=true
					break
			if not overlap:
				actor.bubble_offset=at-base
				occupied.append(rect)
				break

func _chef_can_serve() -> bool:
	if using_chef: return true
	if game.taking_order or (game.busy and (game.production_phase not in ["baking","cooling"] or game.remaining<=0)): return false
	for item in customers:
		if item.state=="counter" or (item.state=="waiting" and game.inventory.count_of(item.recipe)>0): return true
	return false

func _borrow_chef() -> void:
	using_chef=true
	chef_shift_elapsed=0
	cashier_position=room.chef_position
	cashier_route.clear()
	cashier_phase="idle"
	room.walking=false
	room.route.clear()
	game.taking_order=true
	room.busy=true
	game.layout_button.disabled=false

func _release_chef() -> void:
	if not using_chef: return
	var item:=_find(task_id)
	if not item.is_empty() and item.state=="handover": item.state="waiting"
	using_chef=false
	cashier_phase="idle"
	cashier_route.clear()
	task_id=-1
	room.chef_position=cashier_position
	room.chef.working=false
	room.chef.walking=false
	game.taking_order=false
	room.busy=game.busy
	game.layout_button.disabled=false
	room.clear_work_status(3)
	cashier_enabled=level>=4 and cashier_hired
	cashier.visible=cashier_enabled and not room.editing
	if cashier_enabled:
		relocate_cashier()
		if not game.busy: room.park_chef()
	game.order_service_finished.emit()

func actor_at(cell: Vector2i) -> bool:
	if cashier_enabled and cell==Vector2i(cashier_position.round()): return true
	for item in customers:
		if cell==Vector2i(item.pos.round()): return true
	return false

func resume_layout() -> void:
	if using_chef: _release_chef()
	cashier_phase="idle"
	cashier_route.clear()
	task_id=-1
	cashier.working=false
	cashier.walking=false
	cashier.role_label.text="Кассир"
	room.clear_work_status(3)
	for item in customers:
		item.route=[]
		if item.state in ["queue","counter"]: item.state="queue"
		elif item.state in ["to_display","waiting","handover"]:
			item.state="to_display"
			item.needs_pickup_route=true
		elif item.state=="leaving": _route_to_exit(item)
	_update_queue_goals()
