extends "res://chef.gd"

var bubble_offset:=Vector2.ZERO
var queue_number:=0
var phase_label:=""
var shortfall:=false
var wait_seconds := -1
var waiting := false
var paid := false
var bubble: Label
var order_title := "Круассан"
var order_price := 15
var order_xp := 5

func _ready() -> void:
	super._ready()
	picture.texture = preload("res://assets/customer.png")
	bubble = Label.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.add_theme_font_size_override("font_size", 15)
	bubble.add_theme_color_override("font_color", Color("344b3f"))
	var background := StyleBoxFlat.new()
	background.bg_color = Color("fff9ed")
	background.set_corner_radius_all(9)
	background.content_margin_left = 8
	background.content_margin_right = 8
	background.content_margin_top = 5
	background.content_margin_bottom = 5
	bubble.add_theme_stylebox_override("normal", background)
	add_child(bubble)

func _process(delta: float) -> void:
	super._process(delta)
	bubble.visible = waiting or paid
	bubble.text = "+%d монет · +%d опыта" % [order_price, order_xp] if paid else "%s × 1" % order_title
	if waiting and wait_seconds >= 0: bubble.text += " · %d сек." % wait_seconds
	if not paid and not phase_label.is_empty(): bubble.text=phase_label+"\n"+bubble.text
	if queue_number>1 and not paid: bubble.text="№%d" % queue_number
	bubble.add_theme_color_override("font_color",Color("a33f37") if shortfall and not paid else Color("344b3f"))
	bubble.size = Vector2.ZERO
	bubble.position = Vector2(-bubble.size.x * 0.5, -unit * 2.35)+bubble_offset

func set_order(recipe: Dictionary) -> void:
	order_title = recipe.title
	order_price = recipe.price
	order_xp = recipe.xp
