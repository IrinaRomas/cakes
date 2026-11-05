extends "res://chef.gd"

var waiting := false
var paid := false
var bubble: Label

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
	bubble.text = "+15 монет · +5 опыта" if paid else "Круассан × 1"
	bubble.size = Vector2.ZERO
	bubble.position = Vector2(-bubble.size.x * 0.5, -unit * 2.35)
