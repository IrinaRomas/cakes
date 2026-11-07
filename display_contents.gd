extends Node2D

const Icons=preload("res://pastry_icons.gd")
const IDS=["croissant","cookie","cupcake","mousse"]
var capacity:=18
var contents: Array[String]=[]
const ANCHOR=Vector2(455,695)

func set_stock(stock: Dictionary, slots: int=18) -> void:
	capacity=slots
	contents.clear()
	for id in IDS:
		for i in range(int(stock.get(id,0))):
			if contents.size()<capacity: contents.append(id)
	queue_redraw()

func _draw() -> void:
	for i in range(contents.size()):
		var columns:=8 if capacity>18 else 6
		var row:=i/columns
		var column:=i%columns
		var t:=(column+0.5)/float(columns)
		var baseline: float=[283,390,457][row]
		var point:=Vector2(205+295*t,baseline+170*t-14)-ANCHOR
		Icons.draw_food(self,contents[i],point,33 if capacity>18 else 43)
