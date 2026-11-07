extends RefCounted

static func draw_food(canvas: CanvasItem, id: String, at: Vector2, size: float, dough: bool=false) -> void:
	if dough:
		canvas.draw_circle(at,size*0.35,Color("e9c98b"))
		return
	match id:
		"croissant":
			canvas.draw_arc(at+Vector2(0,-size*0.1),size*0.35,0.15,2.99,16,Color("c87b2e"),size*0.25,true)
			canvas.draw_arc(at+Vector2(0,-size*0.12),size*0.34,0.2,2.9,16,Color("edb45e"),size*0.15,true)
			for offset in [-0.18,0.0,0.18]:
				canvas.draw_line(at+Vector2(offset*size,-0.02*size),at+Vector2(offset*size,0.23*size),Color("bd762c"),size*0.035,true)
		"cookie":
			canvas.draw_circle(at,size*0.4,Color("c6873e"))
			canvas.draw_circle(at-Vector2(0,size*0.04),size*0.36,Color("dfb06c"))
			for offset in [Vector2(-0.17,-0.1),Vector2(0.16,-0.15),Vector2(0,0.15),Vector2(0.2,0.14)]:
				canvas.draw_circle(at+offset*size,size*0.055,Color("68422f"))
		"mousse":
			canvas.draw_style_box(_style("d9e7e6"),Rect2(at+Vector2(-0.32,-0.22)*size,Vector2(0.64,0.65)*size))
			canvas.draw_style_box(_style("edaaa9"),Rect2(at+Vector2(-0.27,-0.17)*size,Vector2(0.54,0.51)*size))
			canvas.draw_circle(at-Vector2(0,size*0.23),size*0.28,Color("f6cfc6"))
			canvas.draw_circle(at+Vector2(0.08,-0.4)*size,size*0.11,Color("be4f50"))
		_:
			canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(-0.33,0)*size,at+Vector2(0.33,0)*size,at+Vector2(0.24,0.42)*size,at+Vector2(-0.24,0.42)*size]),Color("bd896c"))
			for offset in [Vector2(-0.17,-0.05),Vector2(0.17,-0.05),Vector2(0,-0.24)]:
				canvas.draw_circle(at+offset*size,size*0.24,Color("f1c6bc"))
			canvas.draw_circle(at+Vector2(0,-0.47)*size,size*0.08,Color("bc4c51"))

static func _style(color: String) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(color)
	style.set_corner_radius_all(4)
	return style
