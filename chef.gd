extends Node2D

var step_phase := 0.0
var walking := false
var working := false
var carrying := false
var carried_count := 1
var quantity_label: Label
var carried_recipe := "croissant"
var carrying_dough := false
var facing_left := false
var unit := 48.0
var picture: Sprite2D

func _ready() -> void:
	picture = Sprite2D.new()
	picture.texture = preload("res://assets/chef.png")
	# Strip the generated low-opacity halo at display time; keep the source intact.
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ vec4 c=texture(TEXTURE,UV); c.a=smoothstep(0.90,0.99,c.a); COLOR=c; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	picture.material = material
	add_child(picture)
	quantity_label = Label.new()
	quantity_label.add_theme_font_size_override("font_size", 12)
	quantity_label.add_theme_color_override("font_color", Color("344b3f"))
	quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := StyleBoxFlat.new()
	badge.bg_color = Color("fff9ed")
	badge.set_corner_radius_all(5)
	quantity_label.add_theme_stylebox_override("normal", badge)
	add_child(quantity_label)

func _process(delta: float) -> void:
	step_phase += delta * (11.0 if walking else 5.0)
	var bob := absf(sin(step_phase)) * unit * 0.045 if walking or working else 0.0
	picture.scale = Vector2.ONE * unit * 1.8 / picture.texture.get_height()
	picture.flip_h = facing_left
	picture.position = Vector2(0, -unit * 0.88 - bob)
	picture.rotation = sin(step_phase) * 0.025 if walking else 0.0
	quantity_label.visible = carrying and carried_count > 1
	quantity_label.text = "×%d" % carried_count
	quantity_label.position = Vector2(-unit * 0.7 if facing_left else unit * 0.3, -unit * 0.9)
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, unit * 0.25, Color(0.2, 0.25, 0.18, 0.18))
	draw_set_transform(Vector2.ZERO)
	if carrying:
		var center := Vector2(-unit * 0.24 if facing_left else unit * 0.24, -unit * 0.72)
		draw_ellipse_tray(center)

func draw_ellipse_tray(center: Vector2) -> void:
	draw_style_box(_tray_style(),Rect2(center-Vector2(unit*0.48,unit*0.10),Vector2(unit*0.96,unit*0.23)))
	var count:=mini(carried_count,8)
	var columns:=4 if count>6 else 3
	for i in range(count):
		var row:=i/columns
		var column:=i%columns
		var point:=center+Vector2((column-(columns-1)*0.5)*(0.22 if columns==4 else 0.27),(row-0.5)*0.17-0.07)*unit
		preload("res://pastry_icons.gd").draw_food(self,carried_recipe,point,unit*0.20,carrying_dough)

func _tray_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d7dad6")
	style.set_corner_radius_all(5)
	return style
