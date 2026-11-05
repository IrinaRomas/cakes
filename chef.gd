extends Node2D

var step_phase := 0.0
var walking := false
var working := false
var carrying := false
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

func _process(delta: float) -> void:
	step_phase += delta * (11.0 if walking else 5.0)
	var bob := absf(sin(step_phase)) * unit * 0.045 if walking or working else 0.0
	picture.scale = Vector2.ONE * unit * 1.8 / picture.texture.get_height()
	picture.flip_h = facing_left
	picture.position = Vector2(0, -unit * 0.88 - bob)
	picture.rotation = sin(step_phase) * 0.025 if walking else 0.0
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, unit * 0.25, Color(0.2, 0.25, 0.18, 0.18))
	draw_set_transform(Vector2.ZERO)
	if carrying:
		var center := Vector2(-unit * 0.24 if facing_left else unit * 0.24, -unit * 0.72)
		draw_ellipse_tray(center)

func draw_ellipse_tray(center: Vector2) -> void:
	draw_style_box(_tray_style(), Rect2(center - Vector2(unit * 0.28, unit * 0.08), Vector2(unit * 0.56, unit * 0.16)))
	draw_arc(center, unit * 0.14, 0.2, 2.9, 12, Color("d99c4c"), unit * 0.10, true)

func _tray_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d7dad6")
	style.set_corner_radius_all(5)
	return style
