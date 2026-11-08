extends "res://chef.gd"
var role_label: Label
func _ready() -> void:
	super._ready()
	picture.texture=preload("res://assets/cashier.png")
	role_label=Label.new()
	role_label.text="Кассир"
	role_label.z_as_relative=false
	role_label.z_index=120
	role_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	role_label.add_theme_font_size_override("font_size",12)
	role_label.add_theme_color_override("font_color",Color("344b3f"))
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("fff9ed")
	style.set_corner_radius_all(5)
	role_label.add_theme_stylebox_override("normal",style)
	add_child(role_label)
func _process(delta: float) -> void:
	super._process(delta)
	role_label.reset_size()
	role_label.position=Vector2(-role_label.size.x/2,-unit*2.05)
