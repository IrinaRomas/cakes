extends Node2D

const Icons=preload("res://pastry_icons.gd")
const IDS=["croissant","cookie","cupcake","mousse"]
var contents: Array[String]=[]
const ANCHOR=Vector2(455,695)

func set_stock(stock: Dictionary) -> void:
	contents.clear()
	for id in IDS:
		for i in range(int(stock.get(id,0))):
			if contents.size()<18: contents.append(id)
	queue_redraw()

func _draw() -> void:
	for i in range(contents.size()):
		var row:=i/6
		var column:=i%6
		var t:=(column+0.5)/6.0
		var baseline: float=[283,390,457][row]
		var point:=Vector2(205+295*t,baseline+170*t-14)-ANCHOR
		Icons.draw_food(self,contents[i],point,43)
