extends Control
var game: Control
var step:=-1
var target: Button
var hint: Label
var portrait: TextureRect
var dialog: Control
var action: Button
var body: Label
var focused_step:=-1
var intro_remaining:=0.0
var focus_elapsed:=0.0
var pan_start:=Vector2.ZERO
var pan_goal:=Vector2.ZERO
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index=900
	mouse_filter=Control.MOUSE_FILTER_STOP
	target=Button.new()
	target.text=""
	var outline:=StyleBoxFlat.new()
	outline.bg_color=Color(1,0.85,0.4,0.08)
	outline.border_color=Color("bf8c38")
	outline.set_border_width_all(3)
	outline.set_corner_radius_all(12)
	for state in ["normal","hover","pressed"]: target.add_theme_stylebox_override(state,outline)
	target.pressed.connect(_target_pressed)
	add_child(target)
	hint=Label.new()
	hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color",Color("344b3f"))
	hint.add_theme_font_size_override("font_size",24)
	var background:=StyleBoxFlat.new()
	background.bg_color=Color("fff9ed")
	background.set_corner_radius_all(24)
	background.set_content_margin_all(24)
	background.border_color=Color("e1c994")
	background.set_border_width_all(2)
	background.shadow_color=Color(0.2,0.15,0.08,0.18)
	background.shadow_size=5
	background.shadow_offset=Vector2(0,4)
	hint.add_theme_stylebox_override("normal",background)
	add_child(hint)
	portrait=TextureRect.new()
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var crop:=AtlasTexture.new()
	crop.atlas=preload("res://assets/chef.png")
	crop.region=Rect2(170,0,540,660)
	portrait.texture=crop
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var shader:=Shader.new()
	shader.code="shader_type canvas_item; void fragment(){vec4 c=texture(TEXTURE,UV); c.a=smoothstep(0.90,0.99,c.a); COLOR=c;}"
	var material:=ShaderMaterial.new()
	material.shader=shader
	portrait.material=material
	add_child(portrait)
	dialog=preload("res://modal_panel.gd").new()
	get_parent().add_child(dialog)
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("fff9ed")
	style.set_corner_radius_all(14)
	style.set_content_margin_all(24)
	dialog.panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",20)
	dialog.panel.add_child(box)
	body=Label.new()
	body.custom_minimum_size.x=360
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color",Color("344b3f"))
	body.add_theme_font_size_override("font_size",22)
	box.add_child(body)
	action=Button.new()
	action.custom_minimum_size.y=52
	action.pressed.connect(_act)
	box.add_child(action)
	hide()
func active() -> bool: return step>=0 and step<5
func begin(value: int=0) -> void:
	game.scale=Vector2.ONE
	game.position=Vector2.ZERO
	step=value
	focused_step=-1
	intro_remaining=2.2 if value==0 else 0.0
	target.visible=false
	hint.visible=false
	portrait.visible=false
	if value==0:
		game.room.overview=true
		game.room.pan_offset=Vector2.ZERO
		game.room._arrange()
	visible=active()
	if not active(): return
	var service=game.room.service
	if service.customers.is_empty(): service.spawn_customer("croissant")
	if not service.customers.is_empty():
		var buyer: Dictionary=service.customers[0]
		buyer.route=[]
		buyer.pos=Vector2(buyer.goal)
		buyer.state="counter"
		buyer.node.wait_seconds=-1
		service.refresh_positions()
	if step==3 and not game.busy and game.job_queue.waiting.is_empty():
		if game.inventory.count_of("croissant")>0: step=4
		else: game._start_batch("croissant")
	game._sync_room_input()
func advance(value: int) -> void:
	if step==0 and value==1:
		game.room.overview=false
		game.room._arrange()
	step=value
	focused_step=-1
	visible=active()
	game._save_progress()
	game._sync_room_input()
func _process(delta: float) -> void:
	if not active(): return
	if intro_remaining>0:
		intro_remaining=maxf(0,intro_remaining-delta)
		target.hide()
		hint.hide()
		portrait.hide()
		queue_redraw()
		return
	target.show()
	hint.show()
	portrait.show()
	if step==3 and not game.busy and game.job_queue.waiting.is_empty() and game.inventory.count_of("croissant")>0: advance(4)
	var room=game.room
	var center:=Vector2.ZERO
	if focused_step!=step:
		focus_elapsed=0
		pan_start=room.pan_offset
		pan_goal=pan_start
		focused_step=step
		if step>0:
			var focus_cell: Vector2=Vector2(room.cells[0])+Vector2(0.5,0.5)
			if step==1 and not room.service.customers.is_empty(): focus_cell=Vector2(room.service.customers[0].pos)+Vector2(0.5,0.5)
			elif step==4: focus_cell=Vector2(room.cells[1])+Vector2(0.5,0.5)
			pan_goal+=room.play_area.get_center()-room.project(focus_cell)+Vector2(0,room.unit*0.6)
	focus_elapsed+=delta
	var amount:=clampf(focus_elapsed/0.7,0,1)
	var eased:=1-pow(1-amount,3)
	hint.modulate.a=1.0
	portrait.modulate.a=hint.modulate.a
	if step==0:
		target.icon=null
		game.scale=Vector2.ONE
		game.position=Vector2.ZERO
		target.position=game.tasks_button.global_position-Vector2(6,6)
		target.size=game.tasks_button.size+Vector2(12,12)
		hint.text="Выполняйте задания, чтобы повышать уровень.\nНажмите на значок заданий."
	else:
		game.scale=Vector2.ONE
		game.position=Vector2.ZERO
		target.icon=null
		room.pan_offset=pan_start.lerp(pan_goal,eased)
		room._arrange()
		var cell: Vector2=Vector2(room.cells[0])+Vector2(0.5,0.5)
		if step==1 and not room.service.customers.is_empty(): cell=Vector2(room.service.customers[0].pos)+Vector2(0.5,0.5)
		elif step==4: cell=Vector2(room.cells[1])+Vector2(0.5,0.5)
		center=game.get_global_transform()*(room.project(cell)-Vector2(0,room.unit*0.8))
		target.size=Vector2(room.unit*1.65,room.unit*2.3)*game.scale
		target.position=center-target.size*0.5
		hint.text={1:"Нажмите на покупателя",2:"Нажмите на печь, чтобы приготовить партию",3:"Кондитер готовит первую партию…",4:"Нажмите на витрину, чтобы выдать заказ"}.get(step,"")
	target.disabled=step==3
	var face_size:=120.0 if size.x<900 else 144.0
	var card_width:=minf(560,size.x-face_size-72)
	hint.size=Vector2(card_width,0)
	hint.custom_minimum_size=Vector2(card_width,150)
	hint.size.y=maxf(150,hint.get_combined_minimum_size().y)
	var group_width:=face_size+24+card_width
	var group_left: float=(size.x-group_width)*0.5
	var card_y: float=(size.y-hint.size.y)*0.5 if step==0 else maxf(game.top_panel.position.y+game.top_panel.size.y+24,target.position.y-hint.size.y-84)
	if step>0 and card_y+hint.size.y>target.position.y-32: card_y=target.position.y+target.size.y+84
	card_y=clampf(card_y,16,size.y-hint.size.y-16)
	hint.position=Vector2(group_left+face_size+24,card_y)
	portrait.size=Vector2.ONE*face_size
	portrait.position=Vector2(group_left,card_y+(hint.size.y-face_size)*0.5)
	queue_redraw()

func _draw() -> void:
	if not active() or target==null or intro_remaining>0: return
	var face_center:=portrait.position+portrait.size*0.5
	draw_circle(face_center,portrait.size.x*0.53,Color("75975b"))
	draw_arc(face_center,portrait.size.x*0.53,0,TAU,64,Color("d7c78f"),4,true)
	var edge:=Vector2(hint.position.x,hint.position.y+hint.size.y*0.5)
	var tail:=PackedVector2Array([edge+Vector2(2,-16),edge+Vector2(-20,0),edge+Vector2(2,16)])
	draw_colored_polygon(tail,Color("fff9ed"))
	draw_polyline(PackedVector2Array([edge+Vector2(0,-16),edge+Vector2(-20,0),edge+Vector2(0,16)]),Color("e1c994"),2,true)
	if step!=3:
		var below:=hint.position.y>target.position.y
		var direction:=Vector2.UP if below else Vector2.DOWN
		var side:=Vector2(-direction.y,direction.x)
		var tip:=Vector2(target.position.x+target.size.x*0.5,target.position.y+target.size.y+14 if below else target.position.y-14)
		tip-=direction*(3+3*sin(focus_elapsed*4))
		var arrow:=PackedVector2Array([tip,tip-direction*25+side*25,tip-direction*25+side*11,tip-direction*60+side*11,tip-direction*60-side*11,tip-direction*25-side*11,tip-direction*25-side*25])
		draw_colored_polygon(arrow,Color("8ee34a"))
		var border:=PackedVector2Array(arrow)
		border.append(arrow[0])
		draw_polyline(border,Color("f7f4bf"),3,true)

func _target_pressed() -> void:
	if intro_remaining>0: return
	if step==0: game._open_tasks()
	elif step==1:
		body.text="Первый заказ\nКруассан × 1\n\nПосетитель ждёт свежую выпечку."
		action.text="Принять"
		dialog.popup_centered(Vector2i(420,260))
	elif step==2:
		advance(3)
		game._start_batch("croissant")
	elif step==4:
		body.text="Заказ готов\nКруассан × 1\nВ витрине: %d\n\nЗа продажу: 15 монет и 5 опыта" % game.inventory.count_of("croissant")
		action.text="Отдать"
		dialog.popup_centered(Vector2i(420,280))
func _act() -> void:
	dialog.hide()
	if step==1: advance(2)
	elif step==4:
		if not game._sell_recipe("croissant"): return
		var service=game.room.service
		if not service.customers.is_empty():
			var buyer: Dictionary=service.customers[0]
			buyer.paid=true
			service.leave(buyer,true)
		game.scale=Vector2.ONE
		game.position=Vector2.ZERO
		advance(5)
		game.auto_restock=true
		game.room.pan_offset=Vector2.ZERO
		game.room._arrange()
		game.unlock_notice.text="Отлично! Теперь кондитер работает самостоятельно. Открывай задания и развивай кондитерскую."
		game.unlock_notice.visible=true
		game.notice_remaining=10
		game._save_progress()
