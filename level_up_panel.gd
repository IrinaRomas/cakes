extends Control
const Progression=preload("res://progression.gd")
const Food=preload("res://pastry_icons.gd")
var level:=2
var reward:=80
var opened: Array[Dictionary]=[]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index=1100
	focus_mode=Control.FOCUS_ALL
	mouse_filter=Control.MOUSE_FILTER_STOP
	hide()
	resized.connect(queue_redraw)

func show_level(value: int, coins: int) -> void:
	level=value
	reward=coins
	opened.clear()
	match level:
		2: opened.assign([{"icon":"cookie","title":"Печенье"},{"icon":"★","title":"Формовочный стол"},{"icon":"★","title":"Вторая витрина"}])
		3: opened.assign([{"icon":"cupcake","title":"Капкейки"},{"icon":"2","title":"Второй покупатель"},{"icon":"★","title":"Стол декора"}])
		4: opened.assign([{"icon":"mousse","title":"Мусс"},{"icon":"★","title":"Найм кассира"},{"icon":"❄","title":"Холодильник"}])
		5: opened.assign([{"icon":"★","title":"Скорость персонала"},{"icon":"★","title":"Сноровка"}])
		6: opened.assign([{"icon":"3","title":"Третий покупатель"},{"icon":"★","title":"Улучшение печи"},{"icon":"★","title":"Полки витрин"}])
		7: opened.assign([{"icon":"★","title":"Найм помощника"},{"icon":"★","title":"Рабочее место"}])
		8: opened.assign([{"icon":"8","title":"Больше поручений"},{"icon":"★","title":"Терпение гостей"}])
	get_parent().move_child(self,-1)
	show()
	grab_focus()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed) or event.is_action_pressed("ui_accept"):
		accept_event()
		hide()

func _text(text: String, at: Vector2, font_size: int, color: Color=Color.WHITE) -> void:
	var font:=ThemeDB.fallback_font
	var width:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string_outline(font,at-Vector2(width*0.5,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color("302033"))
	draw_string(font,at-Vector2(width*0.5,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.08,0.06,0.03,0.82))
	var scale_factor:=minf(size.x/1000.0,size.y/700.0)
	draw_set_transform((size-Vector2(1000,700)*scale_factor)*0.5,0,Vector2.ONE*scale_factor)
	for radius in range(210,20,-12):
		draw_circle(Vector2(500,150),radius,Color(1.0,0.78,0.3,0.012))
	var ribbon:=StyleBoxFlat.new()
	ribbon.bg_color=Color("8950d5")
	ribbon.border_color=Color("ffd351")
	ribbon.set_border_width_all(5)
	ribbon.set_corner_radius_all(26)
	for x in [180,820]:
		var direction: float=-1 if x<500 else 1
		var tail:=PackedVector2Array([Vector2(x,187),Vector2(x+direction*50,201),Vector2(x+direction*33,232),Vector2(x+direction*50,262),Vector2(x,253)])
		draw_colored_polygon(tail,Color("6934b6"))
	Food.draw_food(self,"croissant",Vector2(374,154),110)
	Food.draw_food(self,"cupcake",Vector2(621,148),100)
	draw_style_box(ribbon,Rect2(210,178,580,86))
	var star:=PackedVector2Array()
	for i in range(10):
		var angle: float=-PI/2+i*PI/5
		star.append(Vector2(500,123)+Vector2(cos(angle),sin(angle))*(85 if i%2==0 else 44))
	draw_colored_polygon(star,Color("31aa48"))
	var border:=star.duplicate()
	border.append(star[0])
	draw_polyline(border,Color("ffd351"),9,true)
	_text(str(level),Vector2(500,145),60)
	_text("Новый уровень",Vector2(500,234),38)
	draw_circle(Vector2(520,319),22,Color("eaa928"))
	draw_arc(Vector2(520,319),17,0,TAU,32,Color("ffe47a"),3,true)
	_text("Награда:",Vector2(419,329),27)
	_text(str(reward),Vector2(583,329),28)
	for i in range(opened.size()):
		var x: float=500+(i-(opened.size()-1)*0.5)*230
		var item: Dictionary=opened[i]
		draw_circle(Vector2(x,440),62,Color(1,0.85,0.55,0.09))
		if item.icon in ["cookie","cupcake","mousse"]: Food.draw_food(self,item.icon,Vector2(x,435),100)
		else: _text(item.icon,Vector2(x,462),64,Color("ffdb66"))
		var badge:=StyleBoxFlat.new()
		badge.bg_color=Color("e31b85")
		badge.set_corner_radius_all(8)
		draw_style_box(badge,Rect2(x-66,481,78,28))
		_text("НОВОЕ",Vector2(x-27,501),16)
		_text(item.title,Vector2(x,549),21)
	_text("Нажмите, чтобы продолжить",Vector2(500,638),25,Color("d2c8bb"))
